# Implementation Plan — Remove First-Run Wizard + Add Searchable Help

**Depends on:** `docs/design/FIRST_RUN_ZERO_STATE_HELP_SPEC.md`  
**Architecture baseline:** `UI_ARCHITECTURE_LOCKED.md` v1.5

This plan is intentionally implementation-oriented. It is not another design round.

---

## Task 1 — Remove the onboarding gate

### Modify
- `lib/providers/router_provider.dart`

### Remove/retire
- `lib/screens/onboarding/onboarding_screen.dart`

### Behavior
- Delete import of `onboarding_screen.dart`.
- Delete async `hasCompletedOnboarding()` redirect logic.
- Preserve `/` → `/learn`.
- Add legacy `/onboarding` → `/learn` redirect.
- Initial location stays `/learn`.

### Regression requirements
- No startup write to `hasCompletedOnboarding`.
- No startup write to `dailyGoalMinutes`.
- No startup import of `assets/sample_lesson.json`.

---

## Task 2 — Tighten Learn zero-state copy

### Modify
- `lib/widgets/learn/zero_state.dart`

### Standard state copy
- Title: `What do you want to learn?`
- Body: `Find an exam, certification, course, or subject and start from there.`
- Primary: `Find something to learn`
- Secondary: `Create your own →`

### Catalog-empty copy
Keep the existing create-first behavior, but ensure browse is visibly secondary.

### Keys
Preserve existing keys where reasonable to minimize test churn. If copy-specific test keys are renamed, do so in the same commit as tests.

---

## Task 3 — Add typed Help model and local catalog

### Add
- `lib/models/help_topic.dart`
- `lib/data/help_topics.dart`
- `lib/services/help_search_service.dart`

### Search requirements
- local/offline
- case-insensitive
- punctuation-insensitive
- title/keyword matches rank above body matches
- stable ordering for equal scores
- empty query returns categorized default topics

### Minimum topic coverage
- Find something to learn
- Study timer & breaks
- Focus mode
- Cards per study session
- Recall before reveal
- Flashcards
- Practice questions
- Mock exams
- Completion vs retention
- Daily study goal
- XP, streaks & celebrations
- Create your own learning goal
- Sign in and device settings

---

## Task 4 — Add Help UI

### Add
- `lib/widgets/help/help_action.dart`
- `lib/widgets/help/help_center_sheet.dart`
- `lib/widgets/help/help_topic_view.dart`

### Responsive contract
Use one shared content widget.

Suggested helper:

```dart
Future<void> showHelpCenter(BuildContext context)
```

- narrow: `showModalBottomSheet(isScrollControlled: true)`
- wide: `showDialog` with constrained width

Do not create separate mobile and desktop content implementations.

---

## Task 5 — Add Help to top-level app bars

### Modify
- `lib/screens/learn/learn_screen.dart`
- `lib/screens/library/library_screen.dart`
- `lib/screens/progress/progress_screen.dart`

### Locked order

```dart
actions: const [
  HelpAction(),
  AccountActions(),
]
```

No badge/unread state.

---

## Task 6 — Tests

### Add
- `test/services/help_search_service_test.dart`
- `test/widgets/help_center_test.dart`
- `test/widgets/first_run_zero_state_test.dart`

### Modify
- router tests that reference onboarding
- zero-state/direct-access tests
- account/app-bar tests as needed

### Required assertions

#### Router
- fresh prefs do not redirect to `/onboarding`
- `/onboarding` redirects to `/learn`
- `/` redirects to `/learn`

#### First run
- zero contexts → Learn zero state
- daily-goal key is not written by startup
- no onboarding-complete key is required
- no sample lesson import occurs as a first-run side effect

#### Help search
- `timer`, `pomodoro`, `break` → Study timer & breaks
- `goal` → Daily study goal
- `batch` → Cards per study session
- `retention` → Completion vs retention
- `mock exam` → Mock exams
- nonsense query → no-results state

#### Help UI
- HelpAction visible in Learn/Library/Progress app bars
- Help works when auth provider represents guest/signed-out state
- topic action routes work
- close returns to underlying screen

#### Existing behavior
- Next-Action tests remain unchanged/green
- study timer tests remain green
- Settings tests remain green
- motivation tests remain green

---

## Task 7 — Cleanup

After the implementation compiles and router tests prove there are no references:

- delete `lib/screens/onboarding/onboarding_screen.dart`
- remove dead onboarding constants/helpers
- leave existing SharedPreferences values untouched
- do not delete `assets/sample_lesson.json` solely because onboarding stopped using it; remove only if repository search proves it has no remaining purpose

---

## Suggested PR structure

One PR is appropriate because the routing removal and Help discoverability are one UX change.

Suggested commits:

1. `refactor(onboarding): make Learn zero state the first-run experience`
2. `feat(help): add offline searchable help center`
3. `test(ux): cover first-run and help discoverability`
4. `docs(ux): align first-run and help architecture`

---

## Definition of done

Implementation is ready to merge when:

- all acceptance tests in the design spec pass,
- `flutter analyze` has 0 issues,
- full `flutter test` passes,
- manifest lint/dry-run remain green,
- existing database/taxonomy CI is unaffected,
- and a fresh browser profile can reach useful learning content without seeing or configuring a timer, goal, reminder, streak, or feature-tour screen.
