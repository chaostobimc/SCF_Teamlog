import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:scf_teamlog/data/database/hive_setup.dart';
import 'package:scf_teamlog/data/models/match.dart';
import 'package:scf_teamlog/data/models/match_event.dart';
import 'package:scf_teamlog/data/models/player.dart';
import 'package:scf_teamlog/data/models/team.dart';
import 'package:scf_teamlog/data/repositories/match_repository.dart';
import 'package:scf_teamlog/logic/match_controller.dart';

void main() {
  late Directory tempDir;
  late Box<Match> box;
  late MatchRepository repository;
  late MatchController controller;

  final team = Team(
    id: 'team-1',
    name: 'SCF Testheim',
    players: [
      Player(
        id: 'p-field',
        number: 7,
        firstName: 'Max',
        lastName: 'Mustermann',
        position: PlayerPosition.feldspieler,
      ),
      Player(
        id: 'p-keeper',
        number: 1,
        firstName: 'Erika',
        lastName: 'Musterfrau',
        position: PlayerPosition.torwart,
      ),
    ],
  );

  Match freshMatch({MatchStatus status = MatchStatus.geplant}) {
    return Match(
      id: 'match-1',
      ownTeamId: 'team-1',
      opponentName: 'HSV Gegen',
      date: DateTime(2026, 9, 26),
      isHome: true,
      halfLengthMin: 30,
      status: status,
      phase: MatchPhase.ersteHalbzeit,
    );
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('scf_test');
    Hive.init(tempDir.path);
    await openAppBoxes();
  });

  setUp(() async {
    box = Hive.box<Match>(matchBoxName);
    await box.clear();
    repository = MatchRepository(box);
    controller = MatchController(repository, match: freshMatch(), team: team);
  });

  tearDown(() {
    controller.dispose();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('Spieluhr starten und stoppen', () {
    expect(controller.state.running, isFalse);
    controller.toggleClock();
    expect(controller.state.running, isTrue);
    expect(controller.state.match.status, MatchStatus.laufend);
    controller.toggleClock();
    expect(controller.state.running, isFalse);
  });

  test('Spieluhr laeuft und erhoelt die Halbzeitzeit', () async {
    controller.toggleClock();
    await Future<void>.delayed(const Duration(milliseconds: 550));
    expect(controller.state.match.firstHalfSec, greaterThanOrEqualTo(1));
  });

  test('Spieler waehlen und abwaehlen', () {
    controller.selectPlayer('p-field');
    expect(controller.state.selectedPlayerId, 'p-field');
    controller.selectPlayer('p-field');
    expect(controller.state.selectedPlayerId, isNull);
  });

  test('Tor mit Zielzone wird gespeichert', () {
    controller.toggleClock();
    controller.selectPlayer('p-field');
    controller.onGoalZoneTap(GoalZone.obenLinks);
    expect(controller.state.pendingShot, isNotNull);

    controller.resolvePendingShot(MatchEventType.tor);

    expect(controller.state.pendingShot, isNull);
    final events = controller.state.match.events;
    expect(events, hasLength(1));
    expect(events.first.type, MatchEventType.tor);
    expect(events.first.goalZone, GoalZone.obenLinks);
    expect(events.first.playerId, 'p-field');
  });

  test('Daneben wird sofort als Fehlwurf gespeichert', () {
    controller.toggleClock();
    controller.selectPlayer('p-field');
    controller.onGoalZoneTap(GoalZone.linksDaneben);

    final events = controller.state.match.events;
    expect(events, hasLength(1));
    expect(events.first.type, MatchEventType.fehlwurf);
    expect(events.first.goalZone, GoalZone.linksDaneben);
    expect(controller.state.pendingShot, isNull);
  });

  test('Torhueter: Parade und Gegentor werden korrekt gemappt', () {
    controller.toggleClock();
    controller.selectPlayer('p-keeper');
    controller.onGoalZoneTap(GoalZone.untenMitte);
    controller.resolvePendingShot(MatchEventType.wurfGehalten);

    controller.onGoalZoneTap(GoalZone.obenRechts);
    controller.resolvePendingShot(MatchEventType.tor);

    final events = controller.state.match.events;
    expect(events, hasLength(2));
    expect(events.first.type, MatchEventType.parade);
    expect(events.last.type, MatchEventType.gegentor);
  });

  test('7m-Kontext wird auf Torhueter-Aktionen angewendet', () {
    controller.toggleClock();
    controller.selectPlayer('p-keeper');
    controller.onCourtZoneTap(CourtZone.siebenMeter);
    controller.onGoalZoneTap(GoalZone.untenLinks);
    controller.resolvePendingShot(MatchEventType.wurfGehalten);

    final events = controller.state.match.events;
    expect(events, hasLength(1));
    expect(events.first.type, MatchEventType.paradeSiebenMeter);
    expect(events.first.isSevenMeter, isTrue);
  });

  test('Aktionen ohne Spieler werden abgelehnt', () {
    controller.toggleClock();
    controller.commitQuickAction(MatchEventType.ballverlust);

    expect(controller.state.match.events, isEmpty);
    expect(controller.state.notice, isNotNull);
  });

  test('Sanktionen und Technikfehler werden gespeichert', () {
    controller.toggleClock();
    controller.selectPlayer('p-field');
    controller.commitQuickAction(MatchEventType.zeitstrafe);
    controller.commitQuickAction(MatchEventType.schrittfehler);
    controller.commitQuickAction(MatchEventType.siebenMeterHerausgeholt);

    final events = controller.state.match.events;
    expect(events, hasLength(3));
    expect(events.map((e) => e.type), [
      MatchEventType.zeitstrafe,
      MatchEventType.schrittfehler,
      MatchEventType.siebenMeterHerausgeholt,
    ]);
  });

  test('Undo entfernt die letzte Aktion', () {
    controller.toggleClock();
    controller.selectPlayer('p-field');
    controller.commitQuickAction(MatchEventType.ballverlust);
    controller.commitQuickAction(MatchEventType.ballverlust);
    expect(controller.state.match.events, hasLength(2));

    controller.undoLastEvent();
    expect(controller.state.match.events, hasLength(1));

    controller.undoLastEvent();
    expect(controller.state.match.events, isEmpty);

    controller.undoLastEvent();
    expect(controller.state.match.events, isEmpty);
  });

  test('Ereignisse tragen einen Zeitstempel der Spieluhr', () async {
    controller.toggleClock();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.selectPlayer('p-field');
    controller.commitQuickAction(MatchEventType.ballverlust);

    final event = controller.state.match.events.single;
    expect(event.matchClockSec, greaterThanOrEqualTo(1));
    expect(event.phase, MatchPhase.ersteHalbzeit);
  });

  test('Start der zweiten Halbzeit wechselt die Phase', () {
    controller.toggleClock();
    controller.startSecondHalf();
    expect(controller.state.match.phase, MatchPhase.zweiteHalbzeit);
  });

  test('Spiel beenden setzt Status und Phase', () {
    controller.toggleClock();
    controller.finishMatch();
    expect(controller.state.match.status, MatchStatus.beendet);
    expect(controller.state.match.phase, MatchPhase.beendet);
    expect(controller.state.running, isFalse);

    controller.commitQuickAction(MatchEventType.ballverlust);
    expect(controller.state.match.events, isEmpty);
  });

  test('Ereignisse werden dauerhaft gespeichert', () async {
    controller.toggleClock();
    controller.selectPlayer('p-field');
    controller.commitQuickAction(MatchEventType.ballverlust);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final reloaded = repository.byId('match-1');
    expect(reloaded, isNotNull);
    expect(reloaded!.events, hasLength(1));
  });
}
