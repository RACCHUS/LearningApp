"""P2f review manifest and safe SQL renderer tests for Florida DFS insurance."""
import json
import sys
import unittest
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
import catalog_p2f_insurance_pathways as p2f


class FloridaInsurancePathwayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(p2f.DATA.read_text(encoding="utf-8"))

    def test_two_dfs_reviewed_partial_pathways(self):
        rows = p2f.validate_payload(self.data)
        self.assertEqual({r['source_key'] for r in rows},
                         {'general-lines-2-20', 'life-health-2-15'})
        self.assertGreaterEqual(sum(p2f.validate_tree(r['pathway_tree']) for r in rows), 15)

    def test_wrong_license_type_jurisdiction_and_domain_rejected(self):
        for field, value in [('source_key', 'nclex-rn'), ('jurisdiction', 'US-GA'),
                            ('source_url', 'https://myfloridacfo.com.attacker.tld/')]:
            data = deepcopy(self.data)
            data['records'][0][field] = value
            with self.assertRaises(AssertionError):
                p2f.validate_payload(data)

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
                p2f.validate_payload(data)

    def test_alternative_group_is_not_flattened(self):
        for row in p2f.validate():
            self.assertEqual(row['pathway_tree']['op'], 'all')
            self.assertEqual(row['pathway_tree']['children'][0]['op'], 'any')

    def test_claims_of_full_review_are_rejected(self):
        data = deepcopy(self.data)
        data['records'][0]['coverage'] = 'full_requirements'
        with self.assertRaises(AssertionError):
            p2f.validate_payload(data)

    def test_rendered_sql_uses_approval_and_unchanged_identity(self):
        sql = p2f.sql()
        self.assertTrue(sql.startswith('begin;'))
        self.assertTrue(sql.endswith('commit;\n'))
        self.assertEqual(sql.count('insert into public.catalog_license_pathway_versions'), 2)
        self.assertIn('on conflict (source_namespace,source_key,revision) do nothing', sql)
        self.assertIn("publication_status='published'", sql)
        for forbidden in ('insert into public.learning_targets', 'insert into public.lessons',
                          'delete from', 'truncate ', 'update public.users'):
            self.assertNotIn(forbidden, sql.lower())


if __name__ == '__main__':
    unittest.main()
