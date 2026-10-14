#!/usr/bin/env node
// SCF Teamlog – Server: liefert die Web-App aus, speichert Konten und den Teamstand
// in einer SQLite-Datenbank (eingebautes node:sqlite, keine externen Pakete).
//
// Start:  node server/server.mjs         (Port 5555, Umgebungsvariablen: PORT, HOST, SCF_DATA_DIR)
// Rollen: spieler (nur lesen) · trainer (lesen + bearbeiten) · admin (alles + Konten + Datenbank)

import http from 'node:http';
import path from 'node:path';
import crypto from 'node:crypto';
import { mkdirSync, existsSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';
import { gzipSync } from 'node:zlib';
import { advanceClock } from '../web/js/model.js';

const here = path.dirname(fileURLToPath(import.meta.url));
export const WEB_DIR = path.resolve(here, '..', 'web');
const DEFAULT_DATA_DIR = process.env.SCF_DATA_DIR ?? path.join(here, 'data');
const DEFAULT_DB = process.env.SCF_DB ?? path.join(DEFAULT_DATA_DIR, 'scf-teamlog.db');

export const ROLES = ['spieler', 'trainer', 'admin'];
const RANK = { spieler: 0, trainer: 1, admin: 2 };
const SESSION_DAYS = 30;
const MIN_PASSWORD = 8;
const LOGIN_WINDOW_MS = 15 * 60 * 1000;
const LOGIN_MAX_FAILS = 10;
const EMPTY_STATE = {
  team: { id: 'scf-freising', name: 'SC Freising', primaryColor: '#2563EB', secondaryColor: '#F1F5F9', players: [] },
  matches: [],
};

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

// ------------------------------------------------------------ Datenbank

export function openDb(file = DEFAULT_DB) {
  if (file !== ':memory:') mkdirSync(path.dirname(file), { recursive: true });
  const db = new DatabaseSync(file);
  db.exec('PRAGMA foreign_keys = ON;');
  if (file !== ':memory:') db.exec('PRAGMA journal_mode = WAL;');
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL UNIQUE COLLATE NOCASE,
      display_name TEXT NOT NULL,
      role TEXT NOT NULL CHECK (role IN ('spieler','trainer','admin')),
      password_hash TEXT NOT NULL,
      must_change INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS sessions (
      token_hash TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      expires_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS app_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      version INTEGER NOT NULL,
      data TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      updated_by TEXT
    );
  `);
  db.prepare('INSERT OR IGNORE INTO app_state (id, version, data, updated_at) VALUES (1, 0, ?, ?)')
    .run(JSON.stringify(EMPTY_STATE), Date.now());
  // Teamstand in einzelne Zeilen (Spiele, Ereignisse), damit nur Aenderungen uebertragen werden.
  db.exec(`
    CREATE TABLE IF NOT EXISTS team_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      data TEXT NOT NULL,
      seq INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS matches (
      id TEXT PRIMARY KEY,
      header TEXT NOT NULL,
      updated_at INTEGER NOT NULL DEFAULT 0,
      seq INTEGER NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS matches_seq ON matches (seq);
    CREATE TABLE IF NOT EXISTS events (
      id TEXT PRIMARY KEY,
      match_id TEXT NOT NULL,
      data TEXT NOT NULL,
      seq INTEGER NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS events_seq ON events (seq);
    CREATE INDEX IF NOT EXISTS events_match ON events (match_id);
  `);
  migrateLegacyState(db);
  return db;
}

/** Uebernimmt einen aelteren Teamstand (ein JSON-Dokument in app_state) in die Zeilen-Tabellen. */
function migrateLegacyState(db) {
  if (db.prepare('SELECT COUNT(*) AS n FROM team_state').get().n > 0) return;
  const row = db.prepare('SELECT version, data FROM app_state WHERE id = 1').get();
  let legacy = {};
  try { legacy = JSON.parse(row.data) ?? {}; } catch { legacy = {}; }
  const seq = Math.max(row.version, 1);
  db.exec('BEGIN');
  try {
    db.prepare('INSERT INTO team_state (id, data, seq) VALUES (1, ?, ?)')
      .run(JSON.stringify(legacy.team ?? EMPTY_STATE.team), seq);
    const insM = db.prepare('INSERT OR REPLACE INTO matches (id, header, updated_at, seq, deleted) VALUES (?, ?, ?, ?, 0)');
    const insE = db.prepare('INSERT OR REPLACE INTO events (id, match_id, data, seq, deleted) VALUES (?, ?, ?, ?, 0)');
    for (const m of legacy.matches ?? []) {
      const { events = [], ...header } = m;
      insM.run(m.id, JSON.stringify(header), m.updatedAt ?? 0, seq);
      for (const e of events) insE.run(e.id, m.id, JSON.stringify(e), seq);
    }
    db.prepare("UPDATE app_state SET version = ?, data = '{}' WHERE id = 1").run(seq);
    db.exec('COMMIT');
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

/** Prueft die Aenderungen aus einer Sendung. */
function validChanges(b) {
  if (!isObj(b)) return false;
  if (b.team !== undefined && !(isObj(b.team) && Array.isArray(b.team.players))) return false;
  const list = (v, ok) => v === undefined || (Array.isArray(v) && v.length <= 20000 && v.every(ok));
  const id = (x) => typeof x === 'string' && x.length > 0 && x.length <= 100;
  return list(b.matches, (h) => isObj(h) && id(h.id))
    && list(b.deleteMatches, id)
    && list(b.events, (x) => isObj(x) && isObj(x.event) && id(x.event.id) && id(x.matchId))
    && list(b.deleteEvents, (x) => isObj(x) && id(x.id) && id(x.matchId));
}

// ------------------------------------------------------------ Hilfsfunktionen

export function hashPassword(password) {
  const salt = crypto.randomBytes(16);
  const key = crypto.scryptSync(password, salt, 64, { N: 16384, r: 8, p: 1 });
  return `scrypt$16384$${salt.toString('base64')}$${key.toString('base64')}`;
}

export function verifyPassword(password, stored) {
  const [alg, n, s, k] = String(stored).split('$');
  if (alg !== 'scrypt' || !n || !s || !k) return false;
  const expected = Buffer.from(k, 'base64');
  const key = crypto.scryptSync(password, Buffer.from(s, 'base64'), expected.length, { N: Number(n), r: 8, p: 1 });
  return key.length === expected.length && crypto.timingSafeEqual(key, expected);
}

const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');
const newId = () => crypto.randomUUID();
const newToken = () => crypto.randomBytes(32).toString('base64url');

/** Zufaelliges Einmal-Passwort (fuer Admin-Reset), gut lesbar. */
export function temporaryPassword() {
  return crypto.randomBytes(9).toString('base64url');
}

function publicUser(row) {
  return {
    id: row.id,
    username: row.username,
    displayName: row.display_name,
    role: row.role,
    mustChange: !!row.must_change,
    createdAt: row.created_at,
  };
}

function cookieValue(req, name) {
  const raw = req.headers.cookie ?? '';
  for (const part of raw.split(';')) {
    const [k, ...rest] = part.trim().split('=');
    if (k === name) return decodeURIComponent(rest.join('='));
  }
  return null;
}

function validUsername(u) {
  return typeof u === 'string' && /^[A-Za-z0-9._-]{3,32}$/.test(u);
}

function validPassword(p) {
  return typeof p === 'string' && p.length >= MIN_PASSWORD && p.length <= 200;
}

class HttpError extends Error {
  constructor(status, message, extra = {}) {
    super(message);
    this.status = status;
    this.extra = extra;
  }
}

// ------------------------------------------------------------ Server

export function createServer({ db = openDb(), webDir = WEB_DIR } = {}) {
  const loginFails = new Map(); // username -> { count, since }

  const sendJson = (res, status, body, headers = {}) => {
    const raw = JSON.stringify(body);
    const base = { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...headers };
    const gzipOk = String(res.req?.headers?.['accept-encoding'] ?? '').includes('gzip');
    if (gzipOk && raw.length > 1024) {
      res.writeHead(status, { ...base, 'Content-Encoding': 'gzip', Vary: 'Accept-Encoding' });
      res.end(gzipSync(raw));
      return;
    }
    res.writeHead(status, base);
    res.end(raw);
  };

  const readJson = (req, limit = 25 * 1024 * 1024) => new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) {
        reject(new HttpError(413, 'Daten zu gross.'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => {
      if (!chunks.length) return resolve({});
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch {
        reject(new HttpError(400, 'Ungueltiges JSON.'));
      }
    });
    req.on('error', reject);
  });

  const setSessionCookie = (res, token) => {
    const maxAge = SESSION_DAYS * 24 * 60 * 60;
    res.setHeader('Set-Cookie', `scf_session=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${maxAge}`);
  };

  const createSession = (userId) => {
    const token = newToken();
    db.prepare('INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (?, ?, ?)')
      .run(sha256(token), userId, Date.now() + SESSION_DAYS * 86400000);
    return token;
  };

  /** Liefert den angemeldeten Benutzer (Zeile) oder null. */
  const currentUser = (req) => {
    const token = cookieValue(req, 'scf_session');
    if (!token) return null;
    const row = db.prepare(`
      SELECT u.*, s.expires_at AS session_expires FROM sessions s
      JOIN users u ON u.id = s.user_id WHERE s.token_hash = ?`).get(sha256(token));
    if (!row) return null;
    if (row.session_expires < Date.now()) {
      db.prepare('DELETE FROM sessions WHERE token_hash = ?').run(sha256(token));
      return null;
    }
    return row;
  };

  const requireUser = (req, { min = 'spieler', allowMustChange = false } = {}) => {
    const user = currentUser(req);
    if (!user) throw new HttpError(401, 'Nicht angemeldet.');
    if (user.must_change && !allowMustChange) throw new HttpError(403, 'Bitte zuerst ein neues Passwort setzen.', { mustChange: true });
    if (RANK[user.role] < RANK[min]) throw new HttpError(403, 'Keine Berechtigung für diese Aktion.');
    return user;
  };

  const adminCount = () => db.prepare("SELECT COUNT(*) AS n FROM users WHERE role = 'admin'").get().n;

  const currentVersion = () => db.prepare('SELECT version FROM app_state WHERE id = 1').get().version;

  /** Vollstaendiger Teamstand (fuer Export und Abruf). */
  const readState = () => {
    const row = db.prepare('SELECT version, updated_at FROM app_state WHERE id = 1').get();
    const team = JSON.parse(db.prepare('SELECT data FROM team_state WHERE id = 1').get().data);
    const byMatch = new Map();
    for (const e of db.prepare('SELECT match_id, data FROM events WHERE deleted = 0').all()) {
      if (!byMatch.has(e.match_id)) byMatch.set(e.match_id, []);
      byMatch.get(e.match_id).push(JSON.parse(e.data));
    }
    const matches = db.prepare('SELECT header FROM matches WHERE deleted = 0').all().map((r) => {
      const h = JSON.parse(r.header);
      return { ...h, events: byMatch.get(h.id) ?? [] };
    });
    return { version: row.version, team, matches, updatedAt: row.updated_at };
  };

  /** Alles, was seit Version `since` geaendert wurde (leere Listen werden weggelassen). */
  const changesSince = (since) => {
    const out = {};
    const team = db.prepare('SELECT data, seq FROM team_state WHERE id = 1').get();
    if (team.seq > since) out.team = JSON.parse(team.data);
    const matches = [];
    const deletedMatches = [];
    for (const r of db.prepare('SELECT id, header, deleted FROM matches WHERE seq > ?').all(since)) {
      if (r.deleted) deletedMatches.push(r.id);
      else matches.push(JSON.parse(r.header));
    }
    const events = [];
    const deleteEvents = [];
    for (const r of db.prepare('SELECT id, match_id, data, deleted FROM events WHERE seq > ?').all(since)) {
      if (r.deleted) deleteEvents.push({ matchId: r.match_id, id: r.id });
      else events.push({ matchId: r.match_id, event: JSON.parse(r.data) });
    }
    if (matches.length) out.matches = matches;
    if (deletedMatches.length) out.deletedMatches = deletedMatches;
    if (events.length) out.events = events;
    if (deleteEvents.length) out.deleteEvents = deleteEvents;
    return out;
  };

  // Wartende Abfragen (Long-Polling): werden bei jeder Aenderung geweckt.
  const waiters = new Set();
  const notifyWaiters = () => { for (const wake of [...waiters]) wake(); };
  const waitForChange = (since, ms, res) => new Promise((resolve) => {
    const wake = () => { clearTimeout(timer); waiters.delete(wake); resolve(); };
    const timer = setTimeout(wake, ms);
    waiters.add(wake);
    res.on('close', wake);
  });

  /**
   * Aenderungen speichern. Pro Spiel gewinnt der neuere Stand (updatedAt), es sei denn force.
   * Ereignisse sind eindeutig benannt und werden zusammengefuehrt. Geloeschtes bleibt geloescht.
   * based: die Sendung beruht auf dem aktuellen Stand (dann genuegt die neue Version ohne Abruf).
   */
  const applyChanges = (body, username, { force = false } = {}) => {
    const cur = currentVersion();
    const based = body.since === cur;
    const next = cur + 1;
    const now = Date.now();
    let wrote = false;
    let skipped = false;
    db.exec('BEGIN IMMEDIATE');
    try {
      if (body.team) {
        db.prepare('UPDATE team_state SET data = ?, seq = ? WHERE id = 1').run(JSON.stringify(body.team), next);
        wrote = true;
      }
      const getM = db.prepare('SELECT updated_at, deleted FROM matches WHERE id = ?');
      const upsertM = db.prepare('INSERT OR REPLACE INTO matches (id, header, updated_at, seq, deleted) VALUES (?, ?, ?, ?, 0)');
      for (const raw of body.matches ?? []) {
        const { events: _ignored, ...header } = raw;
        const old = getM.get(header.id);
        if (old?.deleted || (old && !force && old.updated_at > (header.updatedAt ?? 0))) {
          skipped = true;
          continue;
        }
        upsertM.run(header.id, JSON.stringify(header), header.updatedAt ?? 0, next);
        wrote = true;
      }
      const delM = db.prepare("UPDATE matches SET deleted = 1, header = '{}', seq = ? WHERE id = ? AND deleted = 0");
      const delEvs = db.prepare('UPDATE events SET deleted = 1, seq = ? WHERE match_id = ? AND deleted = 0');
      for (const id of body.deleteMatches ?? []) {
        if (delM.run(next, id).changes) {
          delEvs.run(next, id);
          wrote = true;
        }
      }
      const getE = db.prepare('SELECT deleted FROM events WHERE id = ?');
      const upsertE = db.prepare('INSERT OR REPLACE INTO events (id, match_id, data, seq, deleted) VALUES (?, ?, ?, ?, 0)');
      for (const { matchId, event } of body.events ?? []) {
        const m = getM.get(matchId);
        const old = getE.get(event.id);
        if (!m || m.deleted || old?.deleted) {
          skipped = true;
          continue;
        }
        upsertE.run(event.id, matchId, JSON.stringify(event), next);
        wrote = true;
      }
      const delE = db.prepare('UPDATE events SET deleted = 1, seq = ? WHERE id = ? AND match_id = ? AND deleted = 0');
      for (const { matchId, id } of body.deleteEvents ?? []) {
        if (delE.run(next, id, matchId).changes) wrote = true;
      }
      if (wrote) {
        db.prepare('UPDATE app_state SET version = ?, updated_at = ?, updated_by = ? WHERE id = 1').run(next, now, username);
      }
      db.exec('COMMIT');
    } catch (error) {
      db.exec('ROLLBACK');
      throw error;
    }
    if (wrote) notifyWaiters();
    return { version: wrote ? next : cur, based, skipped, wrote };
  };

  /** Laufende Spieluhren: Halbzeitende und Spielende serverseitig nachfuehren, auch ohne offenes Geraet. */
  const advanceRunningClocks = () => {
    const rows = db.prepare("SELECT header FROM matches WHERE deleted = 0 AND header LIKE '%\"clockRunning\":true%'").all();
    const now = Date.now();
    const changed = [];
    for (const r of rows) {
      const h = JSON.parse(r.header);
      const n = advanceClock(h, now);
      if (n.phase !== h.phase || n.status !== h.status) changed.push(n);
    }
    if (changed.length) applyChanges({ since: -1, matches: changed }, 'Uhr', { force: true });
  };

  // ---------------- API-Routen
  async function api(req, res, url) {
    const p = url.pathname;
    const m = req.method;

    if (p === '/api/status' && m === 'GET') {
      return sendJson(res, 200, { setupNeeded: db.prepare('SELECT COUNT(*) AS n FROM users').get().n === 0 });
    }

    if (p === '/api/setup' && m === 'POST') {
      if (db.prepare('SELECT COUNT(*) AS n FROM users').get().n > 0) throw new HttpError(409, 'Die Ersteinrichtung ist bereits erledigt.');
      const body = await readJson(req);
      if (!validUsername(body.username)) throw new HttpError(400, 'Benutzername: 3–32 Zeichen (Buchstaben, Ziffern, . _ -).');
      if (!validPassword(body.password)) throw new HttpError(400, `Passwort: mindestens ${MIN_PASSWORD} Zeichen.`);
      const id = newId();
      db.prepare('INSERT INTO users (id, username, display_name, role, password_hash, must_change, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)')
        .run(id, body.username, String(body.displayName || body.username).slice(0, 80), 'admin', hashPassword(body.password), Date.now());
      setSessionCookie(res, createSession(id));
      return sendJson(res, 201, { user: publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(id)) });
    }

    if (p === '/api/login' && m === 'POST') {
      const body = await readJson(req);
      const key = String(body.username ?? '').toLowerCase();
      const fails = loginFails.get(key);
      if (fails && Date.now() - fails.since < LOGIN_WINDOW_MS && fails.count >= LOGIN_MAX_FAILS) {
        throw new HttpError(429, 'Zu viele Fehlversuche. Bitte in ein paar Minuten erneut versuchen.');
      }
      const row = db.prepare('SELECT * FROM users WHERE username = ?').get(String(body.username ?? ''));
      if (!row || !verifyPassword(String(body.password ?? ''), row.password_hash)) {
        const f = loginFails.get(key);
        if (!f || Date.now() - f.since >= LOGIN_WINDOW_MS) loginFails.set(key, { count: 1, since: Date.now() });
        else f.count += 1;
        throw new HttpError(401, 'Benutzername oder Passwort falsch.');
      }
      loginFails.delete(key);
      setSessionCookie(res, createSession(row.id));
      return sendJson(res, 200, { user: publicUser(row) });
    }

    if (p === '/api/logout' && m === 'POST') {
      const token = cookieValue(req, 'scf_session');
      if (token) db.prepare('DELETE FROM sessions WHERE token_hash = ?').run(sha256(token));
      res.setHeader('Set-Cookie', 'scf_session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0');
      return sendJson(res, 200, { ok: true });
    }

    if (p === '/api/me' && m === 'GET') {
      const user = requireUser(req, { allowMustChange: true });
      return sendJson(res, 200, { user: publicUser(user) });
    }

    if (p === '/api/me/password' && m === 'POST') {
      const user = requireUser(req, { allowMustChange: true });
      const body = await readJson(req);
      if (!verifyPassword(String(body.current ?? ''), user.password_hash)) throw new HttpError(400, 'Aktuelles Passwort ist falsch.');
      if (!validPassword(body.newPassword)) throw new HttpError(400, `Neues Passwort: mindestens ${MIN_PASSWORD} Zeichen.`);
      db.prepare('UPDATE users SET password_hash = ?, must_change = 0 WHERE id = ?').run(hashPassword(body.newPassword), user.id);
      return sendJson(res, 200, { ok: true });
    }

    if (p === '/api/state' && m === 'GET') {
      requireUser(req);
      return sendJson(res, 200, readState());
    }

    // Abruf: nur Aenderungen seit Version `since`. Mit wait > 0 wartet der Server auf Neues.
    if (p === '/api/changes' && m === 'GET') {
      requireUser(req);
      let since = Math.max(0, Math.floor(Number(url.searchParams.get('since')) || 0));
      const wait = Math.min(30, Math.max(0, Number(url.searchParams.get('wait')) || 0));
      if (since > currentVersion()) since = 0; // Datenbank wurde zurueckgesetzt: alles neu senden
      if (wait > 0 && currentVersion() <= since) await waitForChange(since, wait * 1000, res);
      const version = currentVersion();
      const body = { version, now: Date.now() };
      if (version > since) Object.assign(body, changesSince(since));
      return sendJson(res, 200, body);
    }

    // Senden: nur geaenderte Spiele, Ereignisse und Team (ab Trainer).
    if (p === '/api/changes' && m === 'PUT') {
      const user = requireUser(req, { min: 'trainer' });
      const raw = await readJson(req);
      const body = { ...raw, since: Number.isInteger(raw?.since) ? raw.since : -1 };
      if (!validChanges(body)) throw new HttpError(400, 'Ungueltige Aenderungen.');
      const result = applyChanges(body, user.username);
      return sendJson(res, 200, { version: result.version, based: result.based, skipped: result.skipped, now: Date.now() });
    }

    // ---------------- Admin
    if (p === '/api/admin/users' && m === 'GET') {
      requireUser(req, { min: 'admin' });
      const rows = db.prepare('SELECT * FROM users ORDER BY username COLLATE NOCASE').all();
      return sendJson(res, 200, { users: rows.map(publicUser) });
    }

    if (p === '/api/admin/users' && m === 'POST') {
      requireUser(req, { min: 'admin' });
      const body = await readJson(req);
      if (!validUsername(body.username)) throw new HttpError(400, 'Benutzername: 3–32 Zeichen (Buchstaben, Ziffern, . _ -).');
      if (!ROLES.includes(body.role)) throw new HttpError(400, 'Unbekannte Rolle.');
      const password = body.password ? String(body.password) : temporaryPassword();
      if (!validPassword(password)) throw new HttpError(400, `Passwort: mindestens ${MIN_PASSWORD} Zeichen.`);
      if (db.prepare('SELECT 1 FROM users WHERE username = ?').get(body.username)) throw new HttpError(409, 'Benutzername ist schon vergeben.');
      const id = newId();
      // Generiertes Einmal-Passwort: Wechsel erzwingen. Vom Admin gesetztes Passwort: nicht erzwingen.
      const mustChange = body.password ? 0 : 1;
      db.prepare('INSERT INTO users (id, username, display_name, role, password_hash, must_change, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
        .run(id, body.username, String(body.displayName || body.username).slice(0, 80), body.role, hashPassword(password), mustChange, Date.now());
      return sendJson(res, 201, { user: publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(id)), temporaryPassword: body.password ? null : password });
    }

    const userMatch = p.match(/^\/api\/admin\/users\/([^/]+)(\/reset)?$/);
    if (userMatch) {
      const admin = requireUser(req, { min: 'admin' });
      const target = db.prepare('SELECT * FROM users WHERE id = ?').get(decodeURIComponent(userMatch[1]));
      if (!target) throw new HttpError(404, 'Konto nicht gefunden.');

      if (userMatch[2] === '/reset' && m === 'POST') {
        const password = temporaryPassword();
        db.prepare('UPDATE users SET password_hash = ?, must_change = 1 WHERE id = ?').run(hashPassword(password), target.id);
        db.prepare('DELETE FROM sessions WHERE user_id = ?').run(target.id);
        return sendJson(res, 200, { temporaryPassword: password });
      }

      if (!userMatch[2] && m === 'PATCH') {
        const body = await readJson(req);
        const role = body.role ?? target.role;
        if (!ROLES.includes(role)) throw new HttpError(400, 'Unbekannte Rolle.');
        if (target.role === 'admin' && role !== 'admin' && adminCount() <= 1) {
          throw new HttpError(400, 'Der letzte Admin kann nicht herabgestuft werden.');
        }
        const name = body.displayName !== undefined ? String(body.displayName).slice(0, 80) || target.display_name : target.display_name;
        db.prepare('UPDATE users SET role = ?, display_name = ? WHERE id = ?').run(role, name, target.id);
        if (role !== target.role) db.prepare('DELETE FROM sessions WHERE user_id = ?').run(target.id);
        return sendJson(res, 200, { user: publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(target.id)) });
      }

      if (!userMatch[2] && m === 'DELETE') {
        if (target.id === admin.id) throw new HttpError(400, 'Das eigene Konto kann nicht gelöscht werden.');
        if (target.role === 'admin' && adminCount() <= 1) throw new HttpError(400, 'Der letzte Admin kann nicht gelöscht werden.');
        db.prepare('DELETE FROM users WHERE id = ?').run(target.id);
        return sendJson(res, 200, { ok: true });
      }
    }

    if (p === '/api/admin/export' && m === 'GET') {
      requireUser(req, { min: 'admin' });
      const users = db.prepare('SELECT * FROM users ORDER BY username COLLATE NOCASE').all().map(publicUser);
      return sendJson(res, 200, { exportedAt: new Date().toISOString(), users, state: readState() }, {
        'Content-Disposition': `attachment; filename="SCF_Teamlog_Export_${new Date().toISOString().slice(0, 10)}.json"`,
      });
    }

    if (p === '/api/admin/db-file' && m === 'GET') {
      requireUser(req, { min: 'admin' });
      const tmp = path.join(tmpdir(), `scf-copy-${process.pid}-${Date.now()}.db`);
      db.exec(`VACUUM INTO '${tmp.replace(/'/g, "''")}'`);
      try {
        const buf = await readFile(tmp);
        res.writeHead(200, {
          'Content-Type': 'application/vnd.sqlite3',
          'Content-Length': buf.length,
          'Content-Disposition': `attachment; filename="scf-teamlog-${new Date().toISOString().slice(0, 10)}.db"`,
          'Cache-Control': 'no-store',
        });
        res.end(buf);
      } finally {
        if (existsSync(tmp)) unlinkSync(tmp);
      }
      return;
    }

    throw new HttpError(404, 'Nicht gefunden.');
  }

  // ---------------- Statische Dateien
  async function serveStatic(req, res, url) {
    let rel = decodeURIComponent(url.pathname);
    if (rel.endsWith('/')) rel += 'index.html';
    const file = path.normalize(path.join(webDir, rel));
    if (!file.startsWith(webDir + path.sep) && file !== path.join(webDir, 'index.html')) {
      res.writeHead(403); res.end('Forbidden'); return;
    }
    let target = file;
    try {
      const info = await stat(target);
      if (info.isDirectory()) target = path.join(target, 'index.html');
    } catch {
      // Unbekannte Pfade ohne Dateiendung: Einstieg der App (Hash-Routing). Mit Endung: 404.
      if (path.extname(rel)) { res.writeHead(404); res.end('Not found'); return; }
      target = path.join(webDir, 'index.html');
    }
    try {
      const body = await readFile(target);
      res.writeHead(200, {
        'Content-Type': MIME[path.extname(target)] ?? 'application/octet-stream',
        'Cache-Control': 'no-cache',
        'X-Content-Type-Options': 'nosniff',
      });
      res.end(req.method === 'HEAD' ? undefined : body);
    } catch {
      res.writeHead(404); res.end('Not found');
    }
  }

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    try {
      if (url.pathname.startsWith('/api/')) await api(req, res, url);
      else await serveStatic(req, res, url);
    } catch (error) {
      if (error instanceof HttpError) {
        sendJson(res, error.status, { error: error.message, ...error.extra });
      } else {
        console.error('Serverfehler:', error);
        if (!res.headersSent) sendJson(res, 500, { error: 'Interner Serverfehler.' });
      }
    }
  });
  const clockTimer = setInterval(() => {
    try {
      advanceRunningClocks();
    } catch (error) {
      console.error('Spieluhr:', error);
    }
  }, 2000);
  clockTimer.unref();
  server.on('close', () => clearInterval(clockTimer));
  return server;
}

// ------------------------------------------------------------ Start

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.PORT ?? 5555);
  const host = process.env.HOST ?? '0.0.0.0';
  const server = createServer();
  server.listen(port, host, () => {
    console.log(`SCF Teamlog läuft auf http://${host}:${port}  (Datenbank: ${DEFAULT_DB})`);
  });
}
