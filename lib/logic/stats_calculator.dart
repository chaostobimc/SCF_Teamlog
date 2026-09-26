import '../data/models/match.dart';
import '../data/models/match_event.dart';
import '../data/models/player.dart';
import '../data/models/team.dart';

/// Zaehlung je Tor-Zone fuer die Treffer-Visualisierung.
class ZoneTally {
  const ZoneTally({this.goals = 0, this.saved = 0});

  final int goals;
  final int saved;

  int get total => goals + saved;

  ZoneTally add({required bool goal}) {
    return ZoneTally(goals: goals + (goal ? 1 : 0), saved: saved + (goal ? 0 : 1));
  }
}

class PlayerStats {
  const PlayerStats({
    this.shots = 0,
    this.goals = 0,
    this.shotsSevenMeter = 0,
    this.goalsSevenMeter = 0,
    this.blocked = 0,
    this.stepErrors = 0,
    this.dribbleErrors = 0,
    this.attackerFouls = 0,
    this.ballLosses = 0,
    this.foulsSuffered = 0,
    this.sevenMeterWon = 0,
    this.duelsWon = 0,
    this.yellowCards = 0,
    this.twoMinutes = 0,
    this.redCards = 0,
    this.blueCards = 0,
    this.saves = 0,
    this.conceded = 0,
    this.savesSevenMeter = 0,
    this.concededSevenMeter = 0,
    this.savesFreeThrow = 0,
    this.concededFreeThrow = 0,
  });

  final int shots;
  final int goals;
  final int shotsSevenMeter;
  final int goalsSevenMeter;
  final int blocked;
  final int stepErrors;
  final int dribbleErrors;
  final int attackerFouls;
  final int ballLosses;
  final int foulsSuffered;
  final int sevenMeterWon;
  final int duelsWon;
  final int yellowCards;
  final int twoMinutes;
  final int redCards;
  final int blueCards;

  final int saves;
  final int conceded;
  final int savesSevenMeter;
  final int concededSevenMeter;
  final int savesFreeThrow;
  final int concededFreeThrow;

  int get fieldShots => shots - shotsSevenMeter;
  int get fieldGoals => goals - goalsSevenMeter;

  double get shotRatio => shots == 0 ? double.nan : goals / shots;
  double get fieldShotRatio => fieldShots == 0 ? double.nan : fieldGoals / fieldShots;
  double get sevenMeterRatio =>
      shotsSevenMeter == 0 ? double.nan : goalsSevenMeter / shotsSevenMeter;
  double get saveRatio => (saves + conceded) == 0 ? double.nan : saves / (saves + conceded);
  double get sevenMeterSaveRatio =>
      (savesSevenMeter + concededSevenMeter) == 0
          ? double.nan
          : savesSevenMeter / (savesSevenMeter + concededSevenMeter);
  double get freeThrowSaveRatio =>
      (savesFreeThrow + concededFreeThrow) == 0
          ? double.nan
          : savesFreeThrow / (savesFreeThrow + concededFreeThrow);

  int get technicalErrors => stepErrors + dribbleErrors;
  int get sanctions => yellowCards + twoMinutes + redCards + blueCards;

  PlayerStats accumulate(MatchEventType type, MatchEvent event) {
    // Gegnerische Fehlwuerfe zaehlen nicht als eigene Wuerfe des Spielers.
    if (event.isOpponent &&
        (type == MatchEventType.fehlwurf || type == MatchEventType.wurfGeblockt)) {
      return this;
    }
    switch (type) {
      case MatchEventType.tor:
        return _copy(
          shots: shots + 1,
          goals: goals + 1,
          shotsSevenMeter: event.isSevenMeter ? shotsSevenMeter + 1 : shotsSevenMeter,
          goalsSevenMeter: event.isSevenMeter ? goalsSevenMeter + 1 : goalsSevenMeter,
        );
      case MatchEventType.fehlwurf:
      case MatchEventType.wurfGehalten:
        return _copy(
          shots: shots + 1,
          shotsSevenMeter: event.isSevenMeter ? shotsSevenMeter + 1 : shotsSevenMeter,
        );
      case MatchEventType.wurfGeblockt:
        return _copy(
          blocked: blocked + 1,
          shots: shots + 1,
          shotsSevenMeter: event.isSevenMeter ? shotsSevenMeter + 1 : shotsSevenMeter,
        );
      case MatchEventType.schrittfehler:
        return _copy(stepErrors: stepErrors + 1);
      case MatchEventType.prellfehler:
        return _copy(dribbleErrors: dribbleErrors + 1);
      case MatchEventType.stuermerfoul:
        return _copy(attackerFouls: attackerFouls + 1);
      case MatchEventType.ballverlust:
        return _copy(ballLosses: ballLosses + 1);
      case MatchEventType.gefoult:
        return _copy(foulsSuffered: foulsSuffered + 1);
      case MatchEventType.siebenMeterHerausgeholt:
        return _copy(sevenMeterWon: sevenMeterWon + 1);
      case MatchEventType.duelGewonnen:
        return _copy(duelsWon: duelsWon + 1);
      case MatchEventType.gelbeKarte:
        return _copy(yellowCards: yellowCards + 1);
      case MatchEventType.zeitstrafe:
        return _copy(twoMinutes: twoMinutes + 1);
      case MatchEventType.roteKarte:
        return _copy(redCards: redCards + 1);
      case MatchEventType.blaueKarte:
        return _copy(blueCards: blueCards + 1);
      case MatchEventType.parade:
        return _copy(saves: saves + 1);
      case MatchEventType.paradeSiebenMeter:
        return _copy(saves: saves + 1, savesSevenMeter: savesSevenMeter + 1);
      case MatchEventType.paradeFreiwurf:
        return _copy(saves: saves + 1, savesFreeThrow: savesFreeThrow + 1);
      case MatchEventType.gegentor:
        return _copy(conceded: conceded + 1);
      case MatchEventType.gegentorSiebenMeter:
        return _copy(conceded: conceded + 1, concededSevenMeter: concededSevenMeter + 1);
      case MatchEventType.gegentorFreiwurf:
        return _copy(conceded: conceded + 1, concededFreeThrow: concededFreeThrow + 1);
    }
  }

  PlayerStats _copy({
    int? shots,
    int? goals,
    int? shotsSevenMeter,
    int? goalsSevenMeter,
    int? blocked,
    int? stepErrors,
    int? dribbleErrors,
    int? attackerFouls,
    int? ballLosses,
    int? foulsSuffered,
    int? sevenMeterWon,
    int? duelsWon,
    int? yellowCards,
    int? twoMinutes,
    int? redCards,
    int? blueCards,
    int? saves,
    int? conceded,
    int? savesSevenMeter,
    int? concededSevenMeter,
    int? savesFreeThrow,
    int? concededFreeThrow,
  }) {
    return PlayerStats(
      shots: shots ?? this.shots,
      goals: goals ?? this.goals,
      shotsSevenMeter: shotsSevenMeter ?? this.shotsSevenMeter,
      goalsSevenMeter: goalsSevenMeter ?? this.goalsSevenMeter,
      blocked: blocked ?? this.blocked,
      stepErrors: stepErrors ?? this.stepErrors,
      dribbleErrors: dribbleErrors ?? this.dribbleErrors,
      attackerFouls: attackerFouls ?? this.attackerFouls,
      ballLosses: ballLosses ?? this.ballLosses,
      foulsSuffered: foulsSuffered ?? this.foulsSuffered,
      sevenMeterWon: sevenMeterWon ?? this.sevenMeterWon,
      duelsWon: duelsWon ?? this.duelsWon,
      yellowCards: yellowCards ?? this.yellowCards,
      twoMinutes: twoMinutes ?? this.twoMinutes,
      redCards: redCards ?? this.redCards,
      blueCards: blueCards ?? this.blueCards,
      saves: saves ?? this.saves,
      conceded: conceded ?? this.conceded,
      savesSevenMeter: savesSevenMeter ?? this.savesSevenMeter,
      concededSevenMeter: concededSevenMeter ?? this.concededSevenMeter,
      savesFreeThrow: savesFreeThrow ?? this.savesFreeThrow,
      concededFreeThrow: concededFreeThrow ?? this.concededFreeThrow,
    );
  }

  static PlayerStats combine(PlayerStats a, PlayerStats b) {
    return PlayerStats(
      shots: a.shots + b.shots,
      goals: a.goals + b.goals,
      shotsSevenMeter: a.shotsSevenMeter + b.shotsSevenMeter,
      goalsSevenMeter: a.goalsSevenMeter + b.goalsSevenMeter,
      blocked: a.blocked + b.blocked,
      stepErrors: a.stepErrors + b.stepErrors,
      dribbleErrors: a.dribbleErrors + b.dribbleErrors,
      attackerFouls: a.attackerFouls + b.attackerFouls,
      ballLosses: a.ballLosses + b.ballLosses,
      foulsSuffered: a.foulsSuffered + b.foulsSuffered,
      sevenMeterWon: a.sevenMeterWon + b.sevenMeterWon,
      duelsWon: a.duelsWon + b.duelsWon,
      yellowCards: a.yellowCards + b.yellowCards,
      twoMinutes: a.twoMinutes + b.twoMinutes,
      redCards: a.redCards + b.redCards,
      blueCards: a.blueCards + b.blueCards,
      saves: a.saves + b.saves,
      conceded: a.conceded + b.conceded,
      savesSevenMeter: a.savesSevenMeter + b.savesSevenMeter,
      concededSevenMeter: a.concededSevenMeter + b.concededSevenMeter,
      savesFreeThrow: a.savesFreeThrow + b.savesFreeThrow,
      concededFreeThrow: a.concededFreeThrow + b.concededFreeThrow,
    );
  }
}

class TeamStats {
  const TeamStats({required this.perPlayer, required this.zones});

  final Map<String, PlayerStats> perPlayer;
  final Map<GoalZone, ZoneTally> zones;

  PlayerStats get total {
    var result = const PlayerStats();
    for (final stats in perPlayer.values) {
      result = PlayerStats.combine(result, stats);
    }
    return result;
  }

  /// Eigene Tore = Feldspieler-Tore.
  int get goalsFor => total.goals;

  /// Gegentore aus Sicht des eigenen Teams.
  int get goalsAgainst => total.conceded;
}

TeamStats calculateTeamStats(Match match, Team team) {
  final perPlayer = <String, PlayerStats>{};
  final zones = <GoalZone, ZoneTally>{};

  for (final event in match.events) {
    final current = perPlayer[event.playerId] ?? const PlayerStats();
    perPlayer[event.playerId] = current.accumulate(event.type, event);

    final zone = event.goalZone;
    if (zone != null && zone.isOnTarget) {
      if (event.type == MatchEventType.tor) {
        zones[zone] = (zones[zone] ?? const ZoneTally()).add(goal: true);
      } else if (event.type == MatchEventType.wurfGehalten) {
        zones[zone] = (zones[zone] ?? const ZoneTally()).add(goal: false);
      }
    }
  }

  return TeamStats(perPlayer: perPlayer, zones: zones);
}

PlayerStats statsForPlayer(Match match, Player player) {
  var stats = const PlayerStats();
  for (final event in match.events) {
    if (event.playerId != player.id) continue;
    stats = stats.accumulate(event.type, event);
  }
  return stats;
}

/// Wurfbild des Torwarts: wohin geworfen wurde und von wo.
class KeeperShotMap {
  const KeeperShotMap({
    this.goalZones = const {},
    this.originsOnTarget = const {},
    this.originMisses = const {},
  });

  /// Torzonen: [ZoneTally.saved] = Paraden, [ZoneTally.goals] = Gegentore.
  final Map<GoalZone, ZoneTally> goalZones;

  /// Wurfpositionen der gehaltenen/erzielten Schuesse.
  final Map<CourtZone, ZoneTally> originsOnTarget;

  /// Verfehlte/blockierte Gegnerwuerfe je Wurfposition.
  final Map<CourtZone, int> originMisses;

  int get saves {
    var n = 0;
    for (final tally in goalZones.values) {
      n += tally.saved;
    }
    return n;
  }

  int get conceded {
    var n = 0;
    for (final tally in goalZones.values) {
      n += tally.goals;
    }
    return n;
  }

  int get shotsOnTarget => saves + conceded;

  int get shotsFaced {
    var n = shotsOnTarget;
    for (final miss in originMisses.values) {
      n += miss;
    }
    return n;
  }

  double get saveRatio => shotsOnTarget == 0 ? double.nan : saves / shotsOnTarget;
}

/// Wurfbild ueber alle Gegnerwuerfe eines Spiels (optionale Einschraenkung
/// auf einen bestimmten Torwart).
KeeperShotMap keeperShotMap(Match match, {String? goalkeeperId}) {
  final goalZones = <GoalZone, ZoneTally>{};
  final originsOnTarget = <CourtZone, ZoneTally>{};
  final originMisses = <CourtZone, int>{};

  for (final event in match.events) {
    if (!event.isOpponent) continue;
    if (goalkeeperId != null && event.playerId != goalkeeperId) continue;

    final isMiss = event.type == MatchEventType.fehlwurf ||
        event.type == MatchEventType.wurfGeblockt;
    final isGoal = event.type == MatchEventType.gegentor ||
        event.type == MatchEventType.gegentorSiebenMeter ||
        event.type == MatchEventType.gegentorFreiwurf;

    if (isMiss) {
      final zone = event.courtZone;
      if (zone != null) {
        originMisses[zone] = (originMisses[zone] ?? 0) + 1;
      }
      continue;
    }

    final goalZone = event.goalZone;
    if (goalZone != null && goalZone.isOnTarget) {
      goalZones[goalZone] =
          (goalZones[goalZone] ?? const ZoneTally()).add(goal: isGoal);
    }
    final origin = event.courtZone;
    if (origin != null) {
      originsOnTarget[origin] =
          (originsOnTarget[origin] ?? const ZoneTally()).add(goal: isGoal);
    }
  }

  return KeeperShotMap(
    goalZones: goalZones,
    originsOnTarget: originsOnTarget,
    originMisses: originMisses,
  );
}

/// Einzelner Gegner-Schuetze im Wurfbild.
class OpponentShooterStats {
  const OpponentShooterStats({
    this.shots = 0,
    this.onTarget = 0,
    this.saves = 0,
    this.conceded = 0,
    this.misses = 0,
  });

  final int shots;
  final int onTarget;
  final int saves;
  final int conceded;
  final int misses;

  double get efficiency => onTarget == 0 ? double.nan : conceded / onTarget;

  OpponentShooterStats add({
    required bool onTarget,
    required bool goal,
  }) {
    return OpponentShooterStats(
      shots: shots + 1,
      onTarget: this.onTarget + (onTarget ? 1 : 0),
      saves: saves + (onTarget && !goal ? 1 : 0),
      conceded: conceded + (goal ? 1 : 0),
      misses: misses + (onTarget ? 0 : 1),
    );
  }
}

/// Wurfbild je Gegner-Trikotnummer (Schluessel 0 = ohne Nummer erfasst).
Map<int, OpponentShooterStats> opponentShooters(Match match) {
  final result = <int, OpponentShooterStats>{};
  for (final event in match.events) {
    if (!event.isOpponent) continue;
    final isMiss = event.type == MatchEventType.fehlwurf ||
        event.type == MatchEventType.wurfGeblockt;
    final isGoal = event.type == MatchEventType.gegentor ||
        event.type == MatchEventType.gegentorSiebenMeter ||
        event.type == MatchEventType.gegentorFreiwurf;
    final key = event.opponentNumber ?? 0;
    final current = result[key] ?? const OpponentShooterStats();
    result[key] = current.add(onTarget: !isMiss, goal: isGoal);
  }
  return result;
}

/// Laufende 2-Minuten-Strafen bei aktueller Spielzeit.
class ActivePenalty {
  const ActivePenalty({required this.event, required this.endsAtSec});

  final MatchEvent event;
  final int endsAtSec;

  int remainingSec(int matchClockSec) {
    final left = endsAtSec - matchClockSec;
    return left < 0 ? 0 : left;
  }

  bool isActive(int matchClockSec) => endsAtSec > matchClockSec;
}

List<ActivePenalty> activePenalties(Match match) {
  final result = <ActivePenalty>[];
  for (final event in match.events) {
    if (event.type != MatchEventType.zeitstrafe || event.isOpponent) continue;
    final endsAt = event.matchClockSec + 120;
    final penalty = ActivePenalty(event: event, endsAtSec: endsAt);
    if (penalty.isActive(match.matchClockSec)) result.add(penalty);
  }
  return result;
}

/// Summiert die Statistik eines Spielers ueber alle Spiele hinweg.
PlayerStats allTimeStatsForPlayer(List<Match> matches, Player player) {
  var stats = const PlayerStats();
  for (final match in matches) {
    stats = PlayerStats.combine(stats, statsForPlayer(match, player));
  }
  return stats;
}

/// Alltime-Statistik je Spieler.
Map<String, PlayerStats> allTimeStats(List<Match> matches, Team team) {
  final result = <String, PlayerStats>{};
  for (final player in team.players) {
    result[player.id] = allTimeStatsForPlayer(matches, player);
  }
  return result;
}
