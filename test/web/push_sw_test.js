// Deno tests for web/push_sw.js (study reminder notifications).
// Run: deno test --allow-read test/web/push_sw_test.js
//
// The worker is a classic script, so it is loaded into a fake `self` that
// records event listeners, notifications and window calls.
import { assert, assertEquals } from 'jsr:@std/assert@1';

const ORIGIN = 'https://learningapp.example';
const source = await Deno.readTextFile(new URL('../../web/push_sw.js', import.meta.url));

function loadWorker({ windows = [], openWindow, matchAll } = {}) {
  const listeners = {};
  const calls = { opened: [], shown: [], focused: [], navigated: [] };
  const self = {
    location: new URL(`${ORIGIN}/push_sw.js`),
    addEventListener: (type, fn) => { listeners[type] = fn; },
    skipWaiting: () => {},
    registration: {
      showNotification: (title, options) => {
        calls.shown.push({ title, options });
        return Promise.resolve();
      },
    },
    clients: {
      claim: () => Promise.resolve(),
      matchAll: matchAll ?? (() => Promise.resolve(windows)),
      openWindow: (url) => {
        calls.opened.push(url);
        return openWindow ? openWindow(url) : Promise.resolve({ url });
      },
    },
  };
  // Silence the worker's diagnostic warnings in test output.
  const quietConsole = { warn: () => {} };
  new Function('self', 'console', source)(self, quietConsole);

  const click = async (route) => {
    let pending;
    listeners.notificationclick({
      notification: { data: { route }, close: () => {} },
      waitUntil: (p) => { pending = p; },
    });
    return await pending;
  };
  const push = async (payload) => {
    let pending;
    listeners.push({
      data: payload === undefined ? null : { json: () => payload },
      waitUntil: (p) => { pending = p; },
    });
    await pending;
  };
  return { calls, click, push };
}

function tab(url, calls, { focus } = {}) {
  return {
    url,
    focus: () => {
      calls?.focused.push(url);
      return focus ? focus() : Promise.resolve();
    },
    navigate: () => Promise.reject(new TypeError('not controlled')),
  };
}

Deno.test('no open tab: opens the app at the reminder route', async () => {
  const w = loadWorker();
  assertEquals(await w.click('/learn'), 'opened');
  assertEquals(w.calls.opened, [`${ORIGIN}/#/learn`]);
});

Deno.test('an open app tab on another page is focused, not duplicated', async () => {
  const calls = { focused: [] };
  const w = loadWorker({ windows: [tab(`${ORIGIN}/#/progress`, calls)] });
  assertEquals(await w.click('/learn'), 'focused');
  assertEquals(calls.focused, [`${ORIGIN}/#/progress`]);
  assertEquals(w.calls.opened, []);
});

Deno.test('a tab already on the reminder page is preferred', async () => {
  const calls = { focused: [] };
  const w = loadWorker({
    windows: [tab(`${ORIGIN}/#/progress`, calls), tab(`${ORIGIN}/#/learn`, calls)],
  });
  await w.click('/learn');
  assertEquals(calls.focused, [`${ORIGIN}/#/learn`]);
});

Deno.test('other sites\' tabs are ignored', async () => {
  const calls = { focused: [] };
  const w = loadWorker({ windows: [tab('https://elsewhere.example/#/learn', calls)] });
  assertEquals(await w.click('/learn'), 'opened');
  assertEquals(calls.focused, []);
});

Deno.test('if focusing fails, a new tab is opened', async () => {
  const w = loadWorker({
    windows: [tab(`${ORIGIN}/#/learn`, null, { focus: () => Promise.reject(new Error('gone')) })],
  });
  assertEquals(await w.click('/learn'), 'opened');
  assertEquals(w.calls.opened.length, 1);
});

Deno.test('listing tabs failing still opens the app', async () => {
  const w = loadWorker({ matchAll: () => Promise.reject(new Error('boom')) });
  assertEquals(await w.click('/learn'), 'opened');
});

Deno.test('a refused or empty openWindow resolves without throwing', async () => {
  const refused = loadWorker({ openWindow: () => Promise.reject(new Error('no')) });
  assertEquals(await refused.click('/learn'), 'failed');
  const empty = loadWorker({ openWindow: () => Promise.resolve(null) });
  assertEquals(await empty.click('/learn'), 'failed');
});

Deno.test('routes stay on this site', async () => {
  for (const route of ['//evil.example/x', 'https://evil.example', 'javascript:alert(1)', 42, undefined]) {
    const w = loadWorker();
    await w.click(route);
    assertEquals(w.calls.opened, [`${ORIGIN}/#/learn`], String(route));
  }
  const w = loadWorker();
  await w.click('/progress');
  assertEquals(w.calls.opened, [`${ORIGIN}/#/progress`]);
});

Deno.test('push shows the reminder with a same-origin target', async () => {
  const w = loadWorker();
  await w.push({ title: 'Study reminder', body: 'Ready when you are.', url: '/learn', tag: 'study-reminder' });
  const { title, options } = w.calls.shown[0];
  assertEquals(title, 'Study reminder');
  assertEquals(options.body, 'Ready when you are.');
  assertEquals(options.navigate, `${ORIGIN}/#/learn`);
  assertEquals(options.actions[0].navigate, `${ORIGIN}/#/learn`);
  assertEquals(options.data.route, '/learn');
});

Deno.test('a malformed or empty push still shows a safe reminder', async () => {
  const w = loadWorker();
  await w.push(undefined);
  await w.push({ title: 7, url: '//evil.example' });
  for (const { title, options } of w.calls.shown) {
    assertEquals(title, 'Study reminder');
    assert(options.navigate.startsWith(`${ORIGIN}/#/`));
  }
});
