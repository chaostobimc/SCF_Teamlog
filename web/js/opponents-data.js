// Gegner-Auswertung: Mannschaften und Werfer (Trikotnummer) aus den gespeicherten Spielen.
// Reine Datenfunktionen ohne DOM, damit sie in den Node-Tests laufen.
import { CONCEDED_EVENTS, isOnTargetZone } from './model.js';

/** Schluessel fuer einen Gegnernamen (Gross/Klein und Leerzeichen egal). */
export function teamKey(name) {
  return String(name ?? '').trim().replace(/\s+/g, ' ').toLowerCase();
}

/** Ergebnis eines Gegner-Wurfs aus Sicht des Werfers. */
export function opponentOutcome(type) {
  if (CONCEDED_EVENTS.includes(type)) return 'goal';
  if (type === 'fehlwurf') return 'miss';
  if (type === 'wurfGeblockt') return 'block';
  return 'save'; // Parade, 7m-Parade, Freiwurf-Parade, wurfGehalten
}

/** Alle Gegner-Wuerfe (mit Ergebnis) eines Spiels, optional nur fuer eine Trikotnummer. */
export function opponentShots(match, number = undefined) {
  const shots = [];
  for (const e of match.events) {
    if (!e.isOpponent) continue;
    if (number !== undefined && (e.opponentNumber ?? null) !== number) continue;
    shots.push({
      id: e.id,
      matchId: match.id,
      number: e.opponentNumber ?? null,
      origin: e.courtZone ?? null,
      target: e.goalZone ?? null,
      outcome: opponentOutcome(e.type),
      sevenMeter: !!e.isSevenMeter,
      freeThrow: !!e.isFreeThrow,
    });
  }
  return shots;
}

/** Gegnerische Mannschaften, neueste Begegnung zuerst. */
export function groupOpponentTeams(matches) {
  const teams = new Map();
  for (const m of matches) {
    const name = (m.opponentName ?? '').trim();
    if (!name) continue;
    const key = teamKey(name);
    if (!teams.has(key)) teams.set(key, { key, matches: [] });
    teams.get(key).matches.push(m);
  }
  return [...teams.values()]
    .map((t) => {
      const sorted = [...t.matches].sort((a, b) => b.date - a.date);
      return {
        key: t.key,
        // Anzeigename: Schreibweise aus der neuesten Begegnung
        name: sorted[0].opponentName.trim(),
        matches: sorted,
        lastDate: sorted[0]?.date ?? 0,
        shotCount: sorted.reduce((n, m) => n + opponentShots(m).length, 0),
      };
    })
    .sort((a, b) => b.lastDate - a.lastDate);
}

/** Trikotnummern (ohne Nummer = null) mit Wuerfen aus allen Spielen, meiste Wuerfe zuerst. */
export function shooterNumbers(matches) {
  const counts = new Map();
  for (const m of matches) {
    for (const s of opponentShots(m)) {
      counts.set(s.number, (counts.get(s.number) ?? 0) + 1);
    }
  }
  return [...counts.entries()]
    .map(([number, shots]) => ({ number, shots }))
    .sort((a, b) => b.shots - a.shots || (a.number ?? 999) - (b.number ?? 999));
}

/** Tor-Raster-Zaehler fuer einen Werfer: Tore und uebrige Torschuesse je Torzone. */
export function targetTallies(shots) {
  const tallies = {};
  for (const s of shots) {
    if (!s.target || !isOnTargetZone(s.target)) continue;
    const t = tallies[s.target] ?? { goals: 0, saved: 0 };
    if (s.outcome === 'goal') t.goals += 1;
    else if (s.outcome === 'save') t.saved += 1;
    tallies[s.target] = t;
  }
  return tallies;
}

/** Bilanz eines Werfers ueber die gegebenen Wuerfe. */
export function shooterSummary(shots) {
  const goals = shots.filter((s) => s.outcome === 'goal').length;
  const saved = shots.filter((s) => s.outcome === 'save').length;
  const misses = shots.filter((s) => s.outcome === 'miss').length;
  const blocks = shots.filter((s) => s.outcome === 'block').length;
  return {
    shots: shots.length,
    goals,
    saved,
    misses,
    blocks,
    quote: shots.length ? goals / shots.length : NaN,
  };
}
