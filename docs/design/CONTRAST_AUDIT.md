# Color Contrast and Readability Audit

Created: 2026-11-06. Implements the "audit before redesign" steps of §5.5 in
[`docs/history/LEARNER_EXPERIENCE_IMPROVEMENT_PLAN_V2.md`](../history/LEARNER_EXPERIENCE_IMPROVEMENT_PLAN_V2.md). Follow
`COLOR_SYSTEM_GUIDELINES.md` for migrations.

## Method

- **Contrast:** `test/theme/contrast_audit_test.dart` builds `AppTheme.lightTheme()`
  and `AppTheme.darkTheme()` with the default brand. It computes WCAG 2.x
  contrast for every token foreground/background pair the themes define.
  Translucent colors are composited over their background first. Targets are
  WCAG 2.2 AA: 4.5:1 for normal text and 3:1 for control boundaries
  (1.4.11). The test fails on any token pair below AA. To regenerate the
  tables below, run:
  `flutter test test/theme/contrast_audit_test.dart --plain-name 'theme tokens'`.
- **Color vision and grayscale:** the same test simulates protanopia and
  deuteranopia (Viénot, Brettel & Mollon 1999) and grayscale (Rec. 709
  luminance). It reports how far apart `success` and `danger` stay.
- **Text scaling:** `test/widgets/theme_mode_selector_test.dart` renders the new
  theme picker on a 320 px viewport at 200% text size and checks it doesn't
  overflow.
- **Hard-coded color inventory:** `grep -rhoE "Colors\.[a-zA-Z]+" lib`.

## Findings before this change

| Theme | Pair | Before | Needs |
|---|---|---|---|
| Light | `primary` as text (links, text/outlined buttons) on background | 3.66:1 | 4.5:1 |
| Light | `primary` as text on card | 3.48:1 | 4.5:1 |
| Light | `onPrimary` (white) on `primary` (filled buttons) | 3.86:1 | 4.5:1 |
| Light | `warning` text on background | 2.96:1 | 4.5:1 |
| Light | `onWarning` on `warning` | 3.11:1 | 4.5:1 |
| Light | text-field border (`Colors.grey.shade300`) | ~1.3:1 | 3:1 |
| Dark | `outline` / text-field border (`#2A2D38`) on background | 1.41:1 | 3:1 |

All other token pairs already passed. Body text is 16.3:1 in light and 19.3:1
in dark.

## Changes in this PR

- **Light primary:** `AppTheme.accessibleLightPrimary` darkens the brand primary
  in 1% HSL lightness steps until it reaches 4.5:1 against light cards. That
  also covers white and the page background. The default `#0288D1` becomes a
  slightly deeper blue. Custom brands that already pass are unchanged.
- **Light warning:** `#ED6C02` changed to `#B45309`. It passes as text and with
  white text on it.
- **Control boundaries:** the dark `outline` changed to `#7A7E8C`, which is at
  least 3:1 on every dark surface. Text-field borders in both themes now use
  `colorScheme.outline`. The low-contrast `#2A2D38` stays as
  decorative card and divider borders, which 1.4.11 does not cover.
- **System theme:** Settings now offers **Light / Dark / System**, which
  follows the device setting. Previously it had a Dark Mode switch. The default
  is still Dark. No learner evidence supports changing it yet (see Open
  items).

## Results after this change


### Light theme tokens
| Pair | Ratio | Needs | Result |
|---|---|---|---|
| body text on background | 16.27:1 | 4.5:1 | pass |
| body text on card | 15.44:1 | 4.5:1 | pass |
| secondary text on background | 8.89:1 | 4.5:1 | pass |
| secondary text on card | 8.44:1 | 4.5:1 | pass |
| chip label on chip | 13.98:1 | 4.5:1 | pass |
| selected chip label | 7.25:1 | 4.5:1 | pass |
| primary as text (links, text/outlined buttons) on background | 4.81:1 | 4.5:1 | pass |
| primary as text on card | 4.56:1 | 4.5:1 | pass |
| on primary (filled button label) | 5.06:1 | 4.5:1 | pass |
| on primary container | 7.25:1 | 4.5:1 | pass |
| on secondary container | 7.25:1 | 4.5:1 | pass |
| error text on background | 6.14:1 | 4.5:1 | pass |
| on error | 6.46:1 | 4.5:1 | pass |
| success text on background | 4.87:1 | 4.5:1 | pass |
| warning text on background | 4.77:1 | 4.5:1 | pass |
| danger text on background | 6.21:1 | 4.5:1 | pass |
| info text on background | 5.46:1 | 4.5:1 | pass |
| on success | 5.13:1 | 4.5:1 | pass |
| on warning | 5.02:1 | 4.5:1 | pass |
| on danger | 6.54:1 | 4.5:1 | pass |
| on info | 5.75:1 | 4.5:1 | pass |
| outline (control boundary) on background | 4.28:1 | 3.0:1 | pass |
| outline on card | 4.06:1 | 3.0:1 | pass |
| text-field border on background | 4.28:1 | 3.0:1 | pass |
| focused text-field border on background | 4.81:1 | 3.0:1 | pass |

### Light theme: legacy hard-coded colors
| Pair | Ratio | Needs | Result |
|---|---|---|---|
| Colors.green text on background | 2.64:1 | 4.5:1 | **FAIL** |
| Colors.red text on background | 3.50:1 | 4.5:1 | **FAIL** |
| Colors.orange text on background | 2.05:1 | 4.5:1 | **FAIL** |
| Colors.amber text on background | 1.55:1 | 4.5:1 | **FAIL** |
| Colors.blue text on background | 2.97:1 | 4.5:1 | **FAIL** |
| Colors.grey text on background | 2.55:1 | 4.5:1 | **FAIL** |
| Colors.white70 text on background | 1.04:1 | 4.5:1 | **FAIL** |
| Colors.black54 text on background | 4.55:1 | 4.5:1 | pass |

### Light theme: success vs danger under simulation
| View | Contrast between success and danger |
|---|---|
| Full color | 1.27:1 |
| Protanopia | 1.96:1 |
| Deuteranopia | 1.05:1 |
| Grayscale | 1.27:1 |

### Dark theme tokens
| Pair | Ratio | Needs | Result |
|---|---|---|---|
| body text on background | 19.29:1 | 4.5:1 | pass |
| body text on card | 17.00:1 | 4.5:1 | pass |
| secondary text on background | 9.64:1 | 4.5:1 | pass |
| secondary text on card | 8.89:1 | 4.5:1 | pass |
| chip label on chip | 15.23:1 | 4.5:1 | pass |
| selected chip label | 10.48:1 | 4.5:1 | pass |
| primary as text (links, text/outlined buttons) on background | 9.63:1 | 4.5:1 | pass |
| primary as text on card | 8.48:1 | 4.5:1 | pass |
| on primary (filled button label) | 10.48:1 | 4.5:1 | pass |
| on primary container | 7.21:1 | 4.5:1 | pass |
| on secondary container | 7.24:1 | 4.5:1 | pass |
| error text on background | 11.36:1 | 4.5:1 | pass |
| on error | 7.72:1 | 4.5:1 | pass |
| success text on background | 8.16:1 | 4.5:1 | pass |
| warning text on background | 11.14:1 | 4.5:1 | pass |
| danger text on background | 8.45:1 | 4.5:1 | pass |
| info text on background | 8.71:1 | 4.5:1 | pass |
| on success | 8.88:1 | 4.5:1 | pass |
| on warning | 12.13:1 | 4.5:1 | pass |
| on danger | 9.20:1 | 4.5:1 | pass |
| on info | 9.48:1 | 4.5:1 | pass |
| outline (control boundary) on background | 4.77:1 | 3.0:1 | pass |
| outline on card | 4.20:1 | 3.0:1 | pass |
| text-field border on background | 4.77:1 | 3.0:1 | pass |
| focused text-field border on background | 9.63:1 | 3.0:1 | pass |

### Dark theme: legacy hard-coded colors
| Pair | Ratio | Needs | Result |
|---|---|---|---|
| Colors.green text on background | 6.94:1 | 4.5:1 | pass |
| Colors.red text on background | 5.24:1 | 4.5:1 | pass |
| Colors.orange text on background | 8.95:1 | 4.5:1 | pass |
| Colors.amber text on background | 11.83:1 | 4.5:1 | pass |
| Colors.blue text on background | 6.17:1 | 4.5:1 | pass |
| Colors.grey text on background | 7.20:1 | 4.5:1 | pass |
| Colors.white70 text on background | 9.64:1 | 4.5:1 | pass |
| Colors.black54 text on background | 1.05:1 | 4.5:1 | **FAIL** |

### Dark theme: success vs danger under simulation
| View | Contrast between success and danger |
|---|---|
| Full color | 1.04:1 |
| Protanopia | 1.27:1 |
| Deuteranopia | 1.19:1 |
| Grayscale | 1.04:1 |

### What the simulation shows

`success` and `danger` are 1.04–1.96:1 apart in every view, including full
color. **Correct/incorrect must never rely on color alone.** Spot checks of
primary study flows:

- `MCQQuestionWidget`, `TrueFalseQuestionWidget`, and `ShortAnswerField` print
  "Correct!" or "Incorrect", so they don't rely on color alone. They still use
  `Colors.green` and `Colors.red` text, which is 2.64:1 and 3.50:1 in light mode.
- `AudioMCQWidget` marks the selected and correct options **only** with a
  green or red background tint. This needs an icon or text label.
  `McqOptions` and `TrueFalseSelector` have the same problem.

PR #163 adds check/cross icons (with screen-reader labels) to all four widgets
and switches their feedback colors to `SemanticColors`. Verifying this in the
running app under simulation is tracked in #167.

## Hard-coded color inventory

`lib/` has 1,106 `Colors.*` references, 771 of them under `lib/widgets`. The
most common are `grey` (222), `green` (177), `white` (146), `red` (116),
`orange` (107), `blue` (84) and `amber` (84). In light mode, every common
status color used as text fails AA (see the legacy tables). In dark mode,
`Colors.black54` text is effectively invisible. High-traffic screens
(`lib/screens/library`, `study`, `settings`, `profile_screen.dart`) have only
23 references. Most of the debt is in shared widgets.

Files with the most `Colors.green` / `Colors.red` use: `in_context_qa_sheet.dart`
(22), `assessment_result_screen.dart` (16), `procedural_rubric_widget.dart`
(14), `content_quality_widget.dart` (13), `enhanced_json_import_widget.dart`
(10).

## Open items

1. **Migrate study-feedback colors to `SemanticColors`, and add a non-color
   marker to `AudioMCQWidget`.** Done in #163 (`AudioMCQWidget`, `McqOptions`,
   `TrueFalseSelector`, MCQ/true-false feedback text) and #165
   (`ShortAnswerField`), not in this PR.
2. Then migrate `assessment_result_screen.dart` and the files listed above in
   small PRs, following `COLOR_SYSTEM_GUIDELINES.md`.
Items 3 and 4 are tracked in #167. They are not done and must not be treated
as passed.

3. **Not yet done: browser zoom (200%/400%) and manual checks of the running app
   with a color-vision simulator** (Chrome DevTools > Rendering > Emulate
   vision deficiencies).
4. **Not yet done: 20–30 minute moderated sessions in both themes**, covering
   readability, fatigue, hierarchy and distraction. Contrast passing doesn't
   prove comfort. Specific questions to test:
   - Dark mode uses pure-white body text on `#0D0E12`, which is 19.3:1. Some
     readers report halation at that contrast. Should body text be off-white?
   - Should Dark stay the default, or should new learners start on System?
