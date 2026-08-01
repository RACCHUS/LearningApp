# Color System Refresh Plan

Created: 2026-08-01
Scope: low-risk, high-quality color improvements with minimal maintenance overhead.

## Goals
- Increase visual cohesion across screens.
- Reduce hardcoded color drift.
- Improve contrast/readability for colored chips and status UI.
- Keep implementation simple and maintainable.

## Phase 1 (Quick Wins)
- [x] Add semantic status color tokens via a ThemeExtension (success, warning, danger, info + on-colors).
- [x] Wire semantic tokens into app themes (light/dark).
- [x] Replace hardcoded status colors in high-traffic components:
  - [x] lib/providers/connectivity_provider.dart
  - [x] lib/widgets/review_content_widgets.dart (true/false + correctness feedback)
- [x] Improve lesson tag readability:
  - [x] Add a small token helper for readable foreground color.
  - [x] Update lib/widgets/lesson_card.dart tag chip styling for better contrast.
- [x] De-emphasize overuse of primary in home app bar hierarchy:
  - [x] lib/screens/home_screen.dart title color and utility icon emphasis.

## Phase 2 (Fast Follow)
- [x] Migrate remaining `Colors.green/red/orange/blue/grey` status-like usages in top-level screens to semantic tokens.
- [x] Centralize repeated level tier gradient/color mappings in `lib/widgets/level_badge.dart`.
- [x] Normalize “info/warning/error/success” card styles in settings + lesson creation flows.

## Phase 3 (Governance)
- [x] Add a short guideline to docs: prefer theme/tokens over hardcoded `Colors.*` in UI.
- [x] Add PR checklist item for new hardcoded colors.

## Success Criteria
- Analyzer clean.
- Existing tests pass.
- Visual consistency improved on: Home, Review, Lesson Cards, Connectivity banner.

## Notes
- Keep animations and behavior unchanged.
- No broad redesign; only tokenization and hierarchy tuning.
- Prefer incremental migration to reduce regression risk.

## Completion Snapshot
- Added semantic color extension and applied it to high-impact screens/widgets.
- Refactored repeated LevelTier palettes into a single shared mapping.
- Added governance docs/checklist:
  - `docs/design/COLOR_SYSTEM_GUIDELINES.md`
  - `.github/pull_request_template.md`
- Validation: analyzer clean for touched files; full test suite passing (976/0).
