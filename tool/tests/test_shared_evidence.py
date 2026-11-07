"""One non-persistent evidence envelope for file practice and simulations."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.shared_evidence import prepare_activity_evidence

OWNER = "ba410000-0000-4000-8000-000000000001"
ATTEMPT = "ba430000-0000-4000-8000-000000000001"
DIGEST = "a" * 64


class SharedEvidenceTests(unittest.TestCase):
    def test_workbook_uses_transferable_skill_key_and_provisional_trust(self):
        data = prepare_activity_evidence(
            source_kind="file_assessment",
            activity_id="excel-budget-total-v1", activity_version=1,
            attempt_id=ATTEMPT, owner_id=OWNER,
            skill_slug="spreadsheet-range-summation",
            result="pass", assistance_mode="independent",
            artifact_digest=DIGEST,
        )
        self.assertEqual(data["source_kind"], "file_assessment")
        self.assertEqual(data["skill_slug"], "spreadsheet-range-summation")
        self.assertEqual(data["trust"], "unverified")
        self.assertFalse(data["can_award_skill"])
        self.assertNotIn("score", data)
        self.assertNotIn("user_skill_stats", data)
        self.assertNotIn("record_events", data)

    def test_preview_simulation_uses_same_keys_without_fake_identity(self):
        data = prepare_activity_evidence(
            source_kind="simulation_preview",
            activity_id="networking-preview", activity_version=1,
            attempt_id=None, owner_id=None, skill_slug=None,
            result="completed", assistance_mode="guided",
            artifact_digest=None,
        )
        workbook = prepare_activity_evidence(
            source_kind="file_assessment",
            activity_id="excel-budget-total-v1", activity_version=1,
            attempt_id=ATTEMPT, owner_id=OWNER,
            skill_slug="spreadsheet-range-summation",
            result="pass", assistance_mode="independent",
            artifact_digest=DIGEST,
        )
        self.assertEqual(set(data), set(workbook))
        self.assertEqual(data["trust"], "unverified")
        self.assertEqual(data["can_award_skill"], False)
        self.assertIsNone(data["owner_id"])

    def test_software_vendor_is_not_part_of_skill_key(self):
        # Excel and Google Sheets practice must target the same transferable skill.
        for activity in ("excel-budget-total-v1", "sheets-budget-total-v1"):
            data = prepare_activity_evidence(
                source_kind="file_assessment", activity_id=activity,
                activity_version=1, attempt_id=ATTEMPT, owner_id=OWNER,
                skill_slug="spreadsheet-range-summation",
                result="pass", assistance_mode="independent",
                artifact_digest=DIGEST,
            )
            self.assertEqual(data["skill_slug"], "spreadsheet-range-summation")

    def test_self_asserted_verification_cannot_be_requested(self):
        kw = dict(source_kind="file_assessment",
                  activity_id="excel-budget-total-v1", activity_version=1,
                  attempt_id=ATTEMPT, owner_id=OWNER,
                  skill_slug="spreadsheet-range-summation",
                  result="pass", assistance_mode="independent",
                  artifact_digest=DIGEST)
        for malicious in (
            {"trust": "server_verified"}, {"can_award_skill": True},
            {"score": 100}, {"event_type": "mastered"},
        ):
            with self.subTest(malicious=malicious), self.assertRaises(TypeError):
                prepare_activity_evidence(**kw, **malicious)

    def test_file_assessment_must_have_owner_attempt_and_digest(self):
        for owner, attempt, digest in (
            (None, ATTEMPT, DIGEST), (OWNER, None, DIGEST),
            (OWNER, ATTEMPT, "x"), (OWNER, ATTEMPT, None),
            (OWNER.upper(), ATTEMPT, DIGEST),
        ):
            with self.subTest(owner=owner, attempt=attempt, digest=digest):
                with self.assertRaises(ValueError):
                    prepare_activity_evidence(
                        source_kind="file_assessment",
                        activity_id="excel-budget-total-v1",
                        activity_version=1, owner_id=owner,
                        attempt_id=attempt, artifact_digest=digest,
                        result="pass", assistance_mode="independent",
                        skill_slug="spreadsheet-range-summation",
                    )

    def test_simulation_preview_cannot_assert_persistent_owner_evidence(self):
        with self.assertRaises(ValueError):
            prepare_activity_evidence(
                source_kind="simulation_preview", activity_id="networking-preview",
                activity_version=1, owner_id=OWNER, attempt_id=ATTEMPT,
                artifact_digest=None, skill_slug="networking",
                result="completed", assistance_mode="independent",
            )

    def test_invalid_status_and_skill_aliases_rejected(self):
        for result, skill in (
            ("verified", "spreadsheet-range-summation"),
            ("pass", "excel-range-summation"),
            ("pass", "../../skill"),
        ):
            with self.subTest(result=result, skill=skill):
                with self.assertRaises(ValueError):
                    prepare_activity_evidence(
                        source_kind="file_assessment",
                        activity_id="excel-budget-total-v1",
                        activity_version=1, owner_id=OWNER, attempt_id=ATTEMPT,
                        artifact_digest=DIGEST, skill_slug=skill,
                        result=result, assistance_mode="independent",
                    )


if __name__ == "__main__":
    unittest.main()
