import copy
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_practice_items as v  # noqa: E402

CA = yaml.safe_load((v.PRACTICE / "open_openstax_college_algebra_1e.yaml").read_text(encoding="utf-8"))
XL = yaml.safe_load((v.PRACTICE / "excel_fundamentals.yaml").read_text(encoding="utf-8"))


def ca_item(iid):
    return copy.deepcopy(next(i for i in CA["items"] if i["id"] == iid))


class PracticeTests(unittest.TestCase):
    def test_the_real_files_pass(self):
        self.assertEqual(v.main(), 0)

    def test_every_real_item_is_mathematically_right(self):
        for data in (CA, XL):
            for item in data["items"]:
                self.assertEqual(v.ho.check_item(item), [], item["id"])

    def test_a_wrong_key_fails(self):
        it = ca_item("ca1e-pr-1-5-a")
        it["scoring_spec"]["correct_index"] = 1
        self.assertTrue(v.ho.check_item(it))

    def check(self, data, manifest=None):
        with tempfile.TemporaryDirectory() as d:
            if manifest is not None:
                m = Path(d) / "m.yaml"
                m.write_text(yaml.safe_dump(manifest), encoding="utf-8")
                data = {**data, "manifest": str(m)}
            p = Path(d) / "x.yaml"
            p.write_text(yaml.safe_dump(data), encoding="utf-8")
            return v.check_file(p)

    def test_reusing_a_held_out_expression_fails(self):
        data = copy.deepcopy(CA)
        it = next(i for i in data["items"] if i["id"] == "ca1e-pr-1-5-a")
        it["prompt"] = "Factor $x^2 + 3x - 28$."  # held-out ca1e-ho-1-5-a
        self.assertTrue(any("from a held-out check" in p for p in self.check(data)))

    def test_a_held_out_id_is_refused(self):
        data = copy.deepcopy(CA)
        data["items"][0]["id"] = "ca1e-ho-1-1-a"
        self.assertTrue(any("held-out item's id" in p for p in self.check(data)))

    def manifest(self, questions):
        return {"domains": [{"objectives": [{"code": "SPREADSHEET-1.1", "lessons": [{"questions": questions}]}]}]}

    def as_question(self, it):
        return {"id": it["id"], "question_text": it["prompt"], "options": it["response_spec"]["options"],
                "correct_answer": it["scoring_spec"]["correct_index"]}

    def test_an_approved_item_must_be_in_the_manifest_as_written(self):
        data = copy.deepcopy(XL)
        data["min_practice_per_objective"] = 1
        it = next(i for i in data["items"] if v.is_approved(i))
        self.assertTrue(any(f"approved item {it['id']} is missing" in p for p in self.check(data, self.manifest([]))))
        wrong = self.as_question(it)
        wrong["correct_answer"] = (wrong["correct_answer"] + 1) % 4
        problems = self.check(data, self.manifest([wrong]))
        self.assertTrue(any(f"{it['id']} key differs" in p for p in problems))

    def test_an_unapproved_item_must_not_be_in_the_manifest(self):
        data = copy.deepcopy(XL)
        data["min_practice_per_objective"] = 1
        it = data["items"][0]
        it.pop("review", None)
        problems = self.check(data, self.manifest([self.as_question(it)]))
        self.assertTrue(any(f"{it['id']} is in the manifest but isn't approved" in p for p in problems))

    def test_too_few_graded_items_fails(self):
        data = copy.deepcopy(XL)
        data["items"] = []
        problems = self.check(data, self.manifest([]))
        self.assertTrue(any("SPREADSHEET-1.1 has 0 graded items, needs 10" in p for p in problems))


if __name__ == "__main__":
    unittest.main()
