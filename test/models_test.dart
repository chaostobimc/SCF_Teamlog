import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scf_teamlog/data/models/match.dart';
import 'package:scf_teamlog/data/models/match_event.dart';
import 'package:scf_teamlog/data/models/player.dart';
import 'package:scf_teamlog/data/models/team.dart';

void main() {
  test('Player Roundtrip ueber Map', () {
    final player = Player(
      id: 'p1',
      number: 9,
      firstName: 'Lena',
      lastName: 'Schmidt',
      position: PlayerPosition.feldspieler,
      gameRole: PlayerGameRole.rueckraumMitte,
    );

    final copy = Player.fromMap(player.toMap());
    expect(copy.id, player.id);
    expect(copy.number, player.number);
    expect(copy.firstName, player.firstName);
    expect(copy.lastName, player.lastName);
    expect(copy.position, player.position);
    expect(copy.gameRole, player.gameRole);
    expect(copy.fullName, 'Lena Schmidt');
  });

  test('Team Roundtrip inklusive Farben und Kader', () {
    final team = Team(
      id: 't1',
      name: 'SCF I',
      primaryColor: const Color(0xFF123456),
      secondaryColor: const Color(0xFFABCDEF),
      players: [
        Player(id: 'p1', number: 1, firstName: 'A', lastName: 'B',
            position: PlayerPosition.torwart),
        Player(id: 'p2', number: 5, firstName: 'C', lastName: 'D',
            position: PlayerPosition.feldspieler),
      ],
    );

    final copy = Team.fromMap(team.toMap());
    expect(copy.name, team.name);
    expect(copy.players, hasLength(2));
    expect(copy.primaryColor.toARGB32(), 0xFF123456);
    expect(copy.secondaryColor.toARGB32(), 0xFFABCDEF);
    expect(copy.goalkeepers, hasLength(1));
    expect(copy.fieldPlayers, hasLength(1));
    expect(copy.playerById('p2')!.number, 5);
  });

  test('Match Roundtrip mit Ereignissen und Zeitfeldern', () {
    final event = MatchEvent(
      id: 'e1',
      playerId: 'p1',
      type: MatchEventType.paradeSiebenMeter,
      matchClockSec: 754,
      phase: MatchPhase.zweiteHalbzeit,
      isSevenMeter: true,
      goalZone: GoalZone.untenMitte,
      createdAt: DateTime(2026, 9, 26, 19, 30),
    );
    final match = Match(
      id: 'm1',
      ownTeamId: 't1',
      opponentName: 'TSV Nord',
      date: DateTime(2026, 9, 26),
      isHome: false,
      halfLengthMin: 25,
      status: MatchStatus.laufend,
      phase: MatchPhase.zweiteHalbzeit,
      firstHalfSec: 1500,
      secondHalfSec: 600,
      events: [event],
    );

    final copy = Match.fromMap(match.toMap());
    expect(copy.opponentName, 'TSV Nord');
    expect(copy.isHome, isFalse);
    expect(copy.halfLengthSec, 1500);
    expect(copy.matchClockSec, 2100);
    expect(copy.phase, MatchPhase.zweiteHalbzeit);
    expect(copy.events, hasLength(1));

    final copiedEvent = copy.events.single;
    expect(copiedEvent.type, MatchEventType.paradeSiebenMeter);
    expect(copiedEvent.isSevenMeter, isTrue);
    expect(copiedEvent.goalZone, GoalZone.untenMitte);
    expect(copiedEvent.matchClockSec, 754);
    expect(copiedEvent.createdAt, DateTime(2026, 9, 26, 19, 30));
  });

  test('Ereignistypen haben korrekte Kategorien', () {
    expect(MatchEventType.tor.isShotAction, isTrue);
    expect(MatchEventType.fehlwurf.isShotAction, isTrue);
    expect(MatchEventType.parade.isGoalkeeperAction, isTrue);
    expect(MatchEventType.gegentorSiebenMeter.isGoalkeeperAction, isTrue);
    expect(MatchEventType.ballverlust.isGoalkeeperAction, isFalse);
    expect(MatchEventType.zeitstrafe.isSanction, isTrue);
    expect(MatchEventType.blaueKarte.isSanction, isTrue);
    expect(MatchEventType.tor.isPositive, isTrue);
    expect(MatchEventType.ballverlust.isPositive, isFalse);
  });

  test('Torzonen unterscheiden Rahmen und Tor', () {
    expect(GoalZone.obenLinks.isOnTarget, isTrue);
    expect(GoalZone.untenRechts.isOnTarget, isTrue);
    expect(GoalZone.linksDaneben.isOnTarget, isFalse);
    expect(GoalZone.drueber.isOnTarget, isFalse);
    expect(GoalZone.obenMitte.label, 'Oben Mitte');
  });
}
