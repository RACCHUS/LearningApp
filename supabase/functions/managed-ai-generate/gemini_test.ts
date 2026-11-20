import { assertEquals } from 'jsr:@std/assert@1';
import { classifyGeminiError, generateWithGemini } from './gemini.ts';

function fakeFetch(status: number, body: unknown, seen?: { init?: RequestInit; url?: string }) {
  return ((url: string, init?: RequestInit) => {
    if (seen) {
      seen.url = url;
      seen.init = init;
    }
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  }) as unknown as typeof fetch;
}

Deno.test('sends the key in a header, never the URL, and joins parts', async () => {
  const seen: { init?: RequestInit; url?: string } = {};
  const result = await generateWithGemini('hello', {
    apiKey: 'k',
    fetchImpl: fakeFetch(200, {
      candidates: [{
        content: { parts: [{ text: 'thinking', thought: true }, { text: 'A' }, { text: 'B' }] },
        finishReason: 'STOP',
      }],
    }, seen),
  });
  assertEquals(result, { ok: true, text: 'AB' });
  assertEquals(seen.url?.includes('key='), false);
  assertEquals((seen.init?.headers as Record<string, string>)['x-goog-api-key'], 'k');
  assertEquals(seen.url?.endsWith('/models/gemini-flash-latest:generateContent'), true);
});

Deno.test('a reply cut off at the token limit is still returned', async () => {
  const result = await generateWithGemini('p', {
    apiKey: 'k',
    fetchImpl: fakeFetch(200, {
      candidates: [{ content: { parts: [{ text: '{"items":[' }] }, finishReason: 'MAX_TOKENS' }],
    }),
  });
  assertEquals(result, { ok: true, text: '{"items":[' });
});

Deno.test('a per-day 429 is the daily quota', () => {
  assertEquals(
    classifyGeminiError(429, {
      error: {
        status: 'RESOURCE_EXHAUSTED',
        details: [{ violations: [{ quotaId: 'GenerateRequestsPerDayPerProjectPerModel-FreeTier' }] }],
      },
    }),
    { ok: false, code: 'daily_quota' },
  );
});

Deno.test('a per-minute 429 is a short wait', () => {
  assertEquals(
    classifyGeminiError(429, {
      error: {
        details: [
          { violations: [{ quotaId: 'GenerateRequestsPerMinutePerProjectPerModel-FreeTier' }] },
          { retryDelay: '12.5s' },
        ],
      },
    }),
    { ok: false, code: 'rate_limited', retryAfterSeconds: 13 },
  );
});

Deno.test('bad key, retired model or region block need the owner', () => {
  for (const s of [400, 401, 403, 404]) {
    assertEquals(classifyGeminiError(s, {}).ok, false);
    assertEquals((classifyGeminiError(s, {}) as { code: string }).code, 'misconfigured');
  }
});

Deno.test('safety stop and empty reply', async () => {
  const blocked = await generateWithGemini('p', {
    apiKey: 'k',
    fetchImpl: fakeFetch(200, { candidates: [{ finishReason: 'SAFETY' }] }),
  });
  assertEquals(blocked, { ok: false, code: 'blocked' });
  const empty = await generateWithGemini('p', {
    apiKey: 'k',
    fetchImpl: fakeFetch(200, { candidates: [] }),
  });
  assertEquals(empty, { ok: false, code: 'empty_reply' });
});

Deno.test('no connection', async () => {
  const result = await generateWithGemini('p', {
    apiKey: 'k',
    fetchImpl: (() => Promise.reject(new Error('offline'))) as unknown as typeof fetch,
  });
  assertEquals(result, { ok: false, code: 'network' });
});
