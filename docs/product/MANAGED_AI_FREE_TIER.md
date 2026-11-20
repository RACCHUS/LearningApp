# Free AI (Gemini free tier): runbook

**What learners see:** in *Create with your AI chat*, signed-in learners get **Generate with free AI** above *Copy prompt*.
- The first time, they confirm they are 18 or older.
- The reply goes through the same checks, quality tips and redo flow as a pasted reply.
- The screen shows how many free requests they have left today.
- When the free allowance runs out, the button turns off and says so. Copy and paste and *Use your own API key* keep working.

Switch: `ai.managed`. It is **off**, and `release_ready` is true, so the owner can turn it on in the admin panel.

## How it stays free and safe

| Rule | Where |
|---|---|
| The Gemini key never reaches the browser | Secret `GEMINI_API_KEY` in the Edge Function `managed-ai-generate` |
| $0 ceiling | Use a key from a Google AI Studio project **without billing**. Google then stops at the free quota instead of charging |
| Switch off means zero calls | `public.ai_managed_admit` refuses before any provider call |
| Signed-in learners only | The function checks the user's JWT |
| Per-learner cap (default 10 a day) | `private.ai_managed_settings.per_user_daily_limit` |
| Shared cap (default 200 a day) | `shared_daily_limit`. Reaching it pauses free AI for everyone until the next reset |
| Gemini says the daily quota is used up | `429 RESOURCE_EXHAUSTED` with a per-day quota pauses free AI until the next **midnight Pacific**, when Gemini resets daily quotas |
| Short per-minute limits | Refunded and retried once in the app (wait of 30 s or less) |
| Failed calls don't count | Anything other than a quota stop is refunded |
| No content stored | Only daily counts are stored. Prompts and replies are never logged |

Keep the shared cap a little below your project's real free requests-per-day for the model (shown in AI Studio's rate-limit page), so learners see the friendly pause before Google's hard stop.

## Turn it on (owner)

1. In Google AI Studio, create an API key in a project with **no billing account** linked.
2. Set the secret:
   ```
   supabase secrets set GEMINI_API_KEY=... --project-ref xzvkdwebtbxlrxagtzlv
   ```
   Optionally set `GEMINI_MODEL` (default `gemini-flash-latest`).
3. Deploy the function:
   ```
   supabase functions deploy managed-ai-generate --project-ref xzvkdwebtbxlrxagtzlv
   ```
4. Deploy migration `20261120010000` with the guarded deploy (`dart run tool/guarded_supabase_deploy.dart`).
5. Optionally tune the caps. For example:
   ```sql
   update private.ai_managed_settings set shared_daily_limit = 150;
   ```
   Do this through a reviewed migration, or as the owner in the SQL editor.
6. Turn `ai.managed` on in the admin panel. Turn it off there to stop free AI at once.

## Google's terms (read 2026-11-19; recheck before turning on)

- The Gemini API terms require users to be 18 or older, and forbid use in a service directed at, or likely to be accessed by, people under 18. The app asks every learner to confirm they are 18+ before the first use. Whether the app as a whole meets the "likely to be accessed" test is the owner's call.
- On the free tier, Google may have people review prompts and use them to improve its products. The app warns learners not to include personal details.
- The free tier is not for users in the EEA, Switzerland or the UK, and Google describes the API as for developers, "not for consumer use". These are business risks the owner accepts by turning this on.
