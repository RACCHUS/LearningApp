#!/usr/bin/env python3
"""Unit tests for the CLEP Content Production Pipeline & Verification Engine."""
from __future__ import annotations

import copy
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from tool.clep_content_pipeline import (
    EXPECTED_PSYCH_DOMAINS,
    MANIFEST_PATH,
    OFFICIAL_COURSE_SPECS,
    compute_simulation_quotas,
    load_yaml,
    resolve_course_spec,
    run_pipeline,
    run_stage_f_database_ingestion,
    verify_blueprint_coverage,
    verify_lesson_architecture,
    verify_psychometric_items,
    verify_simulation_items,
    verify_source_provenance,
)


class TestClepContentPipeline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = load_yaml(MANIFEST_PATH)

    def test_pipeline_on_pilot_manifest(self):
        """The Introductory Psychology manifest must pass all 6 pipeline stages cleanly."""
        success = run_pipeline(MANIFEST_PATH)
        self.assertTrue(success, "Introductory Psychology manifest failed pipeline verification.")

    def test_stage_a_source_provenance(self):
        """Source provenance must verify blueprint authority and OER instructional reference."""
        issues = verify_source_provenance(self.manifest)
        self.assertEqual(issues, [], f"Stage A reported unexpected issues: {issues}")

        # Mutate to missing blueprint_authority
        bad_manifest = copy.deepcopy(self.manifest)
        bad_manifest["source_releases"] = [
            r for r in bad_manifest["source_releases"]
            if r.get("metadata", {}).get("role") != "blueprint_authority"
        ]
        issues_mutated = verify_source_provenance(bad_manifest)
        self.assertTrue(any("blueprint_authority" in i for i in issues_mutated))

    def test_stage_b_blueprint_coverage(self):
        """All 13 College Board domains must be present and weights sum to 1.00."""
        domain_map, issues = verify_blueprint_coverage(self.manifest)
        self.assertEqual(issues, [], f"Stage B reported unexpected issues: {issues}")
        for code in EXPECTED_PSYCH_DOMAINS:
            self.assertIn(code, domain_map)
            self.assertGreater(domain_map[code]["weight"], 0.0)
            self.assertGreater(domain_map[code]["objective_count"], 0)

        # Mutate to unbalanced weight
        bad_manifest = copy.deepcopy(self.manifest)
        bad_manifest["domains"][0]["weight"] = 0.50
        _, bad_issues = verify_blueprint_coverage(bad_manifest)
        self.assertTrue(any("sum to 1.0" in i for i in bad_issues))

    def test_stage_c_lesson_architecture(self):
        """Lessons must have titles, citations, concept_slugs, and structured blocks."""
        lesson_count, issues = verify_lesson_architecture(self.manifest)
        self.assertEqual(issues, [], f"Stage C reported unexpected issues: {issues}")
        self.assertGreaterEqual(lesson_count, 13)

        # Mutate to missing blocks
        bad_manifest = copy.deepcopy(self.manifest)
        bad_manifest["domains"][0]["objectives"][0]["lessons"][0]["blocks"] = []
        _, bad_issues = verify_lesson_architecture(bad_manifest)
        self.assertTrue(any("no instructional blocks" in i for i in bad_issues))

    def test_stage_d_psychometric_items(self):
        """Assessment items must strictly follow Haladyna psychometric rules."""
        item_count, issues = verify_psychometric_items(self.manifest)
        self.assertEqual(issues, [], f"Stage D reported unexpected issues: {issues}")
        self.assertGreaterEqual(item_count, 13)

        # Test Haladyna: Reject "all of the above"
        bad_manifest = copy.deepcopy(self.manifest)
        bad_manifest["domains"][0]["objectives"][0]["lessons"][0]["assessment_items"][0]["response_spec"]["options"][3] = "All of the above"
        _, bad_issues = verify_psychometric_items(bad_manifest)
        self.assertTrue(any("prohibited giveaway" in i for i in bad_issues))

        # Test Haladyna: Reject distractor length imbalance (> 3.0 ratio)
        bad_manifest2 = copy.deepcopy(self.manifest)
        opts = bad_manifest2["domains"][0]["objectives"][0]["lessons"][0]["assessment_items"][0]["response_spec"]["options"]
        opts[0] = "A"
        opts[1] = "A very extraordinarily long explanation of a cognitive mechanism that outspans everything else"
        opts[2] = "B"
        opts[3] = "C"
        _, bad_issues2 = verify_psychometric_items(bad_manifest2)
        self.assertTrue(any("distractor length imbalance" in i for i in bad_issues2))

    def test_stage_e_simulation_quotas(self):
        """Largest-remainder quota allocation must sum to exactly 95 questions."""
        domain_map, _ = verify_blueprint_coverage(self.manifest)
        quotas = compute_simulation_quotas(domain_map, total_questions=95)
        self.assertEqual(sum(quotas.values()), 95)
        for code in EXPECTED_PSYCH_DOMAINS:
            self.assertGreater(quotas[code], 0)
        # History & Methods (10.5%) should get ~10 questions
        self.assertIn(quotas["1.0"], {10, 11})
        # Biological Bases (9.5%) should get 9 questions
        self.assertEqual(quotas["2.0"], 9)
        # Statistics & Measurement (3.2%) should get 3 questions
        self.assertEqual(quotas["13.0"], 3)

    def test_stage_e_require_simulation_enforcement(self):
        """Simulation quota enforcement must strictly require all 95 questions matching domain quotas."""
        domain_map, _ = verify_blueprint_coverage(self.manifest)
        counts, issues = verify_simulation_items(self.manifest, domain_map, require_simulation=True)
        self.assertEqual(issues, [], f"Stage E with require_simulation failed: {issues}")
        self.assertEqual(sum(counts.values()), 95)

        # Mutate to 94 questions
        bad_manifest = copy.deepcopy(self.manifest)
        bad_manifest["domains"][0]["objectives"][0]["lessons"][0]["assessment_items"].pop()
        _, bad_issues = verify_simulation_items(bad_manifest, domain_map, require_simulation=True)
        self.assertTrue(any("requires exactly 95 authored questions" in i for i in bad_issues))

    @patch("subprocess.run")
    def test_stage_f_subprocess_execution_regression(self, mock_run):
        """Stage F must execute subprocess.run with shell=False and full argument list."""
        mock_proc = MagicMock()
        mock_proc.returncode = 0
        mock_proc.stdout = "Ingestion dry run passed"
        mock_proc.stderr = ""
        mock_run.return_value = mock_proc

        issues = run_stage_f_database_ingestion(MANIFEST_PATH)
        self.assertEqual(issues, [])
        self.assertEqual(mock_run.call_count, 2)

        # Check call 1: ingest_curriculum.dart
        args1, kwargs1 = mock_run.call_args_list[0]
        cmd1 = args1[0]
        self.assertFalse(kwargs1.get("shell", True), "Stage F ingest command MUST use shell=False")
        self.assertIn("run", cmd1)
        self.assertIn("tool/ingest_curriculum.dart", cmd1)
        self.assertIn("--dry-run", cmd1)
        self.assertIn("--target", cmd1)
        self.assertIn("clep-introductory-psychology", cmd1)

        # Check call 2: lint_manifest.dart
        args2, kwargs2 = mock_run.call_args_list[1]
        cmd2 = args2[0]
        self.assertFalse(kwargs2.get("shell", True), "Stage F lint command MUST use shell=False")
        self.assertIn("run", cmd2)
        self.assertIn("tool/lint_manifest.dart", cmd2)

    @patch("subprocess.run")
    def test_stage_f_captures_failure_exit_codes(self, mock_run):
        """Stage F must capture non-zero exit codes from failed subprocess runs."""
        mock_proc = MagicMock()
        mock_proc.returncode = 1
        mock_proc.stdout = "Schema violation detected"
        mock_proc.stderr = "Error: Invalid manifest"
        mock_run.return_value = mock_proc

        issues = run_stage_f_database_ingestion(MANIFEST_PATH)
        self.assertGreaterEqual(len(issues), 1)
        self.assertTrue(any("failed with exit code 1" in i for i in issues))

    def test_algebra_course_spec_resolution_and_quotas(self):
        """College Algebra specification must resolve 4 domains and 60 simulation questions (15, 15, 18, 12)."""
        algebra_manifest = {
            "target": {"slug": "clep-college-algebra", "version_code": "2026"},
            "domains": [
                {"code": "1.0", "title": "Algebraic operations", "weight": 0.25, "objectives": [{"code": "1.1"}]},
                {"code": "2.0", "title": "Equations and inequalities", "weight": 0.25, "objectives": [{"code": "2.1"}]},
                {"code": "3.0", "title": "Functions and their properties", "weight": 0.30, "objectives": [{"code": "3.1"}]},
                {"code": "4.0", "title": "Number systems and operations", "weight": 0.20, "objectives": [{"code": "4.1"}]},
            ]
        }
        spec = resolve_course_spec(algebra_manifest)
        self.assertEqual(spec["title"], "College Algebra")
        self.assertEqual(spec["exam_code"], "CLEP-ALG")
        self.assertEqual(spec["total_simulation_questions"], 60)
        self.assertEqual(len(spec["domains"]), 4)

        domain_map, issues = verify_blueprint_coverage(algebra_manifest, course_spec=spec)
        self.assertEqual(issues, [])
        self.assertEqual(len(domain_map), 4)

        quotas = compute_simulation_quotas(domain_map, total_questions=60, course_spec=spec)
        self.assertEqual(sum(quotas.values()), 60)
        self.assertEqual(quotas["1.0"], 15)  # 25% of 60
        self.assertEqual(quotas["2.0"], 15)  # 25% of 60
        self.assertEqual(quotas["3.0"], 18)  # 30% of 60
        self.assertEqual(quotas["4.0"], 12)  # 20% of 60


if __name__ == "__main__":
    unittest.main()
