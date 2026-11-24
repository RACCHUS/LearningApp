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
