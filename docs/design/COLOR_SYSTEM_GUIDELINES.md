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

- Pairs must meet WCAG 2.2 AA (4.5:1 text, 3:1 control boundaries). `test/theme/contrast_audit_test.dart` enforces this for theme tokens; see `CONTRAST_AUDIT.md`.
- Never signal state (correct/incorrect, success/error) by color alone: `success` and `danger` are nearly indistinguishable in grayscale and for red–green color vision deficiency. Add an icon or text.

## Allowed Exceptions
- One-off decorative illustrations or celebratory effects where semantic meaning is not implied.
- Existing legacy UI not touched by the current PR (migrate incrementally).

## Migration Pattern
1. Replace hardcoded status colors with semantic colors.
2. Replace hardcoded neutral greys with `colorScheme.onSurfaceVariant`/container roles.
3. Keep behavior and layout unchanged while migrating color sources.
