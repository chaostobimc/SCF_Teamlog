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
    clockRunning: false,
    clockAt: 0,
    updatedAt: fields.updatedAt ?? 0,
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
    ...createMatch({ id: raw.id, opponentName: raw.opponentName, date: raw.date, isHome: raw.isHome, halfLengthMin: raw.halfLengthMin, squadPlayerIds: raw.squadPlayerIds, updatedAt: raw.updatedAt }),
    status: raw.status ?? 'geplant',
    phase: raw.phase ?? 'ersteHalbzeit',
    firstHalfSec: raw.firstHalfSec ?? 0,
    secondHalfSec: raw.secondHalfSec ?? 0,
    pauseSec: raw.pauseSec ?? 0,
    clockRunning: !!raw.clockRunning,
    clockAt: raw.clockAt ?? 0,
    events: (raw.events ?? []).map((e) => createEvent(e)),
  };
}

export function normalizePlayer(raw) {
  return createPlayer(raw);
}

// ---------------------------------------------------------- Zeit

/** Versatz der Geraeteuhr zur Serverzeit (ms). Wird bei jeder Serverantwort nachgefuehrt. */
export const clockSync = { offset: 0 };
export const serverNow = () => Date.now() + clockSync.offset;

const CLOCK_KEY = { ersteHalbzeit: 'firstHalfSec', halbzeitpause: 'pauseSec', zweiteHalbzeit: 'secondHalfSec' };

/**
 * Spieluhr fortschreiben. Laeuft die Uhr, werden seit clockAt (Serverzeit) ganze
 * Sekunden auf die aktuelle Phase addiert. Erreicht eine Halbzeit ihre Laenge, wechselt
 * die Phase (Halbzeitpause bzw. Spielende). Reine Funktion: ohne Aenderung wird das
 * gleiche Objekt zurueckgegeben. So laeuft die Zeit auch ohne offenes Geraet weiter.
 */
export function advanceClock(match, now = serverNow()) {
  if (!match.clockRunning || !match.clockAt || match.status !== 'laufend') return match;
  const key = CLOCK_KEY[match.phase];
  if (!key) return match;
  const secs = Math.floor((now - match.clockAt) / 1000);
  if (secs <= 0) return match;
  const half = halfLengthSec(match);
  const value = match[key] + secs;
  if (match.phase === 'halbzeitpause' || value < half) {
    return { ...match, [key]: value, clockAt: match.clockAt + secs * 1000 };
  }
  if (match.phase === 'ersteHalbzeit') {
    return { ...match, firstHalfSec: half, phase: 'halbzeitpause', clockRunning: false, clockAt: 0, updatedAt: now };
  }
  return { ...match, secondHalfSec: half, phase: 'beendet', status: 'beendet', clockRunning: false, clockAt: 0, updatedAt: now };
}

// ---------------------------------------------------------- Speicher

/** Stabile JSON-Darstellung (Schluessel sortiert), fuer den Vergleich mit dem Server-Stand. */
export function canon(value) {
  return JSON.stringify(value, (key, val) => {
    if (val && typeof val === 'object' && !Array.isArray(val)) {
      return Object.keys(val).sort().reduce((o, k) => { o[k] = val[k]; return o; }, {});
    }
    return val;
  });
}

const emptySnap = () => ({ team: '', matches: new Map() });
const headerKey = (m) => { const { events, updatedAt, ...header } = m; return canon(header); };
const stripEvents = ({ events, ...header }) => header;
const byCreated = (a, b) => (a.createdAt - b.createdAt) || (a.id < b.id ? -1 : 1);

/**
 * Speicher. Der Teamstand liegt auf dem Server (Datenbank) und wird zwischen den
 * Geraeten synchronisiert. Der Browser haelt eine lokale Kopie in localStorage
 * (schneller Start, Offline-Fallback). Schreiben duerfen nur Trainer und Admin.
 *
 * Synchronisation: Nur Aenderungen werden gesendet (Spiel-Kopf und einzelne Ereignisse),
 * nur neue Aenderungen werden empfangen (Long-Polling). Die Vergleichsbasis ist der
 * zuletzt bekannte Server-Stand (snap). Die Spieluhr wird nicht gesendet, sondern
 * als Startzeit (clockAt) gespeichert.
 *
 * remote: { fetchChanges({since, wait, signal}), pushChanges(body) }.
 * Ohne remote arbeitet der Speicher rein lokal (Tests).
 */
export class Store {
  constructor(storage = globalThis.localStorage, remote = null) {
    this.storage = storage;
    this.remote = remote;
    this.data = this._load();
    this.version = 0;
    this.role = null; // null = rein lokal
    this.mustChange = false;
    this.status = 'lokal';
    this.synced = false; // erster Abgleich mit dem Server abgeschlossen
    this.snap = emptySnap();
    this._timer = null;
    this._inFlight = null;
    this._again = false;
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

  _cache() {
    try {
      this.storage?.setItem(STORAGE_KEY, JSON.stringify(this.data));
    } catch (error) {
      console.error('Lokale Kopie konnte nicht gespeichert werden', error);
    }
  }

  /** Lokale Aenderung: Cache schreiben und Senden an den Server anstossen. */
  _persist() {
    this._cache();
    this._scheduleSync();
    return true;
  }

  // ---------------- Rollen und Sitzung

  get canWrite() {
    return !(this.role === 'spieler' || this.mustChange);
  }

  get canRead() {
    return !!this.role && !this.mustChange;
  }

  get canSync() {
    return !!this.remote && (this.role === 'trainer' || this.role === 'admin') && !this.mustChange;
  }

  _assertWrite() {
    if (!this.canWrite) throw new Error('Nur Ansicht: keine Berechtigung zum Bearbeiten.');
  }

  /** Nach Anmeldung: Rolle setzen, ausstehende Aenderungen senden. */
  setSession({ role, mustChange = false }) {
    this.role = role;
    this.mustChange = mustChange;
    if (this.canSync) this._scheduleSync();
  }

  /** Abmelden: lokale Kopie entfernen (Daten liegen auf dem Server). */
  clearLocal() {
    clearTimeout(this._timer);
    this.storage?.removeItem(STORAGE_KEY);
    this.data = { team: createTeam(), matches: [] };
    this.version = 0;
    this.synced = false;
    this.snap = emptySnap();
    this.role = null;
    this.mustChange = false;
  }

  _setStatus(status) {
    this.status = status;
    globalThis.dispatchEvent?.(new CustomEvent('scf-sync', { detail: status }));
  }

  // ---------------- Synchronisation

  _scheduleSync(delay = 400) {
    if (!this.canSync || !this.synced) return;
    clearTimeout(this._timer);
    this._timer = setTimeout(() => this.push(), delay);
  }

  /**
   * Vergleich mit dem zuletzt bekannten Server-Stand. Liefert nur die Aenderungen:
   * Team (falls geaendert), Spiel-Kopf (falls geaendert), neue/entfernte Ereignisse.
   */
  _diff() {
    const snap = this.snap;
    const out = { team: null, matches: [], deleteMatches: [], events: [], deleteEvents: [] };
    const next = { team: snap.team, matches: new Map(snap.matches) };
    const teamJson = canon(this.data.team);
    if (teamJson !== snap.team) {
      out.team = this.data.team;
      next.team = teamJson;
    }
    const alive = new Set();
    for (const m of this.data.matches) {
      alive.add(m.id);
      const { events, ...header } = m;
      const hj = canon(header);
      const s = snap.matches.get(m.id);
      const sEvents = s ? s.events : new Map();
      const evMap = new Map();
      const added = [];
      for (const e of events) {
        const ej = canon(e);
        evMap.set(e.id, ej);
        if (sEvents.get(e.id) !== ej) added.push(e);
      }
      const removed = [...sEvents.keys()].filter((id) => !evMap.has(id));
      const headerChanged = !s || s.header !== hj;
      if (!headerChanged && !added.length && !removed.length) continue;
      if (headerChanged) out.matches.push(header);
      for (const e of added) out.events.push({ matchId: m.id, event: e });
      for (const id of removed) out.deleteEvents.push({ matchId: m.id, id });
      next.matches.set(m.id, { header: hj, events: evMap });
    }
    for (const id of snap.matches.keys()) {
      if (!alive.has(id)) {
        out.deleteMatches.push(id);
        next.matches.delete(id);
      }
    }
    const hasChanges = !!(out.team || out.matches.length || out.deleteMatches.length
      || out.events.length || out.deleteEvents.length);
    return { out, next, hasChanges };
  }

  _hasPending() {
    return this.synced && this._diff().hasChanges;
  }

  /** Lokale Aenderungen an den Server senden (nur das Geaenderte). */
  push() {
    if (!this.canSync || !this.synced) return Promise.resolve();
    if (this._inFlight) {
      this._again = true;
      return this._inFlight;
    }
    const { out, next, hasChanges } = this._diff();
    if (!hasChanges) {
      this._setStatus('synchron');
      return Promise.resolve();
    }
    this._setStatus('sendet');
    this._inFlight = (async () => {
      try {
        const t0 = Date.now();
        // Nur belegte Felder senden (leere Listen und fehlendes Team weglassen).
        const body = { since: this.version };
        for (const [key, value] of Object.entries(out)) {
          if (value !== null && !(Array.isArray(value) && value.length === 0)) body[key] = value;
        }
        const res = await this.remote.pushChanges(body);
        this._noteTime(res.now, t0);
        this.snap = next;
        // Nur wenn seit dem letzten Abgleich niemand anders geschrieben hat, uebernehmen wir die Version direkt.
        if (res.based && !res.skipped) {
          this.version = res.version;
          this._cache();
        }
        this._setStatus(this._hasPending() ? 'sendet' : 'synchron');
      } catch (error) {
        if (error.status === 403) this._setStatus('keine Berechtigung');
        else if (error.name !== 'AbortError') {
          this._setStatus('offline');
          this._scheduleSync(5000); // erneut versuchen
        }
      } finally {
        this._inFlight = null;
        if (this._again) {
          this._again = false;
          this.push();
        }
      }
    })();
    return this._inFlight;
  }

  _noteTime(serverMs, t0) {
    if (typeof serverMs === 'number') clockSync.offset = serverMs - (t0 + Date.now()) / 2;
  }

  /**
   * Neue Aenderungen vom Server holen. Mit wait > 0 wartet der Server, bis es etwas Neues gibt
   * (Long-Polling). So kommen Aenderungen sofort an, ohne dauernd Anfragen zu senden.
   */
  async pull({ wait = 25, signal } = {}) {
    if (!this.remote || !this.canRead) return;
    const t0 = Date.now();
    let res;
    try {
      res = await this.remote.fetchChanges({ since: this.version, wait, signal });
    } catch (error) {
      if (error.name !== 'AbortError') this._setStatus('offline');
      throw error;
    }
    this._noteTime(res.now, t0);
    if (this._inFlight) await this._inFlight; // Eigene Sendung zuerst abschliessen
    const changed = this._applyRemote(res);
    this.version = res.version;
    this._cache();
    if (this._hasPending()) {
      this._setStatus('sendet');
      this._scheduleSync(0);
    } else if (this.status !== 'sendet' || !this._inFlight) {
      this._setStatus('synchron');
    }
    if (changed) globalThis.dispatchEvent?.(new CustomEvent('scf-data', { detail: res.version }));
  }

  /**
   * Server-Aenderungen einpflegen. Konflikte: Spiel-Kopf gewinnt der neuere Stand (updatedAt),
   * Ereignisse werden zusammengefuehrt (eindeutige Ids). Lokal geloeschte oder geaenderte
   * Dinge, die noch nicht gesendet wurden, bleiben erhalten.
   */
  _applyRemote(res) {
    let changed = false;
    const firstSync = !this.synced;
    const teamPending = !firstSync && canon(this.data.team) !== this.snap.team;
    if (res.team && !teamPending) {
      this.data.team = createTeam((res.team.players ?? []).map(normalizePlayer));
      this.snap.team = canon(this.data.team);
      changed = true;
    }
    for (const id of res.deletedMatches ?? []) {
      const before = this.data.matches.length;
      this.data.matches = this.data.matches.filter((m) => m.id !== id);
      this.snap.matches.delete(id);
      if (this.data.matches.length !== before) changed = true;
    }
    for (const h of res.matches ?? []) {
      const { events: _ignored, ...header } = h;
      const local = this.data.matches.find((m) => m.id === h.id);
      const known = this.snap.matches.get(h.id);
      if (!local) {
        if (known) continue; // lokal geloescht, Loeschung ist noch nicht gesendet
        const created = normalizeMatch({ ...header, events: [] });
        this.data.matches.push(created);
        this.snap.matches.set(h.id, { header: canon(stripEvents(created)), events: new Map() });
        changed = true;
        continue;
      }
      const serverTime = header.updatedAt ?? 0;
      const localTime = local.updatedAt ?? 0;
      let hj;
      if (serverTime > localTime) {
        // Server neuer: lokale Fassung ersetzen (Ereignisse bleiben).
        const replaced = normalizeMatch({ ...header, events: local.events });
        this.data.matches[this.data.matches.indexOf(local)] = replaced;
        hj = canon(stripEvents(replaced));
        changed = true;
      } else if (serverTime === localTime) {
        hj = canon(stripEvents(local)); // gleicher Stand
      } else {
        hj = canon(header); // lokal neuer und noch nicht gesendet: bleibt zum Senden offen
      }
      if (known) known.header = hj;
      else this.snap.matches.set(h.id, { header: hj, events: new Map() });
    }
    for (const { matchId, event } of res.events ?? []) {
      const known = this.snap.matches.get(matchId);
      const local = this.data.matches.find((m) => m.id === matchId);
      if (!known || !local) continue;
      if (known.events.has(event.id)) continue; // schon bekannt (eigene Sendung) oder lokal entfernt
      const created = createEvent(event);
      known.events.set(event.id, canon(created));
      if (!local.events.some((e) => e.id === event.id)) {
        local.events = [...local.events, created].sort(byCreated);
        changed = true;
      }
    }
    for (const { matchId, id } of res.deleteEvents ?? []) {
      const known = this.snap.matches.get(matchId);
      if (known) known.events.delete(id);
      const local = this.data.matches.find((m) => m.id === matchId);
      if (local && local.events.some((e) => e.id === id)) {
        local.events = local.events.filter((e) => e.id !== id);
        changed = true;
      }
    }
    this.synced = true;
    return changed;
  }

  hasContent() {
    return this.data.matches.length > 0 || this.data.team.players.length > 0;
  }

  // ---------------- Zugriff auf Daten

  /** Spiel mit fortgeschriebener Uhr. Phasenwechsel (z. B. Halbzeitende) werden gespeichert. */
  _live(raw) {
    const m = advanceClock(raw, serverNow());
    if (m !== raw && (m.phase !== raw.phase || m.status !== raw.status)) {
      const i = this.data.matches.indexOf(raw);
      if (i !== -1) this.data.matches[i] = m;
      this._persist();
    }
    return m;
  }

  get team() {
    return this.data.team;
  }

  get matches() {
    return this.data.matches.map((m) => this._live(m));
  }

  /** Spiele, neueste zuerst. */
  matchesSorted() {
    return this.matches.sort((a, b) => b.date - a.date);
  }

  getMatch(id) {
    const raw = this.data.matches.find((m) => m.id === id);
    return raw ? this._live(raw) : null;
  }

  saveMatch(match) {
    this._assertWrite();
    const index = this.data.matches.findIndex((m) => m.id === match.id);
    const prev = index === -1 ? null : this.data.matches[index];
    // updatedAt nur aendern, wenn sich der Spiel-Kopf geaendert hat (Ereignisse sind eigene Eintraege).
    const sameHeader = prev && headerKey(prev) === headerKey(match);
    match.updatedAt = sameHeader ? prev.updatedAt : serverNow();
    if (index === -1) this.data.matches.push(match);
    else this.data.matches[index] = match;
    this._persist();
    return match;
  }

  deleteMatch(id) {
    this._assertWrite();
    this.data.matches = this.data.matches.filter((m) => m.id !== id);
    this._persist();
  }

  /** Kader komplett ersetzen (Kader-Eintraege bleiben stabil per id). */
  setPlayers(players) {
    this._assertWrite();
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
    this._assertWrite();
    this.data.team = { ...this.data.team, players: this.data.team.players.filter((p) => p.id !== id) };
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
      matches: this.matches,
    };
  }

  /** Stellt eine Sicherung wieder her. Wirft bei ungueltigen Daten einen Fehler. */
  importBackup(backup) {
    this._assertWrite();
    if (!backup || backup.format !== BACKUP_FORMAT || !Array.isArray(backup.matches) || !backup.team) {
      throw new Error('Keine gueltige SCF-Teamlog-Sicherung.');
    }
    this.data = {
      team: createTeam((backup.team.players ?? []).map(normalizePlayer)),
      matches: backup.matches.map(normalizeMatch),
    };
    this._persist();
  }

  resetAll() {
    this._assertWrite();
    this.data = { team: createTeam(), matches: [] };
    this._persist();
  }
}
