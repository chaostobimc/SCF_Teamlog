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
  return db;
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

function validState(body) {
  return body && typeof body === 'object'
    && body.team && typeof body.team === 'object' && Array.isArray(body.team.players)
    && Array.isArray(body.matches);
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
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...headers });
    res.end(JSON.stringify(body));
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

  const readState = () => {
    const row = db.prepare('SELECT version, data, updated_at FROM app_state WHERE id = 1').get();
    const data = JSON.parse(row.data);
    return { version: row.version, team: data.team, matches: data.matches, updatedAt: row.updated_at };
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

    if (p === '/api/state' && m === 'PUT') {
      const user = requireUser(req, { min: 'trainer' });
      const body = await readJson(req);
      if (!validState(body)) throw new HttpError(400, 'Ungueltiger Teamstand.');
      const current = db.prepare('SELECT version FROM app_state WHERE id = 1').get().version;
      if (body.version !== current) {
        // Anderes Geraet hat zwischenzeitlich gespeichert: aktuellen Stand zurueckgeben.
        throw new HttpError(409, 'Der Stand wurde auf einem anderen Gerät geändert.', { state: readState() });
      }
      const data = JSON.stringify({ team: body.team, matches: body.matches });
      db.prepare('UPDATE app_state SET version = version + 1, data = ?, updated_at = ?, updated_by = ? WHERE id = 1')
        .run(data, Date.now(), user.username);
      return sendJson(res, 200, { version: current + 1 });
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

  return http.createServer(async (req, res) => {
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
