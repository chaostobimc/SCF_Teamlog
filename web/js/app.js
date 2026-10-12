// Einstiegspunkt: Anmeldung, Router (Hash-Adressen mit Rollenpruefung), Kopfleiste, Synchronisation, Service Worker.
import { Store } from './model.js';
import { api, ApiError, remoteState } from './api.js';
import { h, clear } from './ui.js';
import { applyBackground } from './background.js';
import { ROLE_LABELS, ROLE_RANK } from './views/roles.js';
import { renderHome } from './views/home.js';
import { renderSquad } from './views/squad.js';
import { renderSetup, renderOverview } from './views/match.js';
import { renderLive } from './views/live.js';
import { renderStats, renderPlayerDetail } from './views/stats.js';
import { renderData } from './views/data.js';
import { renderOpponents, renderOpponentTeam } from './views/opponents.js';
import { renderLogin, renderAccount } from './views/auth.js';
import { renderAdmin } from './views/admin.js';

const store = new Store(globalThis.localStorage, remoteState);
const main = document.getElementById('app');
const nav = document.getElementById('main-nav');
const syncEl = document.getElementById('sync-status');
const accountEl = document.getElementById('account-chip');
const logoutBtn = document.getElementById('logout-btn');
applyBackground();

// min: Mindestrolle. live: Route ist Erfassung (Spieler werden zur Spielseite geleitet).
const ROUTES = [
  { pattern: /^\/?$/, view: renderHome, section: 'home', title: 'Start' },
  { pattern: /^\/kader\/?$/, view: renderSquad, section: 'squad', title: 'Kader' },
  { pattern: /^\/spiel\/neu\/?$/, view: renderSetup, section: 'home', title: 'Neues Spiel', min: 'trainer', fallback: () => '/' },
  { pattern: /^\/spiel\/([^/]+)\/live\/?$/, view: renderLive, section: 'home', title: 'Live', min: 'trainer', fallback: (p) => `/spiel/${p[0]}` },
  { pattern: /^\/spiel\/([^/]+)\/?$/, view: renderOverview, section: 'home', title: 'Spiel' },
  { pattern: /^\/gegner\/?$/, view: renderOpponents, section: 'opponents', title: 'Gegner' },
  { pattern: /^\/gegner\/([^/]+)\/?$/, view: renderOpponentTeam, section: 'opponents', title: 'Gegner' },
  { pattern: /^\/statistik\/?$/, view: renderStats, section: 'stats', title: 'Statistik' },
  { pattern: /^\/statistik\/([^/]+)\/?$/, view: renderPlayerDetail, section: 'stats', title: 'Spielerstatistik' },
  { pattern: /^\/daten\/?$/, view: renderData, section: 'data', title: 'Daten' },
  { pattern: /^\/konto\/?$/, view: renderAccount, section: 'account', title: 'Konto' },
  { pattern: /^\/admin\/?$/, view: renderAdmin, section: 'admin', title: 'Admin', min: 'admin', fallback: () => '/' },
];

let current = null; // { dispose?: fn }
let routeToken = 0;
const session = {
  user: null,
  /** Nach Passwortwechsel u. a.: Sitzung aktualisieren (Rollen, Pflichtwechsel). */
  setUser(user) {
    applySession(user);
    store.setSession({ role: user.role, mustChange: user.mustChange });
    if (!user.mustChange) {
      store.pull();
      startSync();
    }
  },
};
let pollTimer = null;

function currentPath() {
  const raw = location.hash.replace(/^#/, '') || '/';
  return raw.startsWith('/') ? raw : '/' + raw;
}

export function navigate(path) {
  if (currentPath() === path) {
    route();
    return;
  }
  location.hash = path;
}

const roleOk = (min) => !min || ROLE_RANK[session.user?.role] >= ROLE_RANK[min];

function route() {
  const token = ++routeToken;
  const path = currentPath();
  if (!session.user) return; // ohne Anmeldung zeigt boot() die Anmeldung
  const match = ROUTES.map((r) => ({ r, m: path.match(r.pattern) })).find((x) => x.m);

  // Pflicht: neues Passwort setzen (z. B. nach Admin-Reset)
  if (session.user.mustChange && !(match && match.r.section === 'account')) {
    navigate('/konto');
    return;
  }

  current?.dispose?.();
  current = null;

  if (!match) {
    clear(main).append(h('div', { class: 'empty' },
      h('h3', {}, 'Seite nicht gefunden'),
      h('a', { class: 'btn primary', href: '#/' }, 'Zur Startseite'),
    ));
    document.title = 'SCF Teamlog';
    setActiveNav('home');
    return;
  }

  const { r, m } = match;
  const params = m.slice(1).map((p) => decodeURIComponent(p));
  if (!roleOk(r.min)) {
    navigate(r.fallback ? r.fallback(params) : '/');
    return;
  }
  setActiveNav(r.section);
  document.title = `${r.title} · SCF Teamlog`;

  const ctx = { store, navigate, params, token, session };
  try {
    const result = r.view(ctx);
    if (token !== routeToken) {
      result?.dispose?.();
      return;
    }
    clear(main);
    main.dataset.view = r.section;
    main.append(result.node ?? result);
    current = result?.dispose ? result : null;
    main.classList.toggle('is-live', r.view === renderLive);
    document.body.dataset.live = r.view === renderLive ? 'yes' : '';
    window.scrollTo({ top: 0 });
  } catch (error) {
    console.error(error);
    clear(main).append(h('div', { class: 'empty' },
      h('h3', {}, 'Da ist etwas schiefgelaufen'),
      h('p', { class: 'muted' }, error.message),
      h('a', { class: 'btn primary', href: '#/' }, 'Zur Startseite'),
    ));
  }
}

function setActiveNav(section) {
  for (const a of nav.querySelectorAll('[data-section]')) {
    a.classList.toggle('is-active', a.dataset.section === section);
    if (a.dataset.section === section) a.setAttribute('aria-current', 'page');
    else a.removeAttribute('aria-current');
  }
}

// ----------------------------------------------------------- Sitzung

function applySession(user) {
  session.user = user;
  document.body.dataset.role = user ? user.role : '';
  document.body.dataset.auth = user ? 'in' : 'out';
  if (accountEl && user) accountEl.textContent = `${user.displayName} · ${ROLE_LABELS[user.role]}`;
  logoutBtn?.classList.toggle('hidden', !user);
}

function showLogin(setupNeeded) {
  applySession(null);
  current?.dispose?.();
  current = null;
  document.title = 'Anmelden · SCF Teamlog';
  clear(main).append(renderLogin({ setupNeeded, onLoggedIn: (user) => enterApp(user) }));
  main.dataset.view = 'login';
}

async function enterApp(user) {
  applySession(user);
  store.setSession({ role: user.role, mustChange: user.mustChange });
  // Solange das Passwort gewechselt werden muss, keine Teamdaten laden.
  if (!user.mustChange) {
    await store.pull();
    startSync();
  }
  route();
  if (!location.hash) navigate('/');
}

function startSync() {
  clearInterval(pollTimer);
  pollTimer = setInterval(() => store.pull(), 20000);
}

function stopSync() {
  clearInterval(pollTimer);
  pollTimer = null;
}

async function logout() {
  try {
    await api('/logout', { method: 'POST' });
  } catch {
    // Auch ohne Verbindung abmelden
  }
  stopSync();
  store.clearLocal();
  location.hash = '#/';
  applySession(null);
  showLogin(false);
}

logoutBtn?.addEventListener('click', logout);

const SYNC_LABELS = { lokal: 'lokal', synchron: 'synchron', sendet: 'sendet …', offline: 'offline', 'keine Berechtigung': 'nur Ansicht' };
globalThis.addEventListener('scf-sync', (e) => {
  if (syncEl) {
    syncEl.textContent = SYNC_LABELS[e.detail] ?? e.detail;
    syncEl.dataset.state = e.detail;
  }
});

// Neue Daten von anderem Geraet: Leseansichten sofort aktualisieren.
// Ansichten ohne laufende Eingabe. Kein Neuzeichnen, solange ein Dialog offen ist.
const REFRESH_VIEWS = ['home', 'opponents', 'stats', 'squad'];
globalThis.addEventListener('scf-data', () => {
  if (REFRESH_VIEWS.includes(main.dataset.view) && !document.querySelector('.overlay')) route();
});

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && session.user && !session.user.mustChange) store.pull();
});

// ----------------------------------------------------------- Start

async function boot() {
  let status;
  try {
    status = await api('/status');
  } catch {
    clear(main).append(h('div', { class: 'empty' },
      h('h3', {}, 'Kein Verbindung zum Server'),
      h('p', { class: 'muted' }, 'SCF Teamlog braucht den Server (Datenbank, Konten). Bitte später erneut laden.'),
    ));
    return;
  }
  if (status.setupNeeded) {
    showLogin(true);
    return;
  }
  try {
    const { user } = await api('/me');
    await enterApp(user);
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) showLogin(false);
    else if (error instanceof ApiError && error.status === 403) {
      // Pflicht-Passwortwechsel: Sitzung ist gueltig, nur eingeschraenkt
      await enterApp(error.data?.user ?? null);
    } else throw error;
  }
}

window.addEventListener('hashchange', route);
boot();

// ----------------------------------------------------------- PWA

let deferredInstall = null;
const installBtn = document.getElementById('install-btn');

window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  deferredInstall = event;
  installBtn?.classList.remove('hidden');
});

installBtn?.addEventListener('click', async () => {
  if (!deferredInstall) return;
  deferredInstall.prompt();
  await deferredInstall.userChoice;
  deferredInstall = null;
  installBtn.classList.add('hidden');
});

window.addEventListener('appinstalled', () => installBtn?.classList.add('hidden'));

if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1')) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch((error) => console.warn('Service Worker nicht registriert', error));
  });
}
