# LearningApp — Companion to External Resources (Path C)

## Implementation Plan — v1.0 (proposed, 2026-11-25)

**Status:** accepted by the owner 2026-11-25 ("Start EX-0"). EX-0 is done (§8.1). No learner-facing feature is built yet.
**Baseline:** `origin/main` at `d4a62a60`, 173 migrations.
**Relation to other plans:** this plan expands Path C of the master plan v2.6 (§9) and §12 of the ingestion plan v1.2. It changes no decision in either. Their binding constraints apply here unchanged: one owner with AI doing the building and reviewing, zero spend, honest labels, append-only migrations through the guarded deploy path, default-OFF feature switches with real server gates, no feature removal, three navigation destinations.

---

## 1. Summary

LearningApp has three ways to serve a learner: its own content (Path A), ingested open content (Path B), and content that stays outside the app (Path C). Path C exists today only in a narrow form. This plan makes it a full product mode.

**The one idea the plan rests on:** the unit of companionship is the **objective of the learner's goal**, not the outside resource. LearningApp does not need to see, host or parse a video, course or book to be useful beside it. It needs to know which objectives of the goal the resource is meant to cover. From that it can supply everything the resource lacks:

1. **Proof of readiness** (primary). Independent checks per objective, readiness by blueprint weight, and an honest statement of what the resource does not cover.
2. **Supplement** (secondary). Fill-in lessons, practice and worked examples where the resource is thin or silent.
3. **Structure and motivation** (third). The resource placed inside the path to a license, job, exam or degree, with a daily plan, a projected finish and a return point.

**Recommended order of work:**

- First, "bring your own resource" on the existing PWA, which works on every device with no install (EX-1 to EX-4).
- Second, the resource catalog and recommendations (EX-5).
- Third, device add-ons in order of reach per unit of effort: Android share target, an in-app player for embeddable video, a floating check window on desktop, then a browser extension (EX-6 to EX-9).

The extension comes last on purpose. Section 5 explains why it is the smallest part of the answer, not the main one.

---

## 2. What exists today, and the gap

Verified in the repository:

| Capability | Where | State |
|---|---|---|
| Link record, focus note, independent checks (levels 0–2) | `lib/models/learning_support/external_companion.dart`, `content/companions/` (12 files) | Live; `content.external_companion` ON |
| Learner picks the depth | `lib/providers/companion_depth_provider.dart` | Live, device-local |
| Bridge as fill-in lesson (level 3) | `content/bridges/` | Live |
| Ordered companion plan (level 4) | `lib/models/learning_support/companion_plan.dart`, `content/companion_plans/` (3 plans) | Live; ticks are device-local and never count |
| Weekly dead-link check | `.github/workflows/external-link-check.yml` | Live |
| Readiness by objective, coverage gate, projected finish | ingestion plan §8.5–§8.7 | Live for College Algebra, Prealgebra, Excel |
| Objective-to-source mapping with review | `data/concept_mappings/`, `tool/verify_concept_mappings.py` | One mapping (CLEP College Algebra to OpenStax) |
| Source and opportunity research files | `data/research/` | Seeded |
| Companion prompt for the learner's own AI chat | master plan Appendix A.7 | Written, provisional |

**The gap.** Every companion today is authored by the maintainer, bundled in the build, hangs off a Bridge, and points at OpenStax. A learner cannot say "I am taking this course" or "I am watching this playlist". So today:

| Need | Missing |
|---|---|
| Any resource | A learner cannot add their own video, course, book or class |
| Readiness | Outside study does not connect to the goal's readiness view. The learner cannot see "this course covers 60% of the exam" |
| Supplement | Fill-ins exist only where a Bridge was hand-written for that companion |
| Structure | Outside study is not in the daily plan or the projected finish |
| Recommendation | No catalog of outside resources, no quality or cost comparison |
| Devices | No capture from other apps, no in-app player, no side-by-side layout, no extension |
| Sync | Companion state is device-local only, so it does not follow the learner from phone to laptop |

---

## 3. Product model

### 3.1 The companion loop

Every outside resource, on every device, goes through the same loop. Each step works without the others.

| Step | What the learner sees | Engine reused |
|---|---|---|
| **Place** | "This course covers these parts of your goal. It does not cover these." | Blueprint weights, Coverage Matrix |
| **Before** | Optional short diagnostic: "You already know sections 2 and 3. Start at 4." | Scoped diagnostic sessions (EXM-03) |
| **During** | For each section: what to look for, in LearningApp's words. Notes. A check at the end of the section. | Companion focus notes, scratchpad |
| **After** | Independent checks on the objectives just studied. Key terms enter spaced review. | Held-out checks, FSRS queue |
| **Fill** | "The course skips percent format in spreadsheets. Here is a 6-minute lesson." | Bridges, lessons, parametric practice, manual AI generation |
| **Goal** | Readiness by objective and a projected finish that include the outside study time | Objective readiness view, readiness projection |

### 3.2 Evidence rules (unchanged, restated because the whole mode depends on them)

- LearningApp cannot observe study that happens outside it. "I finished section 3" is **self-report**. It schedules the check and moves the plan forward. It never counts as mastery or readiness.
- Only LearningApp's own independent checks count toward readiness, under the existing rules (6 held-out checks per objective, coverage gate at 60% of blueprint weight).
- Checks are written independently of the resource. They are never copied from a course's quizzes or a book's exercises.
- Where LearningApp has no checks for an objective, the readiness view says "not yet available", with the outside resource shown as the way to study it. It is never shown as done or as zero.

### 3.3 Three kinds of resource record

| Kind | Who creates it | Visible to | Review |
|---|---|---|---|
| **Catalog resource** | Maintainer (AI-authored, independent AI review) | Everyone | `reviewer_kind` recorded and shown |
| **Learner resource** | The learner ("I'm using this") | Only that learner | None needed; it is private |
| **Nominated resource** | A learner proposes their resource for the catalog | Moderators, then everyone | Existing contribution moderation |

A learner resource needs only a title. A link, a kind (video, course, book, class, podcast, other), and the access cost are optional. This is what "support any and all content" means in practice: a paper textbook or an evening class is a valid resource.

### 3.4 Mapping a resource to objectives

The mapping is the hard part. It is a ladder, and every rung works with zero cost:

| Rung | How | Quality | Cost |
|---|---|---|---|
| 0. No mapping | The learner studies outside and uses the goal's checks and readiness view directly | Goal-level only | None |
| 1. Learner ticks | The learner ticks which objectives the resource covers, from the goal's list | Coarse, honest | None |
| 2. Outline match | The learner pastes the table of contents or syllabus. The Reuse Gate's word-overlap matcher proposes objectives per section; the learner confirms | Section-level, unverified | None (on device) |
| 3. Learner's own AI | Prompt pack A.7: the learner pastes the outline into their own AI chat and pastes back a structured map, which is validated like any generated slot | Section-level, AI-labelled | None to the operator |
| 4. Reviewed catalog map | Maintainer-authored, independently AI-reviewed, in `data/resource_maps/`, checked in CI like `data/concept_mappings/` | Section-level with depth and confidence | Maintainer time |

Rungs 2 and 3 use only what the learner pastes. LearningApp fetches nothing. Rung 4 uses public facts only (titles, section names, durations, stated outcomes).

Every map records, per objective: the resource section or time range, the depth (introduces, teaches, practises), whether the resource has practice, and confidence. "Teaches but has no practice" is the trigger for a supplement.

### 3.5 Recommendations

The learner's benefit is the only ranking input. A catalog resource is scored for one goal at a time on:

| Factor | Measure |
|---|---|
| Coverage | Share of the goal's blueprint weight mapped at "teaches" or deeper |
| Authority and accuracy | Publisher type, review result, known errata |
| Practice | Whether the resource gives meaningful practice |
| Access cost | Free without sign-in, free with sign-in, paid. For paid: a price band and the date it was checked, never a live price |
| Time | Stated length against blueprint weight covered |
| Accessibility | Captions, transcript, language, reading level, works on a phone |
| Freshness | Edition or publish date against the goal's current blueprint |

Rules:

- For every goal the app shows the **best free route** first, then the best overall route with its cost stated. A paid resource is never shown without the free alternative beside it.
- LearningApp's own lessons and ingested lessons compete in the same list on the same factors. The app recommends an outside course over its own lesson when the outside course is better for that learner.
- No paid placement, ever. `marketing.affiliate_links` stays a separate switch, stays OFF, and is barred from the ranking code by a test. If the owner ever turns it on, the label says so on every link it touches.
- Every recommendation states why ("covers 82% of the exam, free, has practice, captions") and when it was last checked.
- High-stakes goals (licensing, health, safety, legal) keep the ingestion plan's T3 rule: link-only, and no recommendation claim beyond what a person reviewed.

---

## 4. Research findings that shape the design

Checked on 2026-11-25. Sources are listed in §13. Items marked "to verify" were not confirmed and are assigned to EX-0.

| Finding | Consequence |
|---|---|
| iOS and iPadOS Safari do not support the Web Share Target API. The WebKit bug has been open since 2019 with no timeline. Android Chrome supports it for installed PWAs. | Capture from other apps is an Android add-on. iPhone and iPad use paste-a-link, plus an optional Apple Shortcut that opens the app with the link |
| Chrome on Android phones still has no extension support. Google's extension work targets desktop-style Android only. Firefox for Android has an open extension ecosystem. | An extension cannot be the phone answer. It reaches desktop browsers and Firefox on Android |
| Chrome's side panel API (`chrome.sidePanel`, Chrome 114+) and Firefox's `sidebar_action` are not compatible. | The extension is a thin shell around the web app, with two small manifests, not two products |
| Document Picture-in-Picture: Chrome and Edge desktop; Firefox from version 151 (May 2026); not Safari; not mobile. | A floating check-and-timer window is a desktop enhancement only |
| YouTube's developer policies forbid modifying, covering or blocking the embedded player, its controls, links or ads. Minimum player size 200×200. | The in-app player puts checks beside or below the video, never over it. Standard controls stay |
| YouTube `captions.download` needs edit permission on the video and costs 200 of the default 10,000 daily quota units. | No transcripts. Mapping uses titles, chapters and the learner's own input. No Data API key is needed for the pilot |
| Udemy closed its Affiliate API to new clients on 2025-01-01. Its remaining APIs serve instructors and business customers. | No provider catalog API can be assumed. The catalog is hand-curated research files, like `data/research/sources/` |
| Median MOOC completion was 12.6% across 221 courses (Jordan, 2015). Among learners who intended to finish, 19.5% did (Reich). | Structure and motivation are a real gap in outside courses, not a nice-to-have. But completion is not the goal; readiness is |
| Interpolated testing during video lectures improved learning in the original study (Szpunar et al., 2013). Later work found mixed effects on attention. | Section-end checks are justified by retrieval practice. The app makes no claim that they improve attention |
| Prequestions before authentic lecture videos showed limited benefit (Toftness et al.). | The "Before" diagnostic is offered to skip known material, not as a learning boost, and is optional |

**EX-0 results (2026-11-25).**

| Item | Result |
|---|---|
| Chrome Web Store fee | Confirmed: a one-time US$5 developer registration fee, required before the dashboard can be used at all. X-11 stays an owner decision |
| YouTube title lookup without a key | Confirmed by a direct request: the oEmbed endpoint answered a cross-origin request with title, author and thumbnail and no key. It is a third-party request from the learner's browser, so it runs only after the learner pastes a link and stays behind `content.learner_resources` |
| Safari extensions on iOS | No sidebar support found; popup support not confirmed. No effect: the Safari extension stays an unbuilt paid slot (X-12) |
| Coursera and edX catalog access | Both gate catalog access behind an application (Coursera: affiliates and partners; edX: a reviewed request). Sources for Coursera were unofficial and disagreed. Conclusion unchanged: the catalog is hand-curated |
| Khan Academy | Its terms limit use to personal, non-commercial use and bar distributing its content to third parties. Link-only; no embed assumed |
| Modern States | Free, self-paced, aligned to CLEP College Algebra, account needed, exam-fee voucher after its final exam at 75% or more. Its terms of service were not found, so it is link-only |
| Evidence register | `ER-11` added (MOOC completion, descriptive). Interpolated-testing studies were **not** registered: both primary sources refused automated access. Section-end checks rest on `ER-01` and the optional diagnostic on `ER-10` until those are read |

---

## 5. Device strategy

The question raised was how to be a capable companion on phones and tablets, where an extension does not reach. The answer is to treat the **web app as the companion on every device**, and to treat everything else as an optional shortcut into it.

### 5.1 Layers

| Layer | What it is | Phone | Tablet | Laptop / desktop | Cost |
|---|---|---|---|---|---|
| **L0 Bookend** | Open the resource in its own app or tab. LearningApp gives the brief before and the check after. A "Back to your plan" return point always shows. | Yes | Yes | Yes | None |
| **L1 Side-by-side** | A compact companion layout that stays usable in a narrow pane: iPad Split View or Slide Over, Android split screen, two desktop windows | Android split screen only; small | Yes, the main tablet mode | Yes | None |
| **L2 Capture** | Send a link from another app into LearningApp | Android: share sheet. iPhone: paste, or Apple Shortcut | Same split as phone | Paste, bookmarklet, extension | None |
| **L3 In-app player** | For embeddable video only: the player on top, the section brief and checks below | Yes, the main phone mode for such video | Yes | Yes | None |
| **L4 Floating window** | A small always-on-top window with the timer, the current focus note and the next check | No | No | Chrome, Edge, Firefox 151+ | None |
| **L5 Extension** | A side panel that shows the companion for the current tab | Firefox for Android only | No | Chrome, Edge, Firefox | See §5.4 |
| **L6 Native wrapper** | Store apps with native share and picture-in-picture | — | — | — | Paid developer accounts; **extension slot, not built** |

### 5.2 Phones

A phone shows one thing at a time, so the phone companion is built around **moments**, not a second pane:

- **Before:** a one-screen brief (what this section is for, what to look for, 15 to 40 minutes).
- **During:** nothing on screen. An optional reminder at the planned end time through the existing study-reminder web push.
- **After:** the learner returns (from the reminder, the home-screen icon or the share sheet) straight into the check for that section.
- **Embeddable video** plays inside the app (L3), so the brief, the video and the check are one screen and no app switching is needed.

### 5.3 Tablets

Tablets are the best side-by-side device and need no new technology, only layout work. The companion route must stay fully usable at about 320dp wide: one column, large targets, no navigation rail, the section list collapsed to a stepper. The ≥900dp rail rule is unaffected because the companion pane is narrow by definition; the Help control stays in the top right.

### 5.4 The extension, scoped

The extension is a convenience for desktop study. It is deliberately thin:

- It contains almost no logic. The side panel loads the web app's compact companion route.
- It uses `activeTab` only. It reads the current tab's address when the learner clicks the button, and nothing else. No content scripts, no page reading, no history, no background tracking. This keeps the store review simple and the privacy promise short.
- If the address matches a resource the learner has, the panel opens that resource's companion. If not, it offers "Add this as a resource".
- Order: Firefox (desktop and Android; listing is free), then Chrome and Edge. The Chrome Web Store charges a one-time US$5 developer registration fee (confirmed in EX-0). Under the zero-cost rule that is an owner decision. Until then the Chrome build ships as a documented manual install for testers only.
- Safari extensions need a paid Apple developer account. Extension slot; not built.

### 5.5 What the companion never does

- No scraping of pages, transcripts, quizzes or answer banks.
- No reading of what the learner does on another site, in any layer.
- No capture of signed-in sessions.
- No server-side fetch of a learner's link (see §7.3).
- No automatic "completed" from watch time, even in the in-app player. Playing a video is not evidence.

---

## 6. Learner experience

Navigation stays Learn, Library, Progress. No new destination, and no badge on a destination.

| Place | Addition |
|---|---|
| **Learn** | Next Action can be an outside step: "Watch section 4 (about 25 min), then a 5-minute check". The daily plan counts its time estimate |
| **Library** | "Add something you're using" in the Create chooser. On a goal: a "Ways to study this" list (LearningApp, open textbook, outside) with the §3.5 reasons |
| **Target detail** | "Your resources for this goal", each with its coverage of the blueprint. One combined view: covered by a resource, covered by LearningApp, not covered by anything yet |
| **Progress** | Readiness by objective already exists. Each objective gains a quiet source line ("studied in: <resource>") and the self-reported / checked distinction |
| **Companion route** | `/companion/<resource>`: the stepper of sections, each with brief, open, done-studying, check, fill-in. Compact layout by default under 600dp |

Copy rules, carried from the existing companion screens: "Open (leaves LearningApp)" on every outside link; the access label on every resource; "studied" and "checked" are different words everywhere; AI-reviewed is never shown as person-reviewed.

Guests can use everything on one device. Signing in adds sync across devices, which matters more here than elsewhere because the usual pattern is video on one device and checks on another.

---

## 7. Architecture

### 7.1 Principles

- One objective identity. Resource maps point at the same objective and concept IDs as lessons, Bridges and held-out checks. No second taxonomy, no second progress ledger.
- Catalog data lives in the repository first (`data/`, validated in CI) and moves to the database only when its shape is stable, as the research files did.
- Learner data is private by RLS, exportable and deletable, and never enters analytics.

### 7.2 Data

**Repository (no migration):**

- `data/external_resources/<id>.yaml` — catalog resource: publisher, title, kind, link, edition or publish date, access, price band with as-of date, language, accessibility facts, rights posture (`link_only` by default), embed permission, `last_checked_at`, `reviewer_kind`.
- `data/resource_maps/<target>__<resource>.yaml` — per objective: sections or time ranges, depth, has-practice, confidence, plus the review record. Same shape and checker pattern as `data/concept_mappings/`.
- `tool/verify_external_resources.py` in CI: schema, https links, access and price-band rules, map objectives exist in the target manifest, review present, no ranking field that could carry a paid placement.
- The existing link check covers the new files.

**Database (additive migrations, guarded deploy):**

| Table | Holds | Access |
|---|---|---|
| `learner_external_resources` | The learner's resources: title, kind, optional link, optional catalog ID, goal | Owner only |
| `learner_resource_sections` | The learner's outline and their confirmed objective map (rungs 1–3) | Owner only |
| `learner_resource_progress` | Self-reported "studied" per section, with time; resume point | Owner only |
| `external_resource_nominations` | A learner's proposal to add a resource to the catalog; reuses the contribution moderation states | Owner and moderators |

No table stores anything read from an outside site. Self-report rows are a new evidence tier that the readiness functions ignore by construction; a database test asserts that no readiness or coverage function reads `learner_resource_progress`.

Guests use the same shapes in device-local storage, moved to the account on sign-in. EX-1 confirms whether an existing guest-to-account path can carry this or a small one is needed.

### 7.3 Privacy and security

- A learner's list of resources shows what they are studying and why. It is personal data: private, in the data export, erased with the account.
- Links are normalized on the device before saving: https only, tracking parameters removed, known redirectors refused.
- A link arriving by share, Shortcut or extension travels in the URL **fragment** of the hash-routed app, so it never reaches the server or its logs until the learner saves it.
- The server never fetches a learner-supplied link. That removes server-side request forgery, cost and terms-of-service risk in one decision. Titles are typed, pasted, or filled from the catalog match.
- The in-app player loads a third party. It uses the provider's privacy-enhanced embed, loads only after the learner taps play, and sits behind its own switch. The production CSP gains exactly one `frame-src` entry; test it on a preview channel, because only a release build served there enforces the real CSP.
- Pasted outlines are text. They are length-capped, rendered as text only, and treated as untrusted input to the matcher and to any prompt.
- Nominations go through moderation before anything is public, with the DMCA policy unchanged.

### 7.4 Feature controls

`content.external_companion` (ON) keeps covering the bundled companions. New keys, each seeded OFF, each with a server gate at its write boundary and a bypass test:

| Key | Covers | OFF behaviour |
|---|---|---|
| `content.learner_resources` | Adding, mapping and tracking the learner's own resources; companion route | Bundled companions and plans work as today; saved data is kept |
| `content.resource_recommendations` | Catalog list and "Ways to study this" ranking | Goals show LearningApp content only |
| `content.companion_capture` | Share target, Shortcut and bookmarklet entry | Paste-a-link still works |
| `content.companion_embeds` | In-app third-party player | "Open (leaves LearningApp)" |
| `content.companion_extension` | The route and handshake the extension uses | Extension shows "not available" |

All five are no-cost features. None is a paid extension slot. The native wrappers and the Safari extension are the paid slots and get keys only if they are ever built.

### 7.5 Code placement

Following `AGENTS.md`: models in `lib/models/companion/`, services in `lib/services/companion/`, providers in `lib/providers/`, widgets in `lib/widgets/companion/`, the route screen in `lib/screens/companion/`. The existing `learning_support` companion files stay where they are; the new mode reads them, it does not move them. Add a "Companion to external resources" section to `docs/engineering/CODEBASE_MAP.md` in the first PR that adds an owner. The extension gets its own top-level `extension/` folder, created only when EX-9 starts.

---

## 8. Work packages

Each package is one or a few PRs, lands behind its switch, and is verified as a guest and signed in, on phone width, tablet split width and desktop.

| ID | Package | Delivers | Depends on |
|---|---|---|---|
| **EX-0** | Verification and contracts | Confirm the "to verify" items (§4, §5.4); evidence-register entries; schemas for resources and maps; pilot selection (§9); CODEBASE_MAP section | — |
| **EX-1** | Outside study on a goal (rung 0–1) | "I'm studying this elsewhere" on a target; learner resources; tick objectives; "studied" self-report; checks and readiness by objective reachable from the resource; `content.learner_resources` | EX-0 |
| **EX-2** | Coverage and gaps | The combined coverage view; "not covered by your course"; fill-in routing to existing lessons, Bridges, parametric practice, Wanted Board and the prompt cart | EX-1 |
| **EX-3** | Outline mapping (rungs 2–3) | Paste an outline; on-device matching; confirm screen; A.7 prompt pack round trip with validation | EX-1 |
| **EX-4** | Plan and motivation | Outside steps in Next Action and the daily plan; time estimates in the projected finish; resume point; reminder at planned end; compact companion route for split view (L0, L1) | EX-1 |
| **EX-5** | Catalog and recommendations | `data/external_resources/`, `data/resource_maps/`, CI checker; "Ways to study this"; best free route rule; ranking-isolation test; nominations; `content.resource_recommendations` | EX-0; first maps from §9 |
| **EX-6** | Capture (L2) | `share_target` in `web/manifest.json` (Android); fragment-based add route; bookmarklet; published Apple Shortcut; `content.companion_capture` | EX-1 |
| **EX-7** | In-app player (L3) | Compliant embed for one provider; brief above, checks below; time-range pointers; CSP change; `content.companion_embeds` | EX-4 |
| **EX-8** | Floating window (L4) | Document Picture-in-Picture companion on supporting desktop browsers, hidden elsewhere | EX-4 |
| **EX-9** | Extension (L5) | Thin side-panel shell; Firefox first; Chrome build pending the fee decision; `content.companion_extension` | EX-4, EX-6 |
| **EX-10** | Evaluation | Descriptive outcome report (§10) through the existing consented analytics, with small-group suppression | EX-1 to EX-5 |

### 8.1 Status

| Package | Status |
|---|---|
| EX-0 | **Done 2026-11-25.** Verification results in §4. Contracts: `data/external_resources/` and `data/resource_maps/` with `tool/verify_external_resources.py` in CI (21 tests). Pilot P1 selected and seeded (§9). `ER-11` registered. The CODEBASE_MAP section came with EX-1. The catalog checker was planned for EX-5 and was brought forward so the schemas are enforced from the first file; EX-5 keeps the app-side list, ranking and the dead-link check for catalog links |
| EX-1 | **Built 2026-11-25 (#423); switch `content.learner_resources` switched on by migration `20261125040000` (owner-approved 2026-11-25).** **Live 2026-11-25:** both migrations deployed through the guarded tool (production 175/175), web build of main `a07d800a` checked on a preview channel as a guest against production and promoted to live (bundle hash matches the build). The signed-in path was verified on the local stack and by production privilege checks, not by a real production sign-in. Migration `20261125030000`: tables `learner_external_resources` and `learner_resource_objectives` (owner-only, removed with the account), four server functions, every write gated; reading and deleting your own rows never depend on the switch. App: "Studying somewhere else?" card on a goal, add or edit dialog (name, kind, optional https link cleaned on the device, cost), and a resource screen where the learner ticks what it covers, marks parts Studied and sees LearningApp's own check status beside each objective. Guests keep resources on the device; a signed-in learner is offered a one-tap move, never a silent one. A database test asserts that no other function reads the two tables, so self-report cannot reach readiness. **Changed from the plan:** objectives are keyed by code (title where a node has no code) so ticks survive a new version; the outline table is left to EX-3; the companion screen is opened from the goal, and its own route comes with EX-4/EX-6 when deep links need it. "Check yourself" opens the goal outline; per-objective check launch is EX-2. The CODEBASE_MAP section is added; its cap was raised to 260 lines / 21 KiB and one stale line removed |
| EX-2 | **Built 2026-11-25; no new switch or migration** (it sits behind `content.learner_resources` and reads only data the learner can already see). On a goal with at least one resource the card shows a three-way split that always adds to 100%: in what you use, not in what you use but LearningApp has lessons, not covered by anything. "See the gaps" lists the objectives nothing of the learner's covers, with "Open the LearningApp lesson" where one exists and "Make my own version" / "Ask for it" where none does, and names what is studied outside but has no independent check and so cannot count toward readiness. On a resource, each covered objective with a LearningApp lesson gets its own button, worded "Check" only when independent checks exist and "Practise" otherwise. If LearningApp's Coverage Matrix can't be read, only the outside half is shown and the screen says so. **Not built from the plan's list:** direct routing to a Bridge or to parametric practice (both are reached from inside the lesson today), and marking outside coverage in the existing "What's here for this goal" chips |
| EX-3 | **Built 2026-11-25; no new switch** (it sits behind `content.learner_resources`). **Live 2026-11-25 (#427):** migration deployed through the guarded tool from `main` `1ca09a8a` (production 176/176); web build of the same tree checked on the preview channel as a guest against production, then promoted to live (bundle hash matches the build). On production the signed-in path was verified by privilege checks (owner-only read, no direct writes, guests refused on the table and the function, no other function reads the table), not by a real production sign-in. A follow-up stops a pasted line that already starts with a number from being numbered twice; it ships with the next web release. Migration `20261125050000`: table `learner_resource_sections` (owner-only, removed with the resource and the account) and one gated write, `set_learner_resource_sections`, which replaces the outline, checks every objective key against the goal and ticks the confirmed objectives as covered. It never marks anything studied, and a database test asserts no other function reads the table. App: "Paste its outline to tick faster" on a resource opens a screen where the learner pastes a table of contents (one part per line; bullets, video timestamps and page numbers are stripped; capped at 200 parts). The device proposes objectives per part by word overlap with the goal's objective and area titles, reusing the Reuse Gate's word rules, and the learner unticks or picks from the full list before saving. Rung 3: "Get a second opinion from your own AI chat" shows a prompt holding only the part titles and numbered objectives; the pasted answer (format `la-resource-map/1`) is checked on the device, entries that name an unlisted part or objective are dropped and counted, and the result is still only a proposal. Every screen says the suggestions are unreviewed. Each covered objective on the resource screen then shows which parts it is in. Guests keep the outline on the device and it moves to the account with the resource. Checked in a real browser on the local stack, as a guest (saved on the device, phone width included) and signed in (the guest outline moved into the account through the gated function). **Changed from the plan:** A.7 in the master plan is a prompt for writing checkpoints, not for mapping, so the mapping prompt is new and lives in `lib/services/companion/outline_mapper.dart`; A.7 is unchanged. **Not built from the plan's list:** depth (introduces, teaches, practises), has-practice and confidence per objective, which belong to reviewed catalog maps (EX-5); self-reported "studied" per section and the resume point, which come with EX-4 |
| EX-4 | **Part 1 built 2026-11-25; no new switch** (behind `content.learner_resources`). **Live 2026-11-25 (#429, #430):** migration `20261125060000` deployed through the guarded tool from `main` `180759c2` (production 177/177); web build of `main` `0dab8abd` checked on the preview channel as a guest against production, then promoted to live (bundle hash matches the build). On production the signed-in path was verified by privilege checks (guests refused on the new write, no direct updates, no readiness or coverage function touches an outside-resource table), not by a real production sign-in. The projected-finish line was not seen in a browser; it is covered by a widget test. Migration `20261125060000` adds two columns to `learner_resource_sections` (the learner's own time estimate per part, and a self-reported studied mark), carries both through `set_learner_resource_sections`, and adds one gated write, `set_learner_resource_section_studied`. When every part that covers an objective is marked, the objective is marked studied too; unmarking a part never unmarks an objective. Database tests assert that no readiness or coverage function mentions any outside-resource table. App: the outline screen reads a length from a pasted line ("12:30", "25 min", "1 h 20 min") into an editable minutes field. A new one-column companion screen (route `/target/<goal>/companion/<resource>`, Help in the top right) lists the parts, opens at the first one not yet studied (the resume point), shows what to look for in it in LearningApp's words (the goal's objectives), has "Done studying this part", and offers LearningApp's own check or practice per objective. It adds up the outside study time left, saying "at least" when a part has no estimate. The goal card and the resource screen show "Continue: <next part>". Checked at 320 wide for split view. **Changed from the plan:** progress lives on the section row, not in a separate `learner_resource_progress` table, and a part whose title is unchanged keeps its mark when the outline is replaced; the route carries the goal id as well as the resource id. **Part 2 built 2026-11-25; no migration.** When the active goal has an outside part left to study: Learn shows an "Outside study" card under the main action ("Next: <part>", the resource, the time, "Then check yourself in LearningApp") that opens the companion; the daily plan says whether that part fits in today's goal and how much outside study is left; the projected finish states the outside time and the days it adds at the daily goal on its own line. All three take no space otherwise. **Changed from the plan:** the outside step is a card beside LearningApp's own next action, not a replacement for it, so the Next Action engine and its ranking are untouched; outside time is not mixed into the projected dates, because an outside part and a LearningApp lesson can cover the same objective and adding both would count it twice; the daily budget is not changed. **Not built:** the reminder at the planned end. The existing reminder sender works on a daily schedule, so a one-off reminder needs its own server path; it is left for a later package |
| EX-5 | **Built 2026-11-26; switch `content.resource_recommendations` seeded OFF** by migration `20261126020000` (one registry row). **Pilot P1 re-pointed** (owner-delegated decision, see §9): OpenStax College Algebra, free without sign-in, record `data/external_resources/openstax-college-algebra.yaml`, **approved 2026-11-26** by an independent AI review (claude-sonnet-5-5, three passes; evidence `data/external_resources/reviews/2026-11-26_openstax-college-algebra.json`). The review found the book's details page now redirects to the 2e, so the record links the 1st-edition web view the map was checked against. It also found the publisher's pages disagree on the license (the preface says CC BY 4.0; the citation panel describes noncommercial, share-alike terms and bars AI training). That does not affect a link; it does matter for lessons adapted from the 1e, which `data/content_sources.json` records as CC BY 4.0 from the preface (flagged to the owner). Its map is derived mechanically by `tool/derive_resource_map.py` from the independently reviewed objective mapping in `data/concept_mappings/`, so it carries that review (approved) with a note saying so; it covers all 20 objectives. CI checks the map still matches its source. `tool/build_resource_catalog.py` bundles records and maps into `assets/companion/resource_catalog.json` (CI checks it is current). App: a "Other ways to study this" card on a goal lists a resource only when its record and its map are both approved: free routes first by coverage and practice, a paid one only after a free one, each with its reasons, check date, reviewer kind and "Not affiliated with". "Use this" adds it to the learner's list with its parts as the outline and the covered objectives ticked, nothing studied. A test reads the ranking code for placement words. The weekly link check now covers every mapped catalog link (and its pipeline now fails on a dead link, which it silently did not before). **Not shown to anyone yet:** the switch is off. **Not built:** nominations (needs the moderation flow), a LearningApp row in the same list (LearningApp's own coverage is already shown beside it on the goal), and saving the catalog id on the learner's resource |
| EX-6 | **Part built 2026-11-25 (#432); switch `content.companion_capture` seeded OFF** by migration `20261125070000` (one registry row, nothing else) **and switched on by migration `20261125080000` (owner-approved 2026-11-25).** **Released 2026-11-25:** the seed migration was deployed through the guarded tool from `main` `807ce66d` (production 178/178) and the web build of the same commit was checked on the preview channel as a guest against production (route refused while the switch was off), then promoted to live (bundle hash matches the build). Before activation the form was driven in a real browser on the local stack as a guest and signed in. The activation migration was deployed through the guarded tool the same day from `main` `77deb557` (production 179/179, one audit row), and the live form was then seen opening as a guest with the cleaned link and no request carrying it. Route `/#/add-resource?url=…&title=…` opens an "Add from a link" form: the link is cleaned on the device and refused if it is not a plain https address, the name is treated as plain text, the learner picks one of their goals, and nothing is saved until they press Add. The form shows a bookmarklet to copy, and the goal card links to the form. The link and name travel in the URL fragment, so no server sees them before the save. **Changed from the plan:** the capture switch controls client entry points only; the save is the existing server function behind `content.learner_resources`, so there is no second server gate to bypass and the migration says so. **Not built:** the Android share target (the simple form of it would send the shared link to the hosting server in a query string; the fragment-only form needs service-worker handling tested on an Android device), and a published Apple Shortcut (needs an Apple device and account; the steps are written in `docs/product/COMPANION_CAPTURE.md`, untested). |
| EX-7 | **Built 2026-11-25; switch `content.companion_embeds` seeded OFF and not to be switched on yet.** **Released with the switch off, 2026-11-25 (#434):** migration `20261125090000` deployed through the guarded tool from `main` `94eebcf9` (production 180/180; the switch is off, the outline write's protections are unchanged). The web build of the same commit was checked on the preview channel as a guest against production: Firebase served the new `frame-src` entry, and a YouTube resource showed no player, no frame and no request to the provider while the switch was off. It was then promoted to live (bundle hash matches the build; the live headers carry the new entry and are otherwise unchanged). With the switch on, the player was seen working only on the local stack under the same headers. Migration `20261125090000` adds the registry row and a nullable `start_seconds` on each part of an outline, and replaces `set_learner_resource_sections` to carry it. App: when a resource's link is a single YouTube video, the companion offers "Play here (loads YouTube)"; the provider's own player then sits pinned above the parts, with what to look for and the checks below. A pasted chapter list ("2:15 Exponents") gives each part a start time, a length up to the next start, and "Play this part here, from 2:15". Nothing is requested from the provider before the tap, nothing is drawn over the player, it is never smaller than 200 by 200, there is no autoplay, and LearningApp records nothing when a video plays. The hosting CSP gains one entry, `frame-src https://www.youtube-nocookie.com`. **Found while building:** the provider's developer policies require wording in the app's own Terms of Service and Privacy Policy before the embedded player may be used. Those documents are the owner's and were not changed; the suggested wording is in `docs/product/COMPANION_EMBEDS.md`. The switch stays off until the owner adopts it. **Changed from the plan:** like capture, this switch controls a client feature only; the player writes nothing, so there is no server write to gate |
| EX-8 | **Built 2026-11-25; no switch of its own and no migration** (behind `content.learner_resources`). **Live 2026-11-25 (#436):** the build that was checked on the preview channel (made from commit `6ed12a84`) was promoted to live. `main` `46d891f1` differs from that commit only in this document, so it is the same app; the live bundle hash matches the tested build. The real-click check was then repeated against the live site with the same results. On browsers with Document Picture-in-Picture, the companion screen's app bar gains a button that opens a small always-on-top window: the part the learner is on, its time estimate, what to look for, a timer for that part, "Done studying this part" and "Back to LearningApp for the check". Marking a part in either place moves both on. The button is not shown where the browser lacks the feature, and a refusal is reported plainly. The window holds no player, watches nothing and is built from plain text; the timer is the learner's own and is never stored. **Verified 2026-11-25** on the preview-channel build, as a guest against production, by driving a separate Chrome (throwaway profile) over the DevTools protocol so the button received a real click: the window opened at 340 by 420 with no sideways scrolling, showed the current part and what to look for, its timer ran and reset on the next part, "Done studying this part" in the window saved the mark and moved both the window and the main screen on, the last one showed the finished state, and closing and reopening worked. A pasted title containing HTML tags was shown as plain text. The built-in test browser blocks windows opened by automated clicks, which is why this needed a separate Chrome. **Not checked:** Edge and Firefox, that the window stays on top of other applications (a browser property, not visible to the test), and a signed-in session |
| EX-9 | **Built 2026-11-25/26; switch `content.companion_extension` seeded OFF** by migration `20261125100000` (one registry row). **Released with the switch off, 2026-11-26 (#438):** the migration was deployed through the guarded tool from `main` `5b27c93b` (production 181/181; the switch is off and has no audit row). The web build of the same commit was checked on the preview channel as a guest against production (the route refused while the switch was off; link capture still worked), then promoted to live (bundle hash matches the build; `X-Frame-Options: DENY` unchanged). The extension was then run against the live site in throwaway Edge and Firefox 161 profiles: the side window and the side panel both landed on the new route and the app handled it. The extension itself is not published anywhere. **The extension** (`extension/firefox`, `extension/chrome`, one shared script, one permission: `activeTab`): one toolbar button that opens LearningApp at `/#/companion-for?url=…&title=…` for the page the learner is on. Firefox on a computer shows it in the browser's side panel; Chrome and Edge open a narrow window beside the browser; Firefox for Android opens a tab. No content scripts, no host permissions, no storage, no requests of its own; the address travels in the URL fragment. **The route:** if the page is one of the learner's resources (same address once tracking parameters, the fragment and a trailing slash are set aside, or the same YouTube video) in any of their goals, its companion opens; otherwise the add form opens, prefilled, and nothing is saved until they press Add. **Changed from the plan:** Chrome and Edge get a side window, not a side panel. Their side panel may only show a page packaged in the extension, so showing LearningApp there would mean framing it, and the site's `X-Frame-Options: DENY` was kept. Firefox's side panel may load a web page directly. As with capture, the switch controls a client entry point only. **Seen in real browsers (throwaway profiles):** Firefox 161 installed it with only `activeTab`; pressing its button opened the side panel on LearningApp's address with the page's address and title, and the app loaded there, not an error page. Edge loaded it with only `activeTab`, its click listener was registered, it could not read any tab's address without a click, and the side window opened at 420 by 760 on the right address. The route itself was driven on the local stack as a guest for both the matching and the new-page case. **Not verified:** Chrome itself (it refuses unpacked extensions from the command line; it needs a manual "Load unpacked"), a human click on the toolbar button in Edge or Chrome, Firefox for Android, a signed-in session. **Not done:** store listings. Firefox and Edge need the owner's free developer accounts and Chrome the US$5 fee (X-11); `extension/README.md` has the manual install steps |
| EX-10 | **Built 2026-11-26; no switch, no new data collection.** **Live 2026-11-26 (#440):** migration deployed through the guarded tool from `main` `14798b66` (production 182/182); on production the function is read-only and guests cannot call it. No web release was needed. Migration `20261126010000` adds one read-only function, `get_companion_outcome_report(target version)`, for admins and moderators, on the pattern of the learner-signal report. For learners who opted in to product analytics only, it counts from rows the server already holds: how many learners of a goal added an outside resource, the furthest mapping rung each reached (listed, ticked, outline by word match, outline with their own AI), and how many self-reported "studied" objectives were followed by one of LearningApp's own checks within 7 days, with the mean score. Groups under 5 are withheld, and so is any figure that would let a withheld one be worked out by subtraction. It returns no resource name, link, outline or learner id. **How this squares with §7.1** ("never enters analytics"): no learner's resource data enters the product event stream or leaves the database; the report returns grouped counts for opted-in accounts only. The self-report isolation tests now allow this one named function and still assert that no readiness, coverage or mastery function reads outside study. **Not measured, and listed as such in the report:** gap offers opened and return after a break (both need events that are not collected), and readiness with and without outside resources (not defined). **State of the data on 2026-11-26:** production had no opted-in account and no outside resource stored in any account, and the opt-in notice is still an unapproved draft, so every figure is withheld for now. **Not built:** a screen for the report. `docs/analytics/COMPANION_OUTCOME_REPORT.md` has the field list and a sentence the owner may want in the opt-in notice; the notice itself was not changed |

**Acceptance, common to all:** switch OFF leaves existing behaviour and data intact; bypass attempts against the server gate fail; no readiness number changes from self-report alone; `flutter analyze`, `flutter test`, `supabase test db` and every verify-job step pass locally before push; accessibility checks at phone width and 200% text.

**Acceptance story for the first milestone (EX-1 to EX-4).** A learner preparing for CLEP College Algebra adds a free video course. They tick or paste its sections. The app shows that the course covers part of the blueprint and names what it leaves out. Next Action says which section to watch. They watch it in the provider's app on a tablet with LearningApp in split view, mark it studied, and take the independent check. Readiness by objective moves because of the check, not the tick. The gap list offers a LearningApp lesson for a skipped objective. The projected finish includes the remaining video time. The same state appears on their phone.

---

## 9. Pilot

Three resource types, chosen to stress different parts of the design. All on goals that already have full held-out coverage, so readiness is real from day one.

| Pilot | Goal | Resource type | Tests |
|---|---|---|---|
| P1 | CLEP College Algebra | **Re-pointed 2026-11-26 to OpenStax College Algebra** (free without sign-in; an independently reviewed objective mapping already existed, so a map could be derived without reading a site that refuses automated access). Originally **selected in EX-0:** Modern States "College Algebra" (`data/external_resources/modern-states-college-algebra.yaml`): free with an account, aligned to the same exam, and its voucher covers the exam fee. Link-only; record and map are not yet reviewed. **Finding 2026-11-25 (start of EX-5):** the publisher's site refuses automated reading (HTTP 403 on the course page and the terms page), and that refusal is respected, not worked around. The module list needed for an objective map could therefore not be read. The record stays link-only, unreviewed and without a map, so it is not shown as a recommendation. A map needs the outline supplied by a person (the owner pastes the module list from a normal browser), or a different pilot resource whose outline is published in a form that may be read | Map quality, best free route, bookend and split-view modes |
| P2 | Excel Fundamentals | A paid course the learner brings (no catalog entry, no embed) | Rungs 1–3, bookend and split-view modes, cost honesty |
| P3 | Prealgebra | A printed or PDF textbook the learner already owns | A resource with no link at all; outline paste; phone bookend mode |

P1 cannot be embedded, so it does not test the in-app player. The embeddable-video resource for EX-7 is chosen when EX-7 starts, from a provider whose terms allow embedding.

The limit to plan around: readiness is only as wide as LearningApp's own check bank. Companion mode on a goal with no held-out checks gives structure and supplement but can only say "not enough checks yet". That is the ingestion plan's §8.6 bank-depth constraint, and this plan raises its priority: every new goal offered for companion use needs checks before lessons.

---

## 10. Measurement

Descriptive only, from opted-in learners, with groups under 5 withheld, as in the learner-signal report.

- Share of learners with a goal who add an outside resource; which rung of mapping they reach.
- Share of "studied" sections followed by a check within 7 days, and the check results.
- Share of gap offers opened, and whether the objective later reaches "strong".
- Readiness coverage reached by learners using outside resources against those using only LearningApp content. Reported side by side with no causal claim.
- Return rate after a break, and dead-link and re-resolution counts.
- Never collected: which outside pages a learner visits, watch time, or resource links in analytics events.

---

## 11. Risks

| Risk | Handling |
|---|---|
| Provider terms change, or an embed is refused | Embeds are one optional layer behind a switch. L0 always works |
| Checks drift into copying a course's own quizzes | Independent authoring rule, the existing verbatim-overlap audit pattern, AI review checklist item |
| A wrong map tells a learner a course covers what it does not | Confidence and review labels on every map; the check, not the map, decides readiness; learners can report a wrong map (extend the check-disputes flow, which covers Bridge checks only today) |
| Recommendations look like endorsements or ads | Reasons and check dates shown; best free route always shown; ranking-isolation test; "not affiliated with <provider>" wording |
| Prices go stale | Price bands with as-of dates; freshness queue raises a review when the date ages out |
| Learners treat "studied" as "ready" | Two different words and two different visuals everywhere; readiness only from checks |
| Maintainer time for catalog maps | Rungs 0–3 need no maintainer. Catalog maps are built only for demand-ranked goals, with AI authoring and independent AI review |
| Scope: five device layers | Layers are independent and ordered. EX-1 to EX-5 deliver the product; EX-6 to EX-9 can stop at any point |
| High-stakes goals | T3 rule: link-only, no readiness claim beyond what a person reviewed |

---

## 12. Decisions

Recommended defaults. Under the owner's standing delegation these stand unless the owner changes them; the items marked **owner** involve money or production activation and are not delegated by this document.

| ID | Decision | Recommendation |
|---|---|---|
| X-1 | Unit of companionship | The goal's objectives, not the resource (§1) |
| X-2 | First milestone | EX-1 to EX-4: bring your own resource on the PWA, all devices |
| X-3 | Extension priority | Last, thin, `activeTab` only |
| X-4 | Server fetch of learner links | Never |
| X-5 | Transcripts and page content | Never read; mapping from learner input and public outlines only |
| X-6 | Self-report | Its own tier; moves the plan; never readiness |
| X-7 | Ranking | Learner benefit only; best free route always shown; affiliate code barred from ranking |
| X-8 | Catalog storage | Repository files first, database later |
| X-9 | Sync | Server tables for signed-in learners; device-local for guests |
| X-10 | Pilots | P1–P3 in §9 |
| X-11 | Chrome Web Store fee | **Owner.** Until decided: Firefox listing plus manual Chrome install for testers |
| X-12 | Native apps and Safari extension | **Owner.** Paid extension slots; not built |
| X-13 | Switching each new key ON in production | **Owner**, per key, after browser verification as guest and signed in |

---

## 13. Sources

Platform and policy:

- [WebKit bug 194593: Web Share Target](https://bugs.webkit.org/show_bug.cgi?id=194593)
- [MDN: `share_target` manifest member](https://developer.mozilla.org/en-US/docs/Web/Manifest/Reference/share_target)
- [Chrome: Receiving shared data with the Web Share Target API](https://developer.chrome.com/docs/capabilities/web-apis/web-share-target)
- [Android Authority: desktop Chrome for Android and extensions](https://www.androidauthority.com/try-new-chrome-for-android-with-extensions-3569268)
- [Android Central: Chrome for Android is getting extensions, but not as expected](https://www.androidcentral.com/apps-software/chrome-for-android-is-getting-extensions-but-not-like-youd-expect)
- [Mozilla: preparing desktop extensions for Firefox on Android](https://blog.mozilla.org/addons/2023/08/10/prepare-your-firefox-desktop-extension-for-the-upcoming-android-release/)
- [Chrome: `chrome.sidePanel` API](https://developer.chrome.com/docs/extensions/reference/api/sidePanel)
- [MDN: `sidebarAction`](https://developer.mozilla.org/en-US/Add-ons/WebExtensions/API/sidebarAction)
- [Chrome: Document Picture-in-Picture](https://developer.chrome.com/docs/web-platform/document-picture-in-picture)
- [Mozilla: intent to ship Document Picture-in-Picture](https://groups.google.com/a/mozilla.org/g/dev-platform/c/ZYhF7VNXwQU)
- [YouTube API Services: Developer Policies](https://developers.google.com/youtube/terms/developer-policies)
- [YouTube API Services: Required Minimum Functionality](https://developers.google.com/youtube/terms/required-minimum-functionality)
- [YouTube Data API: quota costs](https://developers.google.com/youtube/v3/determine_quota_cost)
- [YouTube Data API: `captions.download`](https://developers.google.com/youtube/data/reference/rest/v3/captions/download)
- [Udemy provider listing (Affiliate API closed to new clients)](https://apis.io/providers/udemy/)

Learning research:

- [Jordan (2015), MOOC completion rates revisited](https://dx.doi.org/10.19173/irrodl.v16i3.2112)
- [Chronicle: Rethinking low completion rates in MOOCs (Reich)](https://www.chronicle.com/blogs/wiredcampus/rethinking-low-completion-rates-in-moocs)
- [Szpunar, Khan and Schacter (2013), interpolated tests in online lectures](https://pmc.ncbi.nlm.nih.gov/articles/PMC3631699)
- [Welhaf et al. (2022), interpolated testing and pretesting during a video lecture](https://cognitiveresearchjournal.springeropen.com/articles/10.1186/s41235-022-00372-y)
- [Toftness et al., limited effects of prequestions with authentic lecture videos](https://pure.royalholloway.ac.uk/files/30437641/JARMAC_Toftness_et_al.pdf)

EX-0 verification (2026-11-25):

- [Chrome Web Store: register your developer account](https://developer.chrome.com/docs/webstore/register)
- [Chromium Blog: developer dashboard and registration fee](https://blog.chromium.org/2020/03/new-developer-dashboard-and.html)
- [Modern States: College Algebra](https://modernstates.org/course/college_algebra/) and [FAQ](https://modernstates.org/faq/)
- [Khan Academy: using its videos, name, materials and links](https://support.khanacademy.org/hc/en-us/articles/202262954-Can-I-use-Khan-Academy-s-videos-name-materials-links-)
- [Apple: assessing a Safari web extension's browser compatibility](https://developer.apple.com/documentation/safariservices/assessing-your-safari-web-extension-s-browser-compatibility)
- [edX Course Catalog API: authentication and access request](https://course-catalog-api-guide.readthedocs.io/en/latest/authentication/)
- [Coursera Catalog API listing (unofficial)](https://apis.io/apis/coursera/coursera-catalog-api/)

**Still not verified:** the Modern States terms of service; Safari popup support on iOS; Coursera's official catalog terms; the full text of Jordan (2015), Szpunar et al. (2013) and Welhaf et al. (2022). None blocks EX-1.
