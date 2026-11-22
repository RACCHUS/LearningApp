# Accessibility review: learning support (P3.3)

Master plan v2.6 P3.3 asks for "UI parity, affordance tests and accessibility review" of the contextual help: the **Learning help** action, the choice sheet, Bridges with their checks, outside resources (companions) with the depth control, and the coverage chips and Need cards on Target Detail. This is that review, dated 2026-11-22.

## Method

Automated, repeatable checks in `test/widgets/learning_support_accessibility_test.dart`, run in CI with the other widget tests:

- Flutter's accessibility guidelines on every screen and every screenful of an open Bridge (scrolled to the Back button), in the **light and dark** app themes, at **phone width** (400 px):
  - `androidTapTargetGuideline` (48×48 dp) and `iOSTapTargetGuideline` (44×44 pt),
  - `labeledTapTargetGuideline` (every tappable control has a label a screen reader can read),
  - `textContrastGuideline` (WCAG AA 4.5:1 for normal text, 3:1 for large text).
- Every bundled Bridge opened at **200% text size** on a phone, which fails on any layout overflow.
- The theme colours are the real app colours. Only the web fonts are left out in tests (`AppTheme.useWebFonts = false`), because they cannot be downloaded there; font family does not change contrast.

These sit next to the existing checks: the colour-token audit (`test/theme/contrast_audit_test.dart`, `docs/design/CONTRAST_AUDIT.md`), the help flow tests (`test/widgets/learning_support_flow_test.dart`, `test/widgets/study_surface_help_test.dart`) and the companion flow tests (`test/widgets/external_companion_flow_test.dart`).

## Findings

| # | Surface | Finding | Fix |
|---|---|---|---|
| 1 | Need cards (Target Detail) | "Make my own version" and "Ask for it" were 3.91:1 in the light theme. The card used `surfaceContainerHighest`, which is darker than the `surfaceContainerLow` the primary colour is tuned against. | Card now uses `surfaceContainerLow` with an outline border; 4.5:1 or better in both themes. |

Nothing else failed: the help action, choice sheet, Bridge teaching and examples, numeric and choice checks, misconception feedback, the outside-resource card with its depth control, the "not yet reviewed" notice and the Back button all meet the tap-target, labelling and contrast guidelines in both themes. No Bridge overflows at 200% text.

## P3.3 acceptance, item by item

- **Same support on web and mobile.** One widget tree serves both; the checks run at phone width, and the help flow tests run at tablet width.
- **Pre-reader and audio.** Every Bridge declares `plain_language`, `screen_reader_ready`, `audio_script_available` and `needs_images: false`; the Bridge test in CI rejects one that needs images. All text is real text, so read-aloud and screen readers get it. Coverage chips and states carry text labels, never colour alone (§13.0).
- **No answer leak in simulations.** Exam simulations do not mount the help action at all. In practice questions, help opens Bridges, which contain only their own independently written checks, never the current question or its key.
- **No double help overlay.** Exactly one help action per surface; covered by the "exactly one help action" test (A21, A59).

## Limits

- Automated guidelines are not a full audit. Not covered here: a manual pass with TalkBack, VoiceOver and NVDA, keyboard-only navigation order on web, and reduced-motion. These need a person with the devices, and are listed for the owner or a volunteer reviewer.
- The review covers the learning-support surfaces only, not the whole app.
