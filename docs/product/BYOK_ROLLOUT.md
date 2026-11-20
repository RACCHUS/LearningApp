# Own API key (BYOK): rollout runbook

BYOK lets an adult learner paste their own Gemini, OpenAI or OpenRouter key. In "Create with your AI chat", **Ask Gemini for me** then sends the same prompt the learner would copy, and checks the reply with the same validator, quality tips and redo flow as a pasted reply. Copy and paste is unchanged and always available.

It stays **off** until the owner releases it. Two independent controls must both be on:

| Control | Where | Default |
|---|---|---|
| Build latch `BYOK_RELEASE_APPROVED` (FLAG-015) | `--dart-define` at build time; `ByokReleaseGate.enabled` | off in every normal, CI and preview build |
| Live switch `ai.byok` | `private.site_feature_controls` (admin panel once `release_ready`) | off, `release_ready = false` |

CI sets the latch only in the step *BYOK release-candidate tests (latch on, test-only build)*, which runs the client tests and never builds or deploys.

## What is ready

- Key held in memory for the tab only (never saved, never sent to LearningApp), sent in a header, allowlisted provider endpoints only. Custom endpoints never receive a key.
- One app-wide key session (`byokSessionProvider`), so a key entered in settings is used by "Ask".
- Settings dialog: 18+ and provider-terms confirmation required to save; **Check key** lists the models the key can use and replaces a retired default.
- Errors are classified (`LlmFailureKind`) and shown in plain words that name the provider and never state quota sizes or reset times.
- Short per-minute limits, overloads and dropped connections are retried up to 3 attempts with backoff (or the provider's own wait, up to 30 s).
- **Quota used up** (Gemini per-day `429 RESOURCE_EXHAUSTED`, OpenAI `insufficient_quota`, OpenRouter `402`, or a requested wait over 30 s): nothing is retried, "Ask" turns itself off, the learner is told and pointed to copy and paste, and **Try my key again** turns it back on.
- CSP `connect-src` allows `generativelanguage.googleapis.com`, `api.openai.com` and `openrouter.ai`. While the latch is off, no code calls them.

## Release steps (owner)

1. Re-read the providers' current terms (see below) and approve the release.
2. Add an activation migration for `ai.byok` (`release_ready = true`, `enabled = true`, revision + 1, one audit row, the same pattern as `20261119050000`) and deploy it **only** with `dart run tool/guarded_supabase_deploy.dart`.
3. Build the web app with the usual production flags **plus** `--dart-define=BYOK_RELEASE_APPROVED=true`, and deploy it to the preview channel.
4. On preview, with a real key: Check key → Use this key → Ask … for me, and confirm one reply is checked and imported.
5. Promote preview to live.

**Turn it off fast:** switch `ai.byok` off in the admin panel. "Ask" disappears on the next feature refresh, and no rebuild is needed. Copy and paste keeps working.

## Provider terms to recheck at release (Gemini, read 2026-11-19)

The Gemini API terms (effective 2026-03-23) say:
- Users must be **18 or older**.
- The API must not be used in a service **directed at or likely to be used by under-18s**.
- Free-tier prompts may be **read by human reviewers and used to improve Google products**, so no personal or sensitive information should be sent.
- The free tier is **not for users in the EEA, Switzerland or the UK**.

The dialog requires the 18+ confirmation and warns about personal details. Whether the app as a whole counts as "likely to be accessed" by children (for example the Kids literacy track) is an owner decision to make before release.
