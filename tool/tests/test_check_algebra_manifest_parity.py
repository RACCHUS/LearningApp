"""Mutation tests for the College Algebra generator/committed-YAML parity gate.

Each test corrupts a temporary copy of the real committed manifest (never the
file in content/) and proves the gate reports it. Requires PyYAML.
"""
import contextlib
import copy
import io
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool" / "ci"))
import check_algebra_manifest_parity as parity  # noqa: E402

COMMITTED = ROOT / "content" / "clep_college_algebra.yaml"


def first_item(manifest):
    for domain in manifest["domains"]:
        for objective in domain.get("objectives", []):
            for lesson in objective.get("lessons", []):
                if lesson.get("assessment_items"):
                    return lesson, lesson["assessment_items"][0]
    raise AssertionError("no assessment item in committed manifest")


class StrictDiffTest(unittest.TestCase):
    def test_mapping_key_order_is_ignored(self):
        self.assertEqual(parity.strict_diff({"a": 1, "b": 2}, {"b": 2, "a": 1}), [])

    def test_list_order_matters(self):
        self.assertEqual(parity.strict_diff([1, 2], [2, 1]), ["$[0]: value differs", "$[1]: value differs"])

    def test_types_matter_even_when_python_equality_does_not(self):
        self.assertTrue(parity.strict_diff({"x": True}, {"x": 1}))
        self.assertTrue(parity.strict_diff({"x": 1}, {"x": 1.0}))
        self.assertTrue(parity.strict_diff({"x": "1"}, {"x": 1}))

    def test_missing_and_extra_keys_and_lengths(self):
        self.assertEqual(parity.strict_diff({"a": 1}, {"b": 1}), ["$.a: only in generated", "$.b: only in committed"])
        self.assertEqual(parity.strict_diff([1], [1, 2]), ["$: length 1 != 2"])


class ParityMutationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with COMMITTED.open(encoding="utf-8") as fh:
            cls.committed = yaml.safe_load(fh)
        # Build once; mutation tests reuse it (fresh deep copies per call so the
        # gate's determinism comparison still sees independent objects).
        cls._real_generated = parity.generated_manifest
        cached = cls._real_generated()
        parity.generated_manifest = lambda: copy.deepcopy(cached)

    @classmethod
    def tearDownClass(cls):
        parity.generated_manifest = cls._real_generated

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.path = Path(self._tmp.name) / "clep_college_algebra.yaml"

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, manifest):
        self.path.write_text(yaml.safe_dump(manifest, sort_keys=True, allow_unicode=True), encoding="utf-8")
        return parity.check(self.path)

    def mutated(self, mutate):
        manifest = copy.deepcopy(self.committed)
        mutate(manifest)
        return self.write(manifest)

    def test_real_committed_manifest_has_parity_despite_reformatting(self):
        # safe_dump with sorted keys and different quoting: formatting-only change.
        self.assertEqual(self.write(copy.deepcopy(self.committed)), [])

    def test_changed_answer_key_is_detected(self):
        def mutate(m):
            item = first_item(m)[1]
            item["scoring_spec"]["correct_index"] = (item["scoring_spec"]["correct_index"] + 1) % 4

        problems = self.mutated(mutate)
        self.assertTrue(any("correct_index" in p for p in problems), problems)

    def test_swapped_options_are_detected(self):
        def mutate(m):
            opts = first_item(m)[1]["response_spec"]["options"]
            opts[0], opts[1] = opts[1], opts[0]

        self.assertTrue(any("options[0]" in p for p in self.mutated(mutate)))

    def test_changed_prompt_is_detected(self):
        def mutate(m):
            first_item(m)[1]["prompt"] += " "

        self.assertTrue(any(p.endswith(".prompt: value differs") for p in self.mutated(mutate)))

    def test_reordered_items_are_detected(self):
        def mutate(m):
            lesson = first_item(m)[0]
            lesson["assessment_items"].reverse()

        manifest = copy.deepcopy(self.committed)
        if len(first_item(manifest)[0]["assessment_items"]) < 2:
            self.skipTest("first lesson has a single item")
        self.assertTrue(self.mutated(mutate))

    def test_answer_key_type_change_is_detected(self):
        def mutate(m):
            item = first_item(m)[1]
            item["scoring_spec"]["correct_index"] = str(item["scoring_spec"]["correct_index"])

        self.assertTrue(any("type int != str" in p for p in self.mutated(mutate)))

    def test_added_field_is_detected(self):
        def mutate(m):
            first_item(m)[1]["unreviewed_note"] = "added only in YAML"

        self.assertTrue(any(p.endswith(".unreviewed_note: only in committed") for p in self.mutated(mutate)))

    def test_output_never_prints_values(self):
        def mutate(m):
            first_item(m)[1]["prompt"] = "SECRET-SENTINEL"

        manifest = copy.deepcopy(self.committed)
        mutate(manifest)
        self.path.write_text(yaml.safe_dump(manifest), encoding="utf-8")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(parity.main(["--committed", str(self.path)]), 1)
        self.assertNotIn("SECRET-SENTINEL", out.getvalue())

    def test_missing_committed_file_fails_closed(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(parity.main(["--committed", str(self.path)]), 2)



class RealGeneratorTest(unittest.TestCase):
    """Uses the real generator end to end (no cache)."""

    def test_repository_has_parity_and_committed_file_is_not_modified(self):
        before = COMMITTED.read_bytes()
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(parity.main([]), 0)
        self.assertEqual(COMMITTED.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
