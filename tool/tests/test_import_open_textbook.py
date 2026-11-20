import sys
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import import_open_textbook as t  # noqa: E402

M = 'xmlns="http://www.w3.org/1998/Math/MathML"'
X = 'xmlns="http://www.w3.org/1999/xhtml"'


def tex(markup: str) -> str:
    return t.tex(ET.fromstring(markup))


class MathTests(unittest.TestCase):
    def test_powers_fractions_roots(self):
        self.assertEqual(tex(f'<math {M}><msup><mi>x</mi><mn>2</mn></msup></math>'), "x^2")
        self.assertEqual(tex(f'<math {M}><mfrac><mn>1</mn><mi>y</mi></mfrac></math>'), r"\frac{1}{y}")
        self.assertEqual(tex(f'<math {M}><mroot><mi>x</mi><mn>3</mn></mroot></math>'), r"\sqrt[3]{x}")
        self.assertEqual(tex(f'<math {M}><msqrt><mn>25</mn></msqrt></math>'), r"\sqrt{25}")

    def test_semantics_uses_presentation_only(self):
        markup = (f'<math {M}><semantics><mrow><mi>a</mi><mo>⋅</mo><mi>b</mi></mrow>'
                  '<annotation-xml><mi>ignored</mi></annotation-xml></semantics></math>')
        self.assertEqual(tex(markup), r"a\cdot b")

    def test_malformed_msup_keeps_extra_base_children(self):
        markup = f'<math {M}><msup><mo>(</mo><mn>5</mn><mn>0</mn></msup></math>'
        self.assertEqual(tex(markup), "{(5}^0")

    def test_spaces_and_money_never_break_delimiters(self):
        self.assertEqual(tex(f'<math {M}><mspace/></math>'), r"\;")
        self.assertIn(r"\textdollar", tex(f'<math {M}><mtext>$5</mtext></math>'))
        self.assertNotIn("$", tex(f'<math {M}><mtext>$5</mtext></math>'))

    def test_braces_and_functions(self):
        self.assertEqual(tex(f'<math {M}><mover><mi>x</mi><mo>︷</mo></mover></math>'), r"\overbrace{x}")
        self.assertEqual(tex(f'<math {M}><mi>log</mi></math>'), r"\log ")

    def test_answer_key_math_in_xhtml_namespace(self):
        markup = f'<math {X}><mfrac><mn>11</mn><mn>1</mn></mfrac></math>'
        self.assertEqual(tex(markup), r"\frac{11}{1}")

    def test_unknown_elements_warn(self):
        warnings = []
        t.tex(ET.fromstring(f'<math {M}><mglyph>q</mglyph></math>'), warnings)
        self.assertTrue(warnings)


class NumericAnswerTests(unittest.TestCase):
    def test_plain_numbers_percent_and_terminating_fractions(self):
        cases = {"$12$": "12", "$0.62$": "0.62", "62%": "62", r"$62\%$": "62",
                 r"$\frac{11}{1}$": "11", r"$\frac{3}{4}$": "0.75", r"$-\frac{1}{2}$": "-0.5",
                 "$1,200$": "1200", "$12$.": "12"}
        for answer, value in cases.items():
            self.assertEqual(t.numeric_answer(answer), value, answer)

    def test_expressions_and_repeating_fractions_are_not_graded(self):
        for answer in [r"$k^{15}$", r"$\frac{1}{3}$", "$(x-6)(x-1)$", "24.1 grams", "", "$2x+3$"]:
            self.assertIsNone(t.numeric_answer(answer), answer)


class PartsTests(unittest.TestCase):
    def test_lettered_parts_become_separate_items(self):
        problem = "Simplify.\n\n- ⓐ $2+3$\n- ⓑ $k\\cdot k$"
        answer = "- ⓐ $5$\n- ⓑ $k^2$"
        items = t.numeric_questions(problem, answer, "x-1-1", "cite", 1)
        self.assertEqual(len(items), 1)
        item = items[0]
        self.assertEqual(item["interaction_type"], "numeric_entry")
        self.assertEqual(item["scoring_spec"], {"correct_value": 5, "tolerance": 0})
        self.assertIn("Simplify.", item["prompt"])
        self.assertIn("ⓐ $2+3$", item["prompt"])
        self.assertEqual(item["id"], "x-1-1-q1")


SECTION = f'''<html {X}><body><div data-type="page">
<h2 data-type="document-title">Percents</h2>
<div data-type="abstract"><ul><li>Use percent.</li></ul></div>
<section data-depth="1"><h3 data-type="title">Understand Percent</h3>
<p>A <span data-type="term">percent</span> is a ratio. Percent means per hundred.</p>
<div data-type="equation"><math {M} display="block"><mn>1</mn><mo>%</mo></math></div>
<div data-type="example"><h3 class="os-title"><span>Example</span> <span>1</span></h3>
 <div data-type="exercise"><div data-type="problem"><div><h4 data-type="title">Find it</h4><p>What is 50% of 8?</p></div></div>
 <div data-type="solution"><h4 data-type="solution-title">Solution</h4><div><p>It is 4.</p></div></div></div></div>
<div data-type="note" class="prealgebra try"><h3 class="os-title">Try It</h3><div class="os-note-body">
 <div data-type="exercise" id="ti_1"><div data-type="problem"><div><p>What is 10% of 30?</p></div></div></div>
 <div data-type="exercise" id="ti_2"><div data-type="problem"><div><p>No answer here.</p></div></div></div>
</div></div>
<figure><figcaption>A pie chart</figcaption></figure>
</section>
<section class="section-exercises"><div data-type="exercise" id="ex_1"><div data-type="problem"><div><p>What is 25% of 40?</p></div></div></div></section>
</div></body></html>'''

META = {"source_id": "openstax-prealgebra-1e", "license": "cc_by_4", "book": "Prealgebra",
        "number": "6.1", "title": "Understand Percent", "subject": "math",
        "url": "https://openstax.org/books/prealgebra/pages/6-1-understand-percent"}


class SectionTests(unittest.TestCase):
    def setUp(self):
        answers = {"ti_1": "$3$", "ex_1": "$10$"}
        terms = {"percent": "A ratio whose denominator is 100."}
        self.lesson, self.warnings = t.section_lesson(SECTION, META, answers, terms)

    def kinds(self):
        return [b["block_type"] for b in self.lesson["blocks"]]

    def test_reading_examples_practice_and_credit(self):
        text = "\n".join(b["content"].get("text", "") for b in self.lesson["blocks"])
        self.assertIn("### Understand Percent", text)
        self.assertIn("$$1\\%$$", text)
        self.assertIn("**Example 1: Find it**", text)
        self.assertIn("**Solution**", text)
        self.assertIn("Figure in the original section: A pie chart", text)
        self.assertEqual(self.kinds().count("practice_prompt"), 1)
        credit = self.lesson["blocks"][-1]["content"]
        self.assertEqual(credit["title"], "Source and license")
        self.assertIn("CC BY 4.0", credit["body"])
        self.assertIn("not reviewed by a person", credit["body"])

    def test_graded_items_from_try_it_and_exercises(self):
        items = self.lesson["assessment_items"]
        self.assertEqual([i["scoring_spec"]["correct_value"] for i in items], [3, 10])
        self.assertTrue(all(i["interaction_type"] == "numeric_entry" for i in items))

    def test_inline_math_in_a_sentence_stays_inline(self):
        p = ET.fromstring(f'<p {X}>The product <math {M} display="block"><mn>8</mn></math> equals 8.</p>')
        self.assertEqual(t.inline(p, []), "The product $8$ equals 8.")

    def test_figure_caption_converts_math_once_with_one_period(self):
        fig = ET.fromstring(
            f'<div {X}><figure><figcaption><span class="os-caption">Among <math {M}><semantics>'
            '<mn>100</mn><annotation-xml><mn>100</mn></annotation-xml></semantics></math> '
            'students, <em>N</em> are here.</span></figcaption></figure></div>')
        text = t.blocks_markdown(fig, [])
        self.assertIn("_(Figure in the original section: Among $100$ students, *N* are here.)_", text)
        self.assertNotIn("100100", text)
        self.assertNotIn("..", text)

    def test_description_joins_objectives_cleanly(self):
        self.assertEqual(self.lesson["description"], "Use percent.")

    def test_terms_and_warnings(self):
        self.assertEqual(self.lesson["terms"],
                         [{"term": "percent", "definition": "A ratio whose denominator is 100."}])
        self.assertTrue(any("had no answer" in w for w in self.warnings))
        self.assertIn("unreviewed", self.lesson["tags"])


class SourceGateTests(unittest.TestCase):
    def test_only_approved_cc_by_sources_can_be_imported(self):
        t.check_source("openstax-college-algebra-1e")
        for sid in ["openstax-prealgebra-2e", "microsoft-support", "unknown-book"]:
            with self.assertRaises(t.ImportProblem):
                t.check_source(sid)


if __name__ == "__main__":
    unittest.main()
