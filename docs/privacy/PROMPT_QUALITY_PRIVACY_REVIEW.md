# Privacy review: prompt-quality telemetry and on-device key points

Date: 2026-11-21. Reviewer: Claude (AI agent), at the owner's request. This is an engineering privacy review against the master plan v2.6 rules (§5.7.6, P4.1) and the existing analytics privacy controls. It is not legal advice, and the policy wording in `docs/legal/PRIVACY_POLICY.md` remains a draft for the owner.

Features reviewed:
- `analytics.prompt_quality`: opt-in prompt-quality telemetry (migrations `20261121010000`, `20261121040000`). Switch OFF.
- `ai.local_experimental`: on-device "Key points" (migration `20261121030000`). Switch OFF.

## 1. Prompt-quality telemetry

### What is collected
One row per AI reply a learner checks in the lesson generator, only after they opt in:

| Field | Example | Personal? |
|---|---|---|
| `user_id` | account UUID | Yes, pseudonymous identifier |
| `event_id`, `received_at` | UUID, timestamp | Linked to the account |
| `pack_version` | `la-gen-1.1` | No |
| `ai_label` | `gemini` (one of 6 fixed labels) | No |
| `tier`, `mode` | `compact`, `package` | No |
| `outcome`, `error_code` | `partial`, `invalid_json` | No |
| `requested`, `accepted`, `sentinel` | `3`, `2`, `true` | No |

Not collected, and impossible to store (the table has typed columns only, no free text): prompts, AI replies, subjects, concepts, answers, lesson content, device data.

### Checks

| Area | Finding | Result |
|---|---|---|
| Purpose | Improve prompt packs per AI and tier (plan §5.7.6 signal 1). | Pass |
| Minimisation | Codes and counts only; values checked against fixed patterns or lists; extra fields rejected (pgTAP). | Pass |
| Lawful basis and consent | Explicit, separate opt-in, default off, on top of the base analytics consent; trusted eligibility (reviewed adult account) required; guests never. | Pass |
| Withdrawal | Turning it off deletes all rows; withdrawing base analytics consent or losing eligibility also deletes them (trigger). | Pass |
| Withdrawal reachable | **Gap (fixed):** the control only existed in the generator and disappeared when the switch was off, leaving no way to withdraw while rows remained (up to 90 days). Now the status reports the opt-in regardless of the switch, and the analytics privacy screen has "Turn off and delete". | Fixed |
| Transparency | **Gap (fixed):** neither the privacy policy nor the privacy screen mentioned it. Added a privacy-screen section and a privacy-policy section (draft). | Fixed |
| Right of access | **Gap (fixed):** the analytics export did not include these rows. Added `export_my_prompt_quality_events` and an "Export my rows" button. The export carries no account ID. | Fixed |
| Retention | 90 days; purge function wired into the existing retention workflow with a verification step. | Pass |
| Erasure on account deletion | Rows reference `auth.users` with `ON DELETE CASCADE`. | Pass |
| Access control | RLS on; no browser grants on the tables; all access via `SECURITY DEFINER` functions with fixed `search_path`; owner report is admin-only. | Pass |
| Aggregation | Owner report groups by pack × AI label × tier and suppresses groups under 5 accounts; shows sample sizes. | Pass |
| Abuse | Batch limit 10, rate limit 30 per minute per account. | Pass |
| Third parties | None. Data stays in our Supabase project. | Pass |

### Residual risks (accepted)
- Rows are linked to the account (needed for deletion on withdrawal, rate limits and per-account suppression). Only the service role and the admin aggregate report can read them.
- An admin comparing reports across 7/30/90-day windows could in theory narrow a small group. Admin access is the owner alone today; revisit if more admins are added.

### Recommendation
Ready to switch on once the owner accepts the draft privacy-policy wording in section 2.4. Switching on changes nothing for learners until they opt in.

## 2. On-device key points

| Area | Finding | Result |
|---|---|---|
| Data flow | The app passes the section's reading text to the browser's built-in Summarizer and shows the result. It sends nothing to any server. Verified on 2026-11-21 in desktop Chrome 157: zero network requests during a summary. | Pass |
| Vendor claim | Chrome's documentation states no data is sent to Google or any third party when the model is used. The app quotes this as Chrome's statement and makes no stronger claim. | Pass |
| Download disclosure | Before a first download: one-time, several GB, 22 GB free space, unmetered connection, works offline afterwards; needs the learner's tap. | Pass |
| Content scope | Reading blocks only; practice prompts and answers are excluded (tested). | Pass |
| Storage | Output is not saved. Device-local timings only (`SharedPreferences`), never sent. | Pass |
| Accuracy | Labelled "can be wrong; check it against the lesson"; not graded. | Pass |

Verified run (2026-11-21, desktop Chrome 157, model already present): 6.1 Understand Percent produced five accurate key points; first run 40.1 s (model load), second run 7.3 s. Found and fixed: the "usually … s" hint used the slower of two runs; it now appears only after three runs.

### Recommendation
Ready to switch on. It only appears for learners whose browser and device can run the model; everyone else sees nothing.
