// Pure dispatch logic for study reminders, kept free of network and
// Supabase imports so it can be unit tested with `deno test`.

export interface DueReminder {
  reminder_id: string;
  subscription_id: string;
  endpoint: string;
  p256dh: string;
  auth_secret: string;
}

export interface PushTarget {
  endpoint: string;
  keys: { p256dh: string; auth: string };
}

export interface DispatchDeps {
  /** claim_due_study_reminders: at-most-once claim; empty when the gate is OFF. */
  claimDue(limit: number): Promise<DueReminder[]>;
  /** Sends one encrypted push; resolves to the push service HTTP status. */
  send(target: PushTarget, payload: string): Promise<number>;
  /** record_push_delivery: success, gone (404/410) or failure bookkeeping. */
  record(subscriptionId: string, status: number): Promise<void>;
}

export interface DispatchSummary {
  claimed: number;
  delivered: number;
  failed: number;
}

/**
 * Neutral copy (UI_ARCHITECTURE_LOCKED.md §9.2): no urgency, no streak or
 * loss framing, no exclamation mark. Opens Learn.
 */
export const REMINDER_PAYLOAD = JSON.stringify({
  title: 'Study reminder',
  body: 'Ready when you are. Open LearningApp to pick up where you left off.',
  url: '/learn',
  tag: 'study-reminder',
});

const pushServiceHosts = new Set([
  'fcm.googleapis.com',
  'updates.push.services.mozilla.com',
  'web.push.apple.com',
]);

function trustedPushEndpoint(endpoint: string): string | null {
  let url: URL;
  try {
    url = new URL(endpoint);
  } catch {
    return null;
  }

  if (url.protocol !== 'https:' || url.port || url.username || url.password || url.hash) {
    return null;
  }

  // Edge's Windows Push Notification Service uses regional hosts.
  const isWindowsPush = /^[a-z0-9-]+\.notify\.windows\.com$/.test(url.hostname);
  if (!pushServiceHosts.has(url.hostname) && !isWindowsPush) return null;
  return url.href;
}

export async function dispatchDueReminders(
  deps: DispatchDeps,
  limit = 200,
): Promise<DispatchSummary> {
  const due = await deps.claimDue(limit);
  // One push per browser even if two reminders fall in the same run.
  const bySubscription = new Map<string, DueReminder>();
  for (const row of due) bySubscription.set(row.subscription_id, row);

  let delivered = 0;
  let failed = 0;
  for (const row of bySubscription.values()) {
    const endpoint = trustedPushEndpoint(row.endpoint);
    if (endpoint === null) {
      failed++;
      // Treat unsupported destinations as permanently invalid subscriptions.
      await deps.record(row.subscription_id, 410);
      continue;
    }

    let status: number;
    try {
      status = await deps.send(
        { endpoint, keys: { p256dh: row.p256dh, auth: row.auth_secret } },
        REMINDER_PAYLOAD,
      );
    } catch (error) {
      status = statusOf(error);
    }
    if (status >= 200 && status < 300) delivered++;
    else failed++;
    await deps.record(row.subscription_id, status);
  }
  return { claimed: bySubscription.size, delivered, failed };
}

/** web-push rejects with a WebPushError carrying statusCode; 0 = network. */
export function statusOf(error: unknown): number {
  if (error && typeof error === 'object' && 'statusCode' in error) {
    const code = Number((error as { statusCode: unknown }).statusCode);
    if (Number.isFinite(code)) return code;
  }
  return 0;
}

/** Constant-time comparison for the scheduler secret. */
export function secretMatches(given: string | null, expected: string | undefined): boolean {
  if (!given || !expected) return false;
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}
