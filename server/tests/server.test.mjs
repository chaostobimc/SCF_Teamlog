// Tests fuer Konten, Rollen und Teamstand-Sync (Node-Bordmittel, echte SQLite-Datei in einem Temp-Ordner).
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createServer, openDb, hashPassword, verifyPassword } from '../server.mjs';

let server, base, dir, db;

before(async () => {
  dir = mkdtempSync(path.join(tmpdir(), 'scf-test-'));
  db = openDb(path.join(dir, 'test.db'));
  server = createServer({ db });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => {
  server.close();
  db.close();
  rmSync(dir, { recursive: true, force: true });
});

async function call(method, url, { body, cookie } = {}) {
  const res = await fetch(base + url, {
    method,
    headers: { ...(body ? { 'Content-Type': 'application/json' } : {}), ...(cookie ? { Cookie: cookie } : {}) },
    body: body ? JSON.stringify(body) : undefined,
    redirect: 'manual',
  });
  const setCookie = res.headers.get('set-cookie');
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* keine JSON-Antwort */ }
  return { status: res.status, json, text, cookie: setCookie ? setCookie.split(';')[0] : null };
}

test('Passwort-Hash prueft korrekt', () => {
  const h = hashPassword('geheim123');
  assert.equal(verifyPassword('geheim123', h), true);
  assert.equal(verifyPassword('falsch', h), false);
});

let admin, trainerCookie, playerCookie, playerId, adminCookie;

test('Ersteinrichtung: setupNeeded, Admin anlegen, danach gesperrt', async () => {
  let r = await call('GET', '/api/status');
  assert.equal(r.json.setupNeeded, true);
  r = await call('POST', '/api/setup', { body: { username: 'chef', password: 'passwort1', displayName: 'Chef' } });
  assert.equal(r.status, 201);
  assert.equal(r.json.user.role, 'admin');
  adminCookie = r.cookie;
  r = await call('POST', '/api/setup', { body: { username: 'zwei', password: 'passwort2' } });
  assert.equal(r.status, 409);
  r = await call('GET', '/api/status');
  assert.equal(r.json.setupNeeded, false);
});

test('Ohne Anmeldung kein Zugriff', async () => {
  assert.equal((await call('GET', '/api/state')).status, 401);
  assert.equal((await call('GET', '/api/me')).status, 401);
});

test('Login falsch/richtig, Session-Cookie', async () => {
  let r = await call('POST', '/api/login', { body: { username: 'chef', password: 'falsch' } });
  assert.equal(r.status, 401);
  r = await call('POST', '/api/login', { body: { username: 'CHEF', password: 'passwort1' } });
  assert.equal(r.status, 200);
  assert.match(r.cookie, /^scf_session=/);
  adminCookie = r.cookie;
  r = await call('GET', '/api/me', { cookie: adminCookie });
  assert.equal(r.json.user.username, 'chef');
});

test('Admin legt Trainer und Spieler an, Passwort-Reset erzwingt Wechsel', async () => {
  let r = await call('POST', '/api/admin/users', { cookie: adminCookie, body: { username: 'coach', displayName: 'Coach', role: 'trainer', password: 'trainer-pw' } });
  assert.equal(r.status, 201);
  r = await call('POST', '/api/admin/users', { cookie: adminCookie, body: { username: 'lena', displayName: 'Lena', role: 'spieler' } });
  assert.equal(r.status, 201);
  assert.ok(r.json.temporaryPassword.length >= 8);
  playerId = r.json.user.id;
  const tmpPw = r.json.temporaryPassword;
  r = await call('POST', '/api/login', { body: { username: 'lena', password: tmpPw } });
  playerCookie = r.cookie;
  assert.equal(r.json.user.mustChange, true);
  // Solange das Passwort nicht geaendert ist: keine Daten
  assert.equal((await call('GET', '/api/state', { cookie: playerCookie })).status, 403);
  r = await call('POST', '/api/me/password', { cookie: playerCookie, body: { current: tmpPw, newPassword: 'lena-neu-123' } });
  assert.equal(r.status, 200);
  r = await call('GET', '/api/state', { cookie: playerCookie });
  assert.equal(r.status, 200);

  r = await call('POST', '/api/login', { body: { username: 'coach', password: 'trainer-pw' } });
  trainerCookie = r.cookie;
});

test('Rollen: Spieler lesen, aber nicht schreiben', async () => {
  const r = await call('PUT', '/api/changes', { cookie: playerCookie, body: { since: 0, matches: [{ id: 'x1', updatedAt: 1 }] } });
  assert.equal(r.status, 403);
  const again = (await call('GET', '/api/changes?since=0', { cookie: playerCookie })).json;
  assert.ok(!(again.matches ?? []).some((m) => m.id === 'x1'));
});

test('Trainer sendet Aenderungen, Abruf liefert nur das Neue', async () => {
  const before = (await call('GET', '/api/changes?since=0', { cookie: trainerCookie })).json.version;
  let r = await call('PUT', '/api/changes', {
    cookie: trainerCookie,
    body: { since: before, matches: [{ id: 'm1', opponentName: 'Alpha', updatedAt: 100 }], events: [{ matchId: 'm1', event: { id: 'e1', type: 'tor', createdAt: 1 } }] },
  });
  assert.equal(r.status, 200);
  assert.equal(r.json.based, true);
  assert.equal(r.json.skipped, false);
  const v1 = r.json.version;
  assert.equal(v1, before + 1);

  // Nur eine Aenderung seit v1: ein neues Ereignis, Kopf unveraendert.
  r = await call('PUT', '/api/changes', { cookie: trainerCookie, body: { since: v1, events: [{ matchId: 'm1', event: { id: 'e2', type: 'fehlwurf', createdAt: 2 } }] } });
  assert.equal(r.json.version, v1 + 1);
  const delta = (await call('GET', `/api/changes?since=${v1}`, { cookie: trainerCookie })).json;
  assert.equal(delta.version, v1 + 1);
  assert.deepEqual(delta.events.map((e) => e.event.id), ['e2']);
  assert.equal(delta.matches, undefined, 'Kopf unveraendert, nicht erneut gesendet');

  // Vollstaendiger Stand enthaelt beide Ereignisse.
  const full = (await call('GET', '/api/state', { cookie: trainerCookie })).json;
  assert.equal(full.matches.find((m) => m.id === 'm1').events.length, 2);
});

test('Veraltete Spiel-Kopf-Aenderung wird abgewiesen, Loeschung und Ereignis-Entfernung wirken', async () => {
  const v = (await call('GET', '/api/changes?since=0', { cookie: trainerCookie })).json.version;
  // Neuerer Stand liegt auf dem Server (updatedAt 100) ...
  let r = await call('PUT', '/api/changes', { cookie: trainerCookie, body: { since: v, matches: [{ id: 'm1', opponentName: 'Neu', updatedAt: 200 }] } });
  assert.equal(r.json.skipped, false);
  // ... eine aeltere Sendung wird nicht uebernommen und als uebersprungen gemeldet.
  r = await call('PUT', '/api/changes', { cookie: trainerCookie, body: { since: r.json.version, matches: [{ id: 'm1', opponentName: 'Alt', updatedAt: 150 }] } });
  assert.equal(r.json.skipped, true);
  const full = (await call('GET', '/api/state', { cookie: trainerCookie })).json;
  assert.equal(full.matches.find((m) => m.id === 'm1').opponentName, 'Neu');

  // Ereignis entfernen (Undo) wird als Loeschung ausgeliefert.
  r = await call('PUT', '/api/changes', { cookie: trainerCookie, body: { since: r.json.version, deleteEvents: [{ matchId: 'm1', id: 'e2' }] } });
  const d = (await call('GET', `/api/changes?since=${r.json.version - 1}`, { cookie: trainerCookie })).json;
  assert.deepEqual(d.deleteEvents, [{ matchId: 'm1', id: 'e2' }]);
});

test('Long-Polling: Abruf wartet und kommt sofort, wenn etwas geschrieben wird', async () => {
  const v = (await call('GET', '/api/changes?since=0', { cookie: trainerCookie })).json.version;
  const started = Date.now();
  const waiting = call('GET', `/api/changes?since=${v}&wait=10`, { cookie: trainerCookie });
  await new Promise((r) => setTimeout(r, 150));
  await call('PUT', '/api/changes', { cookie: trainerCookie, body: { since: v, matches: [{ id: 'm2', opponentName: 'Beta', updatedAt: 300 }] } });
  const r = await waiting;
  assert.ok(Date.now() - started < 5000, 'Antwort kommt sofort nach der Aenderung');
  assert.equal(r.json.version, v + 1);
  assert.deepEqual(r.json.matches.map((m) => m.id), ['m2']);
});

test('Long-Polling ohne Aenderung: leere Antwort nach Ablauf (ohne Daten)', async () => {
  const v = (await call('GET', '/api/changes?since=0', { cookie: trainerCookie })).json.version;
  const r = await call('GET', `/api/changes?since=${v}&wait=1`, { cookie: trainerCookie });
  assert.equal(r.json.version, v);
  assert.equal(r.json.matches, undefined);
  assert.equal(r.json.events, undefined);
});

test('Ungueltige Aenderungen werden abgelehnt', async () => {
  const r = await call('PUT', '/api/changes', { cookie: adminCookie, body: { since: 0, matches: 'kaputt' } });
  assert.equal(r.status, 400);
});

test('Trainer hat keinen Admin-Zugriff, Admin hat ihn', async () => {
  assert.equal((await call('GET', '/api/admin/users', { cookie: trainerCookie })).status, 403);
  assert.equal((await call('GET', '/api/admin/users', { cookie: playerCookie })).status, 403);
  const r = await call('GET', '/api/admin/users', { cookie: adminCookie });
  assert.equal(r.json.users.length, 3);
  assert.equal((await call('GET', '/api/admin/export', { cookie: adminCookie })).json.state.matches.length, 2);
  const file = await fetch(base + '/api/admin/db-file', { headers: { Cookie: adminCookie } });
  assert.equal(file.status, 200);
  assert.equal(Buffer.from(await file.arrayBuffer()).subarray(0, 6).toString(), 'SQLite');
});

test('Admin setzt Passwort zurueck, alte Sitzung ist weg', async () => {
  const users = (await call('GET', '/api/admin/users', { cookie: adminCookie })).json.users;
  const coach = users.find((u) => u.username === 'coach');
  const r = await call('POST', `/api/admin/users/${coach.id}/reset`, { cookie: adminCookie });
  assert.equal(r.status, 200);
  assert.equal((await call('GET', '/api/me', { cookie: trainerCookie })).status, 401);
  const login = await call('POST', '/api/login', { body: { username: 'coach', password: r.json.temporaryPassword } });
  assert.equal(login.json.user.mustChange, true);
});

test('Letzter Admin kann nicht herabgestuft oder geloescht werden; Rolle aendern', async () => {
  const users = (await call('GET', '/api/admin/users', { cookie: adminCookie })).json.users;
  const chef = users.find((u) => u.username === 'chef');
  let r = await call('PATCH', `/api/admin/users/${chef.id}`, { cookie: adminCookie, body: { role: 'trainer' } });
  assert.equal(r.status, 400);
  r = await call('DELETE', `/api/admin/users/${chef.id}`, { cookie: adminCookie });
  assert.equal(r.status, 400);
  const lena = users.find((u) => u.id === playerId);
  r = await call('PATCH', `/api/admin/users/${lena.id}`, { cookie: adminCookie, body: { role: 'trainer' } });
  assert.equal(r.json.user.role, 'trainer');
  r = await call('DELETE', `/api/admin/users/${lena.id}`, { cookie: adminCookie });
  assert.equal(r.status, 200);
});

test('Logout beendet die Sitzung, Statische Dateien kommen aus web/', async () => {
  const r = await call('POST', '/api/logout', { cookie: adminCookie });
  assert.equal(r.status, 200);
  assert.equal((await call('GET', '/api/me', { cookie: adminCookie })).status, 401);
  const page = await call('GET', '/');
  assert.equal(page.status, 200);
  assert.match(page.text, /<html/i);
  const leak = await call('GET', '/../server/server.mjs');
  assert.equal(leak.status, 404); // Server-Code wird nicht ausgeliefert
  assert.doesNotMatch(leak.text, /createServer/);
});
