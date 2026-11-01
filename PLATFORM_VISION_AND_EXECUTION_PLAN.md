# LearningApp — Platform Vision, Critique Response & Full-Scope Execution Plan

**Date:** 2026-11-01 · **Baseline Commit:** `main` (`e538585` + `ARCHITECTURE_REVIEW.md`) · **Status:** Actionable Architecture & Execution Plan

---

## 1. Strategic Assessment: Why Shrinking the Scope Is the Wrong Conclusion

The recent review (`ARCHITECTURE_REVIEW.md` and the follow-up critique) makes two very different kinds of claims:

1. **Valid Technical Diagnostics (Keep & Fix Immediately):**
   - The spaced-repetition scheduler uses a static `[1, 3, 7, 14, 30, 60, 120]` ladder with an ease factor capped at its starting value (`2.5`), ignoring actual elapsed time and forgetting curves.
   - There is no per-attempt `learning_events` log, which prevents item calibration, forgetting-curve validation, and empirical pass-rate prediction.
   - MCQ options in simulators (USCIS, DMV, GED) have `correctOptionIndex: 0` without shuffling (`FIX-1`), `increment_user_xp` lacks an `auth.uid()` check (`FIX-2`), 12 legacy client table references drift from `supabase/migrations` (`FIX-3`), web semantics aren't auto-enabled (`FIX-6`), and boot bundle weight can be trimmed (`PERF-1..6`).

2. **Flawed Strategic Prescription (Reject):**
   - The critique argues that because the repo currently bundles only a handful of static seed lessons while having 81 migrations across taxonomy, exam prep (`EXM`), community Q&A (`ECO-01/02`), educator profiles (`ECO-04`), and adult literacy, you should **"abandon the general platform vision and shrink the app to a single hand-written exam prep tool."**

### Why the "Shrink It" Prescription Misunderstands the Product

1. **Confusing the Engine with the Initial Seed Data**
   - Saying LearningApp is an "empty product" because `assets/lessons/` only has 8 JSON files is like looking at YouTube in 2005 with 30 test videos and concluding video hosting should be pivoted into a single niche documentary channel.
   - In the era of structured AI generation, MCP, open educational resources (OER), official government/regulator handbooks, and YouTube transcripts, **raw educational content is abundant and free—what is missing everywhere is the structure, verification, and retention engine that turns scattered content into provable exam/skill mastery.**

2. **Ripping Out Already-Built Foundations Creates Debt, Not Speed**
   - The hardest multi-tenant schemas are *already built and tested* in those 81 migrations and 40 pgTAP suites:
     - **Dual-Layer Canonical Taxonomy (`CANONICAL_TAXONOMY_ARCHITECTURE.md`)**: Lets one concept (`asymmetric-encryption`, `ohm-law`, `cvc-short-a`) transfer mastery across degrees, certifications, job roles, and life skills.
     - **Scoped Curriculum vs. Global Concept State (`LEARNING_ARCHITECTURE_V2.md`)**: Prevents content collision while preserving cross-goal retention credit.
     - **Open-Book Reference Mastery & Server-Scored Exam Parts (`EXM-01..03`)**: Solves open-book tabbing/navigation speed, blueprint weighting, and tamper-proof scoring.
     - **Community Q&A, Moderation & Educator Verification (`ECO-00..04`)**: Provides the human-in-the-loop review queue needed to turn AI-drafted or user-imported content into trusted public curricula.
   - Deleting or freezing these systems would break the exact flywheel that allows the platform to scale content without hiring a $5M textbook publishing team.

3. **Why "Just Use ChatGPT Study Mode / NotebookLM" Doesn't Replace This Platform**
   - Chatbots are stateless conversation loops. They generate plausible explanations and ad-hoc quizzes in a chat scroll, but they **do not** maintain a longitudinal psychometric model of what you will forget 19 days before your licensing exam, **do not** enforce official exam blueprint weights or reference-book navigation under time pressure, and **cannot** prove with calibrated statistical confidence that you will pass.
   - When LearningApp exposes its **Evidence Engine + Taxonomy + Exam Blueprints via MCP and BYOK**, ChatGPT, Claude, and Gemini stop being competitors and become **free content & tutoring workers** that plug directly into LearningApp's structured state.

---

## 2. How to Keep the Full Vision High-Quality & Free to Operate

Instead of shrinking the product, we solve the "scope vs. solo-founder bandwidth" problem through **four architectural mechanisms**:

| Challenge Raised in Review | Wrong Fix (Shrinking) | Right Fix (Platform Architecture) |
|---|---|---|
| **"Not enough content in the catalog"** | Hand-write 500 questions for one Florida exam and drop everything else | **Universal Ingestion + On-Demand AI/MCP Compiler:** Let users/educators import any official syllabus, PDF, URL, or YouTube video/playlist—or request any goal—and compile it into the `curriculum_manifest` schema with automated psychometric linting. |
| **"Headline promise ('prove you can pass') isn't backed by data yet"** | Give up on broad learning analytics | **The Efficacy & Proof Engine:** Ship compact `learning_events` + FSRS v5/v6 + Elo/IRT item calibration + Exam-Date Retrievability $R(t)$ so *every* target on the platform gets mathematically rigorous pass-readiness proof. |
| **"Too many features (Community, Educators, Literacy, Careers, Exams) look empty at launch"** | Delete or abandon Community, Educators, and Taxonomy | **Progressive Surface Activation & Trust Tiers:** Keep all schemas live, but progressively reveal UI surfaces based on context density (e.g., in-context Q&A and educator badges appear automatically when content exists, never as empty ghost towns). |
| **"Hosting, DB storage, and AI costs will blow up the free tier"** | Restrict who can use the platform | **Zero-Marginal-Cost Architecture:** BYOK + MCP + browser-side AI (`WebLLM`/`transformers.js`) = $0 AI cost; compact 64-byte event rows + local-first SQLite/Hive outbox = 7× DB efficiency; Cloudflare Pages + R2 = $0 static/media egress. |

---

## 3. Pillar 1 — The Efficacy & Proof Engine ("Study That Proves You Can Pass")

The #1 priority where we agree with the technical review is making the core study loop **measurably superior to Anki, Quizlet, and raw LLM chat**. A learner who completes their plan in LearningApp must have **statistical proof of exam readiness**.

### 3.1 Replace the Fixed Interval Ladder with FSRS + Exam-Date Retrievability
- **Current Flaw (`lib/models/spaced_repetition.dart`)**:
  - Uses `intervals = [1, 3, 7, 14, 30, 60, 120]` multiplied by `easeFactor.clamp(1.3, 2.5)`. Because `easeFactor` starts at `2.5`, ease can never increase above its initial value, overdue elapsed days are ignored on successful recall, and a lapse schedules the item 1–2 days out with no intraday relearning step.
- **Solution**:
  - Integrate the MIT-licensed [`fsrs`](https://pub.dev/packages/fsrs) Dart package across `ReviewableItem` and `SpacedRepetitionService`.
  - Track the two true memory variables per item and per `knowledge_concept`:
    - **Stability ($S$)**: Time in days for recall probability to decay from 100% to 90%.
    - **Difficulty ($D \in [1, 10]$)**: Inherent complexity of the item for this learner.
  - **Exam-Date Target Compression**: Allow learners to set an optional `target_exam_date` on any `LearningContext`. As `target_exam_date` approaches, dynamically raise desired retention ($R_{\text{desired}}$ from `0.90` up to `0.95`) and prioritize concepts whose predicted retrievability on exam day $R(t_{\text{exam}}) = (1 + \text{factor} \cdot \frac{t_{\text{exam}}}{S})^{\text{decay}}$ falls below passing threshold.
  - **Intraday Relearning Queue**: Failed items (`Again` / incorrect MCQ) enter an in-session relearning step (1 min / 10 min) until recalled without cues before graduating back to day-level intervals.

### 3.2 Compact, High-Runway `learning_events` Telemetry
- **Current Flaw**:
  - No append-only attempt log exists, and storing verbose JSON blobs per attempt would exhaust Supabase's 500 MB free tier quickly.
- **Solution — Ultra-Compact `learning_events` Schema (~64–80 bytes/row)**:
  - Use client-generated **UUIDv7** (`id`) for time-ordered idempotency (`ON CONFLICT (id) DO NOTHING`).
  - Store fixed-width columns instead of multi-kilobyte JSON snapshots:
    - `id uuid primary key` (UUIDv7)
    - `user_id uuid not null`
    - `context_id uuid`
    - `item_id uuid not null`
    - `item_type smallint not null` (`1=mcq, 2=flashcard, 3=cloze, 4=ref_drill, 5=oral_stt, 6=word_skill`)
    - `rating smallint not null` (`1=Again, 2=Hard, 3=Good, 4=Easy`)
    - `score_bps smallint not null` (`0..10000` basis points)
    - `confidence smallint` (`1=Guess, 2=Unsure, 3=Certain` — powers hypercorrection & calibration curves)
    - `latency_ms integer not null`
    - `option_permutation smallint` (compact encoding of the 24 possible 4-option shuffle orders `0..23`, replacing a JSON array!)
    - `selected_index smallint` (authored option index chosen, enabling distractor analytics)
    - `stability_before real`, `stability_after real`, `difficulty_after real`
    - `occurred_at timestamptz not null default now()`
  - **Capacity Math**: At ~72 bytes per row, 500 MB holds **~5 million+ learning events** on the free tier before archiving older raw logs to Cloudflare R2 Parquet/NDJSON files.

### 3.3 Atomic `record_learning_events(jsonb)` RPC + Offline Outbox
- **Solution**:
  - Build a local-first outbox (`hive_ce` / SQLite WASM) that immediately updates local FSRS state and queues compact event payloads.
  - Sync batches via a single `record_learning_events(p_events jsonb)` RPC that:
    1. Inserts into `public.learning_events` (`ON CONFLICT (id) DO NOTHING`).
    2. Atomically updates `review_items` and `user_concept_state` only when `occurred_at > last_event_at` (eliminating offline replay double-counting and multi-tab races).
    3. Updates aggregate item psychometrics (`attempt_count`, `correct_count`, online Elo difficulty rating, per-distractor selection counts) so poor items are automatically flagged for review.

### 3.4 Calibrated Readiness Score ("Proof You Can Pass")
- Replace lifetime cumulative accuracy (`weighted_correct / weighted_total`, which never forgets) with a **3-Factor Exam Readiness Proof**:
  1. **Blueprint Coverage**: % of required `curriculum_node_concepts` with $\ge 3$ spaced retrievals.
  2. **Predicted Exam-Day Recall $\bar{R}(t_{\text{exam}})$**: Blueprint-weighted mean FSRS retrievability across all target concepts.
  3. **Timed Simulation & Reference Speed (`EXM`)**: Performance under realistic time-per-item and open-book lookup constraints.
- Keep the honest heuristic labels from `UI_ARCHITECTURE_LOCKED.md` until a learner crosses the minimum evidence threshold, then display their **Calibrated Readiness Band + Predicted Score Range**.

---

## 4. Pillar 2 — Universal Content, YouTube & On-Demand AI Pipeline

To make "empty catalog" impossible without narrowing the platform, LearningApp should treat **content creation and organization as an automated, user-triggerable pipeline**.

### 4.1 Four Content Channels Feeding One Canonical Schema
All content—regardless of origin—compiles into the same `curriculum_manifest.schema.json` and `v2` primitives (`knowledge_concepts`, `lesson_blocks`, `assessment_items`, `flashcards`, `content_provenance`):

1. **Channel A — Official & Regulator Blueprints (Pre-Seeded & Versioned)**
   - Official taxonomies (BLS/O\*NET/CIP), state licensing blueprints (FL DBPR Contractors, FL DFS Insurance, Security+, NCLEX), and civic/life milestones (full 128-question USCIS 2025 pool + oral STT mode, state DMV manuals, GED bridge).
2. **Channel B — YouTube & Open Web Resource Overlay ("Structured Practice Over Any Video/Doc")**
   - Learners or educators paste a YouTube URL/playlist, open textbook chapter, or official handbook PDF/URL into `PersonalCurriculumOverlay` or the Course Builder.
   - The app embeds the video via privacy-safe `youtube-nocookie` / oEmbed, extracts the transcript/sections, maps timestamps to `knowledge_concepts`, and generates **interactive timestamp checkpoints** (retrieval questions that pause the video at key concepts and schedule those concepts into FSRS).
   - Zero video hosting or bandwidth cost to LearningApp.
3. **Channel C — On-Demand AI Generation via BYOK & Browser AI ($0 Operator Cost)**
   - Upgrade `AiPromptService` from copy-paste prompts to **direct runtime generation** when the user provides their own API key (Gemini, OpenRouter, OpenAI, Anthropic—stored strictly in local device storage) or uses on-device browser AI (`WebLLM` / Chrome Built-in AI).
   - Enforce **JSON Schema Structured Outputs** matching `curriculum_manifest.schema.json` so users can request *any* course, lesson, or practice drill on demand and have it compiled directly into their private study overlay (`user_id = auth.uid(), is_public = false`).
4. **Channel D — MCP Server (`OPP-1`) for External AI Assistants**
   - Expose LearningApp's catalog, learner state (`get_due_items`, `get_weak_concepts`), and draft ingestion (`create_lesson_draft`, `submit_review`) via a lightweight Supabase Edge Function MCP Server (using Supabase Auth OAuth 2.1) and local `dart_mcp` stdio server.
   - Users studying inside ChatGPT, Claude, or VS Code can say *"Build me a 30-question drill on my weakest Florida General Contractor concepts"* and have it land directly in their LearningApp queue with full provenance (`origin = mcp:<client>`).

### 4.2 Deterministic Quality Gate (Keeping AI & Community Content High-Quality)
To prevent low-quality AI slop from polluting study sessions, every imported or generated item runs through a **Deterministic Psychometric Validator** in Dart (`lib/services/content_quality_validator.dart`) before activation:
- **Structure (`FIX-1`)**: Options stored with per-option `{text, is_correct, rationale, misconception_tag}` rather than raw positional indices; shuffled deterministically at render time.
- **Cue Detection**: Rejects items where the correct option is $>1.4\times$ longer than the mean distractor length, contains "all/none of the above", or leaks stem keywords.
- **Grounding Check**: For licensing/exam targets, requires a `source_ref` citation locator + quote excerpt.
- **Literacy Grade Guard**: Computes Flesch-Kincaid / SCOWL lexicon coverage (`assets/lexicons/en_us_scowl_roots.txt`) so adult literacy and ESL items never exceed target reading complexity.
- **Community Promotion Flywheel**: User/AI-generated content starts **private (`Tier 1`)**. If the author opts to share it (`CC BY-SA 4.0`) and it passes deterministic validation + educator/moderator review (`ECO-02`/`ECO-04`) + empirical item discrimination ($r_{pb} > 0.20$ after 30+ attempts), it can be promoted to the shared community catalog (`Tier 2`).

---

## 5. Pillar 3 — Progressive Guardrails & Rollout Rules (Keeping Everything Without Clutter)

We do **not** delete features; instead, we define **runtime guardrails and visibility rules** so the app feels focused, fast, and complete at every stage of growth:

1. **Zero-Ghost-Town UI Rule for Community & Educators (`ECO-01..04`)**
   - In-context Q&A (`InContextQaSheet`) and Educator badges (`educator_profiles`) remain first-class features, but if a concept has `0` questions, show a compact single-line prompt (*"Ask a question or attach a study note for this concept"*) rather than an empty forum feed.
2. **Tiered Provenance Badges (Already Aligned with `ECO-00` & `P2`)**
   - Every target and item clearly displays its provenance tier:
     - **Official / Verified Blueprint** (Regulator-cited, version-locked)
     - **Educator Reviewed** (Verified domain educator sign-off via `ECO-04`)
     - **Personal / AI Study Overlay** (Generated on-demand or imported by the learner—clearly scoped to their private overlay until reviewed)
3. **Free-Tier Resource Quotas (Already Built in `ECO-00C`, Now Wired to Runtime)**
   - Keep the existing `usage_quotas` and rate-limiting tables active for server-side actions while making BYOK, local FSRS scheduling, and YouTube embeds completely unmetered.

---

## 6. Pillar 4 — Complete Technical Remediation Matrix (`FIX-1`..`FIX-14` & `ARCH-1`..`ARCH-10`)

Every concrete bug and bottleneck identified in `ARCHITECTURE_REVIEW.md` is resolved below **without** shrinking the application's scope.

### Phase 0 — Security, Validity & Accessibility Hotfixes (Days 1–5)

| Review ID | Issue | Concrete Fix (Preserving Full Architecture) |
|---|---|---|
| **FIX-1** | Correct answer is always Option A (`correctOptionIndex: 0`) in USCIS/DMV/GED simulators; MCQs don't shuffle | Add deterministic seeded shuffling (`Random(Object.hash(sessionId, itemId, attemptCount))`) in `McqContent`, `McqOptions`, assessment renderer, and USCIS/DMV/GED simulators. Record `option_permutation` and `selected_index`. Expand `officialUscisCivicsCatalog` to all 128 questions and enable oral STT free-recall mode by default. |
| **FIX-2** | `increment_user_xp(p_user_id, p_xp_amount)` is `SECURITY DEFINER` without checking `auth.uid()` | Add a new append-only migration (`supabase/migrations/20261102000000_harden_xp_and_rls_initplans.sql`) that enforces `auth.uid() = p_user_id`, `p_xp_amount BETWEEN 1 AND 500`, `SET search_path = public, pg_temp`, and revokes execute from `anon, public`. |
| **FIX-3** | 12 legacy tables and 2 RPCs called in `lib/` are missing from `supabase/migrations/` | Reconcile legacy `career_paths`/`skills` references into the canonical v2 taxonomy/target equivalents or add a clean compatibility view migration, archive the legacy `database/` directory, and add `tool/verify_client_schema_contract.dart` in CI. |
| **FIX-6** | Screen readers on Flutter Web only see "Enable accessibility" button | Call `SemanticsBinding.instance.ensureSemantics()` on web initialization in `lib/main.dart` so screen readers and Playwright/DevTools MCP snapshots work immediately on boot. |
| **FIX-7** | Timezone-naive `DateTime.now().toIso8601String()` shifts due dates by UTC offset | Standardize all DB writes to `.toUtc().toIso8601String()` and compute "due today" buckets using local midnight boundaries in a shared `TimeUtils` helper. |
| **FIX-8** | `SpacedRepetitionService.getDueItems()` catches errors and returns `[]` ("nothing due") | Propagate typed errors (`AsyncValue.error`) to the UI with a retry banner and fall back to the local Hive/outbox cache when offline. |
| **FIX-10** | `flutter_lints` disabled in `analysis_options.yaml`; 17 `use_build_context_synchronously` warnings; undeclared transitive imports | Enable `include: package:flutter_lints/flutter.yaml`, explicitly declare `crypto`, `json_annotation`, and `timezone` in `pubspec.yaml`, and add `if (!context.mounted) return;` guards across all 17 async `BuildContext` call sites. |
| **FIX-12 / FIX-13** | Non-EXM `assessment_items.scoring_spec` readable by `anon`; bare `auth.uid()` in RLS policies; unpinned `search_path` in 2 functions | Pin `SET search_path = public, pg_temp` on `finalize_official_taxonomy_import` and `resolve_taxonomy_lineage`; wrap `auth.uid()` as `(select auth.uid())` on high-traffic RLS policies (`review_items`, `user_concept_state`, `learning_contexts`); move diagnostic/exam answer key evaluation behind server-side scoring RPCs while keeping practice explanations accessible post-attempt. |

### Phase 1 — Web Delivery Speed, PWA & Zero-Cost Hosting (Days 6–12)

| Review ID | Issue | Concrete Fix |
|---|---|---|
| **FIX-4 / PERF-1** | Deprecated `flutter_service_worker.js` manual registration throws `InvalidStateError` in `web/index.html`; blocking `<script src="main.dart.js">` | Replace manual loader in `web/index.html` with `{{flutter_bootstrap_js}}` and a clean Workbox/cache-first app-shell asset worker for offline study. |
| **PERF-2 / PERF-5** | 7.35 MB `main.dart.js` and 20 KaTeX fonts loaded eagerly at boot | Add `deferred as` imports for heavy secondary modules (Moderation console, Course Builder, Taxonomy Explorer, EXM Portability Export, KaTeX math renderer) so the initial `Learn` screen boots in a fraction of the payload. |
| **PERF-4** | Runtime Google Fonts fetching (5 families) slows boot and breaks offline | Bundle `Inter` and `JetBrains Mono` variable fonts in `assets/fonts/` and set `GoogleFonts.config.allowRuntimeFetching = false`. |
| **PERF-6 / ARCH-8** | `flutter build web --wasm` blocked by `connectivity_plus 3.0.6` and legacy `package:js` | Upgrade `connectivity_plus` to `^7.0.0` and `supabase_flutter` to `^2.18.3` so `--wasm` (Skwasm) compiles cleanly. |
| **FIX-5 / FIX-11 / FIX-14** | `.env` bundled in `pubspec.yaml` assets; Firebase push notifications non-functional on web; missing CSP/security headers | Remove `.env` from `pubspec.yaml` assets in favor of `--dart-define-from-file`; replace broken FCM stub with standard **Web Push (VAPID)** via a Supabase Edge Function; add `X-Content-Type-Options`, `Referrer-Policy`, and `Permissions-Policy` headers. |
| **ARCH-2 / FIX-9** | `ScopeResolver` makes ~35 round-trip queries; unpaginated `.select()` calls | Collapse `ScopeResolver.resolve()` into a single `resolve_learning_scope(p_context_id uuid)` PostgreSQL RPC (as envisioned in `LEARNING_ARCHITECTURE_V2.md §12`), cutting 35 network round-trips down to 1. |

### Phase 2 — The Evidence Engine (`learning_events` + FSRS + Offline Outbox) (Weeks 3–4)

1. **Migration (`20261103000000_learning_events_and_fsrs_state.sql`)**:
   - Create compact `public.learning_events` table + `record_learning_events(jsonb)` atomic RPC.
   - Add FSRS state columns (`stability real`, `difficulty real`, `elapsed_days integer`, `scheduled_days integer`, `lapses integer`, `state smallint`) to `review_items` and `user_concept_state` with non-destructive backfill from existing `repetition_level` and `ease_factor`.
2. **Client FSRS & Outbox Integration**:
   - Upgrade `ReviewableItem.processReview()` to run FSRS (`package:fsrs`) while preserving backwards-compatible getters.
   - Route all flashcard, MCQ, word-learning, and drill completions through a unified `LearningEventOutboxService` (`hive_ce`) so offline reviews never get lost and sync idempotently on reconnect.
3. **Daily Plan & Overdue Retrievability Guard**:
   - Enhance `NextActionEngine` so it respects `UI_ARCHITECTURE_LOCKED.md` while surfacing an urgent review batch whenever predicted retrievability $R(t)$ on core target concepts drops below `0.75`.

### Phase 3 — On-Demand AI (BYOK + MCP) & YouTube/Resource Compiler (Weeks 5–7)

1. **Runtime BYOK + Browser AI Studio (`lib/services/ai_runtime_service.dart`)**:
   - Let users optionally configure a local-only API key (Gemini / OpenRouter / OpenAI) or use local browser inference to generate structured `curriculum_manifest` lessons, flashcards, and blueprint-aligned MCQs directly in the app—validated automatically by `ContentQualityValidator`.
2. **YouTube & Document Practice Overlay**:
   - Allow pasting any YouTube URL or official PDF/webpage into a Goal or Personal Curriculum Overlay to extract concepts, attach timestamped retrieval questions, and schedule them into FSRS.
3. **MCP Server (`supabase/functions/mcp-server` + `tool/mcp_stdio_server.dart`)**:
   - Expose catalog search, learner weak-concept state, due reviews, and validated draft creation to external AI assistants via Supabase OAuth 2.1.

### Phase 4 — Open Ecosystem & Fork Kit (`LICENSE` + Content Portability) (Week 8)

1. **Code & Content Licensing (`FIX-12` / `ARCH-10`)**:
   - Add root `LICENSE` (**Apache-2.0** for code) + `TRADEMARK_POLICY.md` (protecting the LearningApp name and verified badges) + update `TERMS_OF_SERVICE.md` so public community-contributed curricula use **CC BY-SA 4.0**, enabling the VS Code / Code-OSS ecosystem model without giving away brand trust.

---

## 7. Summary of Position

- **Do not shrink the vision.** Your architecture (global concept graph + scoped curricula + verified licensing pathways + open-book reference drills + adult literacy + community/educator moderation) is already built and is what separates LearningApp from disposable AI flashcard toys.
- **Fix the engine, automate content ingestion, and tighten the 14 defects.** By upgrading the scheduler to FSRS with compact `learning_events` telemetry, collapsing `ScopeResolver` into 1 RPC, fixing the 14 concrete bugs (`FIX-1`..`FIX-14`), and wiring BYOK/MCP + YouTube/resource ingestion into the existing manifest pipeline, the platform stays **100% true to its full vision, near-$0 to run, and empirically stronger than commercial prep tools.**
