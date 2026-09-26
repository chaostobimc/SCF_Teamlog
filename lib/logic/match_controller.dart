import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/match.dart';
import '../data/models/match_event.dart';
import '../data/models/team.dart';
import '../data/repositories/match_repository.dart';
import '../core/utils/id_generator.dart';
import 'match_state.dart';

/// Steuerung eines laufenden Spiels: Spieluhr, Phasen, Ereignisse, Undo.
class MatchController extends StateNotifier<MatchState> {
  MatchController(
    this._repository, {
    required Match? match,
    required Team? team,
  })  : assert(match != null, 'MatchController benoetigt ein Match'),
        super(MatchState(match: match!, team: team)) {
    if (match!.status == MatchStatus.laufend) {
      _startTimer();
    }
  }

  final MatchRepository _repository;
  Timer? _ticker;
  int _carryMillis = 0;
  int _ticksSinceSave = 0;

  static const int _halfLengthBonusSec = 5;

  bool get _canRecord =>
      state.match.status == MatchStatus.laufend &&
      state.match.phase != MatchPhase.beendet;

  // ---------------------------------------------------------------- Uhr

  void toggleClock() {
    final match = state.match;
    if (match.status == MatchStatus.beendet ||
        match.phase == MatchPhase.beendet) {
      return;
    }
    if (match.status != MatchStatus.laufend) {
      final started = match.copyWith(status: MatchStatus.laufend);
      _commit(started, keepClockRunning: true);
      _startTimer();
      return;
    }
    if (state.running) {
      _pause();
    } else {
      _startTimer();
    }
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    _persistClock();
    state = state.copyWith(running: false);
  }

  void _startTimer() {
    _ticker?.cancel();
    _carryMillis = 0;
    _ticksSinceSave = 0;
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    state = state.copyWith(running: true);
  }

  void _tick() {
    var match = state.match;
    if (match.status != MatchStatus.laufend || match.phase == MatchPhase.beendet) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }

    _carryMillis += 200;
    final fullSeconds = _carryMillis ~/ 1000;
    if (fullSeconds == 0) return;
    _carryMillis -= fullSeconds * 1000;

    var notice = state.notice;
    var stamp = state.noticeStamp;

    switch (match.phase) {
      case MatchPhase.ersteHalbzeit:
        var elapsed = match.firstHalfSec + fullSeconds;
        if (elapsed >= match.halfLengthSec) {
          elapsed = match.halfLengthSec;
          match = match.copyWith(firstHalfSec: elapsed, phase: MatchPhase.halbzeitpause);
          notice = 'Ende der 1. Halbzeit';
          stamp = DateTime.now().millisecondsSinceEpoch;
          _commit(match, keepClockRunning: false);
          _ticker?.cancel();
          _ticker = null;
          state = state.copyWith(
            match: match,
            running: false,
            notice: notice,
            noticeStamp: stamp,
          );
          return;
        }
        match = match.copyWith(firstHalfSec: elapsed);
        break;
      case MatchPhase.halbzeitpause:
        match = match.copyWith(pauseSec: match.pauseSec + fullSeconds);
        break;
      case MatchPhase.zweiteHalbzeit:
        var elapsed = match.secondHalfSec + fullSeconds;
        if (elapsed >= match.halfLengthSec) {
          elapsed = match.halfLengthSec;
          match = match.copyWith(
            secondHalfSec: elapsed,
            phase: MatchPhase.beendet,
            status: MatchStatus.beendet,
          );
          notice = 'Spielende';
          stamp = DateTime.now().millisecondsSinceEpoch;
          _commit(match, keepClockRunning: false);
          _ticker?.cancel();
          _ticker = null;
          state = state.copyWith(
            match: match,
            running: false,
            notice: notice,
            noticeStamp: stamp,
          );
          return;
        }
        match = match.copyWith(secondHalfSec: elapsed);
        break;
      case MatchPhase.beendet:
        return;
    }

    _ticksSinceSave++;
    final autosave = _ticksSinceSave >= 25;
    if (autosave) _ticksSinceSave = 0;

    state = state.copyWith(match: match);
    if (autosave) _repository.save(match);
  }

  void _persistClock() {
    _repository.save(state.match);
  }

  /// Uebergang zur 2. Halbzeit (manuell, auch vor Ablauf der Zeit).
  void startSecondHalf() {
    final match = state.match;
    if (match.phase == MatchPhase.beendet ||
        match.phase == MatchPhase.zweiteHalbzeit) {
      return;
    }
    final paused = state.running;
    _ticker?.cancel();
    _ticker = null;
    final updated = match.copyWith(phase: MatchPhase.zweiteHalbzeit);
    _commit(updated, keepClockRunning: false);
    state = state.copyWith(
      match: updated,
      running: false,
      clearPendingShot: true,
      notice: '2. Halbzeit',
      noticeStamp: DateTime.now().millisecondsSinceEpoch,
    );
    if (paused) _startTimer();
  }

  void finishMatch() {
    final match = state.match;
    if (match.status == MatchStatus.beendet) return;
    _ticker?.cancel();
    _ticker = null;
    final updated = match.copyWith(
      phase: MatchPhase.beendet,
      status: MatchStatus.beendet,
    );
    _commit(updated, keepClockRunning: false);
    state = state.copyWith(
      match: updated,
      running: false,
      notice: 'Spiel beendet',
      noticeStamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ------------------------------------------------------- Spieler & Zonen

  void selectPlayer(String playerId) {
    final same = state.selectedPlayerId == playerId;
    state = state.copyWith(
      selectedPlayerId: same ? null : playerId,
      clearPendingShot: true,
    );
  }

  /// Tor-Raster angetippt.
  void onGoalZoneTap(GoalZone zone) {
    if (!_canRecord) return;
    final player = _selectedPlayer();
    if (player == null) {
      _notify('Erst Spieler auswählen');
      return;
    }

    if (zone.isOnTarget) {
      final pending = PendingShot(
        goalZone: zone,
        courtZone: _contextCourtZone(),
        isSevenMeter: state.lastCourtZone == CourtZone.siebenMeter,
        isFreeThrow: state.lastCourtZone == CourtZone.freiwurf,
      );
      state = state.copyWith(pendingShot: pending);
    } else {
      // Daneben / Latte: sofortiger Fehlwurf - nur fuer Feldspieler relevant.
      if (player.position == PlayerPosition.torwart) {
        _notify('Daneben - keine Torhüter-Aktion');
        return;
      }
      _recordEvent(
        playerId: player.id,
        type: MatchEventType.fehlwurf,
        goalZone: zone,
        courtZone: _contextCourtZone(),
        isSevenMeter: state.lastCourtZone == CourtZone.siebenMeter,
        isFreeThrow: state.lastCourtZone == CourtZone.freiwurf,
      );
    }
  }

  /// Spielfeld angetippt: Zone merken bzw. laufenden Wurf ergaenzen.
  void onCourtZoneTap(CourtZone zone) {
    if (!_canRecord) return;
    if (zone == CourtZone.siebenMeter || zone == CourtZone.freiwurf) {
      state = state.copyWith(
        lastCourtZone: zone,
        pendingShot: state.pendingShot == null
            ? null
            : PendingShot(
                goalZone: state.pendingShot!.goalZone,
                courtZone: zone,
                isSevenMeter: zone == CourtZone.siebenMeter,
                isFreeThrow: zone == CourtZone.freiwurf,
              ),
      );
      return;
    }
    state = state.copyWith(lastCourtZone: zone);
  }

  /// Wurfkontext ohne Zone setzen (Chips im Aktionspanel).
  void setQuickContext(CourtZone? context) {
    if (context == null) {
      state = state.copyWith(clearCourtZone: true);
      return;
    }
    onCourtZoneTap(context);
  }

  /// Kontextwechsel 7m / Freiwurf / Feldwurf im Aktionspanel.
  void setThrowContext({bool? sevenMeter, bool? freeThrow}) {
    final pending = state.pendingShot;
    if (pending == null) return;
    state = state.copyWith(
      pendingShot: PendingShot(
        goalZone: pending.goalZone,
        courtZone: sevenMeter == true
            ? CourtZone.siebenMeter
            : (freeThrow == true ? CourtZone.freiwurf : pending.courtZone),
        isSevenMeter: sevenMeter ?? pending.isSevenMeter,
        isFreeThrow: freeThrow ?? pending.isFreeThrow,
      ),
    );
  }

  void cancelPendingShot() {
    state = state.copyWith(clearPendingShot: true);
  }

  // ------------------------------------------------------------- Ereignisse

  /// Ergebnis eines aufgeschluesselten Wurfs festhalten.
  void resolvePendingShot(MatchEventType outcome) {
    final pending = state.pendingShot;
    final player = _selectedPlayer();
    if (pending == null || player == null || !_canRecord) return;
    if (player.position == PlayerPosition.torwart) {
      final mapped = _goalkeeperOutcome(outcome, pending);
      if (mapped == null) {
        _notify('Keine passende Torhüter-Aktion');
        return;
      }
      _recordEvent(
        playerId: player.id,
        type: mapped,
        goalZone: pending.goalZone,
        isSevenMeter: pending.isSevenMeter,
        isFreeThrow: pending.isFreeThrow,
      );
      return;
    }
    _recordEvent(
      playerId: player.id,
      type: outcome,
      goalZone: pending.goalZone,
      courtZone: pending.courtZone,
      isSevenMeter: pending.isSevenMeter,
      isFreeThrow: pending.isFreeThrow,
    );
  }

  MatchEventType? _goalkeeperOutcome(MatchEventType outcome, PendingShot pending) {
    switch (outcome) {
      case MatchEventType.tor:
      case MatchEventType.gegentor:
        return pending.isSevenMeter
            ? MatchEventType.gegentorSiebenMeter
            : (pending.isFreeThrow
                ? MatchEventType.gegentorFreiwurf
                : MatchEventType.gegentor);
      case MatchEventType.wurfGehalten:
      case MatchEventType.parade:
        return pending.isSevenMeter
            ? MatchEventType.paradeSiebenMeter
            : (pending.isFreeThrow
                ? MatchEventType.paradeFreiwurf
                : MatchEventType.parade);
      default:
        return null;
    }
  }

  /// Schnellaktion (Technikfehler, Zweikampf, Sanktion ...) festhalten.
  void commitQuickAction(MatchEventType type) {
    if (!_canRecord) return;
    final player = _selectedPlayer();
    if (player == null) {
      _notify('Erst Spieler auswählen');
      return;
    }
    final isKeeperEvent = type.isGoalkeeperAction;
    if (isKeeperEvent && player.position != PlayerPosition.torwart) {
      _notify('Nur für Torhüter');
      return;
    }
    _recordEvent(
      playerId: player.id,
      type: type,
      courtZone: isKeeperEvent ? null : _contextCourtZone(),
      isSevenMeter: state.lastCourtZone == CourtZone.siebenMeter,
      isFreeThrow: state.lastCourtZone == CourtZone.freiwurf,
    );
  }

  void undoLastEvent() {
    final events = state.match.events;
    if (events.isEmpty) return;
    final updated = state.match.copyWith(events: events.sublist(0, events.length - 1));
    final saved = _commit(updated, keepClockRunning: state.running);
    state = state.copyWith(
      match: saved,
      notice: 'Aktion zurückgenommen',
      noticeStamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // --------------------------------------------------------------- intern

  Player? _selectedPlayer() {
    final id = state.selectedPlayerId;
    if (id == null) return null;
    return state.team?.playerById(id);
  }

  CourtZone? _contextCourtZone() {
    final zone = state.lastCourtZone;
    return (zone == CourtZone.siebenMeter || zone == CourtZone.freiwurf)
        ? null
        : zone;
  }

  void _recordEvent({
    required String playerId,
    required MatchEventType type,
    GoalZone? goalZone,
    CourtZone? courtZone,
    bool isSevenMeter = false,
    bool isFreeThrow = false,
  }) {
    final match = state.match;
    final event = MatchEvent(
      id: newId(),
      playerId: playerId,
      type: type,
      matchClockSec: match.matchClockSec,
      phase: match.phase,
      isSevenMeter: isSevenMeter,
      goalZone: goalZone,
      courtZone: courtZone,
      createdAt: DateTime.now(),
    );
    final updated = match.copyWith(events: [...match.events, event]);
    final saved = _commit(updated, keepClockRunning: state.running);
    state = state.copyWith(
      match: saved,
      clearPendingShot: true,
      clearCourtZone: true,
    );
  }

  Match _commit(Match match, {bool keepClockRunning = false}) {
    var toSave = match;
    // Kleine Toleranz damit Wuerfe kurz nach Ablauf noch durchgehen.
    if (!keepClockRunning && toSave.phase != MatchPhase.beendet) {
      final over = toSave.phaseElapsedSec - toSave.halfLengthSec;
      if (over > 0 && over <= _halfLengthBonusSec) {
        switch (toSave.phase) {
          case MatchPhase.ersteHalbzeit:
            toSave = toSave.copyWith(firstHalfSec: toSave.halfLengthSec);
            break;
          case MatchPhase.zweiteHalbzeit:
            toSave = toSave.copyWith(secondHalfSec: toSave.halfLengthSec);
            break;
          default:
            break;
        }
      }
    }
    _repository.save(toSave);
    state = state.copyWith(match: toSave);
    return toSave;
  }

  void _notify(String message) {
    state = state.copyWith(
      notice: message,
      noticeStamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
