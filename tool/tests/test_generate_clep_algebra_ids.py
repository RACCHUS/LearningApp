"""Generator-level stable ID invariant for CLEP College Algebra (plan PR-2b)."""
import copy
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tool.generate_clep_algebra_course import build_manifest, validate_stable_ids  # noqa: E402


def lessons(manifest):
    for d in manifest["domains"]:
        for o in d["objectives"]:
            yield from o["lessons"]


class StableIdInvariantTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = build_manifest()

    def fresh(self):
        return copy.deepcopy(self.manifest)

    def test_authored_manifest_passes(self):
        validate_stable_ids(self.fresh())

    def test_ids_are_authored_in_source_modules(self):
        # IDs must come from tool/curriculum_clep_algebra, not be added later.
        from tool.curriculum_clep_algebra.domain_01_algebraic_operations import DOMAIN_01
        from tool.curriculum_clep_algebra.formative_lesson_questions import RAW_FORMATIVE_QUESTIONS_BY_LESSON

        first_lesson = DOMAIN_01["objectives"][0]["lessons"][0]
        self.assertTrue(first_lesson["assessment_items"][0]["id"].startswith("alg-sim-"))
        first_raw = next(iter(RAW_FORMATIVE_QUESTIONS_BY_LESSON.values()))[0]
        self.assertTrue(first_raw["id"].startswith("alg-fmt-"))

    def assert_rejected(self, mutate, message):
        m = self.fresh()
        mutate(m)
        with self.assertRaises(AssertionError) as ctx:
            validate_stable_ids(m)
        self.assertIn(message, str(ctx.exception))

    def test_missing_id_rejected(self):
        self.assert_rejected(lambda m: next(lessons(m))["assessment_items"][0].pop("id"), "missing or malformed")

    def test_malformed_id_rejected(self):
        def mutate(m):
            next(lessons(m))["questions"][0]["id"] = "alg-fmt-Bad_ID"

        self.assert_rejected(mutate, "missing or malformed")

    def test_wrong_prefix_rejected(self):
        def mutate(m):
            next(lessons(m))["questions"][0]["id"] = "alg-sim-misfiled-formative"

        self.assert_rejected(mutate, "must start with alg-fmt-")

    def test_duplicate_rejected(self):
        def mutate(m):
            items = next(lessons(m))["assessment_items"]
            items[1]["id"] = items[0]["id"]

        self.assert_rejected(mutate, "duplicate id")

    def test_wrong_count_rejected(self):
        self.assert_rejected(lambda m: next(lessons(m))["assessment_items"].pop(), "Expected 60 simulation + 40 formative")

    def test_reordering_preserves_identity(self):
        m = self.fresh()
        before = {i["id"] for l in lessons(m) for i in l["assessment_items"] + l["questions"]}
        for lesson in lessons(m):
            lesson["assessment_items"].reverse()
            lesson["questions"].reverse()
        validate_stable_ids(m)
        after = {i["id"] for l in lessons(m) for i in l["assessment_items"] + l["questions"]}
        self.assertEqual(before, after)


if __name__ == "__main__":
    unittest.main()
