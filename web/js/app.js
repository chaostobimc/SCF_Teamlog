// Einstiegspunkt: Router (Hash-Adressen), Kopfleiste und Service Worker.
import { Store } from './model.js';
import { h, clear } from './ui.js';
import { renderHome } from './views/home.js';
import { renderSquad } from './views/squad.js';
import { renderSetup, renderOverview } from './views/match.js';
import { renderLive } from './views/live.js';
import { renderStats, renderPlayerDetail } from './views/stats.js';
import { renderData } from './views/data.js';
import { renderOpponents, renderOpponentTeam } from './views/opponents.js';
import { applyBackground } from './background.js';

const store = new Store(globalThis.localStorage);
applyBackground();
const main = document.getElementById('app');
const nav = document.getElementById('main-nav');

const ROUTES = [
  { pattern: /^\/?$/, view: renderHome, section: 'home', title: 'Start' },
  { pattern: /^\/kader\/?$/, view: renderSquad, section: 'squad', title: 'Kader' },
  { pattern: /^\/spiel\/neu\/?$/, view: renderSetup, section: 'home', title: 'Neues Spiel' },
  { pattern: /^\/spiel\/([^/]+)\/live\/?$/, view: renderLive, section: 'home', title: 'Live' },
  { pattern: /^\/spiel\/([^/]+)\/?$/, view: renderOverview, section: 'home', title: 'Spiel' },
  { pattern: /^\/gegner\/?$/, view: renderOpponents, section: 'opponents', title: 'Gegner' },
  { pattern: /^\/gegner\/([^/]+)\/?$/, view: renderOpponentTeam, section: 'opponents', title: 'Gegner' },
  { pattern: /^\/statistik\/?$/, view: renderStats, section: 'stats', title: 'Statistik' },
  { pattern: /^\/statistik\/([^/]+)\/?$/, view: renderPlayerDetail, section: 'stats', title: 'Spielerstatistik' },
  { pattern: /^\/daten\/?$/, view: renderData, section: 'data', title: 'Daten' },
];

let current = null; // { dispose?: fn }
let routeToken = 0;

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

function route() {
  const token = ++routeToken;
  const path = currentPath();
  const match = ROUTES.map((r) => ({ r, m: path.match(r.pattern) })).find((x) => x.m);

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
  setActiveNav(r.section);
  document.title = `${r.title} · SCF Teamlog`;

  const ctx = { store, navigate, params, token };
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

window.addEventListener('hashchange', route);
route();
