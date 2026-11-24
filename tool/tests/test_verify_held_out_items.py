import copy
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_held_out_items as v  # noqa: E402

DRAFT = v.DRAFTS / "open_openstax_college_algebra_1e_ch1.yaml"
REAL = yaml.safe_load(DRAFT.read_text(encoding="utf-8"))
PRE = yaml.safe_load((v.DRAFTS / "open_openstax_prealgebra_1e_ch6.yaml").read_text(encoding="utf-8"))
XL = yaml.safe_load((v.DRAFTS / "excel_fundamentals.yaml").read_text(encoding="utf-8"))


def item(iid):
    return copy.deepcopy(next(i for i in REAL["items"] if i["id"] == iid))


class ItemMathTests(unittest.TestCase):
    def test_the_real_drafts_pass(self):
        self.assertEqual(v.main(), 0)

    def test_wrong_numeric_key_fails(self):
        it = item("ca1e-ho-1-1-a")
        it["scoring_spec"]["correct_value"] = 17
        self.assertTrue(any("keyed 17" in p for p in v.check_item(it)))

    def test_wrong_keyed_option_fails(self):
        it = item("ca1e-ho-1-5-a")
        it["scoring_spec"]["correct_index"] = 0
        self.assertTrue(any("is not equal" in p for p in v.check_item(it)))

    def test_a_second_correct_option_fails(self):
        it = item("ca1e-ho-1-4-d")
        it["verify"]["options"][0] = "x**2 - 8*x + 16"
        self.assertTrue(any("also correct" in p for p in v.check_item(it)))

    def test_same_value_distractor_must_really_be_equal(self):
        it = item("ca1e-ho-1-3-c")
        it["verify"]["same_value_distractors"] = [1, 2, 3]
        self.assertTrue(any("listed as same-value" in p for p in v.check_item(it)))

    def test_unlisted_same_value_distractor_fails(self):
        it = item("ca1e-ho-1-3-c")
        it["verify"]["same_value_distractors"] = [1]
        self.assertTrue(any("distractor 3" in p for p in v.check_item(it)))

    def test_special_checks(self):
        self.assertEqual(v.keyed_value(item("ca1e-ho-1-4-a")), 6)
        self.assertEqual(v.keyed_value(item("ca1e-ho-1-4-e")), 6)
        self.assertEqual(v.keyed_value(item("ca1e-ho-1-5-f")), 7)
        self.assertEqual(v.keyed_value(item("ca1e-ho-1-6-d")), 3)


class SpreadsheetAndOtherModesTests(unittest.TestCase):
    CELLS = {"C2": 20, "C3": 30, "C9": 90}

    def test_sheet_eval(self):
        self.assertEqual(v.sheet_eval("=SUM(C2:C9)", self.CELLS), 140)
        self.assertEqual(v.sheet_eval("=SUM(C2,C9)", self.CELLS), 110)
        self.assertEqual(v.sheet_eval("=C2*(C3-10)/2", self.CELLS), 200)
        self.assertEqual(v.sheet_eval("=$C$2+1", self.CELLS), 21)
        for bad in ("=C2:C9", "C2", "=FOO(C2)", "=SUM(C2", "=C2/0", "=2^3"):
            self.assertIsNone(v.sheet_eval(bad, self.CELLS), bad)

    def test_cells_in_range(self):
        self.assertEqual(v._cells_in("A1:B3"), ["A1", "A2", "A3", "B1", "B2", "B3"])
        self.assertEqual(len(v._cells_in("Z1:AB2")), 6)

    def test_spreadsheet_items_catch_a_wrong_key(self):
        it = copy.deepcopy(next(i for i in XL["items"] if i["id"] == "xl-ho-1-1-b"))
        self.assertEqual(v.check_item(it), [])
        it["scoring_spec"]["correct_index"] = 0
        self.assertTrue(v.check_item(it))
        it = copy.deepcopy(next(i for i in XL["items"] if i["id"] == "xl-ho-1-1-a"))
        it["scoring_spec"]["correct_value"] = 41
        self.assertTrue(any("keyed 41" in p for p in v.check_item(it)))

    def test_largest_zero_and_cell_ref_modes(self):
        for iid in ("pa1e-ho-6-1-f", "pa1e-ho-6-5-f"):
            it = copy.deepcopy(next(i for i in PRE["items"] if i["id"] == iid))
            self.assertEqual(v.check_item(it), [], iid)
            it["scoring_spec"]["correct_index"] = 1
            self.assertTrue(v.check_item(it), iid)
        it = copy.deepcopy(next(i for i in XL["items"] if i["id"] == "xl-ho-1-1-f"))
        it["scoring_spec"]["correct_index"] = 0
        self.assertTrue(any("valid cell references" in p for p in v.check_item(it)))

    def test_substitution_applies_to_options(self):
        it = next(i for i in PRE["items"] if i["id"] == "pa1e-ho-6-4-f")
        self.assertEqual(v.check_item(it), [])


class ReviewTests(unittest.TestCase):
    def approved(self, **changes):
        review = {"reviewer_ref": "reviewer-001", "reviewer_qualification": "Certified math teacher",
                  "reviewed_on": "2026-11-20", "review_status": "approved",
                  "rights_review_status": "approved", "reviewer_kind": "human", **changes}
        it = item("ca1e-ho-1-1-a")
        it["review"] = review
        return v.check_review(it, "ai-drafted-by-claude")

    def test_a_complete_approval_passes(self):
        self.assertEqual(self.approved(), [])

    def test_no_review_is_fine_until_approval(self):
        self.assertEqual(v.check_review(item("ca1e-ho-1-1-a"), "ai-drafted-by-claude"), [])

    def test_the_author_cannot_approve(self):
        self.assertTrue(any("cannot be the author" in p for p in self.approved(reviewer_ref="AI-Drafted-by-Claude")))

    def test_approval_needs_qualification_rights_and_a_past_date(self):
        self.assertTrue(any("qualification" in p for p in self.approved(reviewer_qualification="")))
        self.assertTrue(any("rights_review_status" in p for p in self.approved(rights_review_status="pending")))
        self.assertTrue(any("YYYY-MM-DD" in p for p in self.approved(reviewed_on="last week")))
        self.assertTrue(any("future" in p for p in self.approved(reviewed_on="2999-01-01")))


class AiReviewTests(ReviewTests):
    def test_an_ai_review_needs_its_model(self):
        self.assertTrue(any("reviewer_model" in p for p in self.approved(reviewer_kind="ai")))
        self.assertEqual(self.approved(reviewer_kind="ai", reviewer_model="claude-sonnet-5-5",
                                       reviewer_ref="ai-review:claude-sonnet-5-5"), [])

    def test_the_kind_is_required(self):
        self.assertTrue(any("reviewer_kind" in p for p in self.approved(reviewer_kind=None)))
        self.assertTrue(any("reviewer_kind" in p for p in self.approved(reviewer_kind="robot")))


class FileTests(unittest.TestCase):
    def check(self, data):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "x.yaml"
            p.write_text(yaml.safe_dump(data), encoding="utf-8")
            return v.check_file(p)

    def test_too_few_items_for_an_objective_fails(self):
        data = copy.deepcopy(REAL)
        data["items"] = [i for i in data["items"] if i["id"] != "ca1e-ho-1-2-f"]
        self.assertTrue(any("objective 1.2 has 5 items" in p for p in self.check(data)))

    def test_repeating_a_lesson_prompt_fails(self):
        manifest = v.published_manifest(REAL["source_release_id"])
        lesson_prompt = manifest["domains"][0]["objectives"][0]["lessons"][0]["assessment_items"][0]["prompt"]
        data = copy.deepcopy(REAL)
        data["items"][0]["prompt"] = lesson_prompt
        self.assertTrue(any("repeats a lesson prompt" in p for p in self.check(data)))

    def test_concept_map_must_match_the_manifest(self):
        data = copy.deepcopy(REAL)
        data["objective_concepts"]["1.3"] = ["some-other-concept"]
        self.assertTrue(any("objective_concepts[1.3]" in p for p in self.check(data)))

    def test_authoring_fields_are_required(self):
        data = copy.deepcopy(REAL)
        del data["author_ref"]
        data["ai_drafted"] = "yes"
        problems = self.check(data)
        self.assertTrue(any("author_ref is required" in p for p in problems))
        self.assertTrue(any("ai_drafted must be" in p for p in problems))

    def test_reusing_a_lesson_example_expression_fails(self):
        # The first draft of 1.5-a factored x^2 + 2x - 15, the lesson's own
        # Example 2; the independent AI review caught it (2026-11-24).
        data = copy.deepcopy(REAL)
        it = next(i for i in data["items"] if i["id"] == "ca1e-ho-1-5-a")
        it["prompt"] = "Factor $x^2 + 2x - 15$."
        self.assertTrue(any("reuses $x^2+2x-15$" in p for p in self.check(data)))

    def test_short_expressions_are_not_flagged(self):
        self.assertEqual(v.math_segments("Expand $(x - 4)^2$ and $(2x - 3)(x + 5)$."), ["(2x-3)(x+5)"])
        self.assertEqual(v.math_segments("Is $x^2 - 4$ prime?"), [])

    def test_duplicate_ids_fail(self):
        data = copy.deepcopy(REAL)
        data["items"][1]["id"] = data["items"][0]["id"]
        self.assertTrue(any("duplicate id" in p for p in self.check(data)))

    def test_answer_position_bias_fails(self):
        data = copy.deepcopy(REAL)
        for it in data["items"]:
            if it["interaction_type"] == "single_choice":
                opts = it["response_spec"]["options"]
                sym = it["verify"].get("options")
                k = it["scoring_spec"]["correct_index"]
                opts[0], opts[k] = opts[k], opts[0]
                if sym:
                    sym[0], sym[k] = sym[k], sym[0]
                    same = it["verify"].get("same_value_distractors") or []
                    it["verify"]["same_value_distractors"] = [k if s == 0 else s for s in same]
                if "irrational_index" in it["verify"]:
                    vals = it["verify"]["values"]
                    vals[0], vals[k] = vals[k], vals[0]
                    it["verify"]["irrational_index"] = 0
                it["scoring_spec"]["correct_index"] = 0
        self.assertTrue(any("option 0 keys" in p for p in self.check(data)))


if __name__ == "__main__":
    unittest.main()
