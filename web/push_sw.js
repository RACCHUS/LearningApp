// Study reminder push handler (learning.study_reminders).
//
// Registered by the app under its own scope ('./push/') so it never
// controls page loads or caches anything; it only receives pushes sent by
// the send-study-reminders Edge Function and shows them.
'use strict';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = {};
  }
  const title = typeof data.title === 'string' ? data.title : 'Study reminder';
  const options = {
    body: typeof data.body === 'string' ? data.body : '',
    tag: typeof data.tag === 'string' ? data.tag : 'study-reminder',
    icon: 'icons/icon-192.png',
    badge: 'icons/icon-192.png',
    data: { route: typeof data.url === 'string' ? data.url : '/learn' },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  // The app uses hash routing; only same-origin routes are opened.
  const route = String((event.notification.data || {}).route || '/learn');
  const safeRoute = route.startsWith('/') && !route.startsWith('//') ? route : '/learn';
  const target = new URL('/#' + safeRoute, self.location.origin).href;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if (new URL(client.url).origin === self.location.origin && 'focus' in client) {
        await client.focus();
        if ('navigate' in client) {
          try { await client.navigate(target); } catch (_) { /* uncontrolled */ }
        }
        return;
      }
    }
    await self.clients.openWindow(target);
  })());
});
