"""Tests for tool/verify_external_resources.py (companion plan v1.0, EX-0)."""
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tool"))

import verify_external_resources as v  # noqa: E402


def manifest():
    return {"target": {"slug": "t-one"}, "domains": [{"code": "1", "objectives": [
        {"code": "1.1", "title": "A"}, {"code": "1.2", "title": "B"}]}]}


def resource(**kw):
    r = {
        "id": "res-one", "kind": "course", "publisher": "P", "title": "T", "locale": "en-US",
        "canonical_url": "https://example.org/c", "access": "free_no_login", "price": None,
        "rights_posture": "link_only", "embed": {"allowed": False},
        "has_practice": None, "captions": None, "transcript": None, "stated_length_hours": None,
        "targets": ["t-one"], "metadata_checked_at": "2026-11-25",
        "facts": [{"claim": "Free.", "source_url": "https://example.org/c"}],
        "authored_by": "ai", "review": {"status": "pending"},
    }
    r.update(kw)
    return r


def section(**kw):
    s = {"label": "Module 1", "locator": None, "start_seconds": None, "end_seconds": None,
         "depth": "teaches", "has_practice": None, "confidence": "medium"}
    s.update(kw)
    return s


def resource_map(coverage=None, **kw):
    m = {
        "target_slug": "t-one", "resource_id": "res-one", "method": "From the public outline.",
        "authored_by": "ai", "review": {"status": "pending"},
        "coverage": coverage if coverage is not None else [
            {"objective": "1.1", "covered": True, "sections": [section()]},
            {"objective": "1.2", "covered": False, "sections": []},
        ],
    }
    m.update(kw)
    return m


class Helpers:
    def run_check(self, res=None, rmap=None, res_name="res-one.yaml", map_name="t-one__res-one.yaml"):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            for sub in ("content", "resources", "maps"):
                (d / sub).mkdir()
            (d / "content" / "m.yaml").write_text(yaml.safe_dump(manifest()), encoding="utf-8")
            (d / "resources" / res_name).write_text(yaml.safe_dump(res or resource()), encoding="utf-8")
            if rmap is not None:
                (d / "maps" / map_name).write_text(yaml.safe_dump(rmap), encoding="utf-8")
            return v.check_all(d / "resources", d / "maps", d / "content")[0]

    def assertProblem(self, problems, text):
        self.assertTrue(any(text in p for p in problems), f"{text!r} not in {problems}")


class ResourceTests(Helpers, unittest.TestCase):
    def test_a_valid_resource_passes(self):
        self.assertEqual(self.run_check(), [])

    def test_the_committed_files_pass(self):
        self.assertEqual(v.check_all()[0], [])

    def test_id_must_equal_the_file_name(self):
        self.assertProblem(self.run_check(res_name="other.yaml"), "id must be")

    def test_unknown_values_fail(self):
        problems = self.run_check(resource(kind="mooc", access="cheap", rights_posture="adapt"))
        for text in ("kind must be", "access must be", "rights_posture must be link_only"):
            self.assertProblem(problems, text)

    def test_links_must_be_https_but_a_resource_may_have_no_link(self):
        self.assertProblem(self.run_check(resource(canonical_url="http://example.org")), "canonical_url")
        self.assertEqual(self.run_check(resource(canonical_url=None, kind="book")), [])

    def test_a_paid_resource_needs_a_dated_price_band(self):
        self.assertProblem(self.run_check(resource(access="paid")), "needs price.band")
        self.assertProblem(self.run_check(resource(access="paid", price={"band": "under_25"})), "currency")
        ok = resource(access="paid", price={"band": "under_25", "currency": "USD", "checked_at": "2026-11-25"})
        self.assertEqual(self.run_check(ok), [])

    def test_a_free_resource_has_no_price(self):
        self.assertProblem(self.run_check(resource(price={"band": "under_25"})), "price must be null")

    def test_an_allowed_embed_needs_provider_and_terms(self):
        self.assertProblem(self.run_check(resource(embed={"allowed": True})), "embed.provider")
        ok = resource(embed={"allowed": True, "provider": "youtube", "terms_url": "https://example.org/terms"})
        self.assertEqual(self.run_check(ok), [])

    def test_unknown_facts_are_null_not_text(self):
        self.assertProblem(self.run_check(resource(has_practice="probably")), "has_practice must be")
        self.assertProblem(self.run_check(resource(stated_length_hours=0)), "stated_length_hours")

    def test_facts_need_sources(self):
        self.assertProblem(self.run_check(resource(facts=[])), "at least one sourced fact")
        self.assertProblem(self.run_check(resource(facts=[{"claim": "Free."}])), "facts[0]")

    def test_targets_must_be_real_slugs(self):
        self.assertProblem(self.run_check(resource(targets=["nope"])), "is not the slug")

    def test_ranking_and_personal_fields_are_rejected_anywhere(self):
        for bad in ({"affiliate_url": "https://example.org"}, {"sponsored": True}, {"rank_boost": 2},
                    {"embed": {"allowed": False, "priority": 1}}, {"contact_email": "x"}):
            self.assertProblem(self.run_check(resource(**bad)), "is not allowed")

    def test_an_approved_review_names_who_and_when(self):
        self.assertProblem(self.run_check(resource(review={"status": "approved"})), "reviewer_kind")
        self.assertProblem(
            self.run_check(resource(review={"status": "approved", "reviewer_kind": "ai",
                                            "reviewed_on": "2026-11-25"})), "reviewer_model")
        self.assertProblem(
            self.run_check(resource(review={"status": "approved", "reviewer_kind": "human",
                                            "reviewed_on": "2999-01-01"})), "in the future")


class MapTests(Helpers, unittest.TestCase):
    def test_a_valid_map_passes(self):
        self.assertEqual(self.run_check(rmap=resource_map()), [])

    def test_file_name_must_match_target_and_resource(self):
        self.assertProblem(self.run_check(rmap=resource_map(), map_name="x.yaml"), "file name must be")

    def test_the_resource_must_exist_and_list_the_target(self):
        self.assertProblem(self.run_check(rmap=resource_map(resource_id="ghost"),
                                          map_name="t-one__ghost.yaml"), "is not in data/external_resources")
        self.assertProblem(self.run_check(resource(targets=["t-one"]) | {"targets": []},
                                          resource_map()), "does not list target")

    def test_every_objective_is_listed_once(self):
        only = [{"objective": "1.1", "covered": True, "sections": [section()]}]
        self.assertProblem(self.run_check(rmap=resource_map(only)), "objective 1.2 of m.yaml is not listed")
        twice = only + only + [{"objective": "1.2", "covered": False, "sections": []}]
        self.assertProblem(self.run_check(rmap=resource_map(twice)), "listed twice")
        ghost = only + [{"objective": "1.2", "covered": False, "sections": []},
                        {"objective": "9.9", "covered": False, "sections": []}]
        self.assertProblem(self.run_check(rmap=resource_map(ghost)), "is not an objective")

    def test_covered_must_agree_with_sections(self):
        bad = [{"objective": "1.1", "covered": False, "sections": [section()]},
               {"objective": "1.2", "covered": True, "sections": []}]
        problems = self.run_check(rmap=resource_map(bad))
        self.assertEqual(sum("covered must be true with sections" in p for p in problems), 2)

    def test_section_fields(self):
        bad = [{"objective": "1.1", "covered": True, "sections": [
            section(depth="deep", confidence="sure", has_practice="yes", locator="http://x", label="")]},
            {"objective": "1.2", "covered": False, "sections": []}]
        problems = self.run_check(rmap=resource_map(bad))
        for text in ("depth must be", "confidence must be", "has_practice must be", "locator must be", "label is required"):
            self.assertProblem(problems, text)

    def test_time_ranges_come_in_ordered_pairs(self):
        for kw in ({"start_seconds": 10}, {"start_seconds": 20, "end_seconds": 10}, {"start_seconds": 1.5, "end_seconds": 9}):
            cov = [{"objective": "1.1", "covered": True, "sections": [section(**kw)]},
                   {"objective": "1.2", "covered": False, "sections": []}]
            self.assertProblem(self.run_check(rmap=resource_map(cov)), "start_seconds and end_seconds")
        cov = [{"objective": "1.1", "covered": True, "sections": [section(start_seconds=0, end_seconds=90)]},
               {"objective": "1.2", "covered": False, "sections": []}]
        self.assertEqual(self.run_check(rmap=resource_map(cov)), [])

    def test_a_map_needs_a_method_and_a_review(self):
        problems = self.run_check(rmap=resource_map(method="", review={}))
        self.assertProblem(problems, "method is required")
        self.assertProblem(problems, "review.status must be")


if __name__ == "__main__":
    unittest.main()
