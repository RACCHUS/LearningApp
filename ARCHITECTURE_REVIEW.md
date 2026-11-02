# LearningApp — Technical & Architectural Review

**Initial Audit Date:** 2026-10-31 (initial Phase 0 repository audit at `e538585` on `main`; companion learning-science & platform plans authored 2026-11-01) · **Post-PR `#136` Merge Revision Date:** 2026-11-02 (reconciled with `main` at `a23cebb` following PR `#136` merge; documentation & specification scope only) · **Requested by:** project owner
**Method:** read the architecture/product docs; traced the core learning loop in code; scanned schema, RLS and RPCs; ran the analyzer (with and without the standard lint set); served the existing release build locally and audited it in Chrome (network, console, accessibility tree, Lighthouse); attempted a WebAssembly build; checked free-tier and library facts against current sources. Items that could not be verified against production are marked **(verify)**.

> **Bottom line.** The repo is unusually disciplined about *governance*: provenance, RLS, append-only migrations, pgTAP, and honest learner-facing copy. The weakest parts are the ones the mission depends on most: the **learning engine** (scheduler, knowledge model, analytics), **reliability and offline support**, **web delivery cost and speed**, and **openness** (no license, no API, the schema doubles as the API). Most of the highest-value fixes are cheap.

---

## 0. Executive summary

### Top 12 findings (ordered by mission impact × ease of fixing)

| # | Finding | Type | Effort |
|---|---|---|---|
| 1 | **No learning event log.** Without per-attempt data there can be no real analytics, item calibration, FSRS optimization, A/B tests, or evidence that the app works. The locked UI spec already defers `review_log` (§13), which makes the deferral circular (see ARCH-1). | Architecture | M |
| 2 | **The scheduler isn't SM-2 or FSRS.** It uses a fixed `[1,3,7,14,30,60,120]` ladder × an ease factor clamped to ≤2.5 (so ease can only fall). It ignores actual elapsed time and has no in-session relearning. "Mastery" is a lifetime average with no forgetting. | Learning science | M |
| 3 | **Correct answer is always option A** in the USCIS (26/26), DMV (10/10) and GED (8/8) simulators, and none of them shuffle. Bundled AI lessons show the opposite LLM bias: 31/31 answers at B or C. The main MCQ widgets render options in authored order. | **Obvious bug** | S |
| 4 | **Schema drift:** 12 tables and 2 RPCs the client calls are missing from `supabase/migrations`. Recommendations, the Reset Center, skills/leaderboards and course time all silently fail on any schema built from the canonical chain: CI, local, or a fork. | **Obvious bug** | S–M |
| 5 | **`increment_user_xp` is a `SECURITY DEFINER` RPC that takes any `p_user_id`** without checking `auth.uid()`. Anyone holding the public key can change any user's XP. | **Security bug** | S |
| 6 | **No offline app shell.** Flutter's built service worker unregisters itself (Flutter has deprecated its service worker), the custom registration throws a console error on every load, and the docs still claim offline caching. | **Obvious bug** | S |
| 7 | **Study reminders cannot fire on web.** Local notifications are Android/iOS-only, FCM tokens are never stored, and nothing server-side sends pushes. Firebase adds weight and startup risk for no working feature. | **Obvious bug** | S–M |
| 8 | **Screen readers see nothing** on Flutter web until a hidden "Enable accessibility" button is found (no `ensureSemantics()`). This undercuts the non-reader/literacy track. | **Accessibility bug** | S |
| 9 | **Zero production error visibility.** Sentry/Crashlytics are commented-out stubs, there are 411 `catch (e) {` blocks, the core SRS service returns `[]` on errors (so learners see "nothing due"), and there are 524 raw `print(` calls. | Reliability | S |
| 10 | **The database schema is the public API:** ~80 tables are queried directly through ~400 `.from()` calls. There's no versioned contract, it's hostile to forks and MCP, it's chatty (the scope resolver issues ~35 queries), and 304 of 313 selects aren't paginated. | Architecture | M–L |
| 11 | **No runtime AI.** "AI generation" means copying a prompt into ChatGPT and pasting JSON back. Quota and metering infrastructure was built ahead of any AI capability. **BYOK + an MCP server** would make AI capability nearly free to operate. | Opportunity | M |
| 12 | **No LICENSE**, and the UGC license is limited to "within the Service". This blocks the "others build their own version" (VS Code / Code-OSS) strategy and community content portability. | Strategy | S |

### Scorecard (1 = weak, 5 = strong)

| Dimension | Score | One-line reason |
|---|---|---|
| Governance, provenance, migration discipline | **4.5** | Exceptional: manifests with citations and hashes, fail-closed pathways, append-only CI with incremental and clean-slate tests |
| Security (RLS) | **3.5** | RLS-first, with many pgTAP tests. Gaps: XP RPC, client-writable analytics, answer keys readable by anon, RLS initplan performance |
| Test volume | **3.5** | 230 files, ~1,600 `test()` + 278 `testWidgets()`. No E2E, goldens, coverage gate, or pgTAP coverage of the core loop |
| Learning-science core | **2** | Retrieval practice exists, but scheduling, forgetting, calibration and interleaving are heuristic or absent |
| Analytics / evidence | **1** | No event log, so outcomes can't be measured |
| AI capability | **1.5** | Copy-paste prompts only |
| Reliability / observability | **1.5** | No error reporting, silent failures, no deploy automation |
| Offline / PWA | **1** | No app-shell caching; only legacy progress has an outbox |
| Web performance and hosting cost | **2** | 7.35 MB JS, no code splitting, 20 fonts at boot, WASM blocked |
| Openness / platform | **1** | No license, no API, no content-portability terms |
| Accessibility | **2** | Strong intent; web semantics off by default; no i18n |

### What is genuinely strong (keep it)
- **Honesty in specs and UI copy.** Bands are labelled heuristic ([retrieval_state.dart](lib/models/retrieval_state.dart#L54), [UI_ARCHITECTURE_LOCKED.md §6.1](UI_ARCHITECTURE_LOCKED.md#L612)). Diagnostics never fabricate questions. Readiness is never blended with completion.
- **Content provenance pipeline:** YAML manifests, JSON Schema, linter, dry-run ingestion, citations, source hashes, 180-day source renewal, fail-closed pathway verification.
- **Migration governance:** append-only checks, incremental *and* clean-slate DB tests in CI, 40 pgTAP files, official taxonomy ingestion tested in CI.
- **Pure, testable `NextActionEngine`**, the Direct Access Rule, a calm Learn screen, and an ethical gamification policy (no loss framing by default).
- **Guest-first auth** (anonymous → Google `linkIdentity`), moderation and trust & safety, legal docs (ToS, Privacy, DMCA).
- **EXM "Reference Mastery"** (open-book navigation drills) and the **non-reader literacy track** are differentiated ideas few competitors have.

---

## 1. Obvious defects — fix now (mostly small)

| ID | Defect | Evidence | Fix |
|---|---|---|---|
| FIX-1 | **Answer-position cue.** Every USCIS, DMV and GED item has `correctOptionIndex: 0`, and no simulator shuffles. Bundled lessons: 31/31 correct answers at index 1 or 2. `McqContent`, `McqOptions` and the assessment renderer use authored order. | [uscis_civics_item.dart](lib/models/uscis_civics_item.dart#L86), [dmv_exam_item.dart](lib/models/dmv_exam_item.dart#L183), [ged_bridge_item.dart](lib/models/ged_bridge_item.dart#L109), [mcq_content.dart](lib/widgets/study/mcq_content.dart#L74), [mcq_options.dart](lib/widgets/mcq_options.dart#L22) | Shuffle options per presentation with a seeded RNG, and record the presented order in the event log. Add an import validator that flags position imbalance across a set. Store `is_correct` per option instead of an index. |
| FIX-2 | **XP tampering RPC.** `increment_user_xp(p_user_id, p_xp_amount)` is `SECURITY DEFINER`, never checks `auth.uid()`, has no `search_path`, and accepts negative amounts. A leaderboard view exists. | [20250101000002_create_user_xp.sql](supabase/migrations/20250101000002_create_user_xp.sql#L62), [xp_service.dart](lib/services/xp_service.dart) | New migration: drop the parameter and use `auth.uid()`, `set search_path = ''`, require `p_xp_amount > 0` with a cap, and `revoke execute ... from public, anon`. |
| FIX-3 | **Schema drift (client ↔ migrations).** Missing from `supabase/migrations`: `assessment_attempts`, `career_paths`, `career_path_courses`, `career_path_skills`, `user_career_paths`, `skills`, `skill_assessments`, `user_skill_stats`, `skill_leaderboard`, `lesson_texts`, `user_data_snapshots` (all found only in legacy [database/](database/README.md)), plus `study_progress`, RPC `increment_course_time` and RPC `soft_delete_skill_attempts` (found nowhere). | [recommendation_service.dart](lib/services/recommendation_service.dart#L131), [reset_service.dart](lib/services/reset_service.dart#L51), [reset_service.dart](lib/services/reset_service.dart#L649), [course_service.dart](lib/services/course_service.dart#L440), [lesson_provider.dart](lib/providers/lesson_provider.dart#L106), [skill_assessment_service.dart](lib/services/skill_assessment_service.dart#L364) | For each object, either port it into a new migration or delete the dead client code. Then delete `database/`. Add a **CI contract check**: every `.from('x')` and `.rpc('y')` in `lib/` must exist after `supabase db reset` (a ~40-line script). If production has these tables, they were hand-applied, which is drift **(verify)**. |
| FIX-4 | **Broken PWA/offline.** The built `flutter_service_worker.js` unregisters itself. [index.html](web/index.html#L80) registers it anyway and calls `update()`, which logs `InvalidStateError: Failed to update a ServiceWorker` on every load (seen in Lighthouse). The custom [web/flutter_service_worker.js](web/flutter_service_worker.js#L12) never writes to the cache. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md#L92) claims offline caching. | local release-build audit | Switch to the `flutter_bootstrap.js` loader (see PERF-1) and remove the manual registration. Either add a real Workbox-style app-shell worker or document the app as online-only. |
| FIX-5 | **Reminders and push don't work on web.** `zonedSchedule` has only Android/iOS init settings and fails silently. `getToken()` is never persisted; there's no token table and no sender. | [notification_service.dart](lib/services/notification_service.dart#L98), [push_notification_service.dart](lib/services/push_notification_service.dart#L69) | Remove Firebase. Implement **Web Push (VAPID)** from a Supabase Edge Function triggered by `pg_cron` ("N reviews due"), plus an optional email digest. iOS needs an installed PWA (16.4+). |
| FIX-6 | **Screen readers see only "Enable accessibility".** Verified in the accessibility tree of the running build. Lighthouse's 100 is misleading because it can't see canvas content. | live audit | Call `SemanticsBinding.instance.ensureSemantics()` on web at startup. Add `meetsGuideline(textContrastGuideline / labeledTapTargetGuideline / androidTapTargetGuideline)` checks to widget tests. |
| FIX-7 | **Timezone-naive timestamps.** Local `DateTime.now()...toIso8601String()` without an offset is written to `timestamptz` and read back as UTC. Due dates shift by the user's UTC offset, and "due today" uses UTC day parts. Seen in ~19 files; only ~12 files use `toUtc()`. | [spaced_repetition_service.dart](lib/services/spaced_repetition_service.dart#L61), [spaced_repetition.dart](lib/models/spaced_repetition.dart#L222) | Use `toUtc().toIso8601String()` everywhere and bucket days in local time in the UI. Add a lint or test helper for this. |
| FIX-8 | **Silent failure in the core loop.** `getAllReviewItems` and `getDueItems` return `[]` on any error, so learners see "nothing due". Evidence propagation is fire-and-forget. | [spaced_repetition_service.dart](lib/services/spaced_repetition_service.dart#L50), [spaced_repetition_service.dart](lib/services/spaced_repetition_service.dart#L201) | Return typed errors (`AsyncValue.error`) with a retry UI, and queue evidence in an outbox (ARCH-3). |
| FIX-9 | **The 1,000-row cap silently truncates results.** `max_rows = 1000` is also Supabase's hosted default, yet only 9 of 313 selects use `.range()`. `getAllReviewItems()` breaks for large decks. 64 `inFilter()` calls build long URL query strings (readiness passes every curriculum-node id). | [config.toml](supabase/config.toml#L18), [target_readiness_service.dart](lib/services/target_readiness_service.dart#L78) | Move aggregate reads into RPCs (counts and summaries server-side) and paginate the rest. |
| FIX-10 | **Lint rules are off.** [analysis_options.yaml](analysis_options.yaml) doesn't include `flutter_lints` and ignores deprecations. With the standard set enabled the analyzer reports **814 issues**, including **17 `use_build_context_synchronously`** (crash risk), 439 `avoid_print`, and 10 `depend_on_referenced_packages`. `lib/` imports `crypto`, `json_annotation` and `timezone` without declaring them. | ran analyzer with the include added temporarily (reverted) | Add `include: package:flutter_lints/flutter.yaml`, fix the async-context issues first, declare the three packages, and stop ignoring deprecations. |
| FIX-11 | **Fragile client config.** `.env` is bundled as a public asset ([pubspec.yaml](pubspec.yaml#L69)). Firebase options come *only* from it ([firebase_options.dart](lib/config/firebase_options.dart#L6)), but Firebase Hosting's `"**/.*"` ignore rule excludes it from deploys ([firebase.json](firebase.json#L6)). In production Firebase likely gets empty strings **(verify)**. The deployment guide names project `learningpwa-928be`; `.firebaserc` says `learningapp-2ed8a`. | — | Use `--dart-define-from-file=config/prod.json` (public keys only), remove `.env` from assets, and fix the docs. |
| FIX-12 | **Answer keys are readable by anon** for every non-EXM item (`assessment_items.scoring_spec`). Only EXM-approved items were protected ([migration](supabase/migrations/20261101150000_exm_03_authenticated_submit_protected_items.sql#L122)). Learners can also write `user_concept_state`, `user_xp` and `review_items` directly, so "readiness" is client-asserted. | [content_primitives_v2.sql](supabase/migrations/20261004000000_content_primitives_v2.sql#L221) | Decide per content tier. Practice keys can stay public if the content is openly licensed. Diagnostics, readiness and anything shown to educators should be scored and written server-side (ARCH-1). |
| FIX-13 | **RLS performance:** 361 bare `auth.uid()` calls vs 31 `(select auth.uid())`. Two `SECURITY DEFINER` functions have no pinned `search_path` (`finalize_official_taxonomy_import`, `resolve_taxonomy_lineage`). | migrations scan | Run Supabase's **splinter** advisors in CI (`auth_rls_initplan`, `function_search_path_mutable`) and fix the hot tables first. |
| FIX-14 | **No security headers** (CSP, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`); only `Cache-Control` is set. 461 KB PNG icons; no meta description. | [firebase.json](firebase.json) | Add the headers in the hosting config, compress the icons, and add the meta tag. |

---

## 2. Architectural weaknesses (deep dives)

### ARCH-1 — The learning engine isn't evidence-based yet (core mission gap)

**What exists**
- **Scheduler:** a fixed ladder ([spaced_repetition.dart](lib/models/spaced_repetition.dart#L4)) × ease clamped to `[1.3, 2.5]` ([L240](lib/models/spaced_repetition.dart#L240)). Because ease starts at the cap, it can only fall. A lapse resets the item to level 0 and schedules it 1–2 *days* out (no relearning step). Overdue time is ignored.
- **Knowledge model:** `user_concept_state` is a cumulative `weighted_correct / weighted_total`. It never forgets, and a learner who failed early and now recalls perfectly stays "developing". Writes are a client-side select-then-upsert per concept ([concept_evidence_service.dart](lib/services/concept_evidence_service.dart#L95)): racy across tabs/devices, N+1, forgeable, and unrecoverable when offline.
- **"CAT":** item difficulty is hard-coded from a 3-level label (−1/0/+1) ([adaptive_practice_service.dart](lib/services/assessment/adaptive_practice_service.dart#L26)), never calibrated. There's no blueprint content balancing and no exposure control.
- **No per-attempt log:** only XP events and the narrow EXM drill events exist. The locked spec admits this: "True session counting needs a `review_log` table; deferred to §13" ([UI_ARCHITECTURE_LOCKED.md](UI_ARCHITECTURE_LOCKED.md#L886)).
- **Review is deprioritised.** "Review never outranks forward progress while material remains" ([next_action_engine.dart](lib/services/next_action_engine.dart#L234)), and `reviewEmphasis` is deferred "until we have data on real backlog behaviour", data that can't be collected without the deferred log. Spacing research (Cepeda et al., 2006) shows retention depends on doing reviews near their due time, and deferring them lets the backlog grow.

**Why it matters:** "Backed by strong evidence and real analytics" needs (a) a validated memory model, (b) calibrated item statistics, and (c) outcome measurement. None are possible without event data.

**Recommended design (cheap, incremental)**
1. **`learning_events`, append-only** (client-generated UUIDv7 `id`; user-scoped `UNIQUE (user_id, idempotency_key)` where `idempotency_key` is generated once at event creation, persisted durably in the local outbox, and reused across retries, paired with a **server-computed `payload_sha256`** via `encode(digest(convert_to(v_canonical_payload::text, 'UTF8'), 'sha256'), 'hex')` over the 13 immutable client-controlled semantic event-payload fields—excluding envelope identifiers `id` and `idempotency_key`; device-specific `session_id uuid not null` with strictly increasing per-session `client_seq integer not null` and `UNIQUE (user_id, session_id, client_seq)`; and nullable `attempt_id uuid` required when bound to a server-issued attempt): `user_id, event_schema_version, metadata_schema_version, payload_sha256, client_occurred_at (UTC), received_at (UTC), effective_occurred_at (UTC), event_type, item_type, item_id, item_version, context_id, session_id, client_seq, attempt_id, fsrs_rating (1–4, memory cards only), scored_outcome, learner_response, presented_option_ids (text[]), client_latency_ms, server_elapsed_ms, assistance_provided, learner_confidence (1–3), scheduler_version, scheduler_state_before/after, provenance_snapshot, assessment_conditions`. RLS: insert/select own; no update or delete except through the existing **EXM-style owner export/erasure RPCs**, which are already a good template.
2. **One write path:** `record_events(jsonb[])` RPC, acquiring transaction-scoped advisory locks on `(user_id, session_id)` and affected `(user_id, item_id)` / `(user_id, concept_id)` streams, sorting incoming batch items server-side by `(session_id ASC, client_seq ASC, idempotency_key ASC)` independent of request array order, evaluating `UNIQUE (user_id, idempotency_key)` **first** (returning `duplicate_noop` when the server-computed `payload_sha256` matches the stored digest and flagging `idempotency_payload_mismatch` when a key is reused with any changed event-payload field, prior to running sequence or timestamp checks), and—for new keys—enforcing `UNIQUE (user_id, session_id, client_seq)` (`sequence_conflict` on collision). It updates projections (`review_items` FSRS state, `user_concept_state`) **atomically server-side**. Then revoke direct DML on the projection tables. This fixes the races, N+1 queries, forgery, and lost evidence together.
3. **Replace the ladder with FSRS** using the MIT [`fsrs`](https://pub.dev/packages/fsrs) Dart package (v2.0.1, implementing **FSRS-6** via a py-fsrs-style `Scheduler`/`Card`/`ReviewLog` API; `scheduler_version = 'v2_fsrs6'`). Open-spaced-repetition benchmarks (`srs-benchmark`) evaluate recall-prediction performance using Log Loss, calibration RMSE (bins), and AUC (where FSRS-6 leads the evaluated schedulers; note that the published `srs-benchmark` comparison table does not currently include a direct SM-2 row), and Anki has included FSRS as a built-in optional scheduler alongside SM-2 since 23.10, noting qualitatively in its official documentation that FSRS can achieve equivalent target retention with fewer reviews than SM-2 (without claiming a single universal percentage; any review-efficiency gains in LearningApp will be measured empirically). Expose **desired retention** and **exam date** workload planning (adjusting daily review/new budgets as the exam approaches without mutating underlying FSRS memory parameters), and transition existing `v1_sm2_ladder` cards forward to `v2_fsrs6` on their next memory review rather than fabricating history from aggregate counters.
4. **Knowledge state = retrievability, not an average.** Concept readiness is the weighted predicted recall *at the exam date* (FSRS R(t)). Add **Elo-style item difficulty and learner ability** (Pelánek, 2016), which is robust with small data, and graduate to 2PL IRT offline (`py-irt`/`girth` in `tool/`) when items have hundreds of responses. Keep the honest bands, but set their thresholds from **calibration curves** (predicted vs actual recall on held-out reviews). That's how the copy stays honest *and* becomes evidence-based.
5. **Item analytics jobs:** p-value, point-biserial discrimination, distractor selection rates, and median time. Auto-flag bad items (too easy or hard, negative discrimination, a distractor nobody picks) into the existing moderation queue.
6. **A daily plan instead of a binary rule:** a time budget split between due reviews and new material, with a load-aware cap on new items. Ship `reviewEmphasis` (balanced by default) now; it's a learner policy, which is consistent with §8.
7. **Cost guard:** 1,000 daily learners × 50 events ≈ 1.5M rows/month, which would exhaust the 500 MB free database within months. Keep FSRS state server-side (tiny), keep full logs **local-first** and sync batches, and archive anything older than 90 days to object storage (Cloudflare R2's free tier, compressed NDJSON or Parquet). Research use requires opt-in consent.

**Learning-science coverage (Dunlosky et al., 2013 utility ratings)**

| Technique | Status | Next step |
|---|---|---|
| Retrieval practice (high) | ✅ flashcards, MCQ, recall-before-reveal | Default to recall-type items (cloze, short answer, free recall); MCQ is recognition |
| Distributed practice (high) | ⚠️ ladder; reviews deprioritised | FSRS, daily plan, working reminders |
| Interleaving (moderate) | ❌ deferred (§13) | Mixed practice sets within a context |
| Elaborative interrogation / self-explanation (moderate) | ❌ | "Explain why" prompts; AI feedback via BYOK |
| Worked examples → faded steps | ⚠️ example blocks only | Faded-step item type |
| Metacognitive calibration (hypercorrection effect) | ❌ | One-tap confidence; calibration chart in Progress |
| Pretesting / diagnostics | ✅ gated diagnostics | Calibrated item difficulty |
| Prerequisite-aware mastery | ✅ concept graph with bounded traversal | Prerequisite-aware review credit (implicit repetition) |

### ARCH-2 — The database schema is the API
- ~80 tables are hit directly through 403 `.from()` calls (371 in services, 32 in providers, plus 6 direct client uses in screens). Only 19 distinct RPCs exist. Every schema change can break deployed clients. Forks, an MCP server, and third-party front-ends would all couple to the internals.
- **Chatty:** `ScopeResolver` issues ~35 table queries (26 with `inFilter`, zero RPCs) per resolution ([scope_resolver.dart](lib/services/scope_resolver.dart#L10)). The doc's own benchmark gate proposed a single RPC ([LEARNING_ARCHITECTURE_V2.md §12](LEARNING_ARCHITECTURE_V2.md#L1202)).
- **Logic split** between Dart and very large SQL: 81 migrations (~1.2 MB), 20 named hardening/fix/restore/security, and `ingest_curriculum_manifest` redefined **6 times** (37–83 KB each).

**Fix:** a versioned **`api` schema** of RPCs and views (e.g. `api.resolve_scope(context_id)`, `api.learner_summary(context_id)`, `api.record_events(...)`, `api.search_catalog(...)`), with tables moved behind it and unexposed. Use **Supabase declarative schemas** (`supabase/schemas/*.sql` with `supabase db diff`) so each function lives in one file and migrations are generated, which keeps the append-only rule. Add the contract check (FIX-3) and typed DTOs (`json_serializable` is already a dependency; replace the `dynamic` widget inputs, e.g. [mcq_content.dart](lib/widgets/study/mcq_content.dart)).

### ARCH-3 — The core loop is online-only; "offline-first" claims aren't met
- Only legacy `user_progress` has an outbox ([progress_sync_service.dart](lib/services/progress_sync_service.dart#L17)). Reviews, evidence, words and community features all need the network. There's no app-shell cache (FIX-4).
- Hive 2.2.3 is effectively unmaintained; [`hive_ce`](https://pub.dev/packages/hive_ce) is the maintained drop-in.

**Fix:** a local-first event outbox (`hive_ce` short-term, or **Drift + SQLite WASM** for queryable local review queues). On-device FSRS computes **provisional local schedule state** so reviews work offline immediately; when the outbox syncs via `record_events`, the server acquires transaction-scoped locks on `(user_id, session_id)` and affected `(user_id, item_id)` / `(user_id, concept_id)` streams, sorts batch items by `(session_id ASC, client_seq ASC, idempotency_key ASC)`, checks `UNIQUE (user_id, idempotency_key)` first (with server-computed `payload_sha256` mismatch detection over the 13 semantic event-payload fields) before enforcing `UNIQUE (user_id, session_id, client_seq)` and validating `client_occurred_at` against the joint feasibility of the 14-day plausibility window and bidirectional per-session `(session_id, client_seq)` non-decreasing neighbor bounds (`effective_occurred_at` checked against both preceding `client_seq < current` and succeeding `client_seq > current`, rejecting/quarantining events when the window and neighbor bounds cannot both be satisfied) to preserve plausible client-reported offline intervals (treated strictly as a bounded, best-effort input for ordinary memory scheduling rather than trusted timing evidence) while keeping `received_at` and `server_elapsed_ms` authoritative for audit arrival time and timed/high-stakes assessment cutoffs, deterministically replays out-of-order or multi-device review streams over `(effective_occurred_at ASC, session_id ASC, client_seq ASC, id ASC)` to compute the **canonical server projection**, and returns the reconciled state to the client. PowerSync (Supabase partner, free tier and self-hostable) is an option if full sync is needed later.

### ARCH-4 — No runtime AI; governance was built before capability
- Prompts are copy-pasted into external chats ([ai_prompt_service.dart](lib/services/ai_prompt_service.dart#L197)). There are no Edge Functions. The usage-quota and metering tables exist, but no AI provider sits behind them.
- **Fix (keeps cost near $0):** (1) **BYOK** — the learner or creator pastes their own key (OpenRouter/Gemini/OpenAI/Anthropic, which all support browser calls), stored locally, never on the server. (2) An **MCP server** (OPP-1) so ChatGPT, Claude or Copilot bring their own intelligence. (3) In-browser models where available (WebLLM, transformers.js Whisper for free STT, Chrome built-in AI). (4) Server-side LLM calls only for curated or moderated flows, behind the existing quotas.

### ARCH-5 — Content model fragmentation and content-as-code
- Several parallel models coexist: v1 lesson-bound `terms/concepts/questions`; v2 `knowledge_concepts/assessment_items/flashcards/lesson_blocks`; legacy careers and skills (legacy SQL only); bundled `assets/lessons/*.json`; and **high-stakes content hard-coded in Dart** (USCIS, DMV, GED, food safety, Rx, workplace safety). **Five** overlapping lesson providers (`lesson_`, `lessons_`, `available_lessons_`, `combined_lessons_`, `unified_lesson_`).
- `officialUscisCivicsCatalog` holds **27 items** against the 128-question 2025 pool, and it practises an *oral, open-answer* test as multiple choice.
- **Fix:** one open **content package format** (the [curriculum manifest schema](content/schema/curriculum_manifest.schema.json) is a great base). Move literacy and exam content into manifests with citations and effective dates, then deprecate the v1 tables behind the `api` layer. Content becomes updatable without a deploy, translatable, reviewable and portable.

### ARCH-6 — Web delivery: slow, costly, and WASM-blocked
Measured on the existing release build:
- `main.dart.js` is **7.35 MB** raw (**1.99 MB gzip**, 1.45 MB brotli), loaded by a **blocking** `<script>` ([index.html](web/index.html#L269)) instead of `flutter_bootstrap.js`. There's no deferred loading anywhere.
- At boot, the browser fetches **20 KaTeX font files** (from `flutter_math_fork`), CanvasKit, the Firebase SDK, and **5 Google Fonts families fetched at runtime** ([app_theme.dart](lib/theme/app_theme.dart#L248); screens also hardcode Outfit and JetBrains Mono). Runtime Google Fonts also have a GDPR exposure (LG München I, 2022) and fail offline.
- First visit transfers **~2.44 MB gzip from the app's own origin**. Firebase's pricing page lists **360 MB/day** free Hosting transfer (while Firebase's Hosting usage & quotas page lists **10 GB/month**), so the daily free allowance is used up by **about 145–150 first-time visitors a day**.
- **WASM build fails:** verified that `flutter build web --wasm` errors out entirely because of `connectivity_plus 3.0.6` (`dart:html`, `dart:js_util`, discontinued `package:js`).

See PERF items in §4.

### ARCH-7 — Reliability, observability and delivery
- No error reporting, product analytics, uptime monitoring or deploy automation (`firebase deploy` is run by hand; there are no PR previews). The free Supabase tier has **no backups and 1-day log retention**; the SSD backup script is manual.
- Tests: there's no `integration_test/`, no E2E, no goldens and no coverage gate. Of the 40 pgTAP files, the only ones touching the core loop are four with incidental references (word learning, mappings, version governance). XP and evidence writes are untested, which is how FIX-2 slipped through.
- **Fix:** see REL items in §4.

### ARCH-8 — Dependency and platform debt
Multiple majors behind: `flutter_riverpod` 2.6 → 3.4 (41 `StateNotifier`s to migrate), `go_router` 14 → 18, `connectivity_plus` 3 → 7, Firebase 3 → 5, `flutter_local_notifications` 17 → 22, `google_fonts` 6 → 9, `permission_handler` 11 → 13. `supabase_flutter` is locked at 2.9.1 while 2.18.3 is current. The discontinued `js` package is still in the tree. The app is **web-only** (no `android/` or `ios/`), yet it ships native-only plugins. Upgrade order: connectivity_plus (unblocks WASM) → supabase_flutter → remove Firebase → go_router → Riverpod 3.

### ARCH-9 — Process cost ("produce it cheaply")
- ~1.09 MB of Markdown against ~4.7 MB of Dart. The EXM plan alone is 226 KB. 94 files exceed the repo's own 400-line rule (16 exceed 800; `in_context_qa_sheet.dart` is 2,057 lines).
- Effort skews toward edge-case governance before the core loop: 18 EXM migrations, 7 of them for export, erasure or portability of a pilot feature (including a 50k-row export probe), while the general learning record doesn't exist.
- **Fix:** keep short ADRs (≤2 pages) and move the appendix logs into PR descriptions. Use declarative schemas so 80 KB function bodies aren't re-pasted. Make the contract checks and lints the AI agents' "definition of done". Prioritise a walking skeleton of the core loop (event → FSRS → plan → reminder → analytics) before new governance surfaces.

### ARCH-10 — Openness and ecosystem (the VS Code / Code-OSS model)
- No `LICENSE` ([README.md](README.md#L177)). The UGC grant covers only hosting "solely for educational purposes within the Service" ([TERMS_OF_SERVICE.md](docs/legal/TERMS_OF_SERVICE.md#L63)), so community content can't move to forks, exports or federated instances.
- **Fix:** **Apache-2.0** for the code (patent grant; Supabase itself uses it) plus a trademark policy for the name and logo. That's the Code-OSS pattern: the code is open and the brand and hosted service stay yours. Choose AGPL-3.0 only if preventing closed SaaS forks matters more than adoption. Use **CC BY-SA 4.0** (or CC BY 4.0) for public community content. Official sources keep their own licenses (avoid the NC/SA traps the literacy plan already flags).

---

## 3. Big opportunities

### OPP-1 — MCP server: plug any AI into the learner model (near-zero cost)
- **Remote:** a Supabase Edge Function (TypeScript MCP SDK, Streamable HTTP). **Supabase Auth now works as an OAuth 2.1 server with dynamic client registration for MCP clients, at no extra charge, and RLS applies to agent tokens** ([docs](https://supabase.com/docs/guides/auth/oauth-server)). The free tier includes 500k function invocations a month.
- **Local:** a stdio server (Dart [`dart_mcp`](https://pub.dev/packages/dart_mcp) or Node) for power users and creators, costing $0 to host.
- **Tools:**

  | Tool | Purpose |
  |---|---|
  | `search_catalog` | Find learning targets |
  | `get_target_outline` | Curriculum tree for a target |
  | `get_learner_state(context)` | Due counts, weakest concepts, readiness band + confidence |
  | `get_due_items` | Items ready for review |
  | `submit_review` | Writes through `record_events` |
  | `explain_item` | Item + explanation + sources, for grounded tutoring |
  | `get_exam_blueprint` | Exam structure and weights |
  | `create_lesson_draft` | Always private and unreviewed |
  | `validate_lesson` | Server-side schema + quality lint |
  | `propose_item_fix` | Goes to the moderation queue |

- **Resources:** content schema, item-writing rubric. **Prompts:** "make a practice set on my weak concepts", "Socratic tutor on concept X".
- **Guardrails:** write tools only create drafts, existing quotas apply, provenance uses the canonical `origin` enum (`ai_generated` or `user_import`) paired with `origin_client_id = 'mcp:<client_id>'`, and every call is audited.
- **Distribution:** MCP Apps work across ChatGPT's app directory, Claude and VS Code, so you meet learners inside the AI they already pay for.

### OPP-2 — Creator platform ("YouTube for learning") without paying for video
- **Embed-first:** YouTube (`youtube-nocookie`), Vimeo or PeerTube via oEmbed. Add **interactive checkpoints** (questions at timestamps), chapters mapped to concepts, and transcripts that make videos searchable and accessible. AI (BYOK) proposes retrieval questions from the transcript.
- **Media storage on Cloudflare R2** (zero egress fees). Supabase's 1 GB storage / 5 GB egress is too small for media.
- Reuse educator profiles and follows (ECO-04), moderation, DMCA and provenance.
- **Differentiator:** rank content by *measured learning gain* (roadmap W5, which needs ARCH-1), not by likes. Allow remixing and forking of content packages with lineage, like GitHub for lessons.

### OPP-3 — Licensing-exam coverage by exam archetype

| Archetype | Examples | Needed primitives | Status |
|---|---|---|---|
| Large MCQ bank | Insurance 2-15/2-20, real estate, Security+ | Blueprint-weighted timed mocks, item analytics | Mocks exist; analytics missing |
| Open-book reference | FL contractor, PE | Reference navigation drills | **EXM R1–R4 built** ✅ |
| CAT + NGN items | NCLEX | Calibrated IRT; matrix/bowtie/highlight/drag-drop | Some interaction types; no calibration, bowtie or highlight |
| Performance-based questions / sims | CompTIA PBQ, Cisco | Interactive sims, CLI emulators, scenario stimuli | Stimuli exist; sims missing |
| Oral | USCIS civics | STT + answer normalization, free recall | STT exists; pool incomplete; MCQ-based |
| Written / essay | Bar MEE/MPT | Rubric scoring (AI via BYOK) + exemplars + self-assessment | Missing |
| Calculation | FE/PE, pharmacy, electrical | Numeric entry with units and tolerance, formula sheets, worked examples | `numeric_entry` exists |
| Practical / skills | CNA, CDL pre-trip, EMT, cosmetology | Checklists with critical-fail steps, timed tasks, video evidence, assessor sign-off | Missing |
| Eligibility / renewal | Apprenticeship hours, CE | Logbook, verification, renewal reminders | Partial (pathway readiness) |

### OPP-4 — Physical skills
Add a **performance assessment** primitive: rubric/checklist with critical steps, video **self-modeling** (expert demo next to the learner's recording), peer or mentor review reusing the moderation queue, and **on-device pose estimation** (MediaPipe Tasks Vision, WASM: free and private) for movement skills. Keep video on the device or in private R2 by default, with safety disclaimers.

### OPP-5 — Interoperability (makes forks and institutions possible)
**QTI 3.0** item import/export, **xAPI/cmi5** statements from `learning_events`, an **LTI 1.3** tool so LMSs can embed the app, **Open Badges 3.0** for achievements, and **CASE** for standards alignment.

### OPP-6 — The fork kit (platform strategy)
- **Monorepo via Dart pub workspaces:**

  | Package | Contents |
  |---|---|
  | `learning_core` | Pure Dart: models, FSRS wrapper, readiness, next-action, scoring, manifest validators |
  | `learning_api_client` | Typed client over the `api` schema |
  | `learning_ui` | Design system |
  | `app` | Brand shell |

- **Branding:** `brand.json` via `--dart-define-from-file`, plus feature flags.
- **Self-hosting:** `supabase start` + migrations + seed; Docker Compose for self-hosted Supabase.
- **Content:** packages under a published, versioned spec.

### OPP-7 — i18n and reach
There's no localization infrastructure. Add `flutter gen-l10n` (ARB) for the app chrome first, then a content-translation workflow (AI via BYOK, then human review), plus RTL support and a low-bandwidth mode. This is essential for "great for the world".

---

## 4. Quick wins: performance, reliability, libraries

### PERF (load speed and hosting cost)
1. Load the app through `flutter_bootstrap.js` (async, lets the browser pick WASM or JS) and drop the custom service worker code.
2. Use **deferred imports** for rarely used areas: governance/moderation, literacy simulators, taxonomy explorer, EXM, words, editors/course builder, guided generation, audio orchestrator. **Measure the result**; a large cut in initial JS is plausible.
3. **Remove Firebase** (push doesn't work), saving a CDN SDK fetch and blocking init.
4. **Bundle 1–2 font families** (an Inter variable font, plus a monospace font for code) and set `GoogleFonts.config.allowRuntimeFetching = false`.
5. Defer KaTeX (`flutter_math_fork` declares 20 fonts that load at boot). Load math only on lesson screens, or render math to SVG at ingestion.
6. Upgrade `connectivity_plus`, then build with **`--wasm`** (skwasm renderer; the loader falls back to JS automatically).
7. Host on **Cloudflare Pages**: unlimited static bandwidth and requests on the free plan, against Firebase Spark's 360 MB/day. Deploy from GitHub Actions with **PR preview URLs**.
8. Collapse `ScopeResolver` into one RPC and cache by version hash; move summaries into RPCs.

### REL (reliability, mostly free)
1. **Error tracking:** Sentry (free developer tier) or self-hosted GlitchTip, or **PostHog** (errors, product analytics, feature flags, experiments in one tool; EU hosting and self-hosting available).
2. Replace silent `catch → []` and `debugPrint` patterns with typed errors and a retry UI. Start with the core loop.
3. CI additions: the **schema contract check**, **splinter advisors**, `flutter_lints`, a coverage report, and a **Playwright smoke test** against the PR preview (needs `ensureSemantics`).
4. Nightly **`pg_dump` via GitHub Actions** to encrypted storage (free tier has no backups), plus an uptime monitor (UptimeRobot / Better Stack free tiers).
5. Idempotent writes (UUIDv7 + upsert) and an offline outbox (ARCH-3).
6. **Cloudflare Turnstile** on anonymous sign-ins (Supabase supports captcha), on top of the existing per-IP limit.
7. Kill switches and feature flags (PostHog or an `app_config` table).

### Missing libraries and services

| Need | Recommendation | Why |
|---|---|---|
| Scheduling | [`fsrs`](https://pub.dev/packages/fsrs) (MIT) | Evidence-based SRS (ARCH-1) |
| Local store | [`hive_ce`](https://pub.dev/packages/hive_ce) now; [`drift`](https://pub.dev/packages/drift) (SQLite WASM) later | Maintained, queryable, offline |
| Observability | `sentry_flutter` / GlitchTip / `posthog_flutter` | Errors, analytics, experiments |
| MCP | `dart_mcp` or the TypeScript MCP SDK on Edge Functions | OPP-1 |
| Typed models | `json_serializable` (already present) / `freezed` | Replace `dynamic` maps |
| Lints | `flutter_lints` → `very_good_analysis` | FIX-10 |
| DB lint | Supabase **splinter** | Security and performance advisors in CI |
| Prompt evals | **promptfoo** (open source) | Regression-test prompts |
| Item calibration | `py-irt` / `girth` (Python, in `tool/`) | Offline IRT |
| Push | Web Push (VAPID) from an Edge Function + `pg_cron` | Replaces FCM |
| Email | Resend / Amazon SES (free tiers) | Digests and reminders |
| Media | Cloudflare R2 | Zero-egress storage |
| Bot protection | Cloudflare Turnstile | Anonymous sign-up abuse |
| On-device AI | WebLLM, transformers.js (Whisper), MediaPipe Tasks | Free AI, STT, pose |
| i18n | `flutter gen-l10n` (`intl` is already present) | Localization |

### Free-tier cost map (verify current terms before committing)

| Service | Free limit | Note |
|---|---|---|
| Supabase | 500 MB DB, 5 GB egress, 50k MAU, 500k Edge invocations, 1 GB storage | No backups; 1-day logs; pauses after 7 idle days (keepalive exists) |
| Firebase Hosting (Spark) | 10 GB/month (Usage & Quotas doc) / 360 MB/day (Pricing page) | Firebase's own docs list 10 GB/month on the Hosting quotas page and 360 MB/day on the pricing page; site paused after grace period if exceeded |
| Cloudflare Pages | Unlimited static bandwidth and requests | 500 builds/month |
| AI | BYOK / MCP / on-device | **$0 to the operator** |

---

## 5. Prompt improvements (generation quality)

Current prompts are structured well (XML sections, glossary locking, batching), but they lack the controls that matter for exam-grade content ([ai_prompt_service.dart](lib/services/ai_prompt_service.dart#L197), [docs/lesson_generation_prompt.md](docs/lesson_generation_prompt.md), [lesson-generator agent](.github/agents/lesson-generator.agent.md)).

1. **Grounding:** pass `<source>` excerpts and require a `source_ref` per item (locator plus a ≤25-word quote). Allow `"insufficient_source"` instead of guessing. This is mandatory for licensing content.
2. **Item-writing rules** (Haladyna, Downing & Rodriguez, 2002): no "all/none of the above", no negative stems, homogeneous and similar-length options, distractors drawn from **real misconceptions**, no grammatical or length cues.
3. **Per-option structure:** `options[{text, is_correct, rationale, misconception}]` instead of an index. This removes index errors and position cues and enables misconception analytics.
4. **Recall-first mix:** cloze, short answer with acceptable variants, free recall, worked example with faded steps, scenario application, "explain why" prompts, and interleaved sets.
5. **Closed vocabulary:** require `concept_slug` from a provided list so evidence propagates into the knowledge graph.
6. **Metadata:** Bloom level, `difficulty_estimate`, `expected_seconds`, and a target reading grade (critical for the literacy track; validate with Flesch-Kincaid).
7. **Separate critic:** use a different prompt, ideally a different model, with rubric scores **plus deterministic validators in code** (answer leakage, longest-option cue, duplicates, position balance, citation present, reading level). Same-chat self-review adds little.
8. **Prompt registry and evals:** version prompts as files, store `prompt_id@version` in provenance, and run promptfoo against a golden set in CI. When BYOK/API is used, enforce **JSON Schema structured outputs**.

---

## 6. Prioritised roadmap

**Phase 0 — Stop the bleeding (1–2 weeks, ~$0):** FIX-1 through FIX-14; enable lints; error tracking; `ensureSemantics`; bootstrap loader; contract check; LICENSE and UGC terms; correct the deployment docs.

**Phase 1 — Evidence engine (1–2 months):** `learning_events` + `record_events` RPC + server-side projections; FSRS migration; local outbox; daily plan with `reviewEmphasis`; Web Push and email reminders (remove Firebase); item analytics feeding moderation; readiness v2 with calibration.

**Phase 2 — Platform and AI (next quarter):** `api` schema + declarative schemas; MCP server (remote + local) and app-directory listings; BYOK in-app generation with structured outputs and evals; content unification (literacy content → manifests); deferred loading + WASM + Cloudflare Pages + PR previews; i18n scaffolding.

**Phase 3 — Ecosystem (6–12 months):** creator channels with embedded interactive video and learning-gain ranking; performance assessments for physical skills; QTI/xAPI/LTI/Open Badges; the fork kit (packages, branding config, self-host guide).

**Do less, for now:** pause new EXM export/erasure hardening until the general event log exists (then reuse those patterns for it); stop re-pasting large RPCs into new migrations; shorten specs into ADRs.

---

## Appendix — Evidence and commands
- **Size:** `lib/` has 534 Dart files and ~129.7k lines; tests are 230 files and ~45.6k lines; 81 migrations; 40 pgTAP files; 791 commits by one author (133 in the last 30 days).
- **`flutter analyze`:** "No issues found" as configured. With `include: package:flutter_lints/flutter.yaml` added temporarily: **814 issues**. The file was restored; the working tree is clean.
- **`flutter pub outdated`:** majors behind as listed in ARCH-8; `js` is reported discontinued.
- **`flutter build web --wasm`:** **fails** on `connectivity_plus-3.0.6` (`dart:html`, `dart:js_util`, `package:js`).
- **Local release-build audit** (`python -m http.server` on `build/web` + Chrome DevTools): 39 requests at boot, including 20 KaTeX fonts, CanvasKit, Firebase SDK 11.9.1, runtime Google Fonts, and `assets/.env`. Console error: `InvalidStateError ... ServiceWorker`. The accessibility tree contained only "Enable accessibility". Lighthouse (mobile): A11y 100 (misleading for canvas), Best Practices 77, SEO 90.
- **Schema scans:** client tables/RPCs vs `supabase/migrations` (FIX-3); `SECURITY DEFINER` scan (FIX-2, FIX-13); answer-position distribution (FIX-1).
- **External facts checked:** Supabase free-tier limits and OAuth 2.1 server for MCP (supabase.com docs); Firebase Spark Hosting limits (10 GB/month on Firebase Hosting usage & quotas page; 360 MB/day on Firebase pricing page); Cloudflare Pages unlimited static bandwidth; FSRS recall-prediction benchmark results (`srs-benchmark`) and Anki 23.10 optional FSRS integration; pub.dev versions (`fsrs` 2.0.1, `hive_ce` 2.22.0, `drift` 2.35.3, `dart_mcp` 0.5.2, `sentry_flutter` 10.2.0, `posthog_flutter` 5.58.3, `powersync` 2.5.0).
- **References:** Dunlosky et al. (2013) *PSPI* 14(1); Cepeda et al. (2006) *Psychological Bulletin*; Haladyna, Downing & Rodriguez (2002) *Applied Measurement in Education* 15(3); Pelánek (2016) *Computers & Education*; Butterfield & Metcalfe (2001) on the hypercorrection effect; open-spaced-repetition `srs-benchmark`.
