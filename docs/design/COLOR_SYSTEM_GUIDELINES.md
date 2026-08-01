# Color System Guidelines

Created: 2026-08-01

## Purpose
Keep UI color usage consistent, accessible, and easy to maintain.

## Rules
- Prefer `Theme.of(context).colorScheme` for neutral and structural UI colors.
- Prefer `Theme.of(context).extension<SemanticColors>()` for semantic states:
  - `success`, `warning`, `danger`, `info` and their `on*` colors.
- Avoid introducing new hardcoded `Colors.*` values in screens/widgets for status UI.
- Reuse `DesignTokens` helpers for category/tag color handling.
- If a component needs custom brand colors (badges, achievements), centralize mapping in one place.

## Allowed Exceptions
- One-off decorative illustrations or celebratory effects where semantic meaning is not implied.
- Existing legacy UI not touched by the current PR (migrate incrementally).

## Migration Pattern
1. Replace hardcoded status colors with semantic colors.
2. Replace hardcoded neutral greys with `colorScheme.onSurfaceVariant`/container roles.
3. Keep behavior and layout unchanged while migrating color sources.
