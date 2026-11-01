# LearningApp — Platform Vision, Trust Architecture & Full-Scope Execution Plan

**Date:** 2026-11-01 · **Baseline Commit:** `main` (`e538585` + `ARCHITECTURE_REVIEW.md`) · **Status:** Converged Full-Scope Architecture & Execution Plan (v2.0)

---

## 1. Strategic Convergence: Big Vision + Hard Trust Boundaries

Following the technical review (`ARCHITECTURE_REVIEW.md`) and architectural synthesis, the core product strategy is now aligned around **five foundational truths**:

1. **This Is a Pipeline & Verification Platform, Not a Closed Textbook Publisher**
   - Counting bundled JSON questions in `assets/lessons/` was the wrong metric. Raw educational material already exists everywhere (YouTube lectures, official regulator handbooks, PDFs, Anki/Quizlet decks, OER textbooks, and AI generation).
   - The platform's real moat is **how fast and accurately a learner or educator can turn any source into structured practice, and how reliably the engine proves they can pass the real exam.**

2. **Limits & Maturity Gates Beat Feature Cuts ("Don't Pause What's Already Built")**
   - Pausing or ripping out built foundations (`CANONICAL_TAXONOMY_ARCHITECTURE.md`, `LEARNING_ARCHITECTURE_V2.md`, `EXM-01..03` open-book reference drills, `ECO-00..04` community Q&A & educator verification, and the Adult Literacy track) causes code rot and painful rewrites later.
   - Instead of shrinking the scope, every surface stays alive under **explicit maturity levels (`experimental` | `beta` | `stable`), hard free-tier cost limits, feature kill switches, and content trust tiers.**

3. **Where the YouTube Analogy Holds—and Where High-Stakes Exams Require More**
   - *Where it holds*: Just as YouTube didn't shoot the videos, LearningApp doesn't need to hand-author every course from scratch; it makes importing, structuring, and practicing effortless.
   - *Where exam prep is higher-stakes*: A bad YouTube video wastes 10 minutes; a bad answer key or hallucinated rule on a contractor, nursing, or citizenship exam can cost someone hundreds of dollars in exam fees and months of delayed employment.
   - *Architectural resolution*: **Strict separation between "Schedule Anything for Review" (`Personal` Tier) and "Counts Toward Official Exam Pass Proof" (`Verified` & `Calibrated` Tiers).**

4. **"Proof You Can Pass" Must Be Empirically Measured, Not Just Designed**
   - True pass prediction requires three closed loops working together:
     1. An append-only **per-attempt answer log (`learning_events`)** driving an evidence-based scheduler (**FSRS**) and item difficulty/discrimination calibration (**Elo / IRT**).
     2. **Real-world outcome capture (`exam_outcome_reports`)**: Self-reported exam pass/fail + score breakdowns, upgraded to **registry-verified passes** where public license lookup APIs/registries exist (e.g., Florida DBPR contractor licenses) with learner consent.
     3. **Published Calibration Accuracy**: Measuring and publishing how often learners rated "Ready to Pass" actually pass on exam day.

5. **One Proving-Ground Exam as a Calibration Lab (Not a Scope Cut)**
   - We use **Pilot A (Florida DBPR Certified Contractor)** and **Pilot B (Florida Insurance)** as the high-rigor **Tier 4 (`Calibrated`) Test Lab** to prove empirical pass prediction with real candidates—while keeping **every other goal, career, literacy skill, and user-imported topic 100% open** across the `Personal`, `Community`, and `Verified` tiers. Because the engine is generic, calibrating the math on one proving-ground exam validates the machinery for the entire platform.

---

## 2. The 4-Tier Content Trust & Readiness Eligibility Model

To allow **"import or generate anything on demand"** to coexist safely with **"provable exam readiness,"** every assessment item, flashcard, and lesson block carries a machine-enforced `trust_tier`:

| Trust Tier | What Qualifies | Scheduled in FSRS? | Counts Toward Official Exam Readiness Proof? | Promotion Bar to Next Tier |
|---|---|---|---|---|
| **Tier 1: `personal`** | Any user-imported source (YouTube, PDF, Anki/Quizlet/CSV, or BYOK/MCP AI generation). Labeled **Unverified / Personal Study**; private to creator (`is_public = false`). | **Yes** (full spaced repetition & personal progress tracking) | **No (0% weight in official pass prediction)** — tracked in a separate *Personal Study Mastery* meter so unverified items never inflate official exam readiness. | Author opts to share (`CC BY-SA 4.0`) + passes deterministic psychometric linter (`ContentQualityValidator`) + moderation check (`ECO-02`). |
| **Tier 2: `community`** | Passed automated quality gates (option length balance, no stem leakage, reading level check) and community/moderator review. | **Yes** | **Low Confidence (capped diagnostic weight, labeled *Community Practice*)** | Mapped to an active `TargetVersion` official blueprint node + verified `source_ref` citation locator + domain Educator sign-off (`ECO-04`). |
| **Tier 3: `verified`** | Mapped to the official regulator/issuer exam outline (`curriculum_node_concepts`), pinned to an effective date/version, and backed by a verified primary source citation (`content_provenance`). | **Yes** | **Yes (Counts toward Official Blueprint Readiness)** | Accumulates $N \ge 30$ real learner attempts in `learning_events` with positive point-biserial discrimination ($r_{pb} \ge 0.15$) and non-degenerate difficulty ($0.10 \le p \le 0.95$). |
| **Tier 4: `calibrated`** | `verified` item with empirical difficulty ($b_i$), discrimination ($a_i$), and distractor selection telemetry derived from real learner attempts. | **Yes** | **Yes — High Confidence (Powers Calibrated Predicted Exam Score Range & Pass Probability)** | Continuous monitoring; auto-quarantined back to review queue if regulator syllabus changes or discrimination turns negative ($r_{pb} < 0$). |

---

## 3. Feature Maturity Levels, Free-Tier Limits & Kill Switches

Nothing built in the repository is deleted. Instead, every subsystem is governed by a lightweight `app_feature_gates` configuration (cached locally, overridable server-side without redeploying) with explicit cost guardrails that keep operator spend near **$0/month**:

### 3.1 Hard Free-Tier Cost Rules (Operator Cost = ~$0)
1. **Runtime AI Is 100% BYOK, MCP, or On-Device**:
   - Users supply their own API key (Gemini, OpenRouter, OpenAI, Anthropic—stored strictly in local device storage, never on our servers), connect via **MCP** from the AI subscription they already pay for, or use local browser inference (`WebLLM` / `transformers.js`).
   - Server-side quota tables (`usage_quotas` from `ECO-00C`) guard any platform-sponsored pilot credits.
2. **Zero Video or Heavy Media Hosting**:
   - Video lessons use privacy-safe embeds (`youtube-nocookie`, Vimeo, PeerTube) + timestamped retrieval overlays. Any static reference artifacts or archived logs use Cloudflare R2 (zero egress fee).
3. **Private-by-Default Ingestion**:
   - Every AI-generated or user-imported deck lands in the user's private overlay (`Tier 1: personal`). Publishing to the public catalog requires passing the deterministic linter and `ECO-02` review queue.
4. **Local-First Guest Data**:
   - Anonymous guest progress and `Personal` tier decks live on-device (`hive_ce` / SQLite WASM) until the learner links a permanent account (`linkIdentity`) or enters a server-scored `EXM` session.

### 3.2 Subsystem Maturity & Promotion Matrix

| Subsystem | Initial Maturity | Free-Tier Guardrail & Scope | Kill Switch Key | Bar to Promote to Next Level |
|---|---|---|---|---|
| **Core SRS, Learn/Library/Progress, Direct Access** | `stable` | Local-first outbox + compact DB sync | `core.study_loop` (always on) | Upgrade scheduler to FSRS + ship `learning_events` |
| **EXM Open-Book Reference Drills & Mock Exams (`EXM-01..03`)** | `stable` | Server-scored for `verified`/`calibrated` blueprints | `exm.reference_drills` | Complete 20–50 candidate calibration run on Pilot A/B |
| **Universal Importer (YouTube, Anki, Quizlet/CSV, PDF, BYOK AI)** | `beta` | Private (`Tier 1`) by default; uses user's BYOK key / client CPU | `ingest.universal_importer` | $\ge 90\%$ parse success rate + zero unflagged broken items |
| **Adult Literacy & Civic Milestones (USCIS 128, DMV, GED, Phonics)** | `beta` | Bundled offline-capable manifests + browser STT/TTS | `literacy.milestone_tracks` | Expand USCIS pool to all 128 items (2025 spec) + oral recall default + `ensureSemantics()` |
| **Community Q&A (`ECO-01/02`) & Educator Profiles (`ECO-04`)** | `beta` | Contextual-only UI (no empty forum feeds; compact 1-line prompt when `count == 0`); rate-limited by `usage_quotas` | `eco.community_qa`, `eco.educator_profiles` | $\ge 5$ verified domain educators actively reviewing `Tier 2 -> Tier 3` items |
| **MCP Server (`OPP-1`: Remote Edge + Local Stdio)** | `experimental` | Read learner state + write `Tier 1` private drafts only; rate-limited via Supabase OAuth 2.1 | `platform.mcp_server` | End-to-end verification in Claude Desktop, ChatGPT, and VS Code |
| **Physical Skills & Pose Rubric Checklists (`OPP-4`)** | `experimental` | On-device MediaPipe WASM only; zero server video upload | `skills.physical_rubrics` | Validated checklist rubric schema on 1 practical trade/clinical skill exam |

---

## 4. Pillar 1 — The Evidence & Pass-Proof Engine (Build First)

Everything in the platform plugs into the Evidence Engine. It turns practice into **verifiable pass prediction**.

### 4.1 Ultra-Compact `learning_events` Log (~72 Bytes/Row)
- **Migration (`supabase/migrations/20261103000000_learning_events_and_fsrs.sql`)**:
  - Uses client-generated **UUIDv7** (`id`) for chronological sorting and idempotent retries (`ON CONFLICT (id) DO NOTHING`).
  - Avoids bloated JSON columns in favor of compact typed fields so Supabase's 500 MB free database holds **5,000,000+ attempts** before cold archival to Cloudflare R2 Parquet files:
    - `id uuid primary key` (UUIDv7)
    - `user_id uuid not null references auth.users(id) on delete cascade`
    - `context_id uuid`
    - `item_id uuid not null`
    - `item_type smallint not null` (`1=mcq, 2=flashcard, 3=cloze, 4=ref_drill, 5=oral_stt, 6=word_skill, 7=numeric, 8=checklist`)
    - `trust_tier smallint not null` (`1=personal, 2=community, 3=verified, 4=calibrated`)
    - `rating smallint not null` (`1=Again, 2=Hard, 3=Good, 4=Easy`)
    - `score_bps smallint not null` (`0..10000` basis points)
    - `confidence smallint` (`1=Guess, 2=Unsure, 3=Certain` — measures metacognitive calibration & hypercorrection)
    - `latency_ms integer not null`
    - `option_permutation smallint` (`0..23` Lehmer code encoding the exact 4-option presentation order in 2 bytes)
    - `selected_option_id smallint` (identifies which distractor was chosen)
    - `stability_before real`, `stability_after real`, `difficulty_after real`
    - `occurred_at timestamptz not null default now()`

### 4.2 FSRS v5/v6 Scheduler + Exam-Date Retrievability $R(t)$
- Replace the static `[1, 3, 7, 14, 30, 60, 120]` interval ladder in `lib/models/spaced_repetition.dart` with the MIT [`fsrs`](https://pub.dev/packages/fsrs) package:
  - **True Forgetting Curve**: Every `ReviewableItem` and `user_concept_state` tracks **Stability ($S$)** and **Difficulty ($D$)**, allowing instantaneous calculation of current recall probability $R(t)$ and **Exam-Day Recall Probability $R(t_{\text{exam}})$**.
  - **Intraday Relearning Queue**: Lapsed items (`Again`) enter an in-session relearning queue (`1m → 10m`) rather than disappearing for 1–2 days.
  - **Daily Plan Balancing**: Instead of starving reviews behind new material, blend due reviews whose $R(t) < R_{\text{desired}}$ with forward progress within the learner's daily time budget.

### 4.3 Atomic `record_learning_events(jsonb)` RPC + Item Calibration
- A single idempotent RPC writes `learning_events` and atomically updates:
  1. `review_items` (FSRS stability, difficulty, due date, lapses).
  2. `user_concept_state` (separating `verified_retrievability` from `personal_retrievability` so `Tier 1` items never spoof official exam readiness).
  3. `item_psychometrics` (online **Elo difficulty update** on every attempt + distractor selection counters + point-biserial discrimination $r_{pb}$). Once an item in `Tier 3 (verified)` reaches $N \ge 30$ attempts with $r_{pb} \ge 0.15$, it automatically qualifies for `Tier 4 (calibrated)`.

### 4.4 Real-World Outcome Loop & Published Pass Accuracy (`exam_outcome_reports`)
- **Closing the Loop with Real Candidates**:
  - When a learner's `target_exam_date` passes (or anytime from the Target Detail / Progress screen), prompt them to log their official exam result:
    - `outcome_status` (`passed`, `failed`, `rescheduled`)
    - `reported_score` / domain sub-scores
    - `readiness_snapshot_at_exam` (automatically snapshotted from their `Tier 3/4` predicted exam score and FSRS $\bar{R}(t_{\text{exam}})$ on test day)
    - `verification_method`:
      - `self_reported` (default)
      - `score_report_redacted_hash` (optional verification)
      - `public_registry_verified` (for state licenses with public lookup registries such as **Florida DBPR** or **Florida DFS**, learners can optionally consent to verify their issued license number against the state roster)
  - **Published Calibration Table**: Display an honest, live **Readiness Calibration Card** showing predicted pass probability vs. observed pass rate across cohorts (e.g., Pilot A Florida Contractor test lab).

---

## 5. Pillar 2 — Universal Single-Pipeline Importer & Declarative Exam Profiles

### 5.1 One Import Pipeline for Every Source
All external sources pass through a single **Source-to-Manifest Compiler (`lib/services/ingestion/universal_import_pipeline.dart`)** that outputs canonical `curriculum_manifest.schema.json` packages:

1. **YouTube URL / Playlist Importer (Zero Hosting Cost)**:
   - Uses `youtube-nocookie` embed + transcript/timestamp extraction.
   - When the learner provides a Gemini API BYOK key, passes the public YouTube URL directly to Gemini 2.5 Flash/Pro with `responseSchema: curriculumManifestSchema` to generate **timestamped retrieval checkpoints** mapped to target concepts.
2. **Anki (`.apkg` / TSV), Quizlet & CSV Deck Importer**:
   - Parses existing flashcards/questions directly in the browser, normalizes cloze/MCQ/term cards into `v2` primitives, maps them to the active target's `knowledge_concepts` via lexical/embedding match, runs `ContentQualityValidator`, and assigns `Tier 1 (personal)`.
3. **Official Outlines, Regulator Handbooks & PDFs**:
   - Extracts section hierarchies + page/table locators (`source_ref`), generating cited practice items and `EXM` open-book reference navigation drills (`R1–R4`).

### 5.2 Declarative Exam Profiles (`exam_profile_spec` — Configuration, Not Custom Code)
Adding a new licensing exam, certification, or civic test must **never** require writing a new Dart screen or custom service. Every exam target is defined by a declarative JSON/SQL profile (`learning_target_exam_profiles`):
- `delivery_mode`: `standard_mcq` | `open_book_reference` | `cat_adaptive` | `oral_interview_stt` | `calculation_numeric` | `practical_checklist`
- `timing_policy`: total minutes, per-part locks, pause rules (`exam_practice_elapsed_clock`)
- `scoring_policy`: cut score (e.g. `70%`), domain weights, early-stop rule (e.g. USCIS 2025: 128 pool, 20 asked, stop at 12 correct or 9 incorrect), critical-fail checklist steps
- `allowed_references`: array of `exam_reference_manifest` IDs (for open-book exams)
- `readiness_policy`: minimum `Tier 3/4` blueprint coverage and target $\bar{R}(t_{\text{exam}})$ required to display "Ready to Pass"

---

## 6. Pillar 3 — Sequenced Engineering Roadmap (`FIX-1`..`FIX-14` + Core Engine)

### Phase 0 — Security, Validity & Accessibility Hotfixes (Days 1–5)
1. **`FIX-1` (Eliminate Option-A Bias & Shuffle Deterministically)**:
   - Implement seeded Fisher-Yates shuffling (`Random(Object.hash(sessionId, itemId, attemptCount))`) across `McqContent`, `McqOptions`, assessment renderer, and USCIS/DMV/GED simulators.
   - Store per-option `{text, is_correct, rationale, misconception_tag}` and record the 2-byte `option_permutation` (`0..23`) + `selected_option_id`.
2. **`FIX-2` (Harden `increment_user_xp` RPC)**:
   - Append-only migration enforcing `auth.uid() = p_user_id`, `p_xp_amount BETWEEN 1 AND 500`, `SET search_path = public, pg_temp`, and revoking execute from `anon, public`.
3. **`FIX-3` (Client ↔ Migration Schema Contract Check)**:
   - Reconcile the 12 legacy table references (`database/` vs `supabase/migrations/`), remove dead legacy calls, and add `tool/verify_client_schema_contract.dart` in CI so every `.from()` and `.rpc()` in `lib/` is verified against `supabase/migrations/`.
4. **`FIX-6` (Web Screen-Reader Semantics)**:
   - Call `SemanticsBinding.instance.ensureSemantics()` at web startup in `lib/main.dart`.
5. **`FIX-7` & `FIX-8` (UTC Timestamps & Error Visibility in SRS)**:
   - Normalize all timestamp writes to `.toUtc().toIso8601String()`, bucket days in local time, and replace silent `catch (_) { return []; }` in `SpacedRepetitionService` with typed error propagation + local cache fallback.
6. **`FIX-10` & `FIX-13` (Lints, Async Context Guards & RLS Initplan Optimization)**:
   - Enable `flutter_lints`, declare `crypto`, `json_annotation`, and `timezone` in `pubspec.yaml`, fix the 17 `use_build_context_synchronously` sites, pin `search_path` on remaining `SECURITY DEFINER` RPCs, and wrap `auth.uid()` as `(select auth.uid())` in hot RLS policies.

### Phase 1 — Evidence Engine, FSRS & Proving-Ground Calibration Lab (Weeks 2–3)
1. **Ship `learning_events` + `record_learning_events` RPC + `item_psychometrics`**.
2. **Replace fixed interval ladder with `package:fsrs`** and separate `Verified Readiness` (`Tier 3/4`) from `Personal Study Progress` (`Tier 1/2`).
3. **Ship `exam_outcome_reports`** (self-reported + optional FL DBPR / state registry verification) and the **Calibration Accuracy Card**.
4. **Seed Pilot A (FL DBPR Certified Contractor) / Pilot B (FL Insurance)** with 300–500 cited, blueprint-mapped `Tier 3 (verified)` items as the live calibration lab while keeping all other domains open.

### Phase 2 — Universal Import Pipeline, BYOK AI & MCP Server (Weeks 4–5)
1. **Universal Importer (`YouTube URL + timestamps`, `Anki .apkg / Quizlet / CSV`, `PDF / Official Outlines`)** compiling into `Tier 1 (personal)` manifests with automated `ContentQualityValidator` checks.
2. **Runtime BYOK AI Generation** (Gemini / OpenRouter / OpenAI / WebLLM) with strict JSON Schema output and citation locators.
3. **MCP Server (`OPP-1`)** on Supabase Edge Functions (OAuth 2.1) + local `dart_mcp` stdio server.

### Phase 3 — Web Speed, WASM, PWA Offline & Open Ecosystem (Weeks 6–7)
1. **Web Bundle & WASM (`FIX-4`, `FIX-5`, `FIX-9`, `FIX-11`, `FIX-14`, `PERF-1..8`)**:
   - Switch `web/index.html` to `{{flutter_bootstrap_js}}`, bundle `Inter` and `JetBrains Mono` locally (`allowRuntimeFetching = false`), add `deferred as` lazy loading for secondary screens/KaTeX, upgrade `connectivity_plus` to unblock `flutter build web --wasm`, collapse `ScopeResolver` into 1 RPC (`resolve_learning_scope`), and replace unused FCM stubs with VAPID Web Push.
2. **Open-Core Licensing (`ARCH-10`)**:
   - Commit `LICENSE` (**Apache-2.0**), `TRADEMARK_POLICY.md`, and update `TERMS_OF_SERVICE.md` for **CC BY-SA 4.0** community content portability.
