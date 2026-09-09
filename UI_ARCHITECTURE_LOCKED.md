# UI Architecture — LOCKED BASELINE

**Status:** Locked. **Version 1.3** — implementation baseline. **Architecture frozen; P0 may begin.**
**Supersedes:** the IA sections of `LEARNING_UI_PLAN.md` and `LEARNING_UI_RESEARCH.md`. Those documents remain valid for *study-mechanics* sprints (emoji, focus mode, batch size, recall-before-reveal); this document overrides them wherever they disagree about navigation, screen composition, or what appears on the home screen.
**Change control:** see [§14](#14-change-control).
**v1.1 changelog:** six amendments — recommendation policy de-escalated, retrieval bands renamed and re-scoped, Progress question broadened, gamification defaults split into presets, change control widened to four grounds, exclamation-mark rule scoped to urgency framing. See §1.4.
**v1.2 changelog:** five corrections — four internal contradictions resolved (lesson-rooted contexts, content-neutral Next-Action engine, nav-badge wording, context ordering) plus a verified correction to §6 after reading the actual algorithm. See §1.5.
**v1.3 changelog:** two corrections — the `ReviewOnly` dead end (a real defect, mirror of B2) and unspecified empty-catalog behaviour in the zero state. See §1.6. Plus five spec-hygiene fixes at freeze: §1.6.1.

---

## 0. Executive summary

One sentence:

> **You choose what you're learning. The app remembers where you are, makes continuing effortless, can recommend and schedule useful work, and never blocks direct choice. Complexity appears when you ask for it, not because the system possesses it.**

Three destinations: **Learn · Library · Progress**.
One switcher: **Learning Context**.
Two measurements, never merged: **structural completion** and **retrieval strength**.
One rule that overrides feature requests: **Direct Access Rule** (§7.3).

---

## 1. Where I agree and disagree

You asked me to say where I agree, disagree, and what the evidence actually supports. Doing that first, because the rest of the document is downstream of it.

### 1.1 Agree — and the evidence is solid

| Your position | My assessment | Evidence quality |
|---|---|---|
| "Co-regulated learning" is the wrong label | **Agree, strongly.** In the Hadwin/Järvelä/Winne tradition, *co-regulation* is an interpersonal transitional process — another agent temporarily shares regulation and then fades. *Socially shared regulation* is the group case. Neither describes a solo learner with a scheduling engine. Some recent HCI work does stretch "co-regulation" to human–AI pairs, but it is contested and not settled. Do not build the product's public justification on it. | High confidence on the definitional point |
| Correct label is **guided self-regulated learning with adaptive scaffolding** | **Agree.** This is defensible, boring, and accurate. Use it in the spec; use plain English in the product. | High |
| Gemini overstated "learners require a high locus of control" | **Agree.** The learner-control literature (Karich, Burns & Maki 2014 meta-analysis and related reviews) finds small effects, generally larger on motivation/satisfaction than on learning; effects vary by *what* is controlled (pacing and content-order control fare better than control over instructional method). Also relevant: the **expertise-reversal effect** (Kalyuga) — scaffolding that helps novices actively hurts more advanced learners. So the design principle is not "give control," it is **"give agency plus structure, and fade the structure as evidence accumulates."** | High for direction, medium for magnitude |
| Goal must **not** be mandatory | **Agree, and this is the single most important correction in your message.** A mandatory Goal→Path→Course→Module→Lesson chain is a data-model decision masquerading as a UX decision, and it breaks "I'm taking BIO 101" and "I imported 40 flashcards" on day one. §4 solves this with an optional hierarchy plus a `LearningContext` pointer. | N/A — product judgment, and correct |
| Rename "Goal Switcher" → **Learning Context Switcher** | **Agree.** This is the mechanism that resolves clutter-vs-agency. It is also the only new persistent chrome I will accept on Learn. | N/A |
| Progressive disclosure over Gemini's always-visible lesson rows | **Agree, with one mitigation** — see §1.2(c). Progressive disclosure is a 30-year-old, well-validated application-design guideline (Nielsen): show the few important options, defer the rest, and make the path to the deferred set obvious and well-labelled. | High |
| Split **structural progress** from **knowledge state** | **Agree, emphatically.** "100% complete / 55% retained" is not a contradiction and the UI must never launder one into the other. This is §6. | High |
| Library is **not** "manual override" | **Agree.** Choosing your own content is a first-class behaviour. Naming it "override" would encode a paternalism we do not actually want. | N/A |
| "Two-Tap Override Guarantee" is a heuristic, not a law | **Agree.** Keep it, label it honestly, and make it *testable* — I've turned it into an automated test in §7.3 rather than a slogan. | N/A |
| Retrieval practice, spacing, immediate feedback, one objective per lesson | **Agree.** Practice testing and distributed practice are the two highest-utility techniques in Dunlosky et al. (2013); the testing effect (Roediger & Karpicke) and spacing effect (Cepeda et al.) are among the most replicated findings in learning science. This part of the ChatGPT list is the best-supported part. | Very high |
| Gamification stays but one layer down; no punitive FOMO | **Agree.** Meta-analytic evidence (e.g. Sailer & Homner 2020) shows small positive effects, highly moderated by design. Meanwhile Deci, Koestner & Ryan (1999) shows performance-contingent extrinsic rewards can undermine intrinsic motivation. A learner who is already intrinsically motivated is exactly the population where XP pressure is most likely to be counterproductive — hence **off-able** (§9). | Medium-high |

### 1.2 Disagree, or would change before locking

**(a) "Progress" as a permanent top-level tab is in mild tension with the whole thesis.**
The design's core claim is that metric-inspection is a distraction from learning. Giving metrics a permanent, always-visible tab invites exactly the checking behaviour we're removing from Learn.
**I am not overruling you** — a hidden Progress page is undiscoverable and people legitimately want it. **The compromise I am locking:** Progress stays as the third destination, but **the Progress tab may never display a badge, dot, count, or animation.** Nothing may pull the user into Progress. It is a room you walk into, never one you are summoned to. Same rule for Library.

**(b) The Learning Context switcher should not always render as a switcher.**
For a user with exactly one context — which is *most users for their first weeks* — a dropdown with one item is pure noise and implies the user has failed to add more.
**Locked rule:** `contexts.length <= 1` → render the context name as **plain, non-interactive title text**. `>= 2` → render as the switcher control. The switcher earns its place by being needed.

**(c) Collapse `Choose lesson` + `View course` into ONE secondary action.**
Your Continue card has one primary and *two* secondary actions. That is three decisions on the screen whose entire purpose is to reduce decisions, and the two secondaries overlap conceptually — "choose a lesson" and "view the course" are the same destination with different framing.
**Locked:** primary **Continue**, single secondary **Course outline**. The outline screen shows the module/lesson list *and* the course metadata, with any lesson directly tappable. One target, no ambiguity, and the Direct Access Rule is still satisfied in two actions.

**(d) Gemini's always-visible lesson rows had one real virtue we should not lose.**
Seeing `Lesson 6 ✓ / Lesson 7 ▶ / Lesson 8 ○` gives *sense of place* — a cheap, durable motivator ("I am 7 of 12 through this"). Pure progressive disclosure discards it.
**Mitigation, locked:** a single muted line of path orientation directly under the lesson title — `Flutter Path · State Management · Lesson 7 of 12`. One line of text, no rows, no widgets, no controls. It buys back the orientation at ~2% of the pixel cost.

**(e) Cut `Progress: On track`.**
"On track" implies a schedule and a deadline the app does not have. It is false precision dressed as reassurance, and it is the exact failure mode you correctly rejected in "87.3% mastery."
**Locked:** the Learn screen shows either a factual, actionable line (`4 concepts need reinforcement` — tappable, goes to a review) or **nothing at all**. No verdicts about the learner's trajectory.

**(f) Cut the `Good morning` greeting.**
Apply your own Rule 20: does it help the learner choose or perform the next action? No. It occupies the highest-value pixels on the screen. Warmth is delivered by the app being fast and by not nagging, not by a salutation.
**Locked:** no greeting. The first thing below the app bar is the primary action.

**(g) Both proposals under-specify the zero state, which is where learning apps actually fail.**
A first-run user has no context, no history, no recommendation, and every "Continue"-shaped design collapses into an empty box. §5.1.A specifies it explicitly and treats it as a first-class screen, not an edge case.

**(h) Do not ship a "Why?" explainer in v1.**
It is a good idea (rule 15) but it requires the recommendation engine to have real, trustworthy reasons. Shipping "Recommended because it's next in the course" behind a **Why?** button teaches users the explanations are worthless. **Locked:** the one-line rationale ships as static text only when a *non-trivial* reason exists (see §5.2 rationale table); the expandable **Why?** is deferred until the engine has multi-factor reasoning worth reading.

### 1.3 What I'm explicitly declaring "heuristic, not science"

Say these internally, never in marketing: the Direct Access Rule, "one primary CTA per state," the three-destination split, the precedence ordering in §5.2, and **every numeric cutoff in §6.1**. They are reasonable engineering judgments. They are not research findings, and no study produced those exact numbers.

### 1.4 Amendments accepted in v1.1

Six corrections were raised against v1.0. **All six are accepted**, and each fixed a real defect rather than a matter of taste. Recorded here so the reasoning survives.

| # | Amendment | Why it was right |
|---|---|---|
| **A1** | **Reviews no longer supersede the learner's current lesson.** The `dueCount >= 20` / `oldestDueAge > 7 days` promotion is deleted. | The sharpest catch. v1.0 wrote a paternalism ban in §8 and then violated it in §5.2: a learner who deliberately switches to Calculus II to study integration was answered with a Review button. "Not trapped" is not the same as "not countermanded" — spending the loudest affordance on contradicting an intent the user expressed two seconds ago is exactly the failure §8 forbids. The `20` and `7` were invented, not measured. |
| **A2** | **Retrieval bands renamed and re-scoped.** `needsWork/developing/strong/secure` → `needsReinforcement/developing/wellRetained/wellEstablished`; the model is explicitly labelled *retrieval-history classification, not validated mastery*, and its cutoffs are listed as heuristics in the appendix. | Correct and slightly embarrassing: v1.0 spent a section attacking "87.3% mastery" as false precision, then called someone's knowledge **secure** on the strength of an SM-2 scheduling counter. Repetition level records *when we plan to ask again*, not evidence of durable understanding. Bands were the right idea; the labels overclaimed. |
| **A3** | **Progress answers "How am I progressing?"** not "What do I actually know?" | The old question was narrower than the screen it described — Progress also holds completion, activity and XP. Knowledge stays section 1; the question now matches the contents. |
| **A4** | **Gamification defaults split into Minimal / Standard presets**, with streaks and daily goals opt-in. | v1.0 argued that extrinsic mechanics carry mixed evidence and may backfire for intrinsically motivated learners, then defaulted all five to on. Genuine internal inconsistency. See §9.1 for the resolution, and for why a default is still not a contradiction. |
| **A5** | **Change control widened from one ground to four:** user evidence, implementation evidence, accessibility/safety, or demonstrated factual error. | v1.0's rule would have required a real user to be harmed before we could fix an accessibility violation, an impossible data-model assumption, or a misread citation. The intent — stop argument-driven churn — is preserved; the loophole against obvious defects is closed. A2 is itself proof the "factual error" ground is necessary: it corrected a locked section with zero users. |
| **A6** | **Exclamation marks banned in urgency/debt/loss framing only**, not globally. | `"6 OVERDUE!!!"` is the harm. `"Course complete!"` after a finished certification is not. v1.0 wrote a lint rule where it meant a tone rule. |

One v1.0 rule flagged as worth protecting from future drift, now restated explicitly in §7.2: **wider displays get more whitespace, not more widgets.** Desktop layouts habitually fill space because the pixels exist; that habit would dismantle this design.

### 1.5 Corrections in v1.2

Four **internal contradictions** — places where two parts of v1.1 could not both be true — plus one correction forced by reading the code. None are new design opinions. All accepted.

| # | Contradiction | Resolution |
|---|---|---|
| **B1** | §4.2 omitted `lesson` from `ContextRootType`, but §5.4 promised "any item can be turned into a Learning Context." Library lists individual lessons. | **`lesson` added to the enum** (§4.2). Manufacturing a synthetic course so that a standalone lesson has a legal parent is precisely the fake-hierarchy problem §4 exists to prevent. **Concepts remain excluded** — they are measurement atoms, not destinations. |
| **B2** | §4.1 and the §12 ship gate both guarantee a bare StudySet works, but every `NextAction` in §5.2 was lesson-shaped. A new 40-card set has no lesson, no next lesson, and no due reviews — it would have fallen through to `ContextComplete` on first open. | **Engine made content-neutral** (§5.2): `ResumeActivity` / `StartActivity` carry a `LearningActivity` payload that names its own kind. `ResumePointer` restructured to match. This was the most serious defect — a ship-gate item that could not pass. |
| **B3** | §3 said "no destination may show a badge, dot, or count," while §5.4 renders `Courses 7 · Lessons 48 · Study sets 12` inside Library. | **Wording corrected** to scope the ban to *top-level navigation destination controls*. The rule was always about nagging chrome, never about informational counts on a screen the user deliberately opened. §12 uses the same wording. |
| **B4** | `LearningContext.sortOrder` ("manual override") vs §5.1C "ordered by `lastActiveAt` desc." Undefined behaviour after a user pins Spanish. | **Explicit composite rule** (§5.1C): pinned contexts (`sortOrder >= 0`) first, ascending; the rest by `lastActiveAt` desc. `sortOrder` is kept — Settings already promises course priority ordering, so deliberate priority will be needed. |

**B5 — correction under the implementation-evidence ground (§14).** v1.1 §6 claimed retrieval strength draws on "SM-2 repetition level, ease, recency, retrieval accuracy, hint independence," and called P4 a pure display layer. I read the code. Both halves were wrong, and in opposite directions:

- `computeMastery()` in `lib/providers/lesson_progress_provider.dart` uses **`repetitionLevel` alone** — `min(level, 6) / 6`, averaged. Ease, recency and accuracy are never consulted.
- `ReviewableItem` (`lib/models/spaced_repetition.dart`) **does** persist `easeFactor`, `lastReviewedAt`, `totalReviews` and `correctReviews` (with an `accuracy` getter). So three of the five inputs are available but unused — cheap to add.
- **Hint independence is not collected anywhere in the codebase.** Every `hint` match in `lib/` is a `hintText` on a `TextField`. It was aspirational, and is now removed from §6 rather than described as an input.
- **Second defect GPT's review did not catch:** §6.1's confidence tiers require retrievals "across ≥2 sessions" / "≥3 sessions," but `ReviewableItem` stores only a single `lastReviewedAt` timestamp. There is no review log and no session grouping, so **session count is not computable from the current schema.** The tiers are restated in terms of data that exists.
- Also noted for P4: `DifficultyCategory.mastered` exists in `spaced_repetition.dart` and violates the A2 language ban. It must not reach the UI.

This is exactly what the implementation-evidence ground was added for in A5, used once, on its second day.

### 1.6 Corrections in v1.3

A third review raised two "areas to monitor." One is a real defect and is fixed; the other was aimed at the wrong target but exposed a genuine gap next to it.

| # | Finding | Resolution |
|---|---|---|
| **C1** | **The `ReviewOnly` dead end.** A learner who finishes a course keeps hitting case 5 (`ReviewOnly`) and never reaches case 6 (`ContextComplete`), so the "what's next" offer stays hidden. | **Accepted — a real defect, and structurally the same bug as B2.** Worse than the review stated: in a spaced-repetition system `dueCount > 0` is the *steady state*, not a transient one. Reviews regenerate forever, so for a completed course case 6 is not merely delayed — it is **effectively unreachable**, and the exit from a finished context would never appear at all. Fixed by decoupling the forward-progress offer from `dueCount` (§5.2). |
| **C2** | **Zero-state friction** — the two-option first run leans entirely on Library discoverability, and a sparse catalog would feel like a dead end. | **Partly accepted.** The two-option zero state is correct and stays (§1.2g). But the review found the edge of a real gap: v1.2 never specified what `Browse courses` does when the catalog is **empty**. That is an unhandled dead end, not a friction concern. Fixed in §5.1A. |

**The general principle both C1 and B2 are instances of, now stated once so it stops recurring:**

> **No screen state may be reachable-but-terminal.** Every state the engine can produce must offer at least one forward action that is not "do the same thing again." A state that is technically correct but from which the learner cannot progress is a defect, whether it arises from a missing enum case (B2), a precedence order that starves a branch (C1), or an empty data set (C2).

The review also stated that P0 and P1 "require zero visual changes until fully wired." That is true of P0 only; P1 deletes `HomeScreen` and replaces the entire home surface. See §11 for the corrected framing of which phase carries the real risk.

#### 1.6.1 Freeze cleanup

Five items found in a final read-through. Three were editorial drift; two were real decisions that had been left implicit.

| # | Item | Fix |
|---|---|---|
| **D1** | Header still read v1.2 while the document carried a v1.3 changelog | Header corrected |
| **D2** | Appendix still cited the "2–3 sessions" confidence cutoffs that B5 had already removed as uncomputable | Appendix row restated in the terms §6.1 actually uses |
| **D3** | §6's summary table said the v1 source is "`repetitionLevel` only," which describes `computeMastery()` but not the displayed `RetrievalState` — whose confidence draws on four fields | Row split into **Band** and **Confidence**. `computeMastery()` remains single-input; the table now describes the rendered state |
| **D4** | `goal` was a runtime `ContextRootType` while §4.3 defers the Goal entity and P1 requires a test per `rootType` — an untestable enum case | **`goal` removed from the enum.** Goal stays in the conceptual hierarchy (§4.1) and returns as a root type when the entity exists. Shipping infrastructure for a model that does not exist is the kind of speculative generality §2 rejects |
| **D5** | `ResumePointer.activityId` could hold a `reviewBatchId`, but no `ReviewBatch` was ever defined | **Review sessions are not resumable in v1.** `ActivityKind` narrowed to `ResumableKind { lesson, studySet }`. Justified on semantics, not convenience — see §4.2 |

**With these applied the architecture is frozen.** Further change requires one of the four §14 grounds. "A different design is also defensible" is not one of them.

---

## 2. Locked philosophy

Five statements. Everything below is derived from these. If a future feature contradicts one, the feature is wrong.

1. **The learner sets intent and destination. The system reduces friction in sequencing and execution.**
2. **Complex intelligence, simple experience.** The system may model 50 variables and show 3.
3. **Every screen answers one question first.** Learn: *what should I do next?* Library: *what exists and what do I want?* Progress: *how am I progressing?*
4. **No recommendation may trap the learner** (§7.3).
5. **Complexity appears when requested, not because the system possesses it.**

**The one test for every future UI feature:**

> Does seeing this *right now* help the learner choose or perform the next learning action?
> **Yes** → it may appear on Learn. **Useful but not now** → Library or Progress. **Makes the product look feature-rich** → it does not ship.

---

## 3. Locked information architecture

```
┌─ App shell (persistent) ────────────────────────────────────┐
│  Mobile: bottom NavigationBar (3)                           │
│  Desktop/tablet ≥900dp: NavigationRail (3), extended ≥1200dp│
│                                                             │
│   ●  Learn        ○  Library        ○  Progress             │
└─────────────────────────────────────────────────────────────┘
```

| Destination | Answers | Contains |
|---|---|---|
| **Learn** | "What do I do next?" | Learning Context switcher, one primary action, conditional review prompt, one line of orientation. Nothing else. |
| **Library** | "What exists? What do I want?" | Your Learning (contexts, paths, courses, lessons, study sets), Discover (catalog, search, filters, categories), Create (study set, lesson, import), Pinned/Recent. |
| **Progress** | "How am I progressing?" | Retention, structural completion, activity, motivation metrics — in that order. Progressively disclosed. |

**Not top-level destinations** (and this is a change from today's `Lessons | Courses | Study Sets` tabs): Lessons, Courses, Study Sets, Careers, Skills, Create, Search. These are *content types and actions*, not *intentions*. They all live inside Library.

**Settings** is reached from the app bar (mobile: overflow; desktop: rail footer). It is not a destination because it is not a learning intention.

**Locked chrome rules:**
- **No top-level navigation destination control may display a badge, dot, count, animation, or other attention indicator.** (Scoped in B3: this governs the `NavigationBar` / `NavigationRail` items only. Informational counts *inside* Library or Progress are fine — the user opened that screen deliberately. The rule bans summoning, not information.)
- The app bar on Learn contains: context switcher (conditionally, §1.2b) + overflow menu. Nothing else. No `LevelBadge`, no `DailyGoalRing`, no `StreakBadge`, no `ReviewBadge`.
- `SyncStatusIndicator` and `GlobalVoiceIndicator` render **only when not in the idle/nominal state.** Silent when healthy.

---

## 4. Locked data model — hierarchical but optional

### 4.1 The hierarchy

```
Goal          (optional)   e.g. "Career: Software Engineering"
 └─ Path      (optional)   e.g. "Flutter Developer"
     └─ Course            e.g. "Dart Fundamentals"        ← the only required container
         └─ Module        (optional)  e.g. "State Management"
             └─ Lesson
                 └─ Concept / Skill   ← the atom of measurement

StudySet  ──────────────► Concepts        (orthogonal, not inside the tree)
```

Every level except **Course**, **Lesson** and **Concept** is nullable. A course with no path and no goal is a first-class citizen. So is a study set with no course.

Valid shapes, all of which must work without inventing a fake parent:

| Learner says | Shape |
|---|---|
| "I want to be a software engineer" | Goal → Path → Course → Module → Lesson |
| "I want to learn Calculus" | Course → Lesson |
| "I'm taking BIO 101" | Course → Module → Lesson |
| "I imported this textbook" | Course (auto-created) → Module per chapter → Lesson |
| "I want to study these 40 flashcards" | StudySet → Concepts (no course at all) |

### 4.2 `LearningContext` — the new central abstraction

This is the piece neither prior proposal had, and it is what makes the optional hierarchy actually implementable. A **Learning Context** is a user-level pointer to *a thing they are pursuing*, regardless of which level of the tree that thing lives at.

```dart
/// Concepts are deliberately absent: they are measurement atoms, not destinations.
/// `goal` is absent until a Goal entity exists — see §4.3 (D4).
enum ContextRootType { path, course, module, lesson, studySet }

class LearningContext {
  final String id;
  final String userId;
  final String label;          // user-editable: "Software Engineering", "Spanish 1"
  final ContextRootType rootType;
  final String rootId;         // FK into the corresponding table
  final String? emoji;
  final DateTime lastActiveAt; // drives switcher ordering
  final bool isArchived;
  final int sortOrder;         // >= 0 pins the context; -1 = unpinned (§5.1C)
}
```

```dart
/// Only kinds that can be meaningfully resumed. Review sessions are excluded —
/// see D5: a due-set is a query result, not a persistable object.
enum ResumableKind { lesson, studySet }

class ResumePointer {         // one per context
  final String contextId;
  final ResumableKind kind;
  final String activityId;    // lessonId | studySetId
  final int? itemIndex;       // position inside the activity
  final String? courseId;     // breadcrumb only — may be null (B1, B2)
  final String? moduleId;     // breadcrumb only — may be null
  final DateTime updatedAt;
}
```

The breadcrumb fields exist **only** to render the orientation line in §5.1B. They are never required, and nothing in the engine may branch on their presence — that was the coupling that made a bare study set unrepresentable in v1.1.

**Review sessions are not resumable in v1 (D5 — locked).** Exiting a review rebuilds the batch from current due state on re-entry. This is not merely the simpler option: a review batch is a *query over items that are due right now*, and answering items mutates that set. Persisting a batch would replay items that have since left the due window and pin a stale index over a shifting list — so rebuilding is the semantically correct behaviour, not a shortcut. Answered items are already durably recorded on `ReviewableItem`, so no work is lost. A persisted `ReviewSession` is deferred to §13.

**Consequences (all locked):**
- The context switcher lists `LearningContext` rows. It does not care that one is a career path and another is a bare study set.
- "Add something" in the switcher creates a `LearningContext` around whatever the user picked or created in Library.
- Archiving a context removes it from the switcher without deleting content. This is how a user with 12 subjects avoids a 12-item dropdown.
- The Learn screen reads exactly two things: the active `LearningContext` and its `ResumePointer`.

### 4.3 Mapping onto what already exists

| Locked concept | Existing code | Work required |
|---|---|---|
| Goal | *(none)* | Conceptual layer only in v1 — **not** a `ContextRootType` (D4). Optional grouping over `CareerPath`. A nullable `goalId` on path is enough; no Goal model, no Goal UI, no Goal context root until there is a real entity to point at. |
| Path | `CareerPath` — `lib/models/career_path.dart` | Rename in UI copy only ("Path"). No schema change. |
| Course | `Course` — `lib/models/course_models.dart` | None. |
| Module | `LessonSeries` — `lib/models/course_models.dart` (has `courseId`, `seriesOrder`) | Rename in UI copy to "Module". Keep optional. No schema change. |
| Lesson | `Lesson` — `lib/models/lesson.dart` | None. |
| Concept | `Concept` — `lib/models/concept.dart` | Currently a JSON array on the lesson rather than a joined child. Acceptable for v1; promote to a real relation when concept-level analytics land in Progress. |
| StudySet | existing study-set screens/models | None. |
| **LearningContext** | **does not exist** | **New model + Hive adapter + Supabase table + provider.** This is the main new build. |
| **ResumePointer** | partially covered by `lessonLastStudiedProvider` and the continue-hero logic | **New**, per-context. |

Hive type IDs: use **10** for `LearningContext`, **11** for `ResumePointer`. (Verified free per `/memories/repo/flutter_app_patterns.md`; ids 7 and 10–19 are unused. Update `lib/core/hive_type_ids.dart` in the same commit.)

---

## 5. Locked screen specifications

### 5.1 LEARN

Content column is **max 720dp wide, centred**. This is a doing screen, not a dashboard; do not let it fill a 27" monitor.

#### A. Zero state (no contexts)

```
┌──────────────────────────────────────────┐
│  Learn                              ⋯    │
├──────────────────────────────────────────┤
│                                          │
│   What do you want to learn?             │
│                                          │
│   ┌────────────────────────────────┐     │
│   │  Browse courses            →   │     │
│   ├────────────────────────────────┤     │
│   │  Import or create content  →   │     │
│   └────────────────────────────────┘     │
│                                          │
└──────────────────────────────────────────┘
```
Two options. No carousel, no featured grid, no onboarding quiz, no "popular this week". Both routes land in Library and, on selection, create a `LearningContext` and return the user to Learn.

**Neither option may terminate in an empty screen (C2 — locked).**

- **First run seeds the bundled asset lessons** (`assets/lessons/`, currently six) so the catalog is never empty on a fresh install. `Browse courses` always has something to show.
- If the catalog is nevertheless empty — filtered to nothing, offline with no cache, or a future build shipping no seed content — the options **swap emphasis**: `Import or create content` becomes primary and `Browse courses` is demoted, with a plain one-line reason. The screen never presents a route to nowhere as the recommended path.
- Library's own empty-catalog state must itself offer create/import. A dead end one level down is still a dead end.

#### B. Active state (the screen 95% of sessions see)

```
┌──────────────────────────────────────────┐
│  Software Engineering  ▾            ⋯    │   ← switcher (plain text if 1 context)
├──────────────────────────────────────────┤
│                                          │
│  Continue                                │   ← section label, muted, small
│                                          │
│  ┌────────────────────────────────────┐  │
│  │  Provider Basics                   │  │   ← headline, largest text on screen
│  │  Flutter Path · State Management   │  │   ← orientation line, muted (§1.2d)
│  │  · Lesson 7 of 12 · ~11 min        │  │
│  │                                    │  │
│  │  You're ready for this lesson.     │  │   ← rationale, only if non-trivial
│  │                                    │  │
│  │  ┌──────────┐                      │  │
│  │  │ Continue │   Course outline     │  │   ← ONE primary, ONE secondary
│  │  └──────────┘                      │  │
│  └────────────────────────────────────┘  │
│                                          │
│  ─────────────────────────────────────   │
│                                          │
│  6 concepts ready for review · ~4 min    │   ← conditional; absent if 0
│  [ Review ]                              │
│                                          │
└──────────────────────────────────────────┘
```

That is the entire viewport. Anything not in that diagram does not appear on Learn.

**The same layout serves non-lesson contexts unchanged** (B2) — only the payload differs, and the orientation line collapses when there are no breadcrumbs:

```
  Continue                              Continue
  Spanish Verbs                         Big-O Notation
  Study set · 40 cards · ~6 min         Lesson · ~8 min
  [ Practice ]   Browse set             [ Start ]   View lesson
```

A `studySet` or `lesson` root renders one line of metadata instead of `Path · Module · Lesson n of m`, because there is no hierarchy to report — not because anything is missing. The secondary action adapts to the activity kind; there is still exactly one primary and one secondary.

**Explicitly absent from Learn, permanently:** XP today, XP this week, XP-to-next-level, level meter, rank/Bronze, daily-minutes ring, streak counter, mastery charts, search field, category/language filter chips, Create button, course catalog, subject cards, empty-state review card, "on track" verdicts, greeting.

#### C. Context switcher

Trigger: app bar title. Opens a menu (mobile: bottom sheet; desktop: dropdown).

```
Your learning
  📱  Software Engineering        · today
  🇪🇸  Spanish                     · 2 days ago
  📐  Calculus II                  · last week
  ☁️  AWS Certification            · 3 weeks ago
─────────────────────────────────
  Browse all learning            → Library
  + Add something                → Library › Discover
```

- **Ordering (B4, locked):** pinned contexts first — those with `sortOrder >= 0`, ascending by `sortOrder` — then all remaining contexts by `lastActiveAt` desc. Pinning is a deliberate act; recency is the fallback, never an override of it.
- **Max 5 rows**; overflow folds into "Browse all learning". Pinned contexts occupy those rows first.
- Selecting a context switches Learn instantly and persists `defaultContextId`.
- Archived contexts never appear here.

### 5.2 The Next-Action engine (locked precedence)

`Learn` renders whatever this returns. Evaluate top-down; first match wins.

```dart
/// What the learner would actually do. The engine never branches on this;
/// it selects an activity and the UI renders whatever kind came back.
sealed class LearningActivity {
  Duration get estimate;
  String get title;
}
class LessonActivity   extends LearningActivity { final String lessonId; }
class StudySetActivity extends LearningActivity { final String studySetId; }
class ReviewActivity   extends LearningActivity { final List<String> conceptIds; }

sealed class NextAction {}
class ChooseSomething   extends NextAction {}                              // zero state
class ResumeActivity    extends NextAction { LearningActivity a; int i; }  // partially done
class ReinforceConcepts extends NextAction { ReviewActivity a; }           // targeted remediation
class StartActivity     extends NextAction { LearningActivity a; }         // next available
class ReviewOnly        extends NextAction { ReviewActivity a; }           // nothing left but reviews
class ContextComplete   extends NextAction {}                              // nothing left at all
```

| # | Condition | Primary action | Rationale line shown |
|---|---|---|---|
| 1 | No non-archived contexts | `ChooseSomething` | — |
| 2 | `ResumePointer` has `0 < itemIndex < itemCount` | `ResumeActivity` | "Picking up where you left off." |
| 3 | Last activity's post-check accuracy `< 0.6` on ≥3 concepts | `ReinforceConcepts` | "You missed these last time." |
| 4 | The context yields a next available activity | `StartActivity` | *(none — trivial reason, stays silent per §1.2h)* |
| 5 | No activity remains **and** `dueCount > 0` | `ReviewOnly` — "Review 23 concepts · ~9 min" **+ the §5.2.1 offer as secondary** | "You've finished the material here." |
| 6 | No activity remains, nothing due | `ContextComplete` — the §5.2.1 offer as primary | "You've finished this course." |

#### 5.2.1 The context-exhausted offer (C1 — locked)

> **The forward-progress offer is a function of context exhaustion, never of `dueCount`.**

When a context has no remaining activity, the app always surfaces a way onward — the next course in the path if one exists, otherwise switch context or browse. Cases 5 and 6 differ **only in which slot that offer occupies**: secondary in case 5 (review is legitimately primary, because there genuinely is nothing else *in this context* to do), primary in case 6.

Why this is not cosmetic: reviews regenerate indefinitely, so `dueCount > 0` is a completed context's **steady state**. Gating the offer behind `dueCount == 0` would have hidden the exit from every finished course essentially forever — a learner who abandons a course but leaves the context active would face a permanent wall of reviews with no visible way out. That is the trap §7.3 exists to prevent, reintroduced through precedence ordering rather than through navigation.

**Resolving "next available activity" (case 4), per `rootType`** — this is the whole of B2:

| `rootType` | Next activity |
|---|---|
| `path` · `course` · `module` | Next unlocked `LessonActivity` in sequence |
| `lesson` | The lesson itself, while unfinished |
| `studySet` | A `StudySetActivity` over: due items first, then unseen items, else the full set |

**Study sets never complete.** Practice material is repeatable by nature, so a `studySet` context yields a valid `StartActivity` indefinitely and case 6 is unreachable for it. That is what makes the §12 bare-study-set guarantee actually pass — in v1.1 it could not.

**The review-supersession rule (amended A1 — locked):**

> **Reviews are strongly surfaced. They do not replace the learner's forward progress.** Review becomes the primary action only when there is no activity to continue (case 5), or when the learner has explicitly opted into a review-first policy. There is no backlog size at which the app overrides an intent the learner just expressed.

The general form, and the reason the thresholds are gone: **the learner's most recent explicit choice outranks any system recommendation.** Switching context, opening the course outline, and picking a lesson are all explicit choices. The engine adapts to them; it does not argue with them.

**Secondary review prompt:** rendered below the primary **iff** `dueCount > 0` and the primary is not case 5. It states the count plainly — `6 concepts ready for review · ~4 min` — and its **emphasis does not scale with backlog size**. 300 due items look exactly like 6 due items, only with a larger number. If `dueCount == 0` the entire section, divider included, is removed from the tree. No empty card, ever.

*(Deferred to §13: a `reviewEmphasis` preference — balanced / prioritise reviews / prioritise new material. That is the correct mechanism for review-first behaviour: a learner policy, not a system threshold.)*

**Copy rules (locked):** `"6 ready"`, never `"6 overdue!"`. No red. No urgency, debt, or loss framing. No "don't lose your streak". No countdowns. No expiring rewards. (Exclamation marks are governed by §9.2, not banned outright.)

### 5.3 Course outline (the single secondary destination)

Reached from **Course outline** on the Continue card, and from Library.

```
Dart Fundamentals                    63% complete
Flutter Path

▾ State Management
    ✓  Ephemeral vs App State
    ▶  Provider Basics              ← current
    ○  Riverpod Overview
    ○  Architecture Patterns
▸ Navigation
▸ Testing
```

- Every unlocked lesson is directly tappable. This is what satisfies the Direct Access Rule.
- Modules are collapsible; the module containing the current lesson is expanded, the rest collapsed.
- Locked lessons (`🔒`) show a one-line reason on tap. **Locking must be rare** — prerequisites only, never as artificial pacing.
- The `63% complete` figure is **structural only** (§6). Retrieval strength does not appear on this screen.

### 5.4 LIBRARY

The screen where complexity is *invited*. Higher information density is correct here.

```
Library                                    [ 🔍 Search ]

  Your Learning
    ▸ Contexts        4      ▸ Paths          2
    ▸ Courses         7      ▸ Lessons       48
    ▸ Study sets     12      ▸ Pinned         5
    ▸ Recent

  Discover
    [ Categories ] [ Languages ] [ Difficulty ] [ Duration ]
    ...results grid...

  Create
    + Study set    + Lesson    ↑ Import
```

- Search and all filter chips live here and **only** here.
- Create lives here and **only** here. It is a normal-weight button, not the loudest element on the screen.
- Absorbs today's `Lessons | Courses | Study Sets` tabs plus `/careers`, `/my-careers`, `/course-management`, `/lesson-selection`, `/content-picker`.
- Any **path, course, module, lesson or study set** can be turned into a Learning Context via a "Start learning this" action — matching `ContextRootType` exactly (B1). Concepts cannot; they are measurement atoms, not destinations.

### 5.5 PROGRESS

Answers **"How am I progressing?"** (A3). Deliberately richer. Also deliberately un-advertised (§1.2a).

Order is not arbitrary — retention first, motivation last, because that is the order of honesty:

1. **Retention** *(default expanded)* — concept counts by §6.1 band for the active context; retention trend; a tappable "needs reinforcement" list that starts a targeted review.
2. **Completion** *(collapsed)* — per course/path structural %, lessons completed.
3. **Activity** *(collapsed)* — study time, sessions, days active.
4. **Motivation** *(collapsed; hidden entirely under the Minimal preset)* — XP, level, streak, achievements.

Progressive disclosure applies *within* Progress too. Sections 2–4 are collapsed accordions on first visit; expansion state persists per user.

### 5.6 Study / lesson screen

The lesson does not get busier than the screen that launched it.

- One objective per lesson, stated once at the top.
- Retrieval before reveal. Immediate, informative feedback. Hints that degrade rather than reveal.
- Chrome during study: progress-within-lesson indicator + exit. That is all. No XP tickers, no streak, no timer ring.
- XP/celebration, if enabled, appears **only** on the session summary — never mid-item, where it competes with feedback the learner should be reading.

### 5.7 SETTINGS

Customise **behaviour**, not layout. No drag-and-drop dashboard builder — that offloads design onto the user and guarantees an incoherent product.

**Learning**
- Default learning context
- Session length preference (items per session — wires up the existing unused `SettingsModel.studyBatchSize`)
- Review intensity: light / standard / thorough
- Course priority ordering

**Home**
- Show review prompt on Learn *(default on)*
- Show reinforcement line on Learn *(default on)*
- Density: comfortable / compact

**Motivation** — chosen once by a single onboarding question (§9.1), adjustable per-mechanic at any time
- XP · Levels · Streaks · Celebrations · Daily goal

With everything off, the learner gets exactly: *Continue · Course outline · Review*. With everything on they get levels and celebrations. **One learning engine, two skins.** No forked codepaths.

---

## 6. Two measurements, never merged

| | **Structural progress** | **Retrieval strength** |
|---|---|---|
| Question | "How far through this have you gone?" | "What does your retrieval history suggest you're holding on to?" |
| Unit | Path / Course / Module | Concept / Skill |
| Source | lessons completed ÷ lessons total | **Band:** `repetitionLevel`. **Confidence:** `totalReviews`, `lastReviewedAt`, `accuracy`, `repetitionLevel`. See §6.2 — `computeMastery()` itself stays single-input |
| Display | **percentage** — `63% complete` | **band + confidence** — never a percentage |
| Where | Course outline, Library, Progress §2 | Progress §1, targeted-review prompts |

`Course 100% complete` alongside `Concepts: mostly developing` is a **valid, expected, and important** state. The UI must be capable of showing it and must never smooth it over.

### 6.1 Retrieval bands (amended A2 — heuristic, not validated)

> **Scope declaration, binding on all copy:** this model classifies **retrieval history**. It is not a validated measure of mastery, understanding, or transfer. An SM-2 repetition level encodes *when we intend to ask again* — a scheduling artefact that correlates with retention rather than measuring it. Every band name below is therefore a claim about **retention**, never about knowing. Rejecting `87.3% mastery` and then shipping `secure` would have been the same error in a smaller font.

```dart
/// Classification of retrieval history. NOT a mastery measurement.
enum RetrievalBand { needsReinforcement, developing, wellRetained, wellEstablished }
enum Confidence    { low, medium, high }   // our confidence in the classification

class RetrievalState {
  final RetrievalBand band;
  final Confidence confidence;   // f(totalReviews, accuracy, recency) — see §6.1
  final int evidenceCount;       // == ReviewableItem.totalReviews
}
```

**Every cutoff below is an engineering heuristic chosen for v1.** No study produced these numbers. They are listed as heuristic in the appendix and are expected to move once we have retention data.

| Band | SM-2 level (existing `repetitionLevel`, capped at 6) | Learner-facing copy |
|---|---|---|
| `needsReinforcement` | 0–1 | Needs reinforcement |
| `developing` | 2–3 | Developing |
| `wellRetained` | 4–5 | Well retained |
| `wellEstablished` | 6 | Well established |

| Confidence | Condition *(heuristic, and computable from today's schema — B5)* |
|---|---|
| `low` | `totalReviews < 3`, **or** `lastReviewedAt` is null or older than 60 days |
| `medium` | `totalReviews` 3–5, reviewed within 60 days |
| `high` | `totalReviews >= 6` **and** `accuracy >= 0.8` **and** `repetitionLevel >= 4` |

> **Why not "across ≥3 sessions"** (B5): `ReviewableItem` stores a single `lastReviewedAt` timestamp, with no review log and no session grouping, so session counts are **not computable** from the current schema. v1.1 specified a tier the database cannot answer. `repetitionLevel >= 4` is used instead as the long-interval proxy — a defensible substitute, since the level only ever increments on a successful recall and levels 4+ sit at long intervals. True session counting needs a `review_log` table; deferred to §13.

Copy is always band + confidence: **"Well retained · high confidence"**. Never a percentage. Never the words *mastered*, *secure*, *knows*, or *learned*.

### 6.2 What the algorithm actually does today (B5 — verified in code)

v1.1 described §6 as a pure display layer over an algorithm that already weighed five inputs. It does not. Corrected:

| Input | Status |
|---|---|
| `repetitionLevel` | **Used.** `computeMastery()` is `min(level, 6) / 6`, averaged across items. That is the entire algorithm. |
| `easeFactor` | Persisted on `ReviewableItem`, **not used** |
| `lastReviewedAt` (recency) | Persisted, **not used** by `computeMastery()` |
| `accuracy` (`correctReviews / totalReviews`) | Persisted with a getter, **not used** |
| Hint independence | **Not collected anywhere.** No hint instrumentation exists; every `hint` in `lib/` is a `hintText` on a `TextField` |

Consequences, locked:

- **P4 ships bands over the existing single-input algorithm.** Display-layer only, as originally scoped. Honest, and shippable now.
- Ease, recency and accuracy are **available but unused** — folding them in is a small, well-scoped follow-up, not a research project. Deferred to §13 as a weighted model.
- Hint independence requires **new instrumentation** before it can be an input. Removed from §6 rather than left as an aspiration dressed as a spec.
- `DifficultyCategory.mastered` in `lib/models/spaced_repetition.dart` violates the A2 language ban. It may remain as an internal identifier but **must not reach any user-facing string**; P4 adds the mapping to §6.1 copy.

The raw double stays internal and is never rendered.

**Path to a real knowledge model** (deferred, §13): transfer evidence — the same concept retrieved through a *different* question format — is the first upgrade that would justify stronger language. Until then these bands describe behaviour, not understanding.

---

## 7. Interaction laws

### 7.1 Visual hierarchy
- **Exactly one primary CTA per screen state.** Filled button, accent colour.
- Secondary actions are text buttons. Tertiary is muted body text.
- Accent colour is reserved for the primary action and for genuine state. Not for decoration, not for "this is clickable."
- Whitespace is intentional. Do not fill it.
- Typographic ramp on Learn: lesson title `headlineSmall` → orientation `bodySmall` muted → rationale `bodyMedium` muted. The learner's eye must land on the lesson title first, every time.

### 7.2 Responsive
| Width | Nav | Learn content |
|---|---|---|
| `< 600dp` | bottom `NavigationBar` | full width, 16dp gutters |
| `600–899dp` | bottom `NavigationBar` | centred, max 560dp |
| `900–1199dp` | `NavigationRail` (icons) | centred, max 720dp |
| `≥ 1200dp` | `NavigationRail` (extended) | centred, max 720dp |

A wider window gets **more whitespace, not more widgets.** Library is the only destination that adds columns with width. This rule exists because desktop layouts habitually fill space simply because the pixels are there — doing that here would reassemble the dashboard this architecture removed.

### 7.3 The Direct Access Rule (locked, and tested)

> **No recommendation may trap the learner.** From Learn, in **≤ 2 deliberate actions**, the learner must be able to reach (a) a different active learning context, (b) any other available lesson in the current course, or (c) unrestricted browse/search.

| Escape | Path | Actions |
|---|---|---|
| Different subject | Context switcher → Spanish | 2 |
| Different lesson | Course outline → Lesson 11 | 2 |
| Anything else | Library → search | 2 |

**This is enforced by an automated widget test**, not by good intentions:

```
test/widgets/direct_access_rule_test.dart
  ✓ from Learn, ≤2 taps reaches an alternate LearningContext
  ✓ from Learn, ≤2 taps reaches an arbitrary unlocked lesson
  ✓ from Learn, ≤2 taps reaches Library search
```

If a future design change breaks one of these, the build fails. That is the point.

---

## 8. Recommendation ethics

Because personalised systems can end up performing the learner's regulation *for* them rather than developing it — an emerging concern in the SRL literature, and the failure mode you correctly flagged:

1. The system **recommends and schedules**. It never removes the ability to choose.
2. **The learner's most recent explicit choice outranks any system recommendation.** No backlog, streak, schedule, or score may promote itself over an intent the learner just expressed. This is what §5.2 enforces, and why the review-supersession thresholds were deleted (A1).
3. Locking is prerequisite-based only. Never used to enforce pacing, drive engagement, or manufacture progression.
4. Scaffolding **fades**: as `RetrievalState.confidence` rises for a context, rationale lines and prompts reduce. (Expertise-reversal effect — support that helps a novice hurts an expert.)
5. When the learner overrides a recommendation, the app accepts it silently. No "are you sure?", no warning, no scolding.
6. Reasons are shown only when non-trivial (§1.2h). We do not train users to ignore our explanations.

---

## 9. Gamification policy

- **Location:** Progress §4 and the session summary. Never on Learn, never in the app bar, never mid-lesson.
- **Permitted:** XP, levels, streaks, milestone celebrations, optional daily goal.
- **Forbidden:** red overdue counters, "you'll lose your streak", expiring rewards, multiple simultaneous currencies, quest/task stacks, notification badges on nav destinations, guilt copy.
- **Never** may a motivation metric be positioned so as to imply knowledge. 5,000 XP does not mean you know more than someone with 3,000.
- Time goals are a habit tool, not the definition of success. Someone who learns efficiently in 8 minutes has not failed a 15-minute ring — so the ring does not exist on Learn.

### 9.1 Defaults (amended A4 — locked)

One question at onboarding. Not five toggles.

```
Would you like motivational features?

  ( ) Minimal    Quiet. Completion confirmation only.
  (•) Standard   XP, levels and celebrations in Progress.
```

| Mechanic | Minimal | Standard | Notes |
|---|---|---|---|
| Completion confirmation (subtle) | **on** | **on** | Not removable — this is feedback, not a reward |
| XP | off | **on** | Progress §4 and session summary only |
| Levels | off | **on** | Progress §4 only; never "prominent" anywhere |
| Streaks | off | **off — opt-in** | Loss framing; must be chosen deliberately |
| Daily goal | off | **off — opt-in** | Loss framing; must be chosen deliberately |

Skipping the question yields **Standard**. Per-mechanic toggles remain in Settings; the preset just sets them in one action.

**Why a default is still consistent with §2** — the objection A4 raised, answered: the calm guarantee is enforced *structurally* by §5.1, not by the preset. **No motivation mechanic renders on Learn, in the app bar, or mid-lesson under any preset.** A preset only decides what appears in Progress §4 and on the session summary — two places the learner has already chosen to look. So Standard-by-default costs nothing on the surfaces this philosophy is about, whereas off-by-default XP would simply be dead code for most users.

Streaks and daily goals are the exception because they are the two mechanics that manufacture **debt** — something you can lose by not showing up. Debt framing must be opted into, never assigned.

### 9.2 Exclamation marks (amended A6 — locked)

The rule is about **tone**, not punctuation.

| Context | Rule | Example |
|---|---|---|
| Urgency, debt, loss, nagging, overdue | **Forbidden** | "6 overdue!" · "Don't lose your 12-day streak!" |
| Neutral state and counts | **Forbidden** | "6 ready!" → `6 ready` |
| Genuine milestone, celebrations enabled | **Permitted, sparingly** | `Course complete!` · `Path finished!` |

At most one exclamation mark per screen, only on a real achievement, and never on a recurring event — a daily completion is not a milestone.

---

## 10. Migration map — what moves where

| Today | Destination |
|---|---|
| `HomeScreen` 3-tab TabBar (`Lessons`/`Courses`/`Study Sets`) — `lib/screens/home_screen.dart` | **Deleted.** Replaced by app shell + `LearnScreen`; the three tabs become sections of Library. |
| `LevelBadge` (app bar) | Progress §4 |
| `DailyGoalRing` (app bar) | Progress §3; hidden when daily goal is off |
| `StreakBadge` (app bar) | Progress §4 |
| `ReviewBadge` (app bar) | **Deleted.** Replaced by the conditional review section on Learn. |
| `HomeSearchBar` — `lib/screens/home/` | Library only |
| `HomeCategoryFilters` | Library › Discover only |
| `ContinueLearningHero` | Rewritten as the Continue card; now context-scoped and driven by `NextAction` |
| `ReviewDueCard` | Kept, but renders **only** when `dueCount > 0`; no empty state |
| `HomeLessonsList` | Library › Your Learning › Lessons |
| Create buttons on home | Library › Create |
| `GlobalVoiceIndicator`, `SyncStatusIndicator` | Retained; **render only in non-nominal state** |
| `/careers`, `/my-careers`, `/course-management`, `/lesson-selection`, `/content-picker` | Reachable from Library; removed from top-level nav |
| `/progress` (`ProgressDashboardScreen`) | Becomes the Progress destination, restructured per §5.5 |

New routes: `/learn` (default), `/library`, `/progress`, `/course/:courseId/outline`.
`/` redirects to `/learn`. All existing deep-link routes keep working.

---

## 11. Implementation phases

Each phase ships independently and leaves the app usable.

**P0 — Shell + context model** *(foundation; the only phase with no visible change — and the highest-risk phase in the plan)*
- `LearningContext` + `ResumePointer` models, Hive adapters (ids 10/11), `lib/core/hive_type_ids.dart` update, Supabase migration.
- `learningContextsProvider`, `activeLearningContextProvider`, `resumePointerProvider`.
- Backfill: create one context per enrolled career path / started course / used study set.
- `AppShell` with `NavigationBar` / `NavigationRail`; `ShellRoute` in `lib/providers/router_provider.dart`.

**P0 risk register** — verified against the code, and the reason P0 rather than P4 is the hard phase:

| Risk | Detail |
|---|---|
| **Hive typeId landmine** | Adapter registration in `lib/services/hive_service.dart` is guarded by `Hive.isAdapterRegistered(HiveTypeIds.x)`, and `hive_type_ids.dart` has been wrong before. Id 3 is already double-claimed — the custom `ConceptAdapter` is registered there while `question.g.dart` also claims 3 unregistered. Ids 10/11 must be added to the registry **and** the guard in the same commit. A wrong id corrupts existing boxes. |
| **Async global redirect vs `ShellRoute`** | The router runs an `async` redirect awaiting `hasCompletedOnboarding()` on **every** navigation, across 29 flat routes with no shell today. Introducing a shell (and per-destination state) while keeping that redirect and all existing deep links is the sharpest integration point in the phase. |
| **Backfill idempotency** | The migration must not duplicate contexts when re-run, when a second device syncs, or when Hive and Supabase disagree. This is the **only irreversible step in the entire plan** — every other phase is UI and revertible. |
| **Sync surface** | A new synced entity lands amid existing offline/sync tests (`offline_provider_test`, `sync_provider_test`, `progress_sync_service_test`). Offline-created contexts need conflict resolution before P1 depends on them. |

By contrast **P4 is now the easiest phase**, which is counterintuitive: after B5 de-escalated it to a display layer over a single-input algorithm, it is a mapping function and a copy change.

**P1 — Learn**
- `NextActionEngine` (§5.2) + unit tests covering all 6 precedence cases **for each `rootType`**, including a bare study set and a bare lesson (B1, B2).
- `LearnScreen`, `ContinueCard`, `ContextSwitcher`, conditional `ReviewPrompt`.
- Strip the app bar. Delete `HomeScreen`.
- `test/widgets/direct_access_rule_test.dart` (§7.3).

**P2 — Library + Course outline**
- `LibraryScreen` absorbing the three old tabs, search, filters, create.
- `CourseOutlineScreen` with direct lesson access.
- "Start learning this" → creates a `LearningContext`.

**P3 — Progress**
- Restructure `ProgressDashboardScreen` into the four collapsible sections.
- Relocate `LevelBadge` / `DailyGoalRing` / `StreakBadge` here.

**P4 — Retrieval strength**
- `RetrievalState` band+confidence (§6.1) over the existing **single-input** SM-2 algorithm — display layer only, per §6.2 (B5).
- Map `DifficultyCategory` to §6.1 copy so `mastered` never reaches a user-facing string.
- Remove every remaining mastery-as-percentage rendering.
- Targeted "needs reinforcement" review entry point.

**P5 — Settings**
- Learning / Home / Motivation preference groups; the §9.1 onboarding question; wire `studyBatchSize`.
- Verify: Minimal preset ⇒ zero gamification surface anywhere; every preset ⇒ zero gamification on Learn.

---

## 12. Acceptance checklist

Ship gate. Every box must be checked.

- [ ] Learn renders **≤ 5 interactive elements** in the default active state.
- [ ] Learn shows **exactly one** filled/primary button.
- [ ] `dueCount == 0` ⇒ no review section, no divider, no placeholder in the widget tree.
- [ ] No XP / level / streak / rank / daily-ring widget exists anywhere on Learn or in its app bar.
- [ ] No search field or filter chip exists on Learn.
- [ ] No Create button exists on Learn.
- [ ] Context switcher renders as plain text when `contexts.length <= 1`.
- [ ] **No top-level navigation destination control displays a badge, dot, count, animation, or attention indicator** (B3). Informational counts inside Library/Progress are permitted.
- [ ] `direct_access_rule_test.dart` passes all three cases.
- [ ] Retrieval strength is never rendered as a percentage anywhere in the app.
- [ ] No band label uses "mastered", "secure", "knows", or "learned" (A2).
- [ ] Structural completion is never labelled "mastery", "known", or "learned".
- [ ] **Review is never the primary action while an unfinished or unstarted lesson remains in the active context** (A1). Unit-tested across all six §5.2 cases.
- [ ] Review prompt emphasis is identical at `dueCount = 6` and `dueCount = 300`.
- [ ] **Under every preset, zero motivation mechanics render on Learn, in the app bar, or mid-lesson** (A4).
- [ ] Streaks and daily goals are off until explicitly enabled.
- [ ] All motivation mechanics off ⇒ no gamification pixels remain.
- [ ] A learner with a bare StudySet and no course can reach Learn and get a valid primary action (B2).
- [ ] A `lesson`-rooted context resolves to a valid primary action without a synthetic parent course (B1).
- [ ] `ContextComplete` is unreachable for a `studySet`-rooted context (B2).
- [ ] **A context with all material complete and reviews perpetually due still surfaces the forward-progress offer** (C1).
- [ ] **No engine state is reachable-but-terminal** — every `NextAction` offers a forward action that is not a repeat of itself (§1.6).
- [ ] Zero state never routes to an empty screen; emphasis swaps when the catalog is empty (C2).
- [ ] Switcher ordering: pinned (`sortOrder >= 0`) ascending, then `lastActiveAt` desc (B4).
- [ ] No user-facing string derives from `DifficultyCategory.mastered` (B5).
- [ ] A learner with 12 contexts sees ≤5 switcher rows plus "Browse all learning".
- [ ] Zero state offers exactly two options.
- [ ] No copy contains "overdue", "don't lose", or "expires".
- [ ] No exclamation mark appears outside a genuine milestone with celebrations enabled (A6, §9.2).

---

## 13. Deliberately deferred

Not rejected — out of scope for v1, and not to be smuggled in.

- Goal layer UI — the entity, plus `goal` as a `ContextRootType` (D4). A nullable `goalId` on path is sufficient for now
- **Persisted `ReviewSession`** — resumable half-finished review batches (D5). Requires deciding how a stored batch reconciles with a due-set that has since changed
- Expandable **Why?** recommendation explainer (§1.2h)
- **`reviewEmphasis` preference** — balanced / prioritise reviews / prioritise new material. The correct mechanism for review-first behaviour (A1): a learner policy, not a system threshold. Ships when we have data on real backlog behaviour.
- Cross-context interleaving
- **Weighted retrieval model** — fold `easeFactor`, recency and `accuracy` into `computeMastery()`. All three are already persisted; this is a small follow-up, not a research project (B5).
- **`review_log` table** — prerequisite for genuine session-count confidence tiers (B5).
- **Hint instrumentation** — prerequisite before hint independence can be a retrieval input at all (B5).
- Transfer-based retrieval evidence — the same concept via different question formats. Prerequisite for any language stronger than §6.1 permits.
- Social / sharing / leaderboards
- AI tutor chat inside a lesson
- Density preference beyond comfortable/compact

---

## 14. Change control

*(Amended A5 — v1.0's single-ground rule was too absolute.)*

> **Locked sections may change only on one of four grounds: user evidence, implementation evidence, an accessibility/safety/privacy requirement, or a demonstrated factual error. Never on preference or argument alone.**

| Ground | Means | Example |
|---|---|---|
| **User evidence** | Observed behaviour — a real user, session, or metric | Learners cannot find Library search |
| **Implementation evidence** | The design is infeasible or costs unacceptable performance | Context switcher requires an N+1 query per frame |
| **Accessibility / safety / privacy** | WCAG, screen-reader, contrast, motion, or data-handling defect | Muted orientation line fails contrast at AA |
| **Demonstrated factual error** | A cited claim is misread, or a stated mechanism does not exist | The v1.1 amendments — all six qualified, with zero users |

What is **not** a ground: "I've been thinking about it", a competitor's redesign, a new model's opinion, or a more persuasive argument for the same trade-off we already made deliberately.

To propose a change:
1. State which locked section it violates.
2. Name the ground and give the specific evidence. Not a hypothetical.
3. State which of the five principles in §2 justifies the change.
4. Bump this document's version and record the reason in the changelog.

**Absent all four, the answer is no.**

---

### Appendix — evidence confidence

| Claim | Confidence | Basis |
|---|---|---|
| Retrieval practice and spacing improve durable retention | **Very high** | Roediger & Karpicke (2006); Cepeda et al. (2006); Dunlosky et al. (2013) rate both "high utility" |
| Immediate informative feedback beats delayed correctness-only | **High** | Feedback meta-analyses (Hattie & Timperley 2007 and successors) |
| Learner control: small effects, larger on motivation than learning; varies by control type | **Medium-high** | Karich, Burns & Maki (2014) and related reviews |
| Scaffolding must fade as expertise grows | **High** | Expertise-reversal effect (Kalyuga et al.) |
| Progressive disclosure improves learnability, efficiency, error rate | **High** | Nielsen; 30+ years of application-design practice |
| Gamification: small positive effect, heavily design-moderated | **Medium** | Sailer & Homner (2020) meta-analysis |
| Contingent extrinsic rewards can undermine intrinsic motivation | **Medium-high** | Deci, Koestner & Ryan (1999) |
| "Co-regulated learning" is interpersonal, not human–system | **High** (definitional) | Hadwin, Järvelä & Miller; contested extensions in recent HCI work |
| Personalised systems can offload regulation rather than build it | **Emerging** | Recent SRL/AIED commentary; treat as a design caution, not a finding |
| SM-2 repetition level is a *scheduling* signal, not a mastery measurement | **High** (definitional) | It encodes when to ask again; any mapping to "knowledge" is inference. Basis for A2 |
| Direct Access Rule · one-CTA rule · 3-destination split · §5.2 precedence order | **Heuristic** | Our design judgment |
| **§6.1 band cutoffs (0–1 / 2–3 / 4–5 / 6)** | **Heuristic** | Chosen for v1. No study produced these boundaries |
| **§6.1 confidence cutoffs (`totalReviews` 3/6, 60-day recency, 0.8 accuracy, `repetitionLevel >= 4`)** | **Heuristic** | Reasonable engineering defaults, computable from today's schema. Expected to move once retention data exists |
| Minimal/Standard preset composition (§9.1) | **Heuristic** | Informed by the reward/motivation evidence above; the specific split is judgment |
