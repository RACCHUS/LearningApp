import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ci"))
import verify_content_sources as v  # noqa: E402

REAL = json.loads(
    (Path(__file__).resolve().parents[2] / "data" / "content_sources.json").read_text(encoding="utf-8")
)


def bridge(url, license_text, posture="link_only"):
    return {"sources": [{"url": url, "license": license_text, "rights_posture": posture}]}


class RegistryTests(unittest.TestCase):
    def test_real_registry_is_valid(self):
        self.assertEqual(v.validate_registry(REAL), [])

    def test_allowed_uses_cannot_exceed_license(self):
        reg = copy.deepcopy(REAL)
        src = next(s for s in reg["sources"] if s["license"] == "proprietary")
        src["allowed_uses"] = ["link", "adapt"]
        self.assertTrue(any("exceed" in p for p in v.validate_registry(reg)))

    def test_ai_transform_needs_adapt(self):
        reg = copy.deepcopy(REAL)
        src = next(s for s in reg["sources"] if s["license"] == "cc_by_4")
        src["allowed_uses"] = ["link", "ai_transform"]
        self.assertTrue(any("ai_transform needs adapt" in p for p in v.validate_registry(reg)))

    def test_evidence_is_required(self):
        reg = copy.deepcopy(REAL)
        reg["sources"][0]["license_evidence"] = {"url": "http://x", "checked_at": "soon"}
        self.assertTrue(any("license_evidence" in p for p in v.validate_registry(reg)))


class LicenseTextTests(unittest.TestCase):
    def test_normalizes_common_statements(self):
        cases = {
            "CC BY-NC-SA 4.0; publisher prohibits ...": "cc_by_nc_sa_4",
            "Creative Commons Attribution 4.0 International (CC BY 4.0)": "cc_by_4",
            "CC BY-SA 4.0": "cc_by_sa_4",
            "Public Domain (U.S. Government Work)": "public_domain_us_gov",
            "College Board Proprietary (Educational Reference Blueprint)": "proprietary",
            "Copyright IEEE (Educational Reference)": "proprietary",
            "Authoritative Undergraduate Curriculum Standard": "unknown",
        }
        for text, lid in cases.items():
            self.assertEqual(v.normalize_license(text), lid, text)

    def test_longest_prefix_wins(self):
        s = v.find_source(REAL, "https://openstax.org/books/college-algebra-2e/pages/1-1")
        self.assertEqual(s["id"], "openstax-college-algebra-2e")
        s = v.find_source(REAL, "https://openstax.org/books/college-algebra/pages/1-1")
        self.assertEqual(s["id"], "openstax-college-algebra-1e")


class ScanTests(unittest.TestCase):
    def run_scan(self, files):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for rel, data in files.items():
                p = root / rel
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(json.dumps(data), encoding="utf-8")
            return v.scan(REAL, root)

    def test_registered_link_only_use_passes(self):
        problems, warnings = self.run_scan({
            "content/bridges/a.bridge.json": bridge(
                "https://openstax.org/books/prealgebra-2e/pages/6-1", "CC BY-NC-SA 4.0"),
        })
        self.assertEqual((problems, warnings), ([], []))

    def test_unregistered_source_fails(self):
        problems, _ = self.run_scan({
            "content/bridges/a.bridge.json": bridge("https://example.com/book", "CC BY 4.0"),
        })
        self.assertTrue(any("not in data/content_sources.json" in p for p in problems))

    def test_adapting_a_noncommercial_source_fails(self):
        problems, _ = self.run_scan({
            "content/bridges/a.bridge.json": bridge(
                "https://openstax.org/books/prealgebra-2e/pages/6-1", "CC BY-NC-SA 4.0", "may_adapt"),
        })
        self.assertTrue(any("does not allow 'adapt'" in p for p in problems))

    def test_adapting_needs_owner_approval(self):
        reg = copy.deepcopy(REAL)
        src = next(s for s in reg["sources"] if s["id"] == "openstax-prealgebra-1e")
        src["status"] = "proposed"
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "content" / "bridges" / "a.bridge.json"
            p.parent.mkdir(parents=True)
            p.write_text(json.dumps(bridge(
                "https://openstax.org/books/prealgebra/pages/6-1", "CC BY 4.0", "may_adapt")))
            problems, _ = v.scan(reg, Path(d))
        self.assertTrue(any("needs the owner's approval" in p for p in problems))

    def test_approved_source_may_be_adapted(self):
        problems, _ = self.run_scan({
            "content/bridges/a.bridge.json": bridge(
                "https://openstax.org/books/prealgebra/pages/6-1", "CC BY 4.0", "may_adapt"),
        })
        self.assertEqual(problems, [])

    def test_wrong_license_statement_fails(self):
        problems, _ = self.run_scan({
            "content/bridges/a.bridge.json": bridge(
                "https://openstax.org/books/prealgebra-2e/pages/6-1", "CC BY 4.0"),
        })
        self.assertTrue(any("registry says cc_by_nc_sa_4" in p for p in problems))

    def test_real_repository_passes(self):
        self.assertEqual(v.main([]), 0)

    def test_real_manifests_have_no_pin_warnings(self):
        _, warnings = v.scan(REAL, Path(__file__).resolve().parents[2])
        self.assertEqual([w for w in warnings if "sha256" in w], [])


class PinTests(unittest.TestCase):
    """Rule 5 (ingestion plan D-6): manifest sha256 pins must be real."""

    REAL_DIGEST = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"[::-1]

    def check(self, releases):
        problems, warnings = [], []
        v.check_pins(releases, problems, warnings)
        return problems, warnings

    def test_placeholders_are_rejected(self):
        bad = {
            "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2": "repeated pattern",
            "5d41402abc4b2a76b9719d911017c592b21b79fbf576c9ef56e5d0fc0dc95116": "common word",
            "0" * 64: "too few distinct",
            "ABCDEF" * 10 + "ABCD": "64 lowercase hex",
            "abc123": "64 lowercase hex",
        }
        for sha, reason in bad.items():
            why = v.pin_problem(sha)
            self.assertIsNotNone(why, sha)
            self.assertIn(reason, why, sha)

    def test_a_plausible_digest_passes(self):
        self.assertIsNone(v.pin_problem(self.REAL_DIGEST))

    def test_shared_runs_across_sources_fail(self):
        a = "b45a6c1e95632b85d38f8cf2e4389ab9213bc54784a621e25e9d3d3a77a94f01"
        b = "7f8c12b4e95632b85d38f8cf2e4389ab9213bc54784a621e25e9d3d3a77a94f0"
        problems, _ = self.check([("x.yaml", {"id": "one", "sha256": a}),
                                  ("y.yaml", {"id": "two", "sha256": b})])
        self.assertTrue(any("share a" in p for p in problems))

    def test_same_source_in_two_manifests_may_share_its_pin(self):
        problems, _ = self.check([("x.yaml", {"id": "one", "sha256": self.REAL_DIGEST}),
                                  ("y.yaml", {"id": "one", "sha256": self.REAL_DIGEST})])
        self.assertEqual(problems, [])

    def test_missing_pin_needs_a_reason(self):
        _, warnings = self.check([("x.yaml", {"id": "one"})])
        self.assertTrue(any("no sha256" in w for w in warnings))
        problems, warnings = self.check([
            ("x.yaml", {"id": "one", "metadata": {"checksum_status": "unverified_remote_document"}}),
            ("y.yaml", {"id": "two", "metadata": {"imported_by": "tool/import_open_textbook.py"}}),
        ])
        self.assertEqual((problems, warnings), ([], []))

    def test_unknown_checksum_status_fails(self):
        problems, _ = self.check([("x.yaml", {"id": "one", "metadata": {"checksum_status": "trust me"}})])
        self.assertTrue(any("checksum_status must be one of" in p for p in problems))



class DeclaredUseTests(unittest.TestCase):
    """Rule 6 (plan v1.2 §6, slice 5): declared operations and the frozen allowlist."""

    URL = "https://openstax.org/books/college-algebra/pages/preface"

    def manifest(self, use=None):
        meta = {"checksum_status": "unverified_remote_document"}
        if use:
            meta["use"] = use
        return {"source_releases": [{"id": "oc", "source_url": self.URL, "license": "CC BY 4.0", "metadata": meta}]}

    def allowlist(self, *entries):
        return {"entries": [dict(manifest="m.yaml", release_id="oc", issue="undeclared_use",
                                 open_decision="D-test", **e) for e in entries]}

    def scan(self, files):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for rel, data in files.items():
                path = root / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps(data), encoding="utf-8")
            problems, _ = v.scan(REAL, root)
            return problems, v.publish_check(root, "content/m.yaml")

    def test_a_declared_use_passes(self):
        self.assertEqual(self.scan({"content/m.yaml": self.manifest("reference")}), ([], []))

    def test_an_undeclared_use_fails(self):
        problems, _ = self.scan({"content/m.yaml": self.manifest()})
        self.assertTrue(any("must declare metadata.use" in p for p in problems))

    def test_an_allowlisted_release_passes_but_cannot_be_published(self):
        problems, blocked = self.scan({"content/m.yaml": self.manifest(),
                                       "data/rights_discrepancy_allowlist.json": self.allowlist({})})
        self.assertEqual(problems, [])
        self.assertTrue(blocked and "cannot be published" in blocked[0])

    def test_a_stale_allowlist_entry_fails(self):
        problems, _ = self.scan({"content/m.yaml": self.manifest("reference"),
                                 "data/rights_discrepancy_allowlist.json": self.allowlist({})})
        self.assertTrue(any("no longer a discrepancy" in p for p in problems))

    def test_an_entry_needs_an_open_decision(self):
        bad = {"entries": [{"manifest": "m.yaml", "release_id": "oc", "issue": "undeclared_use"}]}
        problems, _ = self.scan({"content/m.yaml": self.manifest(), "data/rights_discrepancy_allowlist.json": bad})
        self.assertTrue(any("open_decision" in p for p in problems))

    def test_the_real_allowlist_blocks_only_its_manifests(self):
        root = Path(__file__).resolve().parents[2]
        self.assertTrue(v.publish_check(root, "content/clep_college_algebra.yaml"))
        self.assertEqual(v.publish_check(root, "content/excel_fundamentals.yaml"), [])


if __name__ == "__main__":
    unittest.main()
