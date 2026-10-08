# LearningApp

A Flutter progressive web app (PWA) for discovering or creating educational material, studying it, and tracking progress across lessons, courses, certifications, licensure exams, academic programs, and career pathways.

**Status:** Active development. Features described here are implemented in the repository; that does not guarantee that each feature has production content or is publicly deployed.

## Learner experience

The current app has three primary destinations:

- **Learn** — resume the active learning context or choose what to study next.
- **Library** — discover learning targets, courses, lessons, and concepts; direct selection is always available.
- **Progress** — review structural completion and retained knowledge without distracting from study.

**No forced onboarding:** a new visitor lands directly on Learn. When no learning context exists, the zero state offers **Find something to learn** and **Create your own**. The app does not require timer, goal, reminder, or streak setup on first launch. A searchable, locally available **Help** utility is accessible from Learn, Library, and Progress. Legacy `/onboarding` links redirect to `/learn`.

The interaction baseline is [UI_ARCHITECTURE_LOCKED.md](UI_ARCHITECTURE_LOCKED.md) (v1.5); see also the [zero-state and searchable Help specification](docs/design/FIRST_RUN_ZERO_STATE_HELP_SPEC.md).

## Implemented capabilities

### Learning architecture and catalog

- **Learning contexts** scope the current study experience without requiring a rigid goal/course/module hierarchy for every learner.
- **Versioned targets and curricula** represent formal learning destinations, curriculum nodes, and related teaching content.
- A **canonical concept layer** allows knowledge evidence to be reused across learning contexts while keeping each context's content relevant.
- **Completion and retention are separate:** finishing content is not the same as remembering it.
- Lesson creation, courses, saved study sets, content selection, and library/catalog browsing.
- A collapsible, searchable sidebar on desktop/tablet; searches open the Library.
- Database-derived goal suggestions for titles, organizations, and purposes, with editable custom values.
- Catalog provenance labels distinguish platform-official records, curated catalog records, and reviewed community material. Newly created personal targets are private drafts. Owners may request review, but only trusted service-role moderation can approve and publish community targets.
- Taxonomy and career-path exploration supported by official **CIP, SOC, and O*NET** ingestion and verification tooling.

### Study and assessment

- Lesson study, flashcards, multiple-choice practice, and review.
- Optional focus mode, recall-before-reveal prompts, session batching, and study/break timers (including longer recovery breaks).
- **Diagnostic pre-assessments** gated on enough published, canonical assessment items and concept coverage for the selected target version.
- Diagnostics use established assessment rendering and scoring. Missing content does **not** produce fabricated questions.
- Diagnostic results can record concept evidence, suggest persistent remedial study material, and activate the correct curriculum context. Initial diagnostic evidence is explicitly distinguished from long-term target readiness.

### Supporting integrations

- Supabase for PostgreSQL content, authentication, and access policies; Hive for local persistence.
- Voice input, text-to-speech, and hands-free study integration.
- AI-assisted lesson/content generation where configured, with review of generated educational material.
- Local/offline storage and synchronization capabilities; availability varies by feature and cached data.

## Future product direction

These goals are **not claims of shipped functionality**:

- Community feedback and recommendation ranking beyond the initial moderation and filtering system.
- Creator publishing and optional sale of educational materials.
- Broader first-party content and AI-assisted course generation for exams, certifications, licenses, and other subjects.

## Technology stack

| Area | Technology |
| --- | --- |
| App | Flutter (CI pinned to **3.32.8**), Dart SDK `>=3.8.0 `<4.0.0 |
| State/navigation | Riverpod, GoRouter |
| Backend | Supabase (PostgreSQL, Auth, Storage, Row Level Security) |
| Local storage | Hive, SharedPreferences |
| Notifications | Firebase Cloud Messaging and local notifications |
| Voice | `flutter_tts`, `speech_to_text` |
| CI/data validation | GitHub Actions, Flutter tests and web build, Supabase/pgTAP, manifest and official taxonomy tooling |

## Getting started

### Prerequisites

- Flutter **3.32.8** (matching CI) and its compatible Dart SDK.
- Supabase project credentials and configured Firebase options.
- Optional for local database tests: Supabase CLI and Docker.

```bash
git clone https://github.com/RACCHUS/LearningApp.git
cd LearningApp
cp .env.example .env
# PowerShell alternative: Copy-Item .env.example .env
# Fill in the client configuration values in .env
flutter pub get
flutter run -d chrome
```

Copy the variable names from [.env.example](.env.example). Supabase initialization requires valid `SUPABASE_URL` and `SUPABASE_ANON_KEY`; Firebase options are maintained in `lib/config/firebase_options.dart`. If changing generated model code, run `dart run build_runner build --delete-conflicting-outputs`.

**Client secret safety:** never place service-role credentials or other server-only secrets in the Flutter web client's `.env`. Bundled client configuration should be treated as inspectable.

### Local verification

```bash
flutter analyze
flutter test
flutter build web --release

# Curriculum checks
dart run tool/lint_manifest.dart --dir content/
dart run tool/ingest_curriculum.dart --dir content/ --dry-run
dart run tool/verify_migration_history.dart --base-ref origin/main
```

For a disposable local Supabase database (requires Docker):

```bash
supabase start
supabase db reset
supabase test db
```

**Do not run `supabase db reset` against production.** Database migrations under `supabase/migrations/` must remain **append-only**: fix previously merged behavior with a new migration, not by editing prior migrations. CI verifies incremental upgrades, clean-slate migrations, database tests, and official taxonomy ingestion. Review the [hosted migration rollout guide](docs/HOSTED_MIGRATION_ROLLOUT.md) before changing a hosted database.

### Continuous integration

PRs targeting the protected `main` branch run automated Flutter analysis, tests, web build, curriculum manifest checks, migration immutability checks, database upgrade/reset tests, and official taxonomy validation. See [Flutter CI](.github/workflows/flutter-ci.yml) and [Official Taxonomy Data](.github/workflows/taxonomy-official-data.yml).

## Key documentation

- [UI Architecture — Locked Baseline](UI_ARCHITECTURE_LOCKED.md): three-destination navigation, zero states, direct access, and progress UX.
- [Learning Architecture v2](LEARNING_ARCHITECTURE_V2.md): learning contexts, target versions, global knowledge, assessment evidence, and curriculum ingestion.
- [Canonical Taxonomy Architecture](CANONICAL_TAXONOMY_ARCHITECTURE.md): education and occupation classification ingestion and mapping.
- [First-Run Zero State and Help](docs/design/FIRST_RUN_ZERO_STATE_HELP_SPEC.md): no-wizard first visit and searchable help behavior.
- [Hosted Migration Rollout](docs/HOSTED_MIGRATION_ROLLOUT.md): hosted database considerations.
- [Deployment Guide](DEPLOYMENT_GUIDE.md): older deployment reference; verify steps against the present setup before release.
- [Testing Guide](test/README.md): test conventions.

The current architecture documents supersede outdated navigation material in `docs/history/`.

## Contributing and branch policy

Create a feature branch, write appropriate regression tests, and submit a PR into `main`. Keep migrations append-only and do not bypass protected CI checks. Once work is merged and verified on `main`, its short-lived branch can be retired. Review unmerged and archival branches before deleting them.

## License

This repository is **public**, but no `LICENSE` file is included. Public visibility by itself does not grant reuse or redistribution permission. A license may be added later.
