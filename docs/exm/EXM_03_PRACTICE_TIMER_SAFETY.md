# EXM-03 — Local Practice Timer Safety (Draft)

**Development state:** Source and deterministic regression tests prepared. GitHub CI
and final real-browser acceptance are separate gates. No official timed simulation
is enabled by this change.

## Behavior and trust boundaries

- `ExamSessionNotifier` measures **active practice elapsed time** with a Dart
  `Stopwatch`-backed clock. A one-second `Timer.periodic` is only a UI
  refresh signal, never the authoritative elapsed-time counter.
- A delayed browser/event-loop callback cannot restore a lost second. Before
  an answer, flag, pause, or submission, the notifier synchronizes from the
  elapsed clock; an expired attempt refuses later answer/flag changes.
- Practice pause stops the clock. Resume **does not reset** the clock, start
  timestamp or recorded answers. This is deliberately a learner-controlled
  practice concession, **not a verified exam-room pause policy**.
- A timer-expired practice attempt remains `expired` when scored.
  Duplicate calls to `submitExam` return no second report. Starting a fresh
  practice attempt resets clock and submission guard.
- No new database persistence, simulation-grade claim, passing cutoff,
  source policy, RLS role, account export scope or retention policy.

## Limitations (must be visible in EXM-03 release planning)

The implementation is an **ephemeral, in-memory practice session**: it does
not restore a live countdown across page reloads or navigation to a new
Flutter application instance. Browser and OS suspension, clock precision,
platform Stopwatch behavior, and foreground repaint still require device tests.
A browser cannot securely prevent outside assistance, prove exam-room reference
use, or enforce official navigation/pause policies. EXM-03 strict modes must
not be exposed until verified part-scoped requirements, persisted interruption
semantics, navigation policy and original reviewed items are implemented.

## Deterministic automated regressions

`test/unit/assessment_engine/exam_practice_clock_test.dart` exercises:

1. Delayed elapsed time checked **before** a second answer/flag.
2. Practice pause ignoring stopped time; resume preserving session start.
3. Expired attempt evaluated once, with original expired status and duration.
4. Manual submit evaluated once, then clean new-attempt reset.
5. Timer callback reconciling a jump larger than its tick interval.
6. Zero-duration session immediately expiring and scoring at most once.

## Deferred manual browser acceptance

On synthetic nonproduction accounts only: verify countdown at start, switching
away for 30–60 seconds and returning, pause/resume preserving the same deadline,
tab visibility changes, laptop sleep/wake, navigation away/re-entry, two rapid
submission clicks, expiry while a confirmation dialog is open, and device clock
changes. Record browser/OS version, actual elapsed time, status and whether
a report was produced. Do not interpret this as official exam fidelity evidence.

The full EXM-03 profile policy, part-scope and interruption/refresh design
remain tracked in `EXM_00_EXAM_SUCCESS_ARCHITECTURE_PLAN.md`.
