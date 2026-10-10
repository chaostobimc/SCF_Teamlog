// Datenmodell, Konstanten, Speicher und Formatierung der SCF-Teamlog-Web-App.
// Entspricht dem Datenmodell der Flutter-App (lib/data/models), serialisiert als JSON.

export const SCF_TEAM_ID = 'scf-freising';
export const SCF_TEAM_NAME = 'SC Freising';
export const STORAGE_KEY = 'scf-teamlog-web-v1';
export const BACKUP_FORMAT = 'scf-teamlog-backup';
export const BACKUP_VERSION = 1;

export const PLAYER_POSITIONS = {
  feldspieler: 'Feldspieler',
  torwart: 'Torwart',
};

export const PLAYER_ROLES = {
  keine: 'Ohne feste Position',
  kreis: 'Kreisspieler',
  rueckraumLinks: 'Rückraum links',
  rueckraumMitte: 'Rückraum Mitte',
  rueckraumRechts: 'Rückraum rechts',
  aussenLinks: 'Außen links',
  aussenRechts: 'Außen rechts',
};

export const PHASE_LABELS = {
  ersteHalbzeit: '1. Halbzeit',
  halbzeitpause: 'Halbzeit',
  zweiteHalbzeit: '2. Halbzeit',
  beendet: 'Beendet',
};

export const GOAL_ZONES = [
  'obenLinks', 'obenMitte', 'obenRechts',
  'untenLinks', 'untenMitte', 'untenRechts',
  'linksDaneben', 'rechtsDaneben', 'drueber',
];

export const GOAL_ZONE_LABELS = {
  obenLinks: 'Oben links',
  obenMitte: 'Oben Mitte',
  obenRechts: 'Oben rechts',
  untenLinks: 'Unten links',
  untenMitte: 'Unten Mitte',
  untenRechts: 'Unten rechts',
  linksDaneben: 'Links vorbei',
  rechtsDaneben: 'Rechts vorbei',
  drueber: 'Über die Latte',
};

/** Die sechs Tor-Zonen, die im Tor liegen. */
export const ON_TARGET_ZONES = GOAL_ZONES.slice(0, 6);

export function isOnTargetZone(zone) {
  return ON_TARGET_ZONES.includes(zone);
}

export const COURT_ZONES = [
  'aussenLinks', 'rueckraumLinks', 'rueckraumMitte', 'kreis',
  'rueckraumRechts', 'aussenRechts', 'siebenMeter', 'freiwurf',
];

export const COURT_ZONE_LABELS = {
  aussenLinks: 'Außen links',
  rueckraumLinks: 'Rückraum links',
  rueckraumMitte: 'Rückraum Mitte',
  kreis: 'Kreis',
  rueckraumRechts: 'Rückraum rechts',
  aussenRechts: 'Außen rechts',
  siebenMeter: '7 Meter',
  freiwurf: 'Freiwurf',
};

/**
 * Ereignistypen. group: 'feld' (Feldspieler), 'tor' (Torhüter), 'strafe' (Sanktion).
 * positive: positive Wertung (grün in Listen).
 */
export const EVENT_TYPES = {
  tor: { label: 'Tor', short: 'Tor' },
  fehlwurf: { label: 'Fehlwurf', short: 'Fehlwurf' },
  wurfGehalten: { label: 'Wurf gehalten', short: 'Gehalten' },
  wurfGeblockt: { label: 'Wurf geblockt', short: 'Geblockt' },
  schrittfehler: { label: 'Schrittfehler', short: 'Schritt' },
  prellfehler: { label: 'Prellfehler', short: 'Prellen' },
  stuermerfoul: { label: 'Stürmerfoul', short: 'Stürmerfoul' },
  ballverlust: { label: 'Ballverlust', short: 'Ballverlust' },
  gefoult: { label: 'Gefoult worden', short: 'Gefoult' },
  siebenMeterHerausgeholt: { label: '7m herausgeholt', short: '7m geholt' },
  duelGewonnen: { label: 'Duell gewonnen', short: 'Duell' },
  parade: { label: 'Parade', short: 'Parade' },
  paradeSiebenMeter: { label: '7m-Parade', short: '7m-Parade' },
  paradeFreiwurf: { label: 'Freiwurf-Parade', short: 'FW-Parade' },
  gegentor: { label: 'Gegentor', short: 'Gegentor' },
  gegentorSiebenMeter: { label: '7m-Gegentor', short: '7m-Gegentor' },
  gegentorFreiwurf: { label: 'Freiwurf-Gegentor', short: 'FW-Gegentor' },
  gelbeKarte: { label: 'Gelbe Karte', short: 'Gelb' },
  zeitstrafe: { label: '2-Minuten-Strafe', short: '2 min' },
  roteKarte: { label: 'Rote Karte', short: 'Rot' },
  blaueKarte: { label: 'Blaue Karte', short: 'Blau' },
};

export const GOALKEEPER_EVENTS = [
  'parade', 'paradeSiebenMeter', 'paradeFreiwurf',
  'gegentor', 'gegentorSiebenMeter', 'gegentorFreiwurf',
];
export const SANCTION_EVENTS = ['gelbeKarte', 'zeitstrafe', 'roteKarte', 'blaueKarte'];
export const SHOT_EVENTS = ['tor', 'fehlwurf', 'wurfGehalten', 'wurfGeblockt'];
export const CONCEDED_EVENTS = ['gegentor', 'gegentorSiebenMeter', 'gegentorFreiwurf'];
const POSITIVE_EVENTS = [
  'tor', 'gefoult', 'siebenMeterHerausgeholt', 'duelGewonnen',
  'parade', 'paradeSiebenMeter', 'paradeFreiwurf',
];

export const isGoalkeeperEvent = (type) => GOALKEEPER_EVENTS.includes(type);
export const isSanctionEvent = (type) => SANCTION_EVENTS.includes(type);
export const isShotEvent = (type) => SHOT_EVENTS.includes(type);
export const isConcededEvent = (type) => CONCEDED_EVENTS.includes(type);
export const isPositiveEvent = (type) => POSITIVE_EVENTS.includes(type);

export const MATCH_STATUS = { geplant: 'Geplant', laufend: 'Läuft', beendet: 'Beendet' };

// ----------------------------------------------------------------- Formate

export function newId() {
  if (globalThis.crypto?.randomUUID) return crypto.randomUUID();
  return 'id-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
}

export function clock(totalSeconds) {
  const s = Math.max(0, Math.floor(totalSeconds));
  const m = Math.floor(s / 60);
  const sec = s % 60;
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
}

export function percent(ratio) {
  if (ratio === null || Number.isNaN(ratio)) return '–';
  return `${Math.round(ratio * 100)}%`;
}

export function dateLabel(ms) {
  const d = new Date(ms);
  return `${String(d.getDate()).padStart(2, '0')}.${String(d.getMonth() + 1).padStart(2, '0')}.${d.getFullYear()}`;
}

export function dateTimeLabel(ms) {
  const d = new Date(ms);
  return `${dateLabel(ms)}, ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')} Uhr`;
}

/** Datum fuer <input type="date"> (YYYY-MM-DD) in lokaler Zeit. */
export function toInputDate(ms) {
  const d = new Date(ms);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** Wandelt YYYY-MM-DD in einen Zeitstempel (Mittag lokal, damit keine Zeitzonen-Verschiebung). */
export function fromInputDate(value) {
  const [y, m, d] = value.split('-').map(Number);
  return new Date(y, m - 1, d, 12, 0, 0).getTime();
}

export function playerFullName(p) {
  const name = `${p.firstName} ${p.lastName}`.trim();
  return name || `Nr. ${p.number}`;
}

export function playerShortName(p) {
  const first = p.firstName.trim();
  const last = p.lastName.trim();
  if (!first && !last) return `Nr. ${p.number}`;
  if (!first) return last;
  if (!last) return first;
  return `${first[0]}. ${last}`;
}

// ----------------------------------------------------------- Modelle

export function createTeam(players = []) {
  return {
    id: SCF_TEAM_ID,
    name: SCF_TEAM_NAME,
    primaryColor: '#2563EB',
    secondaryColor: '#F1F5F9',
    players,
  };
}

export function createPlayer(fields) {
  return {
    id: fields.id ?? newId(),
    number: Number(fields.number),
    firstName: (fields.firstName ?? '').trim(),
    lastName: (fields.lastName ?? '').trim(),
    position: fields.position ?? 'feldspieler',
    gameRole: fields.gameRole ?? 'keine',
  };
}

export function createMatch(fields) {
  return {
    id: fields.id ?? newId(),
    ownTeamId: SCF_TEAM_ID,
    opponentName: (fields.opponentName ?? '').trim(),
    date: fields.date ?? Date.now(),
    isHome: fields.isHome ?? true,
    halfLengthMin: fields.halfLengthMin ?? 30,
    status: 'geplant',
    phase: 'ersteHalbzeit',
    firstHalfSec: 0,
    secondHalfSec: 0,
    pauseSec: 0,
    squadPlayerIds: [...(fields.squadPlayerIds ?? [])],
    events: [],
  };
}

export function createEvent(fields) {
  return {
    id: fields.id ?? newId(),
    playerId: fields.playerId,
    type: fields.type,
    matchClockSec: fields.matchClockSec ?? 0,
    phase: fields.phase ?? 'ersteHalbzeit',
    isSevenMeter: !!fields.isSevenMeter,
    isOpponent: !!fields.isOpponent,
    opponentNumber: fields.opponentNumber ?? null,
    goalZone: fields.goalZone ?? null,
    courtZone: fields.courtZone ?? null,
    createdAt: fields.createdAt ?? Date.now(),
  };
}

/** Netto-Spielzeit (beide Halbzeiten) in Sekunden. */
export function matchClockSec(match) {
  return match.firstHalfSec + match.secondHalfSec;
}

export function halfLengthSec(match) {
  return match.halfLengthMin * 60;
}

export function phaseElapsedSec(match) {
  switch (match.phase) {
    case 'ersteHalbzeit': return match.firstHalfSec;
    case 'halbzeitpause': return match.pauseSec;
    case 'zweiteHalbzeit': return match.secondHalfSec;
    default: return 0;
  }
}

/** Normalisiert gespeicherte Daten (fehlende Felder ergaenzen). */
export function normalizeMatch(raw) {
  return {
    ...createMatch({ id: raw.id, opponentName: raw.opponentName, date: raw.date, isHome: raw.isHome, halfLengthMin: raw.halfLengthMin, squadPlayerIds: raw.squadPlayerIds }),
    status: raw.status ?? 'geplant',
    phase: raw.phase ?? 'ersteHalbzeit',
    firstHalfSec: raw.firstHalfSec ?? 0,
    secondHalfSec: raw.secondHalfSec ?? 0,
    pauseSec: raw.pauseSec ?? 0,
    events: (raw.events ?? []).map((e) => createEvent(e)),
  };
}

export function normalizePlayer(raw) {
  return createPlayer(raw);
}

// ---------------------------------------------------------- Speicher

/**
 * Speicher in localStorage. Hält Team und Spiele im Speicher und schreibt
 * bei jeder Änderung den kompletten Stand (klein genug fuer eine Saison).
 */
export class Store {
  constructor(storage = globalThis.localStorage) {
    this.storage = storage;
    this.data = this._load();
  }

  _load() {
    try {
      const raw = this.storage?.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        return {
          team: createTeam((parsed.team?.players ?? []).map(normalizePlayer)),
          matches: (parsed.matches ?? []).map(normalizeMatch),
        };
      }
    } catch (error) {
      console.error('Konnte gespeicherte Daten nicht lesen', error);
    }
    return { team: createTeam(), matches: [] };
  }

  _persist() {
    try {
      this.storage?.setItem(STORAGE_KEY, JSON.stringify(this.data));
      return true;
    } catch (error) {
      console.error('Speichern fehlgeschlagen', error);
      return false;
    }
  }

  get team() {
    return this.data.team;
  }

  get matches() {
    return this.data.matches;
  }

  /** Spiele, neueste zuerst. */
  matchesSorted() {
    return [...this.data.matches].sort((a, b) => b.date - a.date);
  }

  getMatch(id) {
    return this.data.matches.find((m) => m.id === id) ?? null;
  }

  saveMatch(match) {
    const index = this.data.matches.findIndex((m) => m.id === match.id);
    if (index === -1) this.data.matches.push(match);
    else this.data.matches[index] = match;
    this._persist();
    return match;
  }

  deleteMatch(id) {
    this.data.matches = this.data.matches.filter((m) => m.id !== id);
    this._persist();
  }

  /** Kader komplett ersetzen (Kader-Einträge bleiben stabil per id). */
  setPlayers(players) {
    this.data.team = { ...this.data.team, players };
    this._persist();
  }

  upsertPlayer(player) {
    const players = [...this.data.team.players];
    const index = players.findIndex((p) => p.id === player.id);
    if (index === -1) players.push(player);
    else players[index] = player;
    this.setPlayers(players);
  }

  deletePlayer(id) {
    this.setPlayers(this.data.team.players.filter((p) => p.id !== id));
    // Aufgebote bereinigen, Ereignisse bleiben fuer die Statistik erhalten.
    for (const match of this.data.matches) {
      match.squadPlayerIds = match.squadPlayerIds.filter((pid) => pid !== id);
    }
    this._persist();
  }

  /** Komplette Sicherung (JSON). */
  exportBackup() {
    return {
      format: BACKUP_FORMAT,
      version: BACKUP_VERSION,
      exportedAt: new Date().toISOString(),
      team: this.data.team,
      matches: this.data.matches,
    };
  }

  /** Stellt eine Sicherung wieder her. Wirft bei ungueltigen Daten einen Fehler. */
  importBackup(backup) {
    if (!backup || backup.format !== BACKUP_FORMAT || !Array.isArray(backup.matches) || !backup.team) {
      throw new Error('Keine gültige SCF-Teamlog-Sicherung.');
    }
    this.data = {
      team: createTeam((backup.team.players ?? []).map(normalizePlayer)),
      matches: backup.matches.map(normalizeMatch),
    };
    this._persist();
  }

  resetAll() {
    this.data = { team: createTeam(), matches: [] };
    this._persist();
  }
}
