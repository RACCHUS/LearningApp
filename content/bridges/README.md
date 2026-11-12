# Bridge starter set

These are short prerequisite lessons that work without AI. Learners can open one when they get stuck and then return to the activity they left (master plan v2.6 §8.4 and §10.0). This set is a **demonstration**. It is not a ceiling on what the catalog will cover, and it is not yet wired into the app; PR-B will connect it.

| File | Bridge | Builds on |
|---|---|---|
| `fraction_decimal.bridge.json` | Fractions, decimals and percents | — |
| `percent_change.bridge.json` | Percent change | fraction/decimal |
| `spreadsheet_percent_format.bridge.json` | Showing percentages in Excel | fraction/decimal, percent change |

## Rules (checked in CI by `test/models/bridge_lesson_test.dart`)

- `uses_ai` must be `false`. A Bridge has one primary objective, a return cue and no images.
- Every text block cites at least one listed source. Sources are **link-only**: the text is written independently. OpenStax *Prealgebra 2e* is CC BY-NC-SA 4.0, and its publisher forbids using it to train language models. Do not paste or adapt its text here.
- Check items use only the allowlisted templates in `BridgeCheckEvaluator` (`percent_change`, `percent_of`, `fraction_to_decimal`, `decimal_to_percent`, `percent_to_decimal`).
  - Numbers must be JSON integers or decimal strings. JSON floats are rejected.
  - The stated answer must equal the exact recomputed value, rounded half away from zero when `round_to` is set.
  - A choice item must have exactly one option equal to that value, and it must be the `correct_option_id`.
  - Checks must use numbers that do not appear in any worked example.
- `evidence.human_reviewed` stays `false` until a named person has actually reviewed the Bridge. A passing CI check proves the arithmetic is reproducible. It does not prove the teaching is good.
- `builds_on` must name Bridges that exist, with no cycles.
