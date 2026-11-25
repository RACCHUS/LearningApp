"""Tests for tool/rights_overlap_audit.py (offline: books are given as shingle sets)."""
import json
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tool"))

import rights_overlap_audit as audit  # noqa: E402

BOOK_TEXT = ("A linear equation in one variable can be written in the form ax plus b equals zero "
             "where a is not zero. Psychology is the scientific study of mind and behavior.")
LATER_TEXT = BOOK_TEXT + " Imagine a candle a book of matches and a box of thumbtacks on a table."


def book(text: str) -> set[str]:
    return set(audit.shingles(audit.words(text)))


def manifest(lesson_text: str, objective_text: str = "Short.") -> dict:
    return {
        "domains": [{"code": "1", "title": "Domain", "objectives": [{
            "code": "1.1", "title": "Objective", "description": objective_text,
            "citation": BOOK_TEXT,  # citations are not the manifest's own prose
            "lessons": [{"title": "Lesson", "blocks": [{"content": {"text": lesson_text}}],
                         "tags": ["linear"], "emoji": "x"}],
        }]}],
        "stimuli": [],
    }


class OverlapAuditTest(unittest.TestCase):
    def test_original_text_has_no_overlap(self):
        r = audit.audit(manifest("Solve for the unknown by isolating it on one side of the equals sign."),
                        {"b1": book(BOOK_TEXT)})
        self.assertEqual(r["books"]["b1"]["matched_shingles"], 0)
        self.assertEqual(r["books"]["b1"]["share"], 0.0)
        self.assertEqual(r["books"]["b1"]["matched_passages"], [])

    def test_copied_passage_is_found_with_its_length(self):
        copied = "As the book says, a linear equation in one variable can be written in the form ax plus b equals zero."
        r = audit.audit(manifest(copied), {"b1": book(BOOK_TEXT)})
        b = r["books"]["b1"]
        self.assertGreater(b["share"], 0.5)
        self.assertEqual(b["longest_run_words"], 17)
        self.assertIn("a linear equation in one variable can be written in the form ax plus b equals zero",
                      b["matched_passages"])
        lesson = next(s for s in r["segments"] if s["segment"].startswith("lesson"))
        self.assertGreater(lesson["b1"]["share"], 0.10)
        self.assertEqual(b["segments_with_share_over_10pct"], 1)

    def test_citations_tags_and_emoji_are_not_counted(self):
        r = audit.audit(manifest("Entirely new words here for the reader to enjoy today."),
                        {"b1": book(BOOK_TEXT)})
        self.assertEqual(r["books"]["b1"]["matched_shingles"], 0)

    def test_later_edition_only_text_is_reported(self):
        text = "Consider a candle a book of matches and a box of thumbtacks for this classic problem."
        r = audit.audit(manifest(text), {"first": book(BOOK_TEXT), "later": book(LATER_TEXT)})
        only = r["later_edition_only"]
        self.assertEqual(only["book"], "later")
        self.assertIn("a candle a book of matches and a", only["shingles"])
        self.assertEqual(r["books"]["first"]["matched_shingles"], 0)

    def test_single_book_has_no_later_edition_section(self):
        r = audit.audit(manifest("Hello there."), {"b1": book(BOOK_TEXT)})
        self.assertIsNone(r["later_edition_only"])

    def test_matched_runs_are_maximal(self):
        ws = audit.words("x " + BOOK_TEXT.split(".")[0] + " y")
        runs = audit.matched_runs(ws, book(BOOK_TEXT))
        self.assertEqual(len(runs), 1)
        self.assertTrue(runs[0].startswith("a linear equation"))
        self.assertTrue(runs[0].endswith("is not zero"))

    def test_recorded_clep_audits_support_reference(self):
        """The recorded evidence behind the CLEP releases' 'reference' use."""
        path = REPO / "data" / "rights_audits" / "2026-11-25_clep_openstax.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        for entry in data["audits"]:
            first = entry["books"][entry["declared_release_book"]]
            self.assertLess(first["share"], 0.02, entry["manifest"])
            self.assertEqual(first["segments_with_share_over_10pct"], 0, entry["manifest"])
            self.assertEqual(entry["decision"], "reference")


if __name__ == "__main__":
    unittest.main()
