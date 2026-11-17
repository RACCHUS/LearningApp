// Study reminder push handler (learning.study_reminders).
//
// Registered by the app under its own scope ('./push/') so it never
// controls page loads or caches anything; it only receives pushes sent by
// the send-study-reminders Edge Function and shows them.
'use strict';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

// The app uses hash routing. Keep a push-provided route on this origin.
function reminderTarget(route) {
  const safeRoute = typeof route === 'string' && route.startsWith('/') && !route.startsWith('//')
    ? route
    : '/learn';
  return new URL('/#' + safeRoute, self.location.origin).href;
}

self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = {};
  }
  const title = typeof data.title === 'string' ? data.title : 'Study reminder';
  const target = reminderTarget(data.url);
  const options = {
    body: typeof data.body === 'string' ? data.body : '',
    tag: typeof data.tag === 'string' ? data.tag : 'study-reminder',
    icon: 'icons/icon-192.png',
    badge: 'icons/icon-192.png',
    navigate: target,
    actions: [{ action: 'open-learningapp', title: 'Open LearningApp', navigate: target }],
    data: { route: data.url },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

// Browsers that ignore the native navigate option use this click handler.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = reminderTarget(event.notification.data?.route);
  event.waitUntil(openReminder(target));
});

async function openReminder(target) {
  const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    .catch(() => []);
  const appWindows = windows.filter((client) => new URL(client.url).origin === self.location.origin);

  for (const client of appWindows.filter((client) => client.url === target)) {
    try {
      await client.focus();
      return;
    } catch (_) {
      // A tab can close after matchAll. Try opening the app below.
    }
  }

  try {
    if (await self.clients.openWindow(target)) return;
  } catch (_) {
    // If opening a window fails, try an existing app tab.
  }

  for (const client of appWindows) {
    try {
      const navigated = await client.navigate(target);
      if (!navigated) continue;
      await navigated.focus();
      return;
    } catch (_) {
      // Try the next same-origin app tab.
    }
  }
}
