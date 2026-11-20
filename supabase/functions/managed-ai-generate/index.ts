// managed-ai-generate: free AI lesson generation on LearningApp's own
// free-tier Gemini key, for signed-in learners, while the free allowance
// lasts (feature switch ai.managed, OFF by default).
//
// Required secret (supabase secrets set ...):
//   GEMINI_API_KEY  - from a Google AI Studio project WITHOUT billing, so the
//                     provider itself caps spending at $0.
// Optional: GEMINI_MODEL (default gemini-flash-latest).
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are provided
// by the platform.
//
// Every call is admitted in SQL first (public.ai_managed_admit): switch on,
// not paused, under the shared and per-learner daily caps. With the switch
// OFF nothing reaches Gemini. When Gemini says its daily quota is used up,
// generation pauses for everyone until the next Pacific midnight.
// Prompts and replies are never stored or logged.
import { createClient } from 'jsr:@supabase/supabase-js@2.49.4';
import { generateWithGemini, MAX_PROMPT_CHARS } from './gemini.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(status: number, body: Record<string, unknown>): Response {
  return Response.json(body, { status, headers: cors });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (req.method !== 'POST') return reply(405, { code: 'method_not_allowed' });

  const url = Deno.env.get('SUPABASE_URL')!;
  const authHeader = req.headers.get('Authorization') ?? '';
  const asUser = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userData } = await asUser.auth.getUser();
  const userId = userData?.user?.id;
  if (!userId) return reply(401, { code: 'not_signed_in' });

  let prompt = '';
  try {
    const body = await req.json();
    prompt = typeof body?.prompt === 'string' ? body.prompt : '';
  } catch {
    prompt = '';
  }
  if (!prompt.trim() || prompt.length > MAX_PROMPT_CHARS) {
    return reply(400, { code: 'bad_prompt' });
  }

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });
  const { data: admit, error: admitError } = await admin.rpc('ai_managed_admit', {
    p_user: userId,
  });
  if (admitError) {
    console.error('ai_managed_admit failed', admitError.code);
    return reply(503, { code: 'unavailable' });
  }
  if (!admit?.ok) {
    const code = String(admit?.code ?? 'unavailable');
    const status = code === 'off' ? 503 : 429;
    return reply(status, { code, resumes_at: admit?.resumes_at ?? null });
  }

  const refund = async () => {
    const { error } = await admin.rpc('ai_managed_refund', { p_user: userId });
    if (error) console.error('ai_managed_refund failed', error.code);
  };

  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) {
    await refund();
    return reply(503, { code: 'not_configured' });
  }

  const result = await generateWithGemini(prompt, {
    apiKey,
    model: Deno.env.get('GEMINI_MODEL') ?? undefined,
  });

  if (result.ok) {
    // Counts only: no prompt, reply or user id in logs.
    console.log('managed ai', { ok: true });
    return reply(200, { text: result.text, remaining_today: admit.remaining_today });
  }

  console.log('managed ai', { ok: false, code: result.code });
  if (result.code === 'daily_quota') {
    const { data: until } = await admin.rpc('ai_managed_record_quota_stop');
    return reply(429, { code: 'paused', resumes_at: until ?? null });
  }
  await refund();
  if (result.code === 'rate_limited') {
    return reply(429, { code: 'rate_limited', retry_after: result.retryAfterSeconds ?? null });
  }
  const status = result.code === 'misconfigured' ? 503 : 502;
  return reply(status, { code: result.code });
});
