# LearningApp — Learner Experience Improvement Plan (v2)

**Review draft v2 | 5 November 2026**
**Supersedes:** v1 (same date). v1 was written from a first-pass inspection; v2 is checked against repo commit `422296d` (2026-11-05), `UI_ARCHITECTURE_LOCKED.md`, and the original feedback.
**Method note:** Findings come from reading the code, not from running the app. Anything that needs the running app is listed under "Verify first."

---

## 1. What changed from v1, and why

v1 treated most of Ashley's feedback as a list of things to build. The code audit shows a different picture, so v2 sorts every item into one of four kinds of work and prefers the cheapest honest fix:

| Kind of work | Meaning |
|---|---|
| **Remove / consolidate** | Something is duplicated or crowded; the fix is to take things away. |
| **Surface** | The feature exists but is hard to reach or recognize. |
| **Fix** | The feature exists but is incomplete or inconsistent. |
| **Build** | The feature is genuinely missing. |

**Corrections to v1:**

1. **Vocabulary does not exist yet.** `word_learning_screen.dart` states vocabulary and combined practice "remain W2." What exists is spelling (W1).
2. **Volume and auto-read already exist** in Settings → Audio Settings. v1 proposed building them.
3. **The product is a web-only PWA** (`learning_pwa`; only a `web/` platform folder). v1's iOS/Android/desktop test matrix was wrong.
4. **Short-answer grading is minimal and client-side** in the lesson path. v1 assumed rules existed that needed testing.
5. **A display-name column already exists** in the database. v1 implied schema work.
6. **No localization framework exists.** v1 treated app language as a settings item.
7. **Several v1 proposals conflict with `UI_ARCHITECTURE_LOCKED.md`.** v2 lists these explicitly as amendments (Section 4) instead of proposing them quietly.

**Guiding principle for v2:** Ashley's feedback is evidence about where learners struggle. It is not a feature order. Where the app already does the thing, the job is to make it findable and consistent.

---

## 2. Feedback inventory and honest status

Original feedback, condensed: volume control; color coding and a hard-to-navigate Explore/Library; deep research on light/dark colors; vocabulary hard to find; Create available whether or not existing content is chosen; profile display name and device-only avatar; reader in every mode with on/off and auto-read; short answers now, long later; a drawing board that can be saved locally and reloaded; language settings plus learn-a-language; stories to keep learners interested.

| # | Request | Status in code | Kind of work | Priority |
|---|---|---|---|---|
| 1 | Library/Explore is hard to navigate | Crowded layout (Section 3.1) | Remove / consolidate | P0 |
| 2 | Create everywhere / easy to request | Create appears in 4+ places under different names; none in the empty-search state | Consolidate, then one addition | P0 |
| 3 | Vocabulary hard to find | Only spelling exists, labeled "My spelling words," hidden during search | Surface now; Build later (W2) | P0 label, W2 feature |
| 4 | Volume control | Exists in Settings → Audio Settings | Surface | P0 |
| 5 | Reader in every mode, on/off, auto-read | Speaker exists in every mode traced; Ashley's report not reproduced | Verify first, then Fix | P0 |
| 6 | Color and theme research | Tokens exist; no contrast or comfort research; many hard-coded colors | Evidence audit, then Fix | P1 |
| 7 | Profile display name | UI missing; DB field exists | Build (small) | P1 |
| 8 | Device-only avatar | Missing; new dependencies needed | Build | P2 |
| 9 | Short answer | Works for single-string answers only | Fix | P1 |
| 10 | Long answer | Not started | Defer (note for later) | P3 |
| 11 | Drawing board, save/reload | Missing; a canvas widget exists to reuse | Build | P2 |
| 12 | App language settings | No localization framework | Build (large) | P3, separate decision |
| 13 | Learn a language | No language content or model | Build (pilot) | P2–P3 |
| 14 | Stories / engagement | Decodable stories exist for literacy; motivation presets exist | Pilot | P2 |

---

## 3. Verified findings

### 3.1 Library layout (`lib/screens/library/library_screen.dart`)

Ashley said "Explore." In the code, the browsing screen is **Library**, and "Explore Domains & Fields" is a section header inside it. Top to bottom, with no search text, a learner sees:

1. A "My spelling words" button
2. Search field
3. Scope chips (when a learning context is active)
4. **8 destination chips** in a horizontal scroller: All Destinations, Careers, Certifications, Exams, Academic Programs, Curriculum Standards, Courses & Lessons, Life Milestones & Literacy
5. **4 source chips:** Trusted catalog, Official, Reviewed community, My goals
6. Two banner cards (Taxonomy, Life Milestones)
7. "Your learning" with a **Create Goal** button
8. "Explore Domains & Fields" with a trailing label hard-coded as "12 Domains" while the list itself is dynamic
9. A goals section with a second **Create Goal**
10. A lessons section with **Create Lesson**
11. A **Create** row (Study set, Lesson, Import) near the bottom
12. A "More" list (Learning Targets, Courses, Study sets)

Observations:

- Create appears at least four times under three names (Create Goal ×2+, Create Lesson, Create row). The main Create row sits below nearly everything else.
- Three filter rows and two banners come before content. Chips beyond the first few are off-screen in a horizontal scroller.
- Search with no results shows only a hint (plus "Search entire library" when scoped). It offers no way forward.
- Vocabulary-like content is reachable only through "My spelling words," and that button disappears the moment the learner types in search.

### 3.2 Audio

- `AudioSettings` stores volume, speech rate, pitch, voice, language, auto-play, auto-read questions, auto-read answers. `AudioLessonSettings` separately stores hands-free options, including `autoReadAllContent` (default true) and `voiceLocale`.
- **Settings → Audio Settings** (`audio_settings_screen.dart` via `AudioQualitySection`) already exposes volume (as a percentage), rate, pitch, voice, language, auto-play, auto-read toggles, and a test button. It is only reachable through Settings.
- `AudioControlWidget` is the shared in-content reader (speaker → pause → resume → stop/refresh). It is used in MCQ content, concept content, flashcard content, and through `AudioQuestionHeader` (MCQ, true/false, short answer).
- `AudioQuestionHeader` shows the speaker only when `canSpeak` is true, and the voice-input button only when `canListen` is true. In `McqContent` the microphone appears as a hint line ("Say your answer…").
- The short-answer explanation button calls `AudioService().speak(...)` directly, bypassing the shared provider and its state.
- Lesson screens toggle between hands-free and manual using icons `record_voice_over` and `touch_app`.

### 3.3 Themes and color

- `themeModeProvider` supports **light and dark only**, and **defaults to dark.** There is no System option.
- `docs/design/COLOR_SYSTEM_GUIDELINES.md` and the archived `COLOR_SYSTEM_REFRESH_PLAN.md` cover **semantic status tokens and governance**. Neither covers contrast measurement, comfort, or long-session testing.
- About **745** named `Colors.*` uses (excluding white/black) remain in `lib/`, including in settings screens, despite the guideline against them.

### 3.4 Short answer

- Grading in the lesson path is `MathUtils.isAnswerCorrect`: trim, lowercase, exact equality against one string stored at `options[correctAnswer]`.
- `QuestionContent` (Hive typeId 5) has no accepted-variants list, no numeric tolerance, and no per-question grading method.
- Exam-reference drills use a separate scoring service that calls a server RPC. The lesson path does not.
- `string_similarity` and `fuzzy` are used only for voice-command correction, not grading.

### 3.5 Profile

- `profile_screen.dart` shows the email and the email's first letter.
- `public.users.display_name` exists. `auth_provider.dart` sets it to "Guest" for anonymous users and deliberately avoids overwriting it on later sign-ins. A `users_self_update` row-level-security policy exists.
- Educator profiles (ECO_04) have their own public `display_name` and `avatar_url`.

### 3.6 Platform and dependencies

- Web-only PWA. `pubspec.yaml` has Hive, `shared_preferences`, the `web` package, `flutter_tts`, `speech_to_text`, and `flutter_math_fork`.
- **Not present:** `image_picker`, `file_picker`, `share_plus`, `path_provider`, `flutter_localizations`. There is no `l10n` folder.

### 3.7 Reusable pieces

- `lib/widgets/literacy/letter_tracing_canvas.dart` (pointer and painter code for the whiteboard).
- `lib/models/decodable_story_item.dart` (word-timed story model for literacy, with synchronized highlighting).
- `motivation_preferences_provider.dart` (Minimal/Standard presets, `UI_ARCHITECTURE_LOCKED.md` §9.1).
- `docs/design/LEARNING_UI_RESEARCH.md`, which already documents the seductive-details effect.

---

## 4. Required amendments to the locked architecture

Under §14, a locked section changes only on user evidence, implementation evidence, an accessibility/safety/privacy requirement, or a demonstrated factual error. Each proposal below names the section, ground, and principle. Anything marked "no amendment" is within existing rules.

| # | Proposal | Locked section affected | Ground | Principle (§2) | Amendment needed? |
|---|---|---|---|---|---|
| A1 | Keep **one** Create entry in Library that opens a single "What would you like to make?" chooser (goal, study set, lesson, import); remove the other Create buttons | §5.4 ("Create lives here and only here") | User evidence (Ashley); duplication is observable in code | #3, #5 | Clarify only; consistent with the intent of the rule |
| A2 | Add a **Create** action to the **empty-search state** that carries the query into the chooser | §5.4 | User evidence; the empty state is currently a dead end | #4, #5 | **Yes.** Create then appears in Library and its search state |
| A3 | Make the reader and its volume/rate sheet reachable from inside a lesson | §5.6 (study chrome = progress + exit) | User evidence | #5 | **No**, if the control lives in the content area (as `AudioControlWidget` already does) and not in app-bar chrome |
| A4 | A global volume control in the app bar | §3 locked chrome rules | none | n/a | **Rejected.** Do not do this |
| A5 | "Work it out" board entry on question screens | §5.6 | User evidence (one learner, math) | #5 | **Yes**, if added. Gate to question types where it helps and place it in content as a secondary text button. Defer until a second user confirms the need |
| A6 | Add Appearance (System/Light/Dark), Display name, and Content format to Settings | §5.7 | User evidence; implementation evidence | #5 | **Yes**, minor list additions |
| A7 | Story/format preference (Direct / Story / Mix) **separate from** Minimal/Standard motivation | §9.1 | n/a | #2, #5 | **No change to §9.** Add a separate setting in §5.7 (A6) |
| A8 | Reorganize Library filters and chips | §3 / §5.4 | User evidence | #3, #5 | Within §5.4 if destination-level IA is unchanged; record in the changelog |

**Non-negotiables carried through:** the Direct Access Rule tests (`test/widgets/direct_access_rule_test.dart`) must stay green; no badges or attention indicators on top-level navigation; one primary CTA per screen state.

---

## 5. Workstreams

### 5.1 Library discovery: simplify before adding

**Priority P0 | Kind: Remove / consolidate | Touches A1, A2, A8**

**Goal:** A first-time learner can find spelling words, a career or license path, a lesson, and a way to create something, without help.

**Step 1: Measure before changing.** Run a short task test with 5–8 people unfamiliar with the app, including at least one less comfortable with technology. Tasks: find the spelling words, find a career/license path, find a specific lesson, and create something when search returns nothing. Record time, wrong turns, and unaided success. Ashley's session is a data point, not the baseline.

**Step 2: Subtractive changes (proposed first release).**

- Collapse the four **source chips** into a single "Source" control (default: Trusted catalog). Learners who never change it should never see four chips.
- Merge or remove the two banner cards where they duplicate a chip or section.
- Replace the hard-coded "12 Domains" with a real count or remove it.
- Replace the scattered Create buttons with **one Create entry** (A1). Place it in a consistent, visible position, not at the bottom.
- Keep "Words" visible during search (see 5.2).
- Keep the destination chips, but reorder by actual usage once data exists.

**Step 3: One addition.** Empty-search state: "Nothing found for *query*. Create it, or search the whole library" (A2).

**Step 4: Only if the test shows it is still hard,** try learner-intent groupings (v1's six groups) as a prototype. v1's group list is retained as an option, not a recommendation.

**Color coding:** Defer until the theme audit (5.5). Any domain colors must be paired with an icon and text, and must not reuse semantic success/warning/error colors.

**Acceptance criteria:**
- Create has one entry point in Library and one in the empty-search state.
- No dead-end search.
- The Direct Access Rule tests pass.
- Task-test success rate and time improve against the pre-change baseline.
- Keyboard and screen-reader navigation work.

### 5.2 Spelling and vocabulary: fix the label now, build vocabulary in W2

**Priority P0 (label) | Kind: Surface now; Build later**

- Rename and place the existing entry so a learner looking for word practice finds it. "My spelling words" → a label that fits the feature as it grows (for example "Words"). Keep it visible during search and reachable from Library's main area.
- Do **not** advertise vocabulary until W2 ships. The screen's own helper text says vocabulary testing comes later. Showing a "Vocabulary" entry that only offers spelling would create a new discoverability problem.
- W2 (vocabulary and combined practice) continues under the existing Word Learning plan. v2 does not redesign it.
- Keep one shared word identity across spelling, vocabulary, and language learning.

**Acceptance criteria:** A learner searching for word practice reaches the word lists in one step from Library, in both browse and search states. The label does not promise features that do not exist.

### 5.3 Audio: reuse, surface, unify

**Priority P0 | Kind: Verify first, then Surface and Fix**

**Verify first (reproduce Ashley's report).** Her exact words: *"Some of the modes doesn't seem to have the reader anymore, it has the mic but I didn't see option for it to be read."* No mode, question type, browser, or device was recorded. Do not name a broken mode until reproduced. Check:

1. Is the speaker hidden anywhere because `canSpeak` is false (browser or voice availability)?
2. Is the speaker visually distinguishable from the microphone in each mode? In MCQ the mic hint is prominent, and the speaker is a small icon beside the question.
3. Is the reader available **before, during, and after** answering (question, options, explanation)?
4. Do manual and hands-free lesson navigation expose equivalent reading controls?
5. Does anything differ between question types (MCQ, true/false, short answer, flashcard, concept, lesson-mode text)?

Test in Chrome, Edge, and Safari (including iOS Safari), since the repo has Safari-specific audio services.

**Then, regardless of the result:**

- **Reuse `AudioControlWidget`.** Do not build a second reader. Fix inconsistencies in it.
- Route the short-answer explanation button through the shared audio provider so state (playing, paused, stopped) stays consistent.
- Make the speaker and microphone visually distinct everywhere. The microphone means "I will listen to you." The speaker means "read this to me."
- If `canSpeak` is false, show a disabled speaker with an explanation instead of hiding it. A hidden control looks like a missing feature.
- Add a way to reach reader preferences from inside the lesson (rate, volume, auto-read) without leaving it: for example, a long-press or secondary action on the existing speaker opening a small sheet that also links to full Audio Settings (A3, no chrome change).
- Keep **Audio Settings** as the home for detailed preferences. Add a shortcut to it where learners ask for it.
- Auto-read: keep existing toggles. Clarify, in one place, how `AudioSettings.autoReadQuestions/autoReadAnswers` relate to `AudioLessonSettings.autoReadAllContent` so learners see one coherent set of choices. This may need a settings audit before any UI change.
- Verify volume is honored per browser. If the Web Speech API volume is not honored on a browser, say so in settings instead of showing a slider that does nothing.

**Acceptance criteria:** Every supported mode has a visible, distinct read action, or an explained disabled one. The user can stop speech immediately. Preferences persist. Listening and speaking icons are never confused. Test notes record browser and mode for each check.

### 5.4 Profile: display name first, avatar later

**Priority P1 (name), P2 (avatar) | Kind: Build (small)**

**Display name**

- Show a learner-chosen display name in place of the email in the profile header and greetings. Email stays in account details.
- It is **not** a login username and must not touch authentication.
- Use the existing `users.display_name` column. Before writing any migration, confirm: the `users_self_update` policy allows the learner to edit that column (and only their own row), and what length and content limits to enforce. Educator profiles use a 2–100 character check, which is a reasonable template.
- Decide how this relates to the **educator public display name** so learners do not end up with two unrelated names.
- Anonymous users currently have "Guest." Define what the field shows and whether it can be edited before sign-in.

**Avatar (device-only)**

- Never upload. Two sources: a small set of **bundled, compressed premade avatars** (career-themed options are fine, without implying the user's identity), and **a picture chosen on this device**, with a clear notice that it stays on this device and will not follow the learner elsewhere.
- Store locally in a binary-friendly store (Hive is already in use). Do not put large base64 strings in `shared_preferences`.
- Resize and crop before storing. Provide "Reset to default."
- Picking a file in a web PWA needs either a new package (`file_picker`/`image_picker`) or direct use of the `web` package. This is a dependency decision to make explicitly.
- Warn that clearing browser data may remove the image.

**Acceptance criteria:** The profile headline shows the display name, not the email. The avatar never leaves the device. The local image survives reload. Limits are explained in the UI.

### 5.5 Color and theme: evidence first

**Priority P1 | Kind: Evidence audit, then Fix**

Ashley's instinct that the colors were not researched is consistent with the repo: the existing guideline work is about status tokens, not comfort.

**Audit before redesign**

1. Inventory the roughly 745 hard-coded `Colors.*` uses and classify each: semantic, decorative, subject-specific, accidental. Start with high-traffic screens (Library, study, settings, profile).
2. Generate a contrast report for every foreground/background pair in light and dark themes against WCAG 2.2 AA (4.5:1 normal text, 3:1 large text and UI components).
3. Check color-vision simulation, grayscale, browser zoom, and text scaling.
4. Run 20–30 minute moderated sessions in both themes, asking about readability, fatigue, hierarchy, and what draws attention away from learning.
5. Refine tokens, then migrate components to semantic tokens, in small PRs, following `COLOR_SYSTEM_GUIDELINES.md`.

**Theme options:** Add **System** alongside Light and Dark (A6). Reconsider the **dark default** against user evidence. Contrast passing is necessary but does not prove comfort. A "Reading" surface preference is optional and later.

**Acceptance criteria:** Contrast report with no unexplained AA failures in primary flows; no important state conveyed by color alone; tokens used in touched files; learner feedback recorded for both themes.

### 5.6 Short answers now, long answers later

**Priority P1 (short), P3 (long) | Kind: Fix**

**Short answer:** The current check handles one string with case and whitespace normalization. To support "a word or very short response" reliably:

- Extend the question model with an explicit **list of accepted answers** and a declared **grading method** (exact, normalized-text, numeric-with-tolerance). This is a schema change to a Hive-backed model (`typeId 5`). Add new fields at new `HiveField` indexes so existing stored lessons still load.
- Normalize per method and per content type. Accents and spelling may be the point in language or spelling questions, so normalization must be content-specific.
- Do not use fuzzy matching for correctness.
- Show learners why an answer was accepted or rejected.
- Add test fixtures: case, whitespace, punctuation, accents, synonyms, numeric answers, ambiguous responses.
- Decide whether lesson-path grading stays client-side (answer key shipped to the device) or moves server-side like exam drills. This is an owner decision with privacy and cheating implications for scored content.

**Long answer (note for later):** Do not auto-grade. Until a rubric and review path exist, long writing can be saved as a learner note or draft, not labeled as graded. Future requirements (carried from v1): rubric format, multiple acceptable response patterns, transparent feedback, a self- or human-review path, a privacy and cost model for any AI evaluation, and testing for false accepts and rejects.

**Acceptance criteria:** Grading rules are declared per question, tested, and visible in feedback. Existing lessons keep working.

### 5.7 Whiteboard ("Work it out")

**Priority P2 | Kind: Build | Touches A5**

- Start from `letter_tracing_canvas.dart` for pointer and painter handling. Keep drawing state completely separate from answer state.
- First release: pen, eraser, clear, undo/redo, a few sizes and high-contrast colors, optional grid. Works offline, no account.
- Save as **PNG** to the device. Reopening a PNG loads it as a **reference background**, not as editable strokes (state this plainly in the UI).
- Both save and open need browser mechanisms (canvas export; a file input) and likely a dependency decision (same as the avatar).
- Editable restore (exporting stroke data such as JSON alongside the PNG) is a later option.
- Entry point: a secondary in-content button on question types where it helps (numeric and short-answer first), not app-bar chrome. Per A5, wait for confirmation from a second learner before shipping.
- `flutter_math_fork` is already installed for math display; consider whether math questions should display equations alongside the board.

**Acceptance criteria:** Opening or closing the board never loses the question or typed answer. PNG save works in Chrome, Edge, and Safari. Board contents are never submitted as an answer.

### 5.8 Language: two separate efforts

**Priority P2–P3 | Kind: Build (large)**

**Learning language (content)**

- A learner chooses a language to learn, with its own goals and level. TTS and speech recognition should use that locale.
- There are already two locale fields (`AudioSettings.language`, `AudioLessonSettings.voiceLocale`), in different formats (`en-US` vs `en_US`). Unify them before adding a third.
- Start with one pilot course in one language, with listening, reading, speaking, and short written tasks, reusing the shared word identity. CEFR-style bands can guide, without being a barrier to starting.

**App display language (UI)**

- There is no localization framework. Every user-facing string would have to be extracted. Treat this as a separate project with its own decision, starting with a **string-extraction spike** to size it. Do not bundle it with the learning-language pilot.
- Keep the two settings independent: a learner can use the app in English while learning Spanish, and the reverse.

### 5.9 Engagement and stories: a separate format preference

**Priority P2 | Kind: Pilot**

- **Keep motivation and format separate.** The existing Minimal/Standard preset controls XP, levels, streaks, celebrations, and daily goals, and stays as locked in §9.1. A **Content format** preference (Direct / Story / Mix) is a different setting, added to Settings (A6, A7). Neither depends on the other.
- Precedent exists: decodable stories with word-timed highlighting for literacy. Reuse that model and the same rights discipline (openly licensed or public-domain sources, clear labeling of dramatized versus factual content) rather than inventing a parallel one.
- **Test for stories:** the repo's own research doc cites the seductive-details effect: interesting but irrelevant additions can hurt recall of important material. A story must carry the learning objective and be followed by retrieval practice. Success is delayed recall and task completion, not time in app.
- Pilot in two subjects (for example, a history topic and a vocabulary or literacy topic), comparing direct and story formats with equivalent objectives, and measuring understanding, delayed recall, preference, and effort.
- Music and social features stay deferred (social/sharing is on the locked deferred list). Revisit only after moderation, privacy, and safety work.

---

## 6. Sequence

**Phase 0: Reproduce and measure (no feature code)**
- Reproduce Ashley's reader report across question types and browsers.
- Run the Library task test and record the baseline.
- Run the contrast script and the hard-coded color inventory.
- Check `users_self_update` policy scope for `display_name`.

**Phase 1: Subtract and surface**
- Library consolidation and the single Create chooser (A1, A2, A8).
- Words label and placement fix.
- Audio: shared control fixes, speaker/mic distinction, in-lesson reader sheet and settings link.
- Display name.

**Phase 2: Fix and build contained features**
- Short-answer model and grading tests.
- Theme audit outcomes, System theme option, token migration in priority screens.
- Avatar (after the dependency decision).
- Whiteboard v1 (after a second learner confirms the need).

**Phase 3: Pilots**
- Story/format pilot.
- Learning-language pilot.

**Deferred:** long-answer grading; app UI localization (after its spike); social features; music; editable board export.

**Suggested PR boundaries** (each independently reviewable; migrations append-only through the guarded deploy path):
1. `fix(audio): reader consistency, speaker/mic distinction, in-lesson sheet`
2. `refactor(library): consolidate Create, simplify filters, empty-search create`
3. `fix(words): label and placement for word lists`
4. `feat(profile): editable display name`
5. `feat(assessment): accepted answers and declared grading method`
6. `refactor(theme): contrast fixes and System theme option`
7. `feat(profile): device-local avatar`
8. `feat(study): work-it-out board with PNG export`
9. `feat(settings): content format preference` and pilots

---

## 7. Test plan

- **Browsers:** Chrome, Edge, Safari desktop, iOS Safari (installed PWA and in-browser), Chrome on Android. This is a browser matrix, not a native app matrix.
- **Regression:** Direct Access Rule widget tests; existing suite; new widget tests for the single Create entry, empty-search Create, and reader states.
- **Audio:** state transitions (idle, playing, paused, stopped, error), overlapping utterances, navigation during speech, unavailable voices, persistence.
- **Grading:** fixtures listed in 5.6; backward compatibility with stored lessons.
- **Accessibility:** keyboard and screen-reader pass on Library, study, settings, and profile; text scaling; reduced motion.

---

## 8. Measures

Use product-quality measures, not engagement vanity metrics.

- **Discovery:** time to find a target, unaided success, wrong turns, share of empty searches that lead to Create.
- **Audio:** reader used and completed, failed or interrupted playback, learner able to tell speaker from microphone.
- **Visual comfort:** contrast results, defects at larger text sizes, learner-rated readability after 20–30 minutes.
- **Learning quality:** delayed recall, short-answer false-accept and false-reject rates.
- **Engagement pilots:** voluntary return, completion of meaningful tasks, delayed recall by format. Avoid optimizing for session length or streaks.

---

## 9. Risks

| Risk | Safeguard |
|---|---|
| Chasing Ashley's wording instead of the underlying problem | Measure with several users before and after; treat one tester as a signal |
| Reader fix targets the wrong mode | Reproduce first; record mode and browser |
| New Create entry points recreate the clutter | One chooser; remove the others in the same change |
| Hive model change breaks stored lessons | New fields at new indexes; backward-compatibility tests |
| Display name collides with educator public name | Decide the relationship before shipping |
| Avatar or board export adds dependencies or web quirks | Make the dependency decision explicitly; test in all browsers |
| UI localization is larger than expected | String-extraction spike before committing |
| Theme work changes look without improving comfort | Contrast numbers plus moderated long-session testing |
| Story mode becomes decoration | Learning objective required; retrieval follows; measure delayed recall |

---

## 10. Decisions for owner review

1. **Library:** Approve measuring first, then the subtractive changes in 5.1 (collapse source chips, merge banners, remove hard-coded count). Or choose to go straight to intent groupings.
2. **Create:** Approve one chooser entry plus the empty-search Create (A1, A2).
3. **Words:** Approve renaming and repositioning the spelling entry now, and holding "Vocabulary" until W2.
4. **Audio:** Approve reproducing the report first, reusing `AudioControlWidget`, and the in-lesson reader sheet (A3). Confirm that no global app-bar volume control will be added (A4).
5. **Display name:** Approve using the existing `display_name` after confirming the policy, and decide how it relates to the educator public name.
6. **Short answers:** Approve adding accepted answers and a declared grading method, and decide whether lesson-path grading stays client-side.
7. **Theme:** Approve the evidence audit, and decide whether to add System and reconsider the dark default.
8. **Whiteboard:** Approve v1 scope (PNG save, reference-image open), pending a second learner's confirmation (A5).
9. **Dependencies:** Decide `file_picker`/`image_picker` versus direct `web` package use for avatar picking and board import/export.
10. **Language:** Approve learning-language pilot first; commission the UI-localization spike separately.
11. **Engagement:** Approve a separate Content format preference (A6, A7) and a two-subject pilot.
12. **Long answers:** Agree to defer and store as notes only.

---

## 11. References carried over from v1

These were cited in v1 and are not re-verified in this revision; verify before relying on any specific figure.

- W3C, Web Content Accessibility Guidelines (WCAG) 2.2: https://www.w3.org/TR/WCAG22/
- U.S. Section 508, Making Color Usage Accessible: https://www.section508.gov/create/making-color-usage-accessible/
- Carpenter, Pan & Butler (2022), spacing and retrieval practice, *Nature Reviews Psychology*.
- Mayer (2017), Using multimedia for e-learning, *Journal of Computer Assisted Learning*.
- Narrative vs. expository text meta-analysis (PubMed 33410100).
- Council of Europe, CEFR Companion Volume (2020).
- Internal: `UI_ARCHITECTURE_LOCKED.md`, `docs/design/LEARNING_UI_RESEARCH.md`, `docs/design/COLOR_SYSTEM_GUIDELINES.md`, `docs/product/LITERACY_ACCESSIBILITY_PLAN.md`, Word Learning W1 acceptance report.

---

## 12. Final recommendation

Start with the work that removes friction without adding surface area: reproduce Ashley's reader issue, test and then simplify Library (one Create, fewer chip rows), fix the word-list label, and make the existing audio controls consistent and reachable from the lesson. Add the display name next, since the data field already exists. Then do the evidence-based theme work, the short-answer model change, and the contained builds (avatar, whiteboard). Treat language learning and stories as measured pilots.

> **LearningApp should make it easy to find the right thing, understand it in the way that works best for the learner, practice it meaningfully, and come back because learning feels useful, not because the app is trying to keep them scrolling.**
