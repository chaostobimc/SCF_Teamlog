// Statistik-Berechnung. Portiert aus lib/logic/stats_calculator.dart.
import { isConcededEvent, isOnTargetZone, matchClockSec } from './model.js';

export const COUNTER_KEYS = [
  'shots', 'goals', 'shotsSevenMeter', 'goalsSevenMeter', 'blocked',
  'stepErrors', 'dribbleErrors', 'attackerFouls', 'ballLosses', 'foulsSuffered',
  'sevenMeterWon', 'duelsWon', 'yellowCards', 'twoMinutes', 'redCards', 'blueCards',
  'saves', 'conceded', 'savesSevenMeter', 'concededSevenMeter',
  'savesFreeThrow', 'concededFreeThrow',
];

export function emptyStats() {
  const s = {};
  for (const key of COUNTER_KEYS) s[key] = 0;
  return s;
}

/** Summe mehrerer Statistiken. */
export function combineStats(list) {
  const total = emptyStats();
  for (const s of list) {
    for (const key of COUNTER_KEYS) total[key] += s[key];
  }
  return total;
}

/** Verarbeitet ein Ereignis und veraendert die Statistik (mutiert [s]). */
export function accumulate(s, event) {
  const type = event.type;
  // Gegnerische Fehlwuerfe zaehlen nicht als eigene Wuerfe des Spielers.
  if (event.isOpponent && (type === 'fehlwurf' || type === 'wurfGeblockt')) return s;
  const seven = event.isSevenMeter;
  switch (type) {
    case 'tor':
      s.shots += 1;
      s.goals += 1;
      if (seven) { s.shotsSevenMeter += 1; s.goalsSevenMeter += 1; }
      break;
    case 'fehlwurf':
    case 'wurfGehalten':
      s.shots += 1;
      if (seven) s.shotsSevenMeter += 1;
      break;
    case 'wurfGeblockt':
      s.blocked += 1;
      s.shots += 1;
      if (seven) s.shotsSevenMeter += 1;
      break;
    case 'schrittfehler': s.stepErrors += 1; break;
    case 'prellfehler': s.dribbleErrors += 1; break;
    case 'stuermerfoul': s.attackerFouls += 1; break;
    case 'ballverlust': s.ballLosses += 1; break;
    case 'gefoult': s.foulsSuffered += 1; break;
    case 'siebenMeterHerausgeholt': s.sevenMeterWon += 1; break;
    case 'duelGewonnen': s.duelsWon += 1; break;
    case 'gelbeKarte': s.yellowCards += 1; break;
    case 'zeitstrafe': s.twoMinutes += 1; break;
    case 'roteKarte': s.redCards += 1; break;
    case 'blaueKarte': s.blueCards += 1; break;
    case 'parade':
      s.saves += 1;
      break;
    case 'paradeSiebenMeter':
      s.saves += 1;
      s.savesSevenMeter += 1;
      break;
    case 'paradeFreiwurf':
      s.saves += 1;
      s.savesFreeThrow += 1;
      break;
    case 'gegentor':
      s.conceded += 1;
      break;
    case 'gegentorSiebenMeter':
      s.conceded += 1;
      s.concededSevenMeter += 1;
      break;
    case 'gegentorFreiwurf':
      s.conceded += 1;
      s.concededFreeThrow += 1;
      break;
    default:
      break;
  }
  return s;
}

// Kennzahlen (NaN = keine Daten)

export const ratio = (a, b) => (b === 0 ? NaN : a / b);

export function derived(s) {
  return {
    shotRatio: ratio(s.goals, s.shots),
    fieldShots: s.shots - s.shotsSevenMeter,
    fieldGoals: s.goals - s.goalsSevenMeter,
    fieldShotRatio: ratio(s.goals - s.goalsSevenMeter, s.shots - s.shotsSevenMeter),
    sevenMeterRatio: ratio(s.goalsSevenMeter, s.shotsSevenMeter),
    saveRatio: ratio(s.saves, s.saves + s.conceded),
    sevenMeterSaveRatio: ratio(s.savesSevenMeter, s.savesSevenMeter + s.concededSevenMeter),
    freeThrowSaveRatio: ratio(s.savesFreeThrow, s.savesFreeThrow + s.concededFreeThrow),
    technicalErrors: s.stepErrors + s.dribbleErrors,
    sanctions: s.yellowCards + s.twoMinutes + s.redCards + s.blueCards,
  };
}

// Spielstatistik

export function statsForPlayer(match, playerId) {
  const s = emptyStats();
  for (const event of match.events) {
    if (event.playerId !== playerId) continue;
    accumulate(s, event);
  }
  return s;
}

/** Statistik je Spieler plus Zonen-Tally (Tore/Paraden je Torzone) fuer ein Spiel. */
export function teamStats(match) {
  const perPlayer = {};
  const zones = {};
  for (const event of match.events) {
    if (!perPlayer[event.playerId]) perPlayer[event.playerId] = emptyStats();
    accumulate(perPlayer[event.playerId], event);

    const zone = event.goalZone;
    if (zone && isOnTargetZone(zone)) {
      if (!zones[zone]) zones[zone] = { goals: 0, saved: 0 };
      if (event.type === 'tor') zones[zone].goals += 1;
      else if (event.type === 'wurfGehalten') zones[zone].saved += 1;
    }
  }
  const total = combineStats(Object.values(perPlayer));
  return {
    perPlayer,
    zones,
    total,
    goalsFor: total.goals,
    goalsAgainst: total.conceded,
  };
}

/** Ergebnis aus Sicht des eigenen Teams. */
export function scoreOf(match) {
  let goalsFor = 0;
  let goalsAgainst = 0;
  for (const event of match.events) {
    if (event.type === 'tor' && !event.isOpponent) goalsFor += 1;
    if (isConcededEvent(event.type)) goalsAgainst += 1;
  }
  return { goalsFor, goalsAgainst };
}

/** 'sieg' | 'remis' | 'niederlage' | null (noch nicht beendet / keine Tore). */
export function resultOf(match) {
  if (match.status !== 'beendet') return null;
  const { goalsFor, goalsAgainst } = scoreOf(match);
  if (goalsFor > goalsAgainst) return 'sieg';
  if (goalsFor < goalsAgainst) return 'niederlage';
  return 'remis';
}

// Wurfbild Torwart

/**
 * Torzonen (Paraden/Gegentore) und Wurfpositionen des Gegners.
 * goalkeeperId optional: nur Wuerfe, die dieser Torwart gesehen hat.
 */
export function keeperShotMap(match, goalkeeperId = null) {
  const goalZones = {};
  const originsOnTarget = {};
  const originMisses = {};
  for (const event of match.events) {
    if (!event.isOpponent) continue;
    if (goalkeeperId && event.playerId !== goalkeeperId) continue;
    const isMiss = event.type === 'fehlwurf' || event.type === 'wurfGeblockt';
    const isGoal = isConcededEvent(event.type);
    if (isMiss) {
      if (event.courtZone) originMisses[event.courtZone] = (originMisses[event.courtZone] ?? 0) + 1;
      continue;
    }
    const gz = event.goalZone;
    if (gz && isOnTargetZone(gz)) {
      if (!goalZones[gz]) goalZones[gz] = { goals: 0, saved: 0 };
      if (isGoal) goalZones[gz].goals += 1;
      else goalZones[gz].saved += 1;
    }
    const origin = event.courtZone;
    if (origin) {
      if (!originsOnTarget[origin]) originsOnTarget[origin] = { goals: 0, saved: 0 };
      if (isGoal) originsOnTarget[origin].goals += 1;
      else originsOnTarget[origin].saved += 1;
    }
  }
  const saves = Object.values(goalZones).reduce((n, t) => n + t.saved, 0);
  const conceded = Object.values(goalZones).reduce((n, t) => n + t.goals, 0);
  const missCount = Object.values(originMisses).reduce((n, m) => n + m, 0);
  return {
    goalZones,
    originsOnTarget,
    originMisses,
    saves,
    conceded,
    shotsOnTarget: saves + conceded,
    shotsFaced: saves + conceded + missCount,
    saveRatio: ratio(saves, saves + conceded),
  };
}

/** Gegner-Werfer je Trikotnummer (0 = ohne Nummer). */
export function opponentShooters(match) {
  const result = {};
  for (const event of match.events) {
    if (!event.isOpponent) continue;
    const isMiss = event.type === 'fehlwurf' || event.type === 'wurfGeblockt';
    const isGoal = isConcededEvent(event.type);
    const key = event.opponentNumber ?? 0;
    const cur = result[key] ?? { shots: 0, onTarget: 0, saves: 0, conceded: 0, misses: 0 };
    cur.shots += 1;
    if (!isMiss) cur.onTarget += 1;
    if (!isMiss && !isGoal) cur.saves += 1;
    if (isGoal) cur.conceded += 1;
    if (isMiss) cur.misses += 1;
    result[key] = cur;
  }
  return result;
}

/** Laufende 2-Minuten-Strafen bei der aktuellen Netto-Spielzeit. */
export function activePenalties(match) {
  const now = matchClockSec(match);
  const list = [];
  for (const event of match.events) {
    if (event.type !== 'zeitstrafe' || event.isOpponent) continue;
    const endsAtSec = event.matchClockSec + 120;
    if (endsAtSec > now) list.push({ event, endsAtSec, remainingSec: endsAtSec - now });
  }
  return list;
}

/** Statistik eines Spielers ueber alle Spiele. */
export function allTimeStatsForPlayer(matches, playerId) {
  return combineStats(matches.map((m) => statsForPlayer(m, playerId)));
}

/** Pro Spiel: Anzahl gespielter Spiele (mit mindestens einem Ereignis oder im Aufgebot). */
export function playedMatches(matches, playerId) {
  return matches.filter(
    (m) => m.squadPlayerIds.includes(playerId) || m.events.some((e) => e.playerId === playerId),
  );
}
