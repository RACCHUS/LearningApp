# LearningApp

A Flutter progressive web app (PWA) for discovering or creating educational material, studying it, and tracking progress across lessons, courses, certifications, licensure exams, academic programs, and career pathways.

**Status:** Active development. Features described here are implemented in the repository; that does not guarantee that each feature has production content or is publicly deployed.

## Learner experience

The current app has three primary destinations:

- **Learn** — resume the active learning context or choose what to study next.
- **Library** — discover learning targets, courses, lessons, and concepts; direct selection is always available.
- **Progress** — review structural completion and retained knowledge without distracting from study.

**No forced onboarding:** a new visitor lands directly on Learn (the home destination). When no learning context exists, the zero state offers **Find something to learn** and **Create your own**. The app does not require timer, goal, reminder, or streak setup on first launch. A searchable, locally available **Help** (`?`) control sits at the **top right** of Learn, Library, and Progress, immediately before Settings and Log in (or the signed-in account avatar). Legacy `/onboarding` links redirect to `/learn`.

The interaction baseline is [UI_ARCHITECTURE_LOCKED.md](UI_ARCHITECTURE_LOCKED.md) (v1.6); see also the [zero-state and searchable Help specification](docs/design/FIRST_RUN_ZERO_STATE_HELP_SPEC.md).

## Implemented capabilities

### Learning architecture and catalog

- **Learning contexts** scope the current study experience without requiring a rigid goal/course/module hierarchy for every learner.
- **Versioned targets and curricula** represent formal learning destinations, curriculum nodes, and related teaching content.
- A **canonical concept layer** allows knowledge evidence to be reused across learning contexts while keeping each context's content relevant.
- **Completion and retention are separate:** finishing content is not the same as remembering it.
- Lesson creation, courses, saved study sets, content selection, and library/catalog browsing.
- Taxonomy and career-path exploration supported by official **CIP, SOC, and O*NET** ingestion and verification tooling.

### Navigation and Help

- On desktop and tablet (**≥900dp**), the three destinations use a **collapsible `NavigationRail`**. The rail can expand or collapse; a search field on the rail opens **Library** with that query. Phone layouts keep the bottom navigation bar and do not use the rail.
- **Help** is required chrome on Learn, Library, and Progress: top-right `HelpAction`, then `AccountActions` (Log in + Settings when signed out or guest; account avatar when signed in). Help must not disappear when the learning-context switcher is visible.

### Create your own goal

**Create your own** keeps all fields editable. Suggestions never block custom text.

The form has four sections:

| Section | What is suggested | What the learner may still type |
| --- | --- | --- |
| **Goal type** | The six stored target types (career, academic program, certification, licensure exam, standardized exam, curriculum standard). | Any of those types. Type is a dropdown, not free text. |
| **Title** | Trusted catalog titles for the selected type. Career titles also match **BLS/O\*NET SOC** occupations; academic titles also match **NCES CIP** programs. Taxonomy search is bounded in the database (typically after three characters). | Any custom title. |
| **Organization** | Provider or institution names from trusted catalog rows of that type. Academic programs store the value in `institution_name`; other types use `provider_name`. | Any custom organization. |
| **Description / purpose** | Purpose text from trusted catalog rows of that type. | Any custom description. |

Choosing an existing **catalog** goal can open that record instead of creating a duplicate. Choosing a **SOC or CIP** classification copies reference text into the form and still creates a **private personal draft**. It does not mark the new row official and does not publish it into the trusted catalog.

### Catalog trust and provenance

Library default browsing is the **trusted catalog** (published official records and approved community records). Unreviewed personal goals stay out of that default list. Learners can still switch filters:

- Trusted catalog
- Official
- Reviewed community
- My goals

Source labels on targets and Library rows: **Official**, **Catalog**, **Community · reviewed**, **Community · pending review**, **Private · not approved**, **My draft**.

Client-created goals always start as **private, unreviewed drafts**. Owners may **Submit for community review**. They cannot set `is_official`, publish publicly, or approve their own entries. Only a **service-role** moderation or ingestion workflow can approve and publish a useful community goal. Creators cannot delete official or already-approved public records.

Hosted databases must apply `supabase/migrations/20261009000005_learning_target_catalog_provenance.sql` **before** deploying the app that depends on these labels and policies. See [Hosted Migration Rollout](docs/HOSTED_MIGRATION_ROLLOUT.md).

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

### Browser automation & MCP tooling

Model Context Protocol (MCP) servers are configured for developers and AI agents to inspect and automate browser verification of the Flutter PWA:

- **`chrome-devtools` (`chrome-devtools-mcp`)**: Inspect console errors, track network traffic, evaluate JavaScript in the running client, and audit PWA/performance metrics.
- **`playwright` (`@playwright/mcp`)**: Automate end-to-end user journeys (navigation rail, search, quizzes, onboarding redirects) across Chrome browser tabs.

See [AGENTS.md](AGENTS.md) for full MCP server details and workflows.

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

- [Agent & MCP Guidelines](AGENTS.md): Model Context Protocol servers (Chrome DevTools, Playwright) and architectural rules for AI agents and automated testing.
- [UI Architecture — Locked Baseline](UI_ARCHITECTURE_LOCKED.md): three-destination navigation, collapsible searchable rail, Help chrome, catalog filters, zero states, direct access, and progress UX.
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
