import 'package:hive/hive.dart';

import 'match.dart';

/// Wurfzone im Tor (aus Sicht des Werfers bzw. des Tors).
enum GoalZone {
  obenLinks,
  obenMitte,
  obenRechts,
  untenLinks,
  untenMitte,
  untenRechts,
  linksDaneben,
  rechtsDaneben,
  drueber;

  bool get isOnTarget =>
      index <= GoalZone.untenRechts.index;

  String get label {
    switch (this) {
      case GoalZone.obenLinks:
        return 'Oben links';
      case GoalZone.obenMitte:
        return 'Oben Mitte';
      case GoalZone.obenRechts:
        return 'Oben rechts';
      case GoalZone.untenLinks:
        return 'Unten links';
      case GoalZone.untenMitte:
        return 'Unten Mitte';
      case GoalZone.untenRechts:
        return 'Unten rechts';
      case GoalZone.linksDaneben:
        return 'Links vorbei';
      case GoalZone.rechtsDaneben:
        return 'Rechts vorbei';
      case GoalZone.drueber:
        return 'Über die Latte';
    }
  }
}

/// Position auf dem Spielfeld.
enum CourtZone {
  aussenLinks,
  rueckraumLinks,
  rueckraumMitte,
  kreis,
  rueckraumRechts,
  aussenRechts,
  siebenMeter,
  freiwurf;

  String get label {
    switch (this) {
      case CourtZone.aussenLinks:
        return 'Außen links';
      case CourtZone.rueckraumLinks:
        return 'Rückraum links';
      case CourtZone.rueckraumMitte:
        return 'Rückraum Mitte';
      case CourtZone.kreis:
        return 'Kreis';
      case CourtZone.rueckraumRechts:
        return 'Rückraum rechts';
      case CourtZone.aussenRechts:
        return 'Außen rechts';
      case CourtZone.siebenMeter:
        return '7 Meter';
      case CourtZone.freiwurf:
        return 'Freiwurf';
    }
  }
}

/// Ereignistypen mit Fokus auf Wurfqualitaet, Technikfehler, Zweikaempfe,
/// Torhueter-Aktionen und Sanktionen.
enum MatchEventType {
  tor,
  fehlwurf,
  wurfGehalten,
  wurfGeblockt,
  schrittfehler,
  prellfehler,
  stuermerfoul,
  ballverlust,
  gefoult,
  siebenMeterHerausgeholt,
  duelGewonnen,
  parade,
  paradeSiebenMeter,
  paradeFreiwurf,
  gegentor,
  gegentorSiebenMeter,
  gegentorFreiwurf,
  gelbeKarte,
  zeitstrafe,
  roteKarte,
  blaueKarte;

  String get label {
    switch (this) {
      case MatchEventType.tor:
        return 'Tor';
      case MatchEventType.fehlwurf:
        return 'Fehlwurf';
      case MatchEventType.wurfGehalten:
        return 'Wurf gehalten';
      case MatchEventType.wurfGeblockt:
        return 'Wurf geblockt';
      case MatchEventType.schrittfehler:
        return 'Schrittfehler';
      case MatchEventType.prellfehler:
        return 'Prellfehler';
      case MatchEventType.stuermerfoul:
        return 'Stürmerfoul';
      case MatchEventType.ballverlust:
        return 'Ballverlust';
      case MatchEventType.gefoult:
        return 'Gefoult worden';
      case MatchEventType.siebenMeterHerausgeholt:
        return '7m herausgeholt';
      case MatchEventType.duelGewonnen:
        return 'Duell gewonnen';
      case MatchEventType.parade:
        return 'Parade';
      case MatchEventType.paradeSiebenMeter:
        return '7m-Parade';
      case MatchEventType.paradeFreiwurf:
        return 'Freiwurf-Parade';
      case MatchEventType.gegentor:
        return 'Gegentor';
      case MatchEventType.gegentorSiebenMeter:
        return '7m-Gegentor';
      case MatchEventType.gegentorFreiwurf:
        return 'Freiwurf-Gegentor';
      case MatchEventType.gelbeKarte:
        return 'Gelbe Karte';
      case MatchEventType.zeitstrafe:
        return '2-Minuten-Strafe';
      case MatchEventType.roteKarte:
        return 'Rote Karte';
      case MatchEventType.blaueKarte:
        return 'Blaue Karte';
    }
  }

  /// Kurzkennung fuer kompakte Schaltflaechen und Listen.
  String get shortLabel {
    switch (this) {
      case MatchEventType.siebenMeterHerausgeholt:
        return '7m geholt';
      case MatchEventType.duelGewonnen:
        return 'Duell';
      case MatchEventType.paradeSiebenMeter:
        return '7m-Parade';
      case MatchEventType.paradeFreiwurf:
        return 'FW-Parade';
      case MatchEventType.gegentorSiebenMeter:
        return '7m-Gegentor';
      case MatchEventType.gegentorFreiwurf:
        return 'FW-Gegentor';
      case MatchEventType.zeitstrafe:
        return '2 min';
      default:
        return label;
    }
  }

  bool get isGoalkeeperAction =>
      index >= MatchEventType.parade.index &&
      index <= MatchEventType.gegentorFreiwurf.index;

  bool get isSanction =>
      index >= MatchEventType.gelbeKarte.index;

  /// Wurfaktive Aktionen (Tor, daneben, gehalten, geblockt).
  bool get isShotAction =>
      this == MatchEventType.tor ||
      this == MatchEventType.fehlwurf ||
      this == MatchEventType.wurfGehalten ||
      this == MatchEventType.wurfGeblockt;

  /// Positive Wertung fuer Feldspieler bzw. Torhueter.
  bool get isPositive {
    switch (this) {
      case MatchEventType.tor:
      case MatchEventType.gefoult:
      case MatchEventType.siebenMeterHerausgeholt:
      case MatchEventType.duelGewonnen:
      case MatchEventType.parade:
      case MatchEventType.paradeSiebenMeter:
      case MatchEventType.paradeFreiwurf:
        return true;
      default:
        return false;
    }
  }
}

class MatchEvent {
  MatchEvent({
    required this.id,
    required this.playerId,
    required this.type,
    required this.matchClockSec,
    required this.phase,
    this.isSevenMeter = false,
    this.goalZone,
    this.courtZone,
    required this.createdAt,
  });

  final String id;
  final String playerId;
  final MatchEventType type;

  /// Netto-Spielzeit (Summe beider Halbzeiten) in Sekunden.
  final int matchClockSec;
  final MatchPhase phase;

  /// Wurf gehoerte zu einem 7-Meter.
  final bool isSevenMeter;
  final GoalZone? goalZone;
  final CourtZone? courtZone;
  final DateTime createdAt;

  MatchEvent copyWith({
    String? playerId,
    MatchEventType? type,
    int? matchClockSec,
    MatchPhase? phase,
    bool? isSevenMeter,
    GoalZone? goalZone,
    CourtZone? courtZone,
  }) {
    return MatchEvent(
      id: id,
      playerId: playerId ?? this.playerId,
      type: type ?? this.type,
      matchClockSec: matchClockSec ?? this.matchClockSec,
      phase: phase ?? this.phase,
      isSevenMeter: isSevenMeter ?? this.isSevenMeter,
      goalZone: goalZone ?? this.goalZone,
      courtZone: courtZone ?? this.courtZone,
      createdAt: createdAt,
    );
  }

  factory MatchEvent.fromMap(Map<dynamic, dynamic> map) {
    final goalZoneIdx = map['goalZone'] as int?;
    final courtZoneIdx = map['courtZone'] as int?;
    return MatchEvent(
      id: map['id'] as String,
      playerId: map['playerId'] as String,
      type: MatchEventType.values[(map['type'] as int?) ?? 0],
      matchClockSec: (map['matchClockSec'] as int?) ?? 0,
      phase: MatchPhase.values[(map['phase'] as int?) ?? 0],
      isSevenMeter: (map['isSevenMeter'] as bool?) ?? false,
      goalZone: goalZoneIdx == null ? null : GoalZone.values[goalZoneIdx],
      courtZone: courtZoneIdx == null ? null : CourtZone.values[courtZoneIdx],
      createdAt:
          DateTime.fromMillisecondsSinceEpoch((map['createdAt'] as int?) ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'playerId': playerId,
      'type': type.index,
      'matchClockSec': matchClockSec,
      'phase': phase.index,
      'isSevenMeter': isSevenMeter,
      'goalZone': goalZone?.index,
      'courtZone': courtZone?.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}

class MatchEventAdapter extends TypeAdapter<MatchEvent> {
  @override
  final int typeId = 4;

  @override
  MatchEvent read(BinaryReader reader) => MatchEvent.fromMap(reader.readMap());

  @override
  void write(BinaryWriter writer, MatchEvent obj) => writer.writeMap(obj.toMap());
}
