"""P2g review manifest and safe SQL renderer tests for Florida DBPR contractors."""
import json
from datetime import datetime
import sys
import unittest
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
import catalog_p2g_contractor_pathways as p2g


class FloridaContractorPathwayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(p2g.DATA.read_text(encoding="utf-8"))

    def test_two_cilb_reviewed_partial_pathways(self):
        rows = p2g.validate_payload(self.data)
        self.assertEqual({r['source_key'] for r in rows},
                         {'certified-general-contractor', 'certified-building-contractor'})
        self.assertGreaterEqual(sum(p2g.validate_tree(r['pathway_tree'], p2g.IDENTITIES[(r['source_namespace'], r['source_key'])]) for r in rows), 20)
        for row in rows:
            retrieved_at = datetime.fromisoformat(row['source_retrieved_at'].replace('Z', '+00:00'))
            self.assertIsNotNone(retrieved_at.tzinfo)
            self.assertEqual(row['source_retrieved_at'], '2026-11-07T03:18:00Z')
            self.assertEqual(row['source_checked_on'], '2026-11-06')
            self.assertEqual(row['reviewed_on'], '2026-11-06')
            self.assertGreaterEqual(len(row['review_note']), 80)
            self.assertEqual(row['uncertainty_status'], 'conditional')
            self.assertEqual(row['pathway_kind'], 'initial_licensure')

    def test_wrong_license_type_jurisdiction_and_domain_rejected(self):
        for field, value in [('source_key', 'nclex-rn'), ('jurisdiction', 'US-GA'),
                            ('source_url', 'https://myfloridalicense.com.attacker.tld/')]:
            data = deepcopy(self.data)
            data['records'][0][field] = value
            with self.assertRaises(AssertionError):
                p2g.validate_payload(data)

    def test_missing_provenance_and_unknown_tree_nodes_rejected(self):
        for change in ('missing_url', 'wrong_operator', 'extra_key'):
            data = deepcopy(self.data)
            node = data['records'][0]['pathway_tree']['children'][0]['children'][0]
            if change == 'missing_url':
                del node['source_url']
            elif change == 'wrong_operator':
                node['op'] = 'pass_exam'
            else:
                node['price'] = 'unknown'
            with self.assertRaises(AssertionError):
                p2g.validate_payload(data)

    def test_alternative_group_is_not_flattened(self):
        for row in p2g.validate():
            self.assertEqual(row['pathway_tree']['op'], 'all')
            self.assertEqual(row['pathway_tree']['children'][0]['op'], 'any')

    def test_claims_of_full_review_are_rejected(self):
        data = deepcopy(self.data)
        data['records'][0]['coverage'] = 'full_requirements'
        with self.assertRaises(AssertionError):
            p2g.validate_payload(data)

    def test_rendered_sql_uses_approval_and_unchanged_identity(self):
        sql = p2g.sql()
        self.assertTrue(sql.startswith('begin;'))
        self.assertTrue(sql.endswith('commit;\n'))
        self.assertEqual(sql.count('insert into public.catalog_license_pathway_versions'), 2)
        self.assertIn('source_retrieved_at', sql)
        self.assertIn('review_note', sql)
        self.assertIn('uncertainty_status', sql)
        self.assertIn('pathway_kind', sql)
        self.assertIn('source_checked_at', sql)
        self.assertIn('2026-11-07T03:18:00Z', sql)
        self.assertIn('on conflict (source_namespace,source_key,revision) do nothing', sql)
        self.assertIn("publication_status='published'", sql)
        for forbidden in ('insert into public.learning_targets', 'insert into public.lessons',
                          'delete from', 'truncate ', 'update public.users'):
            self.assertNotIn(forbidden, sql.lower())


if __name__ == '__main__':
    unittest.main()
