"""Tests for tool/check_notation.py (plan v1.2 §8.9 notation profiles)."""
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tool"))

import check_notation as n  # noqa: E402

LATEX = {"math_markup": "latex", "decimal_separator": ".", "thousands_separator": ","}
EXCEL = {"math_markup": "plain", "excel_function_case": "upper", "decimal_separator": ".",
         "thousands_separator": ","}


def manifest(text, **lesson):
    return {"domains": [{"objectives": [{"lessons": [
        {"blocks": [{"content": {"text": text}}], "citation": r"Book \frac section", **lesson}]}]}]}


class FindingTests(unittest.TestCase):
    def test_math_inside_dollars_is_fine(self):
        f = n.findings(manifest(r"Simplify $\frac{x^2}{x}$ and $$y \leq 3$$."), LATEX)
        self.assertEqual(f["bare_latex"], [])
        self.assertEqual(f["plain_math"], [])

    def test_bare_latex_and_plain_math_outside_dollars(self):
        f = n.findings(manifest(r"Simplify \sqrt{8} where x^2 <= 4 and $x > 0$."), LATEX)
        self.assertEqual(len(f["bare_latex"]), 1)
        self.assertEqual(len(f["plain_math"]), 2)

    def test_citations_are_not_course_text(self):
        self.assertEqual(n.findings(manifest("Plain."), LATEX)["bare_latex"], [])

    def test_a_plain_course_is_not_checked_for_latex(self):
        self.assertEqual(n.findings(manifest(r"x^2 \frac"), EXCEL)["plain_math"], [])

    def test_excel_function_case(self):
        f = n.findings(manifest("Type =sum(A1:A3) or =SUM(A1:A3)."), EXCEL)
        self.assertEqual(f["excel_case"], ["blocks/content/text: sum("])

    def test_separators(self):
        f = n.findings(manifest("It is 2,5 cm long, 1,152 cm wide and 12 500 tall."), LATEX)
        self.assertEqual(len(f["decimal_comma"]), 1, "1,152 is a thousands comma")
        self.assertEqual(len(f["thousands_space"]), 1)

    def test_bare_option_wrapping_is_deterministic(self):
        self.assertEqual(n.wrap_bare_latex_option(r"\frac{4x^4}{y^2}"), r"$\frac{4x^4}{y^2}$")
        self.assertEqual(n.wrap_bare_latex_option(r"$4\sqrt{3}$"), r"$4\sqrt{3}$")
        self.assertEqual(n.wrap_bare_latex_option("x = 3"), "x = 3")


class BaselineTests(unittest.TestCase):
    def run_check(self, text, baseline, profile=LATEX):
        with tempfile.TemporaryDirectory() as d:
            content = Path(d)
            (content / "m.yaml").write_text(yaml.safe_dump(manifest(text)), encoding="utf-8")
            return n.check({"m.yaml": profile}, baseline, content)

    def test_new_findings_fail(self):
        self.assertTrue(any("1 plain_math (baseline 0)" in p for p in self.run_check("x^2", {})))

    def test_a_baseline_may_only_shrink(self):
        self.assertEqual(self.run_check("x^2", {"m.yaml": {"plain_math": 1}}), [])
        problems = self.run_check("clean", {"m.yaml": {"plain_math": 1}})
        self.assertTrue(any("lower it" in p for p in problems))

    def test_every_manifest_needs_a_profile(self):
        with tempfile.TemporaryDirectory() as d:
            content = Path(d)
            (content / "m.yaml").write_text(yaml.safe_dump(manifest("x")), encoding="utf-8")
            self.assertTrue(any("no notation profile" in p for p in n.check({}, {}, content)))

    def test_the_repository_passes(self):
        import json
        baseline = json.loads(n.BASELINE.read_text(encoding="utf-8"))["counts"]
        self.assertEqual(n.check(n.load_profiles(), baseline), [])


class ImporterScriptTests(unittest.TestCase):
    def test_digit_superscripts_become_unicode(self):
        import import_open_textbook as t
        self.assertEqual(t.script("2", t.SUPERSCRIPT, "^"), "²")
        self.assertEqual(t.script("-4", t.SUPERSCRIPT, "^"), "⁻⁴")
        self.assertEqual(t.script("2", t.SUBSCRIPT, "_"), "₂")
        self.assertEqual(t.script("n", t.SUPERSCRIPT, "^"), "^n", "letters keep the marker")


if __name__ == "__main__":
    unittest.main()
