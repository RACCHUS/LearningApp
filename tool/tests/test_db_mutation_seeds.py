"""DB mutation runner contract tests, requiring neither Docker nor Flutter."""
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "ci"))
import db_mutation_seeds as db  # noqa: E402


class SqlMutationRunnerTest(unittest.TestCase):
    def test_each_real_sql_seed_has_one_live_anchor(self):
        self.assertEqual(db.check(), [])

    def test_sql_mutation_preserves_original_newlines(self):
        seed = db.SEEDS[0]
        initial = b"first\r\n" + seed.before.encode() + b"\r\nlast\r\n"
        changed = db.mutate(seed, initial)
        self.assertIn(b"  using (true);\r\n", changed)
        self.assertNotIn(b"\n" + seed.before.encode() + b"\r\n", changed)

    def test_source_anchor_must_be_exactly_one(self):
        seed = db.SEEDS[1]
        with self.assertRaises(ValueError):
            db.mutate(seed, b"unrelated SQL")
        with self.assertRaises(ValueError):
            db.mutate(seed, (seed.before + seed.before).encode())

    def test_sql_mutation_seed_ids_are_unique(self):
        ids = [s.id for s in db.SEEDS]
        self.assertEqual(len(ids), len(set(ids)))

    def test_remote_stack_is_rejected_before_database_change(self):
        result = mock.Mock(returncode=0, stdout=(
            'API_URL="https://project.supabase.co"\n'
            'DB_URL="postgresql://postgres:pw@project.supabase.co/postgres"\n'
        ))
        with mock.patch.object(db, "_command", return_value=result):
            with self.assertRaisesRegex(RuntimeError, "non-loopback"):
                db.require_local_stack()

    def test_nonzero_pg_tap_baseline_is_not_called_a_kill(self):
        result = mock.Mock(returncode=1, stdout="not ok - baseline broken", stderr="")
        with mock.patch.object(db, "_tap", return_value=result):
            with self.assertRaisesRegex(RuntimeError, "baseline fails"):
                db._baseline(1)


if __name__ == "__main__":
    unittest.main()
