"""Tests for the report-only Dart coverage summary (plan PR-9)."""
import contextlib
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path

CI_DIR = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI_DIR))
import summarize_coverage as sc  # noqa: E402


def record(path, hits):
    body = "".join(f"DA:{i + 1},{h}\n" for i, h in enumerate(hits))
    return f"SF:{path}\n{body}LF:{len(hits)}\nLH:{sum(1 for h in hits if h)}\nend_of_record\n"


LCOV = (
    record("/repo/lib/services/assessment/grader.dart", [1, 0, 0, 0] * 10)
    + record("/repo/lib/providers/auth_provider.dart", [1, 1, 1, 0])
    + record("/repo/lib/widgets/button.dart", [1, 1])
    + record("/repo/lib/models/thing.g.dart", [0] * 50)
    + record("/repo/lib/l10n/app_localizations_en.dart", [0] * 50)
    + record("/repo/lib/services/offline/outbox.dart", [5, 0])
)


class CoverageTest(unittest.TestCase):
    def test_parse_counts_hits_and_strips_root(self):
        files = sc.parse_lcov(LCOV, "/repo")
        grader = [f for f in files if f.path == "lib/services/assessment/grader.dart"][0]
        self.assertEqual((grader.found, grader.hit), (40, 10))

    def test_areas(self):
        self.assertEqual(sc.area_of("lib/services/assessment/grader.dart"), "Assessment, simulation & grading")
        self.assertEqual(sc.area_of("lib/providers/auth_provider.dart"), "Auth, roles & moderation")
        self.assertEqual(sc.area_of("lib/providers/site_feature_provider.dart"), "Feature controls & governance")
        self.assertEqual(sc.area_of("lib/services/offline/outbox.dart"), "Offline, sync & storage")
        self.assertEqual(sc.area_of("lib/services/lesson/lesson_import_service.dart"), "Lesson import & generation")
        self.assertIsNone(sc.area_of("lib/widgets/button.dart"))

    def test_render_excludes_generated_and_reports_areas(self):
        text = sc.render(sc.parse_lcov(LCOV, "/repo"), top=5)
        # 40 + 4 + 2 + 2 = 48 lines; hits 10 + 3 + 2 + 1 = 16
        self.assertIn("Overall `lib/`: **33.3%** (16/48 lines, 4 files; 2 generated/non-lib files excluded)", text)
        self.assertIn("| Assessment, simulation & grading | 1 | 10/40 | 25.0% |", text)
        self.assertIn("| Auth, roles & moderation | 1 | 3/4 | 75.0% |", text)
        self.assertIn("| Privacy & analytics | 0 | 0/0 | — |", text)
        self.assertIn("`lib/services/assessment/grader.dart`", text)  # >=30 lines, in low list
        self.assertNotIn("auth_provider.dart` |", text.split("Least-covered")[1])  # too small to list
        self.assertIn("No percentage gate", text)

    def test_cli_missing_or_empty_is_error_else_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            empty = Path(tmp) / "lcov.info"
            empty.write_text("", encoding="utf-8")
            good = Path(tmp) / "good.info"
            good.write_text(LCOV, encoding="utf-8")
            old = os.environ.pop("GITHUB_STEP_SUMMARY", None)
            try:
                with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(sc.main([str(Path(tmp) / "missing.info")]), 2)
                    self.assertEqual(sc.main([str(empty)]), 2)
                    self.assertEqual(sc.main([str(good), "--root", "/repo"]), 0)
            finally:
                if old is not None:
                    os.environ["GITHUB_STEP_SUMMARY"] = old


if __name__ == "__main__":
    unittest.main()
