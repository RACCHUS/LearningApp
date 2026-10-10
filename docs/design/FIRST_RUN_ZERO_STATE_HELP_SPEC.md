# First-Run Zero State + Searchable Help — Implementation-Ready UX Spec

**Status:** Approved design direction; ready for implementation  
**Applies to:** Learn, Library, Progress, router, Settings/help discovery  
**Decision:** The Learn zero state *is* onboarding. There is no separate first-run wizard.

---

## 1. Product decision

A new learner should experience product value before being asked to configure study behavior.

The app must **not** require a first-run sequence for:

- daily study goals,
- timers or Pomodoro settings,
- reminders/notifications,
- streaks or XP,
- batch size,
- recall-before-reveal,
- focus mode,
- sample lessons,
- or any other optional study mechanic.

Those capabilities remain available later through **contextual discovery**, **Settings**, and a new **searchable Help** surface.

### Locked first-run principle

> **Choose something to learn, then start. Configure the system only when the learner asks or when the feature becomes relevant.**

No setup wizard is allowed between app launch and the Learn zero state.

---

## 2. First-run flow

### Current flow to remove

```
Launch
  ↓
/onboarding
  ↓
Welcome
  ↓
Set daily goal
  ↓
Feature tour
  ↓
Import sample lesson
  ↓
/learn
```

### Replacement

```
Launch
  ↓
/learn
  ↓
No LearningContext?
  ↓
LearnZeroState
  ↓
Find something to learn ─────────→ Library
            OR
Create your own ─────────────────→ CreateTargetDialog
```

No persisted `hasCompletedOnboarding` flag is required for routing.

Existing installations may retain the old SharedPreferences key; it becomes inert and can be removed opportunistically later. No data migration is necessary.

The legacy `/onboarding` URL should redirect to `/learn` for compatibility rather than rendering the old wizard.

---

## 3. Learn zero-state design

The existing `LearnZeroState` is the foundation. This is an evolution, not a new screen.

### Standard zero state

```
┌──────────────────────────────────────────┐
│ Learn                         [?] [Acct] │
├──────────────────────────────────────────┤
│                                          │
│              ◉ compass                   │
│                                          │
│       What do you want to learn?         │
│                                          │
│  Find an exam, certification, course,    │
│  or subject and start from there.        │
│                                          │
│        [ Find something to learn ]       │
│                                          │
│             Create your own →            │
│                                          │
└──────────────────────────────────────────┘
```

### Copy

**Title:**  
`What do you want to learn?`

**Body:**  
`Find an exam, certification, course, or subject and start from there.`

**Primary CTA:**  
`Find something to learn` → `/library`

**Secondary CTA:**  
`Create your own →` → `CreateTargetDialog.show(context)`

The CTA language deliberately describes the learner's task instead of exposing the app's information architecture. "Explore learning" is acceptable internally but the implementation should prefer "Find something to learn."

### Empty catalog variant

If the discoverable catalog really is empty:

**Title:** `Create your first learning goal`

**Body:** `Create your own exam, course, certification, or subject to start learning.`

**Primary:** `Create a goal`

**Secondary:** `Browse library →`

Do not render a disabled search CTA or a dead-end empty Library as the recommended action.

### Explicitly absent

The first-run surface must not contain:

- "Welcome" carousel,
- page indicators,
- feature marketing,
- timer configuration,
- daily-goal picker,
- reminder permission prompt,
- streak/XP controls,
- personalization questionnaire,
- sample lesson import,
- forced sign-in,
- or a "Skip" button.

There is nothing to skip because there is no onboarding flow.

---

## 4. Help entry point

A persistent **Help** utility is allowed in the top-level app bars:

```
Learn / Library / Progress                    [?] [Account]
```

Use:

- icon: `Icons.help_outline`
- tooltip: `Help`
- semantic label: `Help`
- minimum target: 48×48 logical pixels
- no badge, dot, animation, or attention treatment

Help is available to signed-in users, anonymous users, and guests.

It is a utility, **not** a fourth navigation destination. The bottom navigation remains exactly:

`Learn · Library · Progress`

### Placement

In top-level app bars:

```dart
actions: const [
  HelpAction(),
  AccountActions(),
]
```

The Help icon appears immediately before account/settings actions.

This trailing pair is required on Learn (zero state and active context), Library, and Progress. Help must remain visible when the learning-context switcher is present. On signed-out/guest chrome the order is `Help`, then `Log in`, then `Settings`.

---

## 5. Searchable Help surface

### Interaction

Tap `?` → open `HelpCenterSheet`.

Responsive presentation:

- **Phone / narrow tablet:** near-full-height modal bottom sheet.
- **Wide tablet / desktop / web:** modal panel/dialog, max width 560dp.
- Browser/system Back closes Help before leaving the underlying screen.
- Opening Help must not mutate learning state.

### Initial view

```
┌──────────────────────────────────────┐
│ Help                            [×]  │
│                                      │
│ [ 🔍 Search help...                ] │
│                                      │
│ Getting started                      │
│   Find something to learn        →   │
│   How learning paths work        →   │
│                                      │
│ Studying                             │
│   Study timer & breaks           →   │
│   Focus mode                     →   │
│   Cards per study session        →   │
│   Recall before reveal           →   │
│                                      │
│ Practice & exams                     │
│   Flashcards                      →  │
│   Practice questions              →  │
│   Mock exams                      →  │
│                                      │
│ Progress                             │
│   Completion vs retention         →  │
│                                      │
│ Goals & motivation                   │
│   Daily study goal                →  │
│   XP, streaks & celebrations      →  │
│                                      │
│ Creating content                     │
│   Create your own learning goal   →  │
│                                      │
│ Account & settings                   │
│   Sign in and device settings     →  │
└──────────────────────────────────────┘
```

### Search behavior

Search is local and instant. v1 does **not** require AI, embeddings, a network call, or a backend search service.

Searchable fields:

- topic title,
- aliases,
- keywords,
- summary,
- body text.

Normalize case and punctuation. Token matching is sufficient for v1.

Examples:

| Query | Must surface |
|---|---|
| `timer`, `pomodoro`, `break` | Study timer & breaks |
| `goal`, `minutes per day` | Daily study goal |
| `cards`, `batch` | Cards per study session |
| `focus`, `distraction` | Focus mode |
| `retention`, `mastery`, `progress` | Completion vs retention |
| `streak`, `xp` | XP, streaks & celebrations |
| `mock exam`, `practice test` | Mock exams |
| `create`, `my own` | Create your own learning goal |

No-results copy:

`No help topics matched that search.`

Secondary text:

`Try a shorter phrase or open Settings to browse available controls.`

Action: `Open Settings`

---

## 6. Help content model

Keep the first version static and typed.

Suggested model:

```dart
enum HelpCategory {
  gettingStarted,
  studying,
  practiceAndExams,
  progress,
  goalsAndMotivation,
  creatingContent,
  accountAndSettings,
}

class HelpTopic {
  final String id;
  final HelpCategory category;
  final String title;
  final String summary;
  final String body;
  final List<String> keywords;
  final HelpActionTarget? action;
}

sealed class HelpActionTarget {}

class HelpRouteAction extends HelpActionTarget {
  final String route;
  final String label;
}

class HelpCallbackAction extends HelpActionTarget {
  final String actionId;
  final String label;
}
```

Suggested files:

```
lib/models/help_topic.dart
lib/data/help_topics.dart
lib/services/help_search_service.dart
lib/widgets/help/help_action.dart
lib/widgets/help/help_center_sheet.dart
lib/widgets/help/help_topic_view.dart
```

Do not store Help topics in Supabase for v1. Help must remain available offline and before login.

---

## 7. Initial Help topic actions

Where a useful direct action exists, Help should take the learner there instead of merely explaining it.

| Topic | Primary action |
|---|---|
| Find something to learn | `Open Library` → `/library` |
| Study timer & breaks | `Got it` initially; timer remains discoverable in study UI |
| Focus mode | `Got it`; explain the in-study focus control |
| Cards per study session | `Open Settings` → `/settings` |
| Recall before reveal | `Open Settings` → `/settings` |
| Daily study goal | `Open Settings` → `/settings` |
| XP, streaks & celebrations | `Open Motivation settings` → `/settings/motivation` |
| Completion vs retention | `Open Progress` → `/progress` |
| Create your own learning goal | `Open Library` → `/library`; Library exposes Create |
| Sign in and device settings | `Open Settings` → `/settings` |

A later iteration may deep-link directly to a specific Settings section, but that is not required to ship this change.

---

## 8. Contextual discovery policy

Searchable Help replaces forced explanation. Contextual hints may complement it later.

Rules:

1. A hint appears only after the learner reaches the feature's relevant context.
2. A hint is dismissible.
3. A hint never blocks the primary task.
4. A dismissed hint is not repeatedly shown.
5. No more than one new-feature hint is shown in a session.
6. Help always remains the durable way to rediscover the feature.

Examples:

- First time a learner opens a study screen: optional one-time pointer to Focus mode.
- After several study sessions: optional prompt that a daily goal exists.
- First long session: optional explanation of the timer/break control.

These prompts are **deferred from the first implementation**. Ship zero-state first run + searchable Help first.

---

## 9. Router and persistence changes

Implementation must:

1. Remove `hasCompletedOnboarding()` from the global router redirect.
2. Remove the forced `/onboarding` redirect.
3. Make `/learn` the real first-render destination.
4. Keep `/` → `/learn`.
5. Keep a temporary legacy `/onboarding` → `/learn` redirect.
6. Remove the onboarding screen once no code references it.
7. Stop writing `hasCompletedOnboarding`.
8. Stop writing `dailyGoalMinutes` as a startup side effect.
9. Stop importing `assets/sample_lesson.json` as a startup side effect.

Bundled lessons already load independently from `assets/lessons/` through the normal lesson/catalog provider. Removing onboarding must not remove those catalog assets.

Existing `dailyGoalMinutes` values remain respected. New users simply have no explicit goal until they choose one.

---

## 10. State behavior

### Fresh install, zero contexts

Expected:

`/learn → ChooseSomething → LearnZeroState`

No preferences or content are mutated simply because the user opened the app.

### Fresh install, bundled catalog available

Primary zero-state CTA opens Library with the bundled/catalog content discoverable.

### Signed-out user

The same zero state is usable. Top-right chrome still renders:

`Help · Log in · Settings`

Help remains available offline and before login.

### Returning user with context

Nothing changes in the active Learn flow. Continue/review behavior remains governed by the existing Next-Action engine.

---

## 11. Accessibility

Required:

- Help icon has tooltip + semantic label.
- Search field has label `Search help`, not placeholder-only semantics.
- Search results are keyboard navigable on web/desktop.
- Escape closes the modal Help surface on desktop/web.
- Focus moves into the search field when Help opens when that does not conflict with touch accessibility.
- Closing Help returns focus to the Help button.
- All text follows existing theme scaling; do not lock fixed text heights.
- Do not encode topic category by color alone.

---

## 12. Implementation sequence

### Slice 1 — Remove onboarding gate

Files:

- modify `lib/providers/router_provider.dart`
- retire/delete `lib/screens/onboarding/onboarding_screen.dart`
- update router/onboarding tests

Ship criterion: fresh install lands directly on Learn zero state.

### Slice 2 — Finalize zero-state copy

Files:

- modify `lib/widgets/learn/zero_state.dart`
- update zero-state/direct-access widget tests

Ship criterion: one primary discovery CTA, one secondary create CTA, no setup options.

### Slice 3 — Searchable Help

Files:

- add Help model/data/search service
- add HelpAction + HelpCenterSheet + topic view
- add HelpAction to Learn, Library and Progress app bars
- add unit/widget tests

Ship criterion: timer, goal, focus, batch, retention and mock-exam queries all resolve offline.

### Slice 4 — Documentation cleanup

- retire any documentation that still calls onboarding/timer setup a first-run requirement
- keep study mechanics themselves intact
- do not remove Settings or study timer functionality

---

## 13. Acceptance tests

The implementation is done only when all of these pass:

1. **Fresh first visit renders Learn, not Onboarding.**
2. **No-context state renders `What do you want to learn?`.**
3. **Primary zero-state action reaches Library in one action.**
4. **Secondary action opens custom goal creation.**
5. **Fresh launch does not create `dailyGoalMinutes`.**
6. **Fresh launch does not import `sample_lesson.json`.**
7. **Bundled `assets/lessons/` content remains discoverable.**
8. **Legacy `/onboarding` redirects to `/learn`.**
9. **Help icon appears on Learn, Library and Progress.**
10. **Help works signed out.**
11. **Searching `timer` returns Study timer & breaks.**
12. **Searching `goal` returns Daily study goal.**
13. **Searching `retention` returns Completion vs retention.**
14. **Help action links navigate correctly.**
15. **Help search works with no network connection.**
16. **Closing Help returns to the same screen without changing learning state.**
17. Existing Next-Action, direct-access, settings, timer, motivation, and study tests stay green.

---

## 14. Non-goals

This change does **not**:

- redesign Library,
- redesign Settings,
- remove timers,
- remove daily goals,
- remove motivation mechanics,
- add an AI support chatbot,
- add support tickets,
- add remote help CMS,
- add onboarding analytics,
- or introduce new learning recommendation logic.

The goal is narrower: **remove premature configuration and make advanced capability discoverable on demand.**

---

## 15. Future extension

The local Help index is deliberately structured so a future AI assistant can search or answer from the same `HelpTopic` corpus. If/when that ships, local deterministic search remains the fallback.

The Help experience should evolve from:

`Search help → topic`

to optionally:

`Ask LearningApp → answer + relevant actions`

without changing the first-run experience.
