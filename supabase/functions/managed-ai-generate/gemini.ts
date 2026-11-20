// Gemini call and error classification for managed-ai-generate. Pure apart
// from the injected fetch, so it is unit-tested without network or secrets.

export const MAX_PROMPT_CHARS = 40_000;
export const DEFAULT_MODEL = 'gemini-flash-latest';
const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta';

export type GeminiResult =
  | { ok: true; text: string }
  | {
    ok: false;
    // daily_quota: the free daily quota is used up (pause until reset).
    // rate_limited: a short per-minute limit.
    code:
      | 'daily_quota'
      | 'rate_limited'
      | 'blocked'
      | 'provider_busy'
      | 'empty_reply'
      | 'misconfigured'
      | 'network';
    retryAfterSeconds?: number;
  };

type Fetch = typeof fetch;

export async function generateWithGemini(
  prompt: string,
  options: { apiKey: string; model?: string; fetchImpl?: Fetch },
): Promise<GeminiResult> {
  const doFetch = options.fetchImpl ?? fetch;
  const model = options.model || DEFAULT_MODEL;
  let response: Response;
  try {
    response = await doFetch(
      `${ENDPOINT}/models/${encodeURIComponent(model)}:generateContent`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': options.apiKey,
        },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.4, maxOutputTokens: 8192 },
        }),
      },
    );
  } catch {
    return { ok: false, code: 'network' };
  }

  let body: unknown = null;
  try {
    body = await response.json();
  } catch {
    body = null;
  }

  if (!response.ok) return classifyGeminiError(response.status, body);

  const data = (body ?? {}) as Record<string, unknown>;
  const feedback = data.promptFeedback as Record<string, unknown> | undefined;
  if (feedback?.blockReason) return { ok: false, code: 'blocked' };
  const candidates = data.candidates as Array<Record<string, unknown>> | undefined;
  const first = candidates?.[0];
  const parts = ((first?.content as Record<string, unknown> | undefined)?.parts ??
    []) as Array<Record<string, unknown>>;
  const text = parts
    .filter((p) => typeof p.text === 'string' && p.thought !== true)
    .map((p) => p.text as string)
    .join('');
  if (!text.trim()) {
    const reason = String(first?.finishReason ?? '');
    const refused = ['SAFETY', 'PROHIBITED_CONTENT', 'BLOCKLIST', 'SPII'];
    return { ok: false, code: refused.includes(reason) ? 'blocked' : 'empty_reply' };
  }
  // A reply cut off at MAX_TOKENS is still returned: the app keeps the
  // finished items and asks only for the rest.
  return { ok: true, text };
}

export function classifyGeminiError(status: number, body: unknown): GeminiResult {
  const error = ((body ?? {}) as Record<string, unknown>).error as
    | Record<string, unknown>
    | undefined;
  const details = (error?.details ?? []) as Array<Record<string, unknown>>;

  if (status === 429) {
    let daily = false;
    let retryAfterSeconds: number | undefined;
    for (const d of details) {
      for (const v of (d.violations ?? []) as Array<Record<string, unknown>>) {
        const id = String(v.quotaId ?? '');
        if (id.includes('PerDay') || id.includes('Spend')) daily = true;
      }
      if (typeof d.retryDelay === 'string') {
        const s = parseFloat(d.retryDelay.replace('s', ''));
        if (!Number.isNaN(s)) retryAfterSeconds = Math.ceil(s);
      }
    }
    return daily
      ? { ok: false, code: 'daily_quota' }
      : { ok: false, code: 'rate_limited', retryAfterSeconds };
  }
  if (status === 400 || status === 401 || status === 403 || status === 404) {
    // Bad or restricted key, wrong model, or free tier unavailable here:
    // the owner has to fix the configuration.
    return { ok: false, code: 'misconfigured' };
  }
  if (status === 408 || status >= 500) return { ok: false, code: 'provider_busy' };
  return { ok: false, code: 'provider_busy' };
}
