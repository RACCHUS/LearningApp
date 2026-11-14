"""Tests for the generated database security-check matrix (plan §12)."""
import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

CI_DIR = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI_DIR))
import pgtap_security_matrix as m  # noqa: E402

SECURE = """
begin;
select plan(5);
-- set role anon   (comments are ignored)
set local role anon;
select throws_ok($$ select * from private.x $$, '42501');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'u1', true);
select ok(not exists(select 1 from t));
select set_config('request.jwt.claims', '{"sub": "u2"}', true);
select is_empty($$ select 1 $$);
reset role;
select ok(has_table_privilege('authenticated', 'public.t', 'SELECT'));
select ok((select relrowsecurity from pg_class where relname = 't'));
select * from finish();
rollback;
"""
CROSS_USER_ONLY = """
select plan(2);
set local role authenticated;
perform set_config('request.jwt.claim.sub', 'a', true);
select is((select count(*)::int from t), 0);
perform set_config('request.jwt.claim.sub', 'b', true);
select is((select count(*)::int from t), 0);
"""
PLAIN = "select plan(3);\nselect is(1, 1);\n"
NO_PLAN = "select no_plan();\nset role service_role;\nselect throws_ok('x');\n"


class MatrixTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        tests = self.root / m.TESTS_DIR
        tests.mkdir(parents=True)
        for name, sql in {
            "ana_103_privacy_test.sql": SECURE,
            "word_learning_owner_rls.sql": CROSS_USER_ONLY,
            "library_search_performance_test.sql": PLAIN,
            "software_learning_gate_test.sql": NO_PLAN,
            "zzz_unknown_test.sql": PLAIN,
        }.items():
            (tests / name).write_text(sql, encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def scan(self, name):
        return m.scan(self.root / m.TESTS_DIR / name)

    def test_signals_ignore_comments_and_count_each_kind(self):
        f = self.scan("ana_103_privacy_test.sql")
        self.assertEqual(f.area, "Analytics, privacy & retention")
        self.assertEqual(f.planned, 5)
        self.assertEqual(f.roles, {"anon", "authenticated"})
        self.assertEqual((f.identity_switches, f.denials, f.privileges, f.rls_checks), (2, 3, 1, 1))

    def test_cross_user_identity_switches_count_as_a_security_signal(self):
        f = self.scan("word_learning_owner_rls.sql")
        self.assertEqual(f.denials, 0)
        self.assertTrue(m.has_security_signal(f))
        self.assertFalse(m.has_security_signal(self.scan("library_search_performance_test.sql")))

    def test_no_plan_is_reported_not_counted_as_zero(self):
        f = self.scan("software_learning_gate_test.sql")
        self.assertTrue(f.no_plan)
        self.assertEqual(f.roles, {"service_role"})
        text = m.build(self.root)
        self.assertIn("runtime (`no_plan`)", text)
        self.assertIn("plus 1 files using `no_plan()`", text)

    def test_render_areas_thin_list_and_other(self):
        text = m.build(self.root)
        self.assertIn("**Totals:** 5 test files, 13 planned assertions", text)
        thin = text.split("## Files with no security signal")[1].split("## By file")[0]
        self.assertIn("library_search_performance_test.sql", thin)
        self.assertIn("zzz_unknown_test.sql", thin)
        self.assertNotIn("word_learning_owner_rls.sql", thin)
        self.assertIn("| `zzz_unknown_test.sql` | Other |", text)

    def test_check_detects_stale_doc_and_write_fixes_it(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(m.main(["--check", "--root", str(self.root)]), 1)
            self.assertEqual(m.main(["--write", "--root", str(self.root)]), 0)
            self.assertEqual(m.main(["--check", "--root", str(self.root)]), 0)
            (self.root / m.TESTS_DIR / "new_test.sql").write_text(PLAIN, encoding="utf-8")
            self.assertEqual(m.main(["--check", "--root", str(self.root)]), 1)
        self.assertIn("stale database security matrix", out.getvalue())

    def test_repository_matrix_is_current(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(m.main(["--check"]), 0)


if __name__ == "__main__":
    unittest.main()
