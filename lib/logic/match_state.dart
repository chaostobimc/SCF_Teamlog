import '../data/models/match.dart';
import '../data/models/match_event.dart';
import '../data/models/team.dart';

/// Wurf, der gerade aufgeschluesselt wird (Zone getippt, Ergebnis folgt).
class PendingShot {
  const PendingShot({
    required this.goalZone,
    this.courtZone,
    this.isSevenMeter = false,
    this.isFreeThrow = false,
  });

  final GoalZone goalZone;
  final CourtZone? courtZone;
  final bool isSevenMeter;
  final bool isFreeThrow;
}

class MatchState {
  const MatchState({
    required this.match,
    required this.team,
    this.running = false,
    this.selectedPlayerId,
    this.pendingShot,
    this.lastCourtZone,
    this.notice,
    this.noticeStamp,
  });

  final Match match;
  final Team? team;

  /// Spieluhr laeuft gerade.
  final bool running;

  final String? selectedPlayerId;
  final PendingShot? pendingShot;

  /// Zuletzt angetippte Feldzone, wird der naechsten Aktion zugeordnet.
  final CourtZone? lastCourtZone;

  /// Kurzinfo an die Oberflaeche (z. B. Halbzeit erreicht).
  final String? notice;

  /// Zeitstempel der letzten Meldung, damit die UI sie nur einmal zeigt.
  final int? noticeStamp;

  bool get hasPendingShot => pendingShot != null;

  MatchState copyWith({
    Match? match,
    Team? team,
    bool? running,
    String? selectedPlayerId,
    PendingShot? pendingShot,
    bool clearPendingShot = false,
    CourtZone? lastCourtZone,
    bool clearCourtZone = false,
    String? notice,
    bool clearNotice = false,
    int? noticeStamp,
  }) {
    return MatchState(
      match: match ?? this.match,
      team: team ?? this.team,
      running: running ?? this.running,
      selectedPlayerId: selectedPlayerId ?? this.selectedPlayerId,
      pendingShot: clearPendingShot ? null : (pendingShot ?? this.pendingShot),
      lastCourtZone: clearCourtZone ? null : (lastCourtZone ?? this.lastCourtZone),
      notice: clearNotice ? null : (notice ?? this.notice),
      noticeStamp: noticeStamp ?? this.noticeStamp,
    );
  }
}
