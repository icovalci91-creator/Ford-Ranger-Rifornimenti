// RangerTrack service worker — offline shell + apertura istantanea
// Strategia: HTML network-first (aggiornamenti sempre visibili con rete),
// asset cache-first con aggiornamento in background.
const CACHE = 'rangertrack-v2';
const ASSETS = ['./', './index.html', './logo.png', './apple-touch-icon.png', './preload_bimestri.json'];

self.addEventListener('install', e => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS).catch(() => {})));
});

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Documento HTML: network-first, fallback offline alla cache
  if (req.mode === 'navigate' || req.destination === 'document') {
    e.respondWith((async () => {
      try {
        const fresh = await fetch(req);
        const c = await caches.open(CACHE);
        c.put('./index.html', fresh.clone());
        return fresh;
      } catch {
        return (await caches.match('./index.html')) || (await caches.match('./')) || Response.error();
      }
    })());
    return;
  }

  // Asset stessa origine o Google Fonts: cache-first + refresh in background
  if (url.origin === location.origin || /fonts\.(googleapis|gstatic)\.com$/.test(url.host)) {
    e.respondWith((async () => {
      const cached = await caches.match(req);
      if (cached) {
        fetch(req).then(r => { if (r && r.ok) caches.open(CACHE).then(c => c.put(req, r.clone())); }).catch(() => {});
        return cached;
      }
      try {
        const r = await fetch(req);
        if (r && r.ok) { const c = await caches.open(CACHE); c.put(req, r.clone()); }
        return r;
      } catch {
        return cached || Response.error();
      }
    })());
  }
});
