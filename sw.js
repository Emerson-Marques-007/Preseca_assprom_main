// ============================================
// SERVICE WORKER — Presença Digital
// Cache estratégico para funcionar como PWA
// ============================================

const CACHE_NAME = 'presenca-digital-v2';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/p.html',
  '/presenca.html',
  '/aluno/index.html',
  '/aluno/historico.html',
  '/professor/index.html',
  '/css/style.css',
  '/js/config.js',
  '/js/utils.js',
  '/js/auth.js',
  '/manifest.json',
  '/assets/logo.png'
];

// Instalar — cachear assets estáticos
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting())
  );
});

// Ativar — limpar caches antigos
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then(keys => {
      return Promise.all(
        keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch — Network first, fallback to cache
self.addEventListener('fetch', (event) => {
  // Ignorar requests para Supabase (sempre online)
  if (event.request.url.includes('supabase')) {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then(response => {
        // Cache a cópia da resposta
        const clone = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        return response;
      })
      .catch(() => {
        return caches.match(event.request);
      })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = event.notification?.data?.url || '/aluno/index.html';

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientsArr) => {
      for (const client of clientsArr) {
        if ('focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }

      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }

      return undefined;
    })
  );
});
