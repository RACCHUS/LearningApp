import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_open_content_index as b  # noqa: E402

TREE = {
    "contents": [
        {"id": "p@", "slug": "preface", "title": '<span class="os-text">Preface</span>'},
        {
            "id": "c1@x",
            "slug": "1-prerequisites",
            "title": '<span class="os-number"><span class="os-part-text">Chapter </span>1</span>'
                     '<span class="os-divider"> </span><span class="os-text">Prerequisites</span>',
            "contents": [
                {"id": "i@", "slug": "1-introduction", "title": '<span class="os-text">Introduction to Prerequisites</span>'},
                {"id": "s12@", "slug": "1-2-exponents",
                 "title": '<span class="os-number">1.2</span><span class="os-divider"> </span>'
                          '<span class="os-text">Exponents &amp; Scientific Notation</span>'},
                {"id": "r@x", "slug": "1-chapter-review", "title": '<span class="os-text">Chapter Review</span>',
                 "contents": [{"id": "k@", "slug": "1-key-terms", "title": '<span class="os-text">Key Terms</span>'}]},
            ],
        },
    ]
}


class ParseTests(unittest.TestCase):
    def test_keeps_numbered_teaching_sections_only(self):
        secs = b.sections(TREE)
        self.assertEqual(len(secs), 1)
        s = secs[0]
        self.assertEqual((s["number"], s["title"], s["chapter"], s["page"]),
                         ("1.2", "Exponents & Scientific Notation", "Prerequisites", "s12"))

    def test_key_terms_are_deduplicated_and_cleaned(self):
        html = ('<span data-type="term">Radicand</span> x <span data-type="term" id="t">'
                'radicand</span> <span data-type="term">principal <em>n</em>th root</span>')
        self.assertEqual(b.key_terms(html), ["radicand", "principal n th root"])

    def test_term_markup_inside_the_term_is_kept(self):
        html = '<dfn data-type="term">nth <sup>root</sup> rule</dfn> <span data-type="term">base</span>'
        self.assertEqual(b.key_terms(html), ["nth root rule", "base"])

    def test_committed_index_is_valid(self):
        index = json.loads(b.OUT.read_text(encoding="utf-8"))
        self.assertEqual(b.check(index), [])

    def test_check_rejects_unregistered_or_out_of_prefix_links(self):
        bad = {"sections": [
            {"source_id": "nope", "number": "1", "title": "t", "url": "https://x/y"},
            {"source_id": "openstax-college-algebra-1e", "number": "1", "title": "t",
             "url": "https://openstax.org/books/college-algebra-2e/pages/1"},
        ]}
        problems = b.check(bad)
        self.assertTrue(any("not registered" in p for p in problems))
        self.assertTrue(any("outside" in p for p in problems))


if __name__ == "__main__":
    unittest.main()
