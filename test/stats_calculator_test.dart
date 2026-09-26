import 'package:flutter_test/flutter_test.dart';
import 'package:scf_teamlog/data/models/match.dart';
import 'package:scf_teamlog/data/models/match_event.dart';
import 'package:scf_teamlog/data/models/player.dart';
import 'package:scf_teamlog/data/models/team.dart';
import 'package:scf_teamlog/logic/stats_calculator.dart';

MatchEvent _event({
  required String playerId,
  required MatchEventType type,
  int clock = 0,
  bool sevenMeter = false,
  GoalZone? goalZone,
  CourtZone? courtZone,
}) {
  return MatchEvent(
    id: 'e-$clock-$type',
    playerId: playerId,
    type: type,
    matchClockSec: clock,
    phase: MatchPhase.ersteHalbzeit,
    isSevenMeter: sevenMeter,
    goalZone: goalZone,
    courtZone: courtZone,
    createdAt: DateTime(2026, 9, 26),
  );
}

void main() {
  final team = Team(
    id: 't1',
    name: 'SCF',
    players: [
      Player(id: 'a', number: 5, firstName: 'A', lastName: 'Aa',
          position: PlayerPosition.feldspieler),
      Player(id: 'b', number: 1, firstName: 'B', lastName: 'Bb',
          position: PlayerPosition.torwart),
    ],
  );

  Match matchWith(List<MatchEvent> events) {
    return Match(
      id: 'm1',
      ownTeamId: 't1',
      opponentName: 'Gegner',
      date: DateTime(2026, 9, 26),
      isHome: true,
      events: events,
    );
  }

  test('Wurfquote und 7m-Bilanz werden korrekt berechnet', () {
    final match = matchWith([
      _event(playerId: 'a', type: MatchEventType.tor, sevenMeter: true,
          goalZone: GoalZone.untenLinks),
      _event(playerId: 'a', type: MatchEventType.tor,
          goalZone: GoalZone.obenRechts),
      _event(playerId: 'a', type: MatchEventType.fehlwurf,
          goalZone: GoalZone.drueber),
      _event(playerId: 'a', type: MatchEventType.wurfGehalten,
          goalZone: GoalZone.untenMitte),
      _event(playerId: 'a', type: MatchEventType.wurfGeblockt),
    ]);

    final stats = statsForPlayer(match, team.players.first);
    expect(stats.shots, 5);
    expect(stats.goals, 2);
    expect(stats.fieldShots, 4);
    expect(stats.fieldGoals, 1);
    expect(stats.shotsSevenMeter, 1);
    expect(stats.goalsSevenMeter, 1);
    expect(stats.blocked, 1);
    expect(stats.shotRatio, closeTo(0.4, 0.001));
    expect(stats.sevenMeterRatio, closeTo(1.0, 0.001));
    expect(stats.fieldShotRatio, closeTo(0.25, 0.001));
  });

  test('Torhueter-Kennzahlen inklusive 7m und Freiwurf', () {
    final match = matchWith([
      _event(playerId: 'b', type: MatchEventType.parade),
      _event(playerId: 'b', type: MatchEventType.paradeSiebenMeter,
          sevenMeter: true),
      _event(playerId: 'b', type: MatchEventType.paradeFreiwurf),
      _event(playerId: 'b', type: MatchEventType.gegentor),
      _event(playerId: 'b', type: MatchEventType.gegentorSiebenMeter,
          sevenMeter: true),
    ]);

    final stats = statsForPlayer(match, team.players.last);
    expect(stats.saves, 3);
    expect(stats.conceded, 2);
    expect(stats.savesSevenMeter, 1);
    expect(stats.concededSevenMeter, 1);
    expect(stats.savesFreeThrow, 1);
    expect(stats.saveRatio, closeTo(0.6, 0.001));
    expect(stats.sevenMeterSaveRatio, closeTo(0.5, 0.001));
  });

  test('Technikfehler, Ballverluste und Sanktionen werden gezaehlt', () {
    final match = matchWith([
      _event(playerId: 'a', type: MatchEventType.schrittfehler),
      _event(playerId: 'a', type: MatchEventType.prellfehler),
      _event(playerId: 'a', type: MatchEventType.ballverlust),
      _event(playerId: 'a', type: MatchEventType.gefoult),
      _event(playerId: 'a', type: MatchEventType.siebenMeterHerausgeholt),
      _event(playerId: 'a', type: MatchEventType.duelGewonnen),
      _event(playerId: 'a', type: MatchEventType.gelbeKarte),
      _event(playerId: 'a', type: MatchEventType.zeitstrafe),
    ]);

    final stats = statsForPlayer(match, team.players.first);
    expect(stats.technicalErrors, 2);
    expect(stats.ballLosses, 1);
    expect(stats.foulsSuffered, 1);
    expect(stats.sevenMeterWon, 1);
    expect(stats.duelsWon, 1);
    expect(stats.yellowCards, 1);
    expect(stats.twoMinutes, 1);
    expect(stats.sanctions, 2);
  });

  test('Trefferzonen-Tabelle zaehlt Tore und gehaltene Wuerfe', () {
    final match = matchWith([
      _event(playerId: 'a', type: MatchEventType.tor,
          goalZone: GoalZone.obenLinks),
      _event(playerId: 'a', type: MatchEventType.tor,
          goalZone: GoalZone.obenLinks),
      _event(playerId: 'a', type: MatchEventType.wurfGehalten,
          goalZone: GoalZone.obenLinks),
      _event(playerId: 'a', type: MatchEventType.fehlwurf,
          goalZone: GoalZone.obenLinks),
    ]);

    final stats = calculateTeamStats(match, team);
    final tally = stats.zones[GoalZone.obenLinks];
    expect(tally, isNotNull);
    expect(tally!.goals, 2);
    expect(tally.saved, 1);
    expect(tally.total, 3);

    final total = stats.total;
    expect(total.shots, 4);
    expect(total.goals, 2);
    expect(stats.goalsFor, 2);
    expect(stats.goalsAgainst, 0);
  });
}
