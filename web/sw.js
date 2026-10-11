// Service Worker: macht die App offline nutzbar (Cache-first fuer die eigenen Dateien).
const CACHE = 'scf-teamlog-v8';
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

  event.respondWith(
    caches.match(req, { ignoreSearch: true }).then((cached) => {
      const network = fetch(req)
        .then((res) => {
          if (res && res.ok) {
            const copy = res.clone();
            caches.open(CACHE).then((cache) => cache.put(req, copy));
          }
          return res;
        })
        .catch(() => cached);
      return cached || network;
    }),
  );
});
