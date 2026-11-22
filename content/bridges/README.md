# Bridge starter set

These are short prerequisite lessons that work without AI. Learners can open one when they get stuck and then return to the activity they left (master plan v2.6 §8.4 and §10.0). This set is a starting point, not a ceiling on what the catalog will cover. It is wired into the app behind `learning.quick_rescue`.

| File | Bridge | Builds on |
|---|---|---|
| `fraction_decimal.bridge.json` | Fractions, decimals and percents | — |
| `percent_change.bridge.json` | Percent change | fraction/decimal |
| `spreadsheet_percent_format.bridge.json` | Showing percentages in Excel | fraction/decimal, percent change |
| `percent_of_number.bridge.json` | Finding a percent of a number | fraction/decimal |
| `exponents.bridge.json` | Exponents, including zero and negative ones | — |
| `scientific_notation.bridge.json` | Scientific notation to an ordinary number | exponents |
| `square_roots.bridge.json` | Square roots of perfect squares | exponents |
| `order_of_operations.bridge.json` | Order of operations | — |
| `fraction_arithmetic.bridge.json` | Adding, multiplying and dividing fractions | fraction/decimal |
| `integer_division.bridge.json` | Whole-number division and remainders (`//`, `%`) | — |
| `loop_count.bridge.json` | How many times a counting loop runs (`range`) | integer division |

Each Bridge lists `applies_to_tags`. "Learning help" appears on a lesson only when a Bridge applies to one of the lesson's tags, and it offers only those Bridges plus the ones they build on. Imported open-textbook lessons get topic tags from `TOPIC_TAGS` in `tool/import_open_textbook.py`.

## Rules (checked in CI by `test/models/bridge_lesson_test.dart`)

- `uses_ai` must be `false`. A Bridge has one primary objective, a return cue and no images.
- Every text block cites at least one listed source. Sources are **link-only**: the text is written independently. OpenStax *Prealgebra 2e* is CC BY-NC-SA 4.0, and its publisher forbids using it to train language models. Do not paste or adapt its text here. OpenStax first editions (e.g. *College Algebra*) are CC BY 4.0; they are still linked, not pasted. *Introduction to Python Programming* is CC BY-NC-SA 4.0: linked only.
- Check items use only the allowlisted templates in `BridgeCheckEvaluator` (`percent_change`, `percent_of`, `fraction_to_decimal`, `decimal_to_percent`, `percent_to_decimal`, `power`, `scientific_to_decimal`, `square_root`, `add_product`, `product_of_sum`, `subtract_quotient`, `fraction_add`, `fraction_multiply`, `fraction_divide`, `integer_quotient`, `remainder`, `range_count`). The order-of-operations templates are fixed forms (for example `a + b × c`); nothing parses a typed expression. `power` and `scientific_to_decimal` take whole-number exponents from -12 to 12; `square_root` only accepts perfect squares and is never approximated. `integer_quotient` and `remainder` refuse negative numbers (languages disagree on them); `range_count` follows Python's `range()` for whole numbers from -10,000 to 10,000.
- `applies_to_tags` must list at least one lowercase lesson tag.
  - Numbers must be JSON integers or decimal strings. JSON floats are rejected.
  - The stated answer must equal the exact recomputed value, rounded half away from zero when `round_to` is set.
  - A choice item must have exactly one option equal to that value, and it must be the `correct_option_id`.
  - Checks must use numbers that do not appear in any worked example.
- `evidence.human_reviewed` stays `false` until a named person has actually reviewed the Bridge. A passing CI check proves the arithmetic is reproducible. It does not prove the teaching is good.
- `builds_on` must name Bridges that exist, with no cycles.
