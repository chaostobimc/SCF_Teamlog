import 'package:hive/hive.dart';

import 'match_event.dart';

enum MatchStatus { geplant, laufend, beendet }

enum MatchPhase {
  ersteHalbzeit,
  halbzeitpause,
  zweiteHalbzeit,
  beendet;

  String get label {
    switch (this) {
      case MatchPhase.ersteHalbzeit:
        return '1. Halbzeit';
      case MatchPhase.halbzeitpause:
        return 'Halbzeit';
      case MatchPhase.zweiteHalbzeit:
        return '2. Halbzeit';
      case MatchPhase.beendet:
        return 'Beendet';
    }
  }
}

class Match {
  Match({
    required this.id,
    required this.ownTeamId,
    required this.opponentName,
    required this.date,
    required this.isHome,
    this.halfLengthMin = 30,
    this.status = MatchStatus.geplant,
    this.phase = MatchPhase.ersteHalbzeit,
    this.firstHalfSec = 0,
    this.secondHalfSec = 0,
    this.pauseSec = 0,
    List<String> squadPlayerIds = const [],
    List<MatchEvent> events = const [],
  })  : squadPlayerIds = List.of(squadPlayerIds),
        events = List.of(events);

  final String id;
  final String ownTeamId;
  final String opponentName;

  /// Anpfiff-Tag des Spiels.
  final DateTime date;

  /// true = Heimspiel, false = Auswaertsspiel.
  final bool isHome;

  /// Laenge einer Halbzeit in Minuten.
  final int halfLengthMin;

  final MatchStatus status;
  final MatchPhase phase;

  /// Laufene Netto-Spielzeit der 1. Halbzeit in Sekunden.
  final int firstHalfSec;

  /// Laufene Netto-Spielzeit der 2. Halbzeit in Sekunden.
  final int secondHalfSec;

  /// Laufene Dauer der Halbzeitpause in Sekunden.
  final int pauseSec;

  /// Spieler des Aufgebots bei diesem Spiel (leer = alle verfuegbar).
  final List<String> squadPlayerIds;

  final List<MatchEvent> events;

  int get halfLengthSec => halfLengthMin * 60;

  int get matchClockSec => firstHalfSec + secondHalfSec;

  int get phaseElapsedSec {
    switch (phase) {
      case MatchPhase.ersteHalbzeit:
        return firstHalfSec;
      case MatchPhase.halbzeitpause:
        return pauseSec;
      case MatchPhase.zweiteHalbzeit:
        return secondHalfSec;
      case MatchPhase.beendet:
        return 0;
    }
  }

  Match copyWith({
    MatchStatus? status,
    MatchPhase? phase,
    int? firstHalfSec,
    int? secondHalfSec,
    int? pauseSec,
    List<String>? squadPlayerIds,
    List<MatchEvent>? events,
  }) {
    return Match(
      id: id,
      ownTeamId: ownTeamId,
      opponentName: opponentName,
      date: date,
      isHome: isHome,
      halfLengthMin: halfLengthMin,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      firstHalfSec: firstHalfSec ?? this.firstHalfSec,
      secondHalfSec: secondHalfSec ?? this.secondHalfSec,
      pauseSec: pauseSec ?? this.pauseSec,
      squadPlayerIds: squadPlayerIds ?? this.squadPlayerIds,
      events: events ?? this.events,
    );
  }

  factory Match.fromMap(Map<dynamic, dynamic> map) {
    final eventMaps = (map['events'] as List?) ?? const <dynamic>[];
    final squadMaps = (map['squadPlayerIds'] as List?) ?? const <dynamic>[];
    return Match(
      id: map['id'] as String,
      ownTeamId: map['ownTeamId'] as String,
      opponentName: map['opponentName'] as String,
      date: DateTime.fromMillisecondsSinceEpoch((map['date'] as int?) ?? 0),
      isHome: (map['isHome'] as bool?) ?? true,
      halfLengthMin: (map['halfLengthMin'] as int?) ?? 30,
      status: MatchStatus.values[(map['status'] as int?) ?? 0],
      phase: MatchPhase.values[(map['phase'] as int?) ?? 0],
      firstHalfSec: (map['firstHalfSec'] as int?) ?? 0,
      secondHalfSec: (map['secondHalfSec'] as int?) ?? 0,
      pauseSec: (map['pauseSec'] as int?) ?? 0,
      squadPlayerIds: squadMaps.map((e) => e as String).toList(),
      events: eventMaps
          .map((e) => MatchEvent.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownTeamId': ownTeamId,
      'opponentName': opponentName,
      'date': date.millisecondsSinceEpoch,
      'isHome': isHome,
      'halfLengthMin': halfLengthMin,
      'status': status.index,
      'phase': phase.index,
      'firstHalfSec': firstHalfSec,
      'secondHalfSec': secondHalfSec,
      'pauseSec': pauseSec,
      'squadPlayerIds': squadPlayerIds,
      'events': events.map((e) => e.toMap()).toList(),
    };
  }
}

class MatchAdapter extends TypeAdapter<Match> {
  @override
  final int typeId = 3;

  @override
  Match read(BinaryReader reader) => Match.fromMap(reader.readMap());

  @override
  void write(BinaryWriter writer, Match obj) => writer.writeMap(obj.toMap());
}
