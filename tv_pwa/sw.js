// Service worker de BabyWolf TV.
//
// Dos estrategias, según lo que se pide:
//   Cache First   para los estáticos — la app arranca aunque no haya red.
//   Network First para la API        — las noticias deben ser frescas, con
//                                      el cache como red de seguridad.

const CACHE_ESTATICO = 'babywolf-tv-static-v1';
const CACHE_DINAMICO = 'babywolf-tv-dynamic-v1';

const ESTATICOS = [
  './',
  './index.html',
  './css/styles.css',
  './js/api.js',
  './js/sync.js',
  './js/navigation.js',
  './js/app.js',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches
      .open(CACHE_ESTATICO)
      .then((cache) => cache.addAll(ESTATICOS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches
      .keys()
      .then((claves) =>
        Promise.all(
          claves
            .filter((k) => k !== CACHE_ESTATICO && k !== CACHE_DINAMICO)
            .map((k) => caches.delete(k))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  // El estado del hub siempre tiene que ser el de ahora: nunca se cachea.
  if (url.port === '8090') return;

  if (url.href.includes('/api/posts')) {
    e.respondWith(networkFirst(e.request));
    return;
  }

  e.respondWith(cacheFirst(e.request));
});

async function cacheFirst(request) {
  const enCache = await caches.match(request);
  if (enCache) return enCache;

  try {
    return await fetch(request);
  } catch {
    // Sin red y sin cache: para una navegación, se devuelve la app.
    if (request.mode === 'navigate') {
      const inicio = await caches.match('./index.html');
      if (inicio) return inicio;
    }
    return Response.error();
  }
}

async function networkFirst(request) {
  try {
    const res = await fetch(request);
    const cache = await caches.open(CACHE_DINAMICO);
    cache.put(request, res.clone());
    return res;
  } catch (err) {
    // Se sirven las últimas noticias conocidas en vez de una pantalla vacía.
    const enCache = await caches.match(request);
    if (enCache) return enCache;
    throw err;
  }
}
