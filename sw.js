/*
  EERSSA Inspector — Service Worker
  Estrategia: cache-first para el "app shell" (HTML/manifest/íconos),
  de forma que la app abra y funcione sin conexión.
  Las peticiones a Supabase (otro origen) NO se interceptan aquí:
  se dejan pasar directo a la red y, si no hay internet, simplemente
  fallan — la app las reintenta más tarde mediante la cola de sincronización.
*/
const CACHE_VERSION = 'eerssa-inspector-v1';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-512-maskable.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // Solo manejamos peticiones GET de nuestro propio origen (el app shell).
  // Todo lo demás (Supabase, CDN de supabase-js, etc.) pasa directo a la red.
  if (req.method !== 'GET' || url.origin !== self.location.origin) {
    return;
  }

  event.respondWith(
    caches.match(req).then((cached) => {
      const network = fetch(req)
        .then((res) => {
          if (res && res.status === 200) {
            const copy = res.clone();
            caches.open(CACHE_VERSION).then((cache) => cache.put(req, copy));
          }
          return res;
        })
        .catch(() => cached);
      // Cache-first: responde de inmediato con la copia local si existe,
      // y de fondo actualiza la caché para la próxima vez.
      return cached || network;
    })
  );
});
