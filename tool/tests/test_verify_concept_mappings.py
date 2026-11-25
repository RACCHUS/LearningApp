"""Tests for tool/verify_concept_mappings.py (plan v1.2 §8.1, D-13)."""
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tool"))

import verify_concept_mappings as v  # noqa: E402


def manifest(citation="Book 1e, Section 1.2: Exponents; Section 2.7: Inequalities"):
    return {"domains": [{"code": "1", "objectives": [
        {"code": "1.1", "title": "Exponents", "citation": citation},
    ]}]}


def imported():
    return {"domains": [{"code": "CH1", "objectives": [{"code": "1.2", "title": "Exponents"}]}]}


def section(sec="1.2", title="Exponents", **kw):
    s = {"section": sec, "title": title, "match": "exact", "depth": "same", "roles": ["teach"],
         "locator": "https://example.org/x", "confidence": "high", "imported_in_learningapp": False}
    s.update(kw)
    return s


def mapping(sections=None, status="pending", **review):
    return {
        "from": {"manifest": "m.yaml"},
        "to": {"imported_manifest": "imp.yaml"},
        "review": {"status": status, **review},
        "mappings": [{"objective": "1.1", "sections": sections if sections is not None else [
            section(), section("2.7", "Inequalities")]}],
    }


class MappingTests(unittest.TestCase):
    def run_check(self, doc, man=None):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "content").mkdir()
            (d / "content" / "m.yaml").write_text(yaml.safe_dump(man or manifest()), encoding="utf-8")
            (d / "content" / "imp.yaml").write_text(yaml.safe_dump(imported()), encoding="utf-8")
            path = d / "map.yaml"
            path.write_text(yaml.safe_dump(doc), encoding="utf-8")
            return v.check_file(path, d / "content")

    def test_a_consistent_mapping_passes(self):
        self.assertEqual(self.run_check(mapping()), [])

    def test_bad_field_values_fail(self):
        problems = self.run_check(mapping([section(match="same_as"), section("2.7", "Inequalities", roles=[])]))
        self.assertTrue(any("match must be" in p for p in problems))
        self.assertTrue(any("roles must be" in p for p in problems))

    def test_a_cited_section_must_be_mapped(self):
        problems = self.run_check(mapping([section()]))
        self.assertTrue(any("cites section 2.7, which its mapping lacks" in p for p in problems))

    def test_a_cited_title_must_match_the_mapping(self):
        problems = self.run_check(mapping(), manifest("Book 1e, Section 1.2: Linear Equations"))
        self.assertTrue(any("cites section 1.2 as 'Linear Equations'" in p for p in problems))

    def test_an_unmapped_objective_fails(self):
        doc = mapping()
        doc["mappings"] = []
        self.assertTrue(any("1.1 of m.yaml is not mapped" in p for p in self.run_check(doc)))

    def test_imported_sections_must_exist_with_the_same_title(self):
        ok = self.run_check(mapping([section(imported_in_learningapp=True), section("2.7", "Inequalities")]))
        self.assertEqual(ok, [])
        bad = self.run_check(mapping([section(imported_in_learningapp=True), section("2.7", "Inequalities",
                                                                                     imported_in_learningapp=True)]))
        self.assertTrue(any("has no objective 2.7" in p for p in bad))

    def test_an_approved_review_needs_its_reviewer(self):
        problems = self.run_check(mapping(status="approved", reviewer_kind="ai"))
        self.assertTrue(any("reviewer_model" in p for p in problems))
        self.assertTrue(any("reviewed_on" in p for p in problems))
        ok = self.run_check(mapping(status="approved", reviewer_kind="ai", reviewer_model="m", reviewed_on="2026-11-25"))
        self.assertEqual(ok, [])

    def test_publish_check_blocks_an_unreviewed_mapping(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "a.yaml").write_text(yaml.safe_dump(mapping()), encoding="utf-8")
            self.assertTrue(v.publish_check("content/m.yaml", d))
            self.assertEqual(v.publish_check("content/other.yaml", d), [])
            (d / "a.yaml").write_text(yaml.safe_dump(mapping(status="approved")), encoding="utf-8")
            self.assertEqual(v.publish_check("m.yaml", d), [])

    def test_the_real_mappings_pass(self):
        files = sorted(v.MAPPINGS.glob("*.yaml"))
        self.assertTrue(files)
        for f in files:
            self.assertEqual(v.check_file(f), [], f.name)


if __name__ == "__main__":
    unittest.main()
