// Service Worker: offline nutzbar. Network-first, damit keine alten Dateien haengen bleiben.
const CACHE = 'scf-teamlog-v9';
const ASSETS = [
  './',
  './index.html',
  './css/styles.css?v=8',
  './js/app.js?v=8',
  './js/model.js',
  './js/stats.js',
  './js/match.js',
  './js/court.js',
  './js/ui.js',
  './js/components.js',
  './js/views/home.js',
  './js/views/squad.js',
  './js/views/match.js',
  './js/views/live.js',
  './js/views/stats.js',
  './js/views/data.js',
  './js/views/opponents.js',
  './js/opponents-data.js',
  './js/background.js',
  './manifest.webmanifest',
  './img/logo.png?v=8',
  './img/icon-192.png?v=8',
  './img/icon-512.png?v=8',
  './img/apple-touch-icon.png?v=8',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  // Network-first: frische Dateien zuerst, Cache nur als Offline-Fallback.
  event.respondWith(
    fetch(req)
      .then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((cache) => cache.put(req, copy));
        }
        return res;
      })
      .catch(() => caches.match(req, { ignoreSearch: true })),
  );
});
