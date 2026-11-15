import { assertEquals } from 'jsr:@std/assert@1.0.13';
import {
  dispatchDueReminders,
  DueReminder,
  REMINDER_PAYLOAD,
  secretMatches,
  statusOf,
} from './dispatch.ts';

function row(subscription: string, reminder = 'r-' + subscription): DueReminder {
  return {
    reminder_id: reminder,
    subscription_id: subscription,
    endpoint: `https://push.example.invalid/${subscription}`,
    p256dh: 'p256dh-key-0123456789abcdef',
    auth_secret: 'auth-secret-01',
  };
}

Deno.test('sends once per browser and records every result', async () => {
  const sent: string[] = [];
  const recorded: [string, number][] = [];
  const summary = await dispatchDueReminders({
    claimDue: () => Promise.resolve([row('a', 'r1'), row('a', 'r2'), row('b'), row('c')]),
    send: (target) => {
      sent.push(target.endpoint);
      if (target.endpoint.endsWith('/b')) {
        return Promise.reject(Object.assign(new Error('gone'), { statusCode: 410 }));
      }
      if (target.endpoint.endsWith('/c')) return Promise.reject(new Error('offline'));
      return Promise.resolve(201);
    },
    record: (id, status) => {
      recorded.push([id, status]);
      return Promise.resolve();
    },
  });
  assertEquals(sent.length, 3, 'two reminders for browser a give one push');
  assertEquals(recorded, [['a', 201], ['b', 410], ['c', 0]]);
  assertEquals(summary, { claimed: 3, delivered: 1, failed: 2 });
});

Deno.test('nothing claimed (gate OFF) sends nothing', async () => {
  let sends = 0;
  const summary = await dispatchDueReminders({
    claimDue: () => Promise.resolve([]),
    send: () => {
      sends++;
      return Promise.resolve(201);
    },
    record: () => Promise.resolve(),
  });
  assertEquals(sends, 0);
  assertEquals(summary, { claimed: 0, delivered: 0, failed: 0 });
});

Deno.test('payload copy is neutral and opens Learn', () => {
  const payload = JSON.parse(REMINDER_PAYLOAD);
  assertEquals(payload.url, '/learn');
  assertEquals(/!/.test(payload.title + payload.body), false);
  assertEquals(/streak|lose|overdue|miss/i.test(payload.body), false);
});

Deno.test('secret check', () => {
  assertEquals(secretMatches('s3cret-value', 's3cret-value'), true);
  assertEquals(secretMatches('s3cret-valuX', 's3cret-value'), false);
  assertEquals(secretMatches('s3cret', 's3cret-value'), false);
  assertEquals(secretMatches(null, 's3cret-value'), false);
  assertEquals(secretMatches('anything', undefined), false);
});

Deno.test('statusOf reads WebPushError.statusCode, else 0', () => {
  assertEquals(statusOf({ statusCode: 404 }), 404);
  assertEquals(statusOf(new Error('x')), 0);
});
