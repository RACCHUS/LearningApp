// Study reminder push handler (learning.study_reminders).
//
// Registered by the app under its own scope ('./push/') so it never
// controls page loads or caches anything; it only receives pushes sent by
// the send-study-reminders Edge Function and shows them.
'use strict';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

// The app uses hash routing. Only same-origin app routes are ever opened.
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
    // Browsers with declarative notification navigation open this directly;
    // the others (Chrome, Edge, Firefox) use the click handler below.
    navigate: target,
    actions: [{ action: 'open-learningapp', title: 'Open LearningApp', navigate: target }],
    data: { route: data.url },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

// A click on the notification body or its "Open LearningApp" button.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = reminderTarget(event.notification.data && event.notification.data.route);
  event.waitUntil(openReminder(target));
});

// Reuse an open LearningApp tab, else open a new one.
//
// App pages are NOT controlled by this worker (its scope is ./push/), so
// client.navigate() always rejects for them: an open tab is focused as it
// is. Every failure is logged, because a silent failure here looks to the
// learner like "clicking does nothing".
async function openReminder(target) {
  let windows = [];
  try {
    windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
  } catch (error) {
    console.warn('[push_sw] could not list open tabs', error);
  }
  const appWindows = windows
    .filter((client) => sameOrigin(client.url))
    // Prefer a tab that is already on the reminder's page.
    .sort((a, b) => Number(b.url === target) - Number(a.url === target));

  for (const client of appWindows) {
    try {
      await client.focus();
      return 'focused';
    } catch (error) {
      console.warn('[push_sw] could not focus an open tab', error);
    }
  }

  try {
    const opened = await self.clients.openWindow(target);
    if (opened) return 'opened';
    console.warn('[push_sw] openWindow returned no window for', target);
  } catch (error) {
    console.warn('[push_sw] could not open', target, error);
  }
  return 'failed';
}

function sameOrigin(url) {
  try {
    return new URL(url).origin === self.location.origin;
  } catch (_) {
    return false;
  }
}
