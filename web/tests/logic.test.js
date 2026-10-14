import { test } from 'node:test';
import assert from 'node:assert/strict';

import * as M from '../js/model.js';
import * as S from '../js/stats.js';
import { LiveSession } from '../js/match.js';

// Speicher-Attrappe fuer localStorage
function memoryStorage() {
  const data = new Map();
  return {
    getItem: (k) => (data.has(k) ? data.get(k) : null),
    setItem: (k, v) => data.set(k, String(v)),
    removeItem: (k) => data.delete(k),
  };
}

function setupStore() {
  const store = new M.Store(memoryStorage());
  const players = [
    M.createPlayer({ id: 'p1', number: 7, firstName: 'Max', lastName: 'Muster', position: 'feldspieler', gameRole: 'rueckraumMitte' }),
    M.createPlayer({ id: 'p2', number: 12, firstName: 'Tom', lastName: 'Torwart', position: 'torwart' }),
    M.createPlayer({ id: 'p3', number: 3, firstName: 'Anna', lastName: 'Außen', position: 'feldspieler' }),
  ];
  store.setPlayers(players);
  const match = M.createMatch({ id: 'm1', opponentName: 'TSV Test', date: new Date(2026, 9, 10).getTime(), halfLengthMin: 20, squadPlayerIds: ['p1', 'p2', 'p3'] });
  store.saveMatch(match);
  return store;
}

test('Formate: Uhr, Prozent, Datum', () => {
  assert.equal(M.clock(0), '00:00');
  assert.equal(M.clock(75), '01:15');
  assert.equal(M.clock(-5), '00:00');
  assert.equal(M.percent(0.5), '50%');
  assert.equal(M.percent(NaN), '–');
  assert.equal(M.dateLabel(new Date(2026, 0, 5).getTime()), '05.01.2026');
  assert.equal(M.toInputDate(new Date(2026, 9, 10).getTime()), '2026-10-10');
  assert.equal(M.fromInputDate('2026-10-10') > 0, true);
});

test('Spielername: kurz und voll', () => {
  const p = M.createPlayer({ number: 9, firstName: 'Lena', lastName: 'Schmidt' });
  assert.equal(M.playerShortName(p), 'L. Schmidt');
  assert.equal(M.playerFullName(p), 'Lena Schmidt');
  const blank = M.createPlayer({ number: 9, firstName: '', lastName: '' });
  assert.equal(M.playerFullName(blank), 'Nr. 9');
});

test('Statistik: Feldwurf, 7m und Gegnerwurf-Regel', () => {
  const match = M.createMatch({ opponentName: 'X' });
  match.events = [
    M.createEvent({ playerId: 'p1', type: 'tor', isSevenMeter: true }),
    M.createEvent({ playerId: 'p1', type: 'fehlwurf' }),
    M.createEvent({ playerId: 'p1', type: 'wurfGeblockt' }),
    M.createEvent({ playerId: 'p1', type: 'fehlwurf', isOpponent: true }), // Gegnerwurf zaehlt nicht
    M.createEvent({ playerId: 'p2', type: 'parade' }),
    M.createEvent({ playerId: 'p2', type: 'gegentorFreiwurf', isOpponent: true }),
  ];
  const s1 = S.statsForPlayer(match, 'p1');
  assert.equal(s1.shots, 3);
  assert.equal(s1.goals, 1);
  assert.equal(s1.goalsSevenMeter, 1);
  assert.equal(s1.blocked, 1);
  assert.equal(S.derived(s1).shotRatio, 1 / 3);

  const s2 = S.statsForPlayer(match, 'p2');
  assert.equal(s2.saves, 1);
  assert.equal(s2.conceded, 1);
  assert.equal(s2.concededFreeThrow, 1);
  assert.equal(S.derived(s2).saveRatio, 0.5);
});

test('Ergebnis und Ergebnisart', () => {
  const match = M.createMatch({ opponentName: 'X' });
  match.events = [
    M.createEvent({ playerId: 'p1', type: 'tor' }),
    M.createEvent({ playerId: 'p1', type: 'tor' }),
    M.createEvent({ playerId: 'p2', type: 'gegentor', isOpponent: true }),
  ];
  assert.deepEqual(S.scoreOf(match), { goalsFor: 2, goalsAgainst: 1 });
  assert.equal(S.resultOf(match), null); // noch nicht beendet
  match.status = 'beendet';
  assert.equal(S.resultOf(match), 'sieg');
});

test('Wurfbild Torwart und Gegner-Werfer', () => {
  const match = M.createMatch({ opponentName: 'X' });
  match.events = [
    M.createEvent({ playerId: 'p2', type: 'parade', isOpponent: true, goalZone: 'obenLinks', courtZone: 'kreis', opponentNumber: 9 }),
    M.createEvent({ playerId: 'p2', type: 'gegentor', isOpponent: true, goalZone: 'untenMitte', courtZone: 'rueckraumMitte', opponentNumber: 9 }),
    M.createEvent({ playerId: 'p2', type: 'fehlwurf', isOpponent: true, courtZone: 'aussenLinks', opponentNumber: 4 }),
  ];
  const map = S.keeperShotMap(match);
  assert.equal(map.saves, 1);
  assert.equal(map.conceded, 1);
  assert.equal(map.originMisses.aussenLinks, 1);
  assert.equal(map.shotsFaced, 3);
  const shooters = S.opponentShooters(match);
  assert.equal(shooters[9].conceded, 1);
  assert.equal(shooters[9].saves, 1);
  assert.equal(shooters[4].misses, 1);
});

test('Zeitstrafen laufen 120 s', () => {
  const match = M.createMatch({ opponentName: 'X' });
  match.firstHalfSec = 300;
  match.events = [M.createEvent({ playerId: 'p1', type: 'zeitstrafe', matchClockSec: 280 })];
  const list = S.activePenalties(match);
  assert.equal(list.length, 1);
  assert.equal(list[0].remainingSec, 100);
  match.firstHalfSec = 400;
  assert.equal(S.activePenalties(match).length, 0);
});

test('Zonen-Geometrie: Feldbereiche', async () => {
  const { zoneAt } = await import('../js/court.js');
  assert.equal(zoneAt(300, 273), 'siebenMeter');
  assert.equal(zoneAt(300, 100), 'kreis');
  assert.equal(zoneAt(300, 340), 'rueckraumMitte');
  assert.equal(zoneAt(20, 150), 'aussenLinks');
  assert.equal(zoneAt(580, 150), 'aussenRechts');
  assert.equal(zoneAt(300, -20), null);
});

test('Live: Wurf-Erfassung über Tor-Raster und Undo', () => {
  const store = setupStore();
  const session = new LiveSession({ store, matchId: 'm1' });
  session.toggleClock(); // startet das Spiel
  assert.equal(store.getMatch('m1').status, 'laufend');
  session.dispose();

  const live = new LiveSession({ store, matchId: 'm1' });
  live.selectPlayer('p1');
  live.onCourtZoneTap('rueckraumMitte');
  live.onGoalZoneTap('obenLinks');
  assert.ok(live.pendingShot);
  live.resolvePendingShot('tor');
  assert.equal(live.match.events.length, 1);
  assert.equal(live.match.events[0].type, 'tor');
  assert.equal(live.match.events[0].courtZone, 'rueckraumMitte');
  assert.equal(live.match.events[0].goalZone, 'obenLinks');

  live.onGoalZoneTap('linksDaneben'); // sofortiger Fehlwurf
  assert.equal(live.match.events.at(-1).type, 'fehlwurf');

  live.undoLastEvent();
  assert.equal(live.match.events.length, 1);
  live.dispose();
});

test('Live: Torwart-Mapping auf Gegentore und Gegnernummer', () => {
  const store = setupStore();
  const live = new LiveSession({ store, matchId: 'm1' });
  live.toggleClock();
  live.selectPlayer('p2');
  live.setOpponentNumber(11);
  live.setQuickContext('kreis');
  live.onGoalZoneTap('obenMitte');
  live.resolvePendingShot('tor');
  const ev = live.match.events.at(-1);
  assert.equal(ev.type, 'gegentor');
  assert.equal(ev.isOpponent, true);
  assert.equal(ev.opponentNumber, 11);

  live.onCourtZoneTap('freiwurf');
  live.onGoalZoneTap('untenLinks');
  live.resolvePendingShot('wurfGehalten');
  assert.equal(live.match.events.at(-1).type, 'paradeFreiwurf');
  live.dispose();
});

test('Live: Halbzeitwechsel per Uhr und Spielende', () => {
  const store = setupStore();
  const realNow = Date.now;
  let fake = realNow();
  Date.now = () => fake;
  try {
    const live = new LiveSession({ store, matchId: 'm1' });
    live.setPeriodClock(20 * 60 - 1);
    live.toggleClock(); // Anpfiff: Uhr laeuft ab jetzt aus der Startzeit
    assert.equal(live.running, true);
    fake += 2000;
    assert.equal(live.match.phase, 'halbzeitpause');
    assert.equal(live.match.firstHalfSec, 20 * 60);
    live.startSecondHalf();
    assert.equal(live.match.phase, 'zweiteHalbzeit');
    live.setPeriodClock(20 * 60 - 1);
    live.toggleClock();
    fake += 2000;
    assert.equal(live.match.status, 'beendet');
    assert.equal(live.match.phase, 'beendet');
    live.dispose();
  } finally {
    Date.now = realNow;
  }
});

test('Spieluhr: laeuft aus der Startzeit weiter, Halbzeitende wird berechnet', () => {
  const start = 1_000_000;
  const m = { ...M.createMatch({ id: 'x', halfLengthMin: 1 }), status: 'laufend', clockRunning: true, clockAt: start };
  assert.equal(M.advanceClock(m, start), m, 'ohne Zeitablauf unveraendert');
  const later = M.advanceClock(m, start + 30_500);
  assert.equal(later.firstHalfSec, 30);
  assert.equal(later.clockAt, start + 30_000, 'Startzeit rueckt um ganze Sekunden vor');
  const end = M.advanceClock(m, start + 61_000);
  assert.equal(end.phase, 'halbzeitpause');
  assert.equal(end.firstHalfSec, 60);
  assert.equal(end.clockRunning, false);
  const stopped = { ...m, clockRunning: false, clockAt: 0 };
  assert.equal(M.advanceClock(stopped, start + 99_000), stopped, 'angehaltene Uhr laeuft nicht');
});

test('Sync: nur Aenderungen werden gesendet, Abruf ohne Neues sendet nichts', async () => {
  const sent = [];
  const remote = {
    fetchChanges: async () => ({ version: 0, now: Date.now() }),
    pushChanges: async (body) => {
      sent.push(body);
      return { version: sent.length, based: true, skipped: false, now: Date.now() };
    },
  };
  const store = new M.Store(memoryStorage(), remote);
  store.setSession({ role: 'trainer' });
  await store.pull({ wait: 0 });
  store.setPlayers([M.createPlayer({ id: 'p1', number: 7, firstName: 'Max', lastName: 'Muster', position: 'feldspieler' })]);
  await store.push();
  assert.ok(sent[0].team, 'Team wird gesendet');

  store.saveMatch(M.createMatch({ id: 'm9', opponentName: 'Gegner' }));
  await store.push();
  assert.equal(sent[1].matches.length, 1);
  assert.equal(sent[1].events, undefined, 'keine Ereignisse gesendet');

  const m = store.getMatch('m9');
  m.events = [...m.events, M.createEvent({ id: 'e1', playerId: 'p1', type: 'tor', createdAt: 5 })];
  store.saveMatch(m);
  await store.push();
  assert.equal(sent[2].matches, undefined, 'Spiel-Kopf unveraendert, nicht erneut gesendet');
  assert.deepEqual(sent[2].events.map((e) => e.event.id), ['e1']);

  await store.push();
  assert.equal(sent.length, 3, 'ohne Aenderung wird nichts gesendet');
});

test('Store: Sicherung exportieren und wieder einlesen', () => {
  const store = setupStore();
  const backup = JSON.parse(JSON.stringify(store.exportBackup()));
  const other = new M.Store(memoryStorage());
  other.importBackup(backup);
  assert.equal(other.team.players.length, 3);
  assert.equal(other.matches.length, 1);
  assert.throws(() => other.importBackup({ foo: 1 }));
});

test('Store: Spieler löschen bereinigt Aufgebot', () => {
  const store = setupStore();
  store.deletePlayer('p3');
  assert.deepEqual(store.getMatch('m1').squadPlayerIds, ['p1', 'p2']);
  assert.equal(store.team.players.length, 2);
});
