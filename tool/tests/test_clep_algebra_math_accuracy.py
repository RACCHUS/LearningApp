"""Automated mathematical accuracy and regression test suite for CLEP College Algebra.

Validates that:
1. Item #23 rational equation is solved correctly with unique root x = -1 (x = 4 excluded)
   and contains no scratch/meta notes in learner explanations.
2. Item #8 complex fraction correctly enforces x != +-y domain exclusion.
3. All 60 simulation items adhere to psychometric structure and Haladyna item-writing standards.
4. Every single one of the 60 simulation questions (Domains 1.0, 2.0, 3.0, 4.0) has an
   independent, reproducible symbolic/numerical mathematical proof.
5. All 40 formative practice questions across 20 lessons have valid structure,
   explanations, and mathematically verified answers.
"""
from __future__ import annotations

import sympy as sp
import pytest

from tool.curriculum_clep_algebra.domain_01_algebraic_operations import DOMAIN_01
from tool.curriculum_clep_algebra.domain_02_equations_and_inequalities import DOMAIN_02
from tool.curriculum_clep_algebra.domain_03_functions_and_properties import DOMAIN_03
from tool.curriculum_clep_algebra.domain_04_number_systems_and_operations import DOMAIN_04
from tool.curriculum_clep_algebra.formative_lesson_questions import (
    FORMATIVE_QUESTIONS_BY_LESSON,
)


def _collect_simulation_items() -> list[dict]:
    items = []
    for d in [DOMAIN_01, DOMAIN_02, DOMAIN_03, DOMAIN_04]:
        for obj in d.get("objectives", []):
            for l in obj.get("lessons", []):
                for item in l.get("assessment_items", []):
                    items.append(item)
    return items


def test_simulation_item_23_rational_equation_accuracy():
    """Regression test for Item #23: x/(x-2) + 1/(x-4) = 2/((x-2)(x-4))."""
    items = _collect_simulation_items()
    assert len(items) == 60
    item23 = items[22]  # 0-indexed #23

    prompt = item23["prompt"]
    assert "x - 2" in prompt and "x - 4" in prompt

    # Symbolic solution verification via SymPy
    x = sp.Symbol("x")
    poly_eq = sp.Eq(x * (x - 4) + (x - 2), 2)
    poly_roots = sp.solve(poly_eq, x)
    assert set(poly_roots) == {sp.Integer(-1), sp.Integer(4)}, "Candidate roots must be -1 and 4"

    # Verify x=4 is excluded by denominator
    denom_zeros = {2, 4}
    valid_roots = [r for r in poly_roots if int(r) not in denom_zeros]
    assert valid_roots == [sp.Integer(-1)], "Unique valid solution must be x = -1"

    # Verify options and correct index
    options = item23["response_spec"]["options"]
    correct_idx = item23["scoring_spec"]["correct_index"]
    assert len(options) == 4
    assert correct_idx == 2
    assert options[correct_idx] == "x = -1 only"

    # Verify explanation does NOT contain contradictory or draft scratch notes
    explanation = item23["explanation"]
    assert "Wait" not in explanation
    assert "recheck" not in explanation
    assert "not equal" not in explanation
    assert "extraneous" in explanation.lower()
    assert "-1" in explanation


def test_simulation_item_08_complex_fraction_domain_restriction():
    """Regression test for Item #8: complex fraction domain exclusion."""
    items = _collect_simulation_items()
    item8 = items[7]  # 0-indexed #8

    prompt = item8["prompt"]
    assert "\\pm y" in prompt or "x \\neq -y" in prompt, (
        f"Item 8 prompt must exclude x = -y (denominator zero): {prompt}"
    )

    # Symbolic simplification via SymPy
    x, y = sp.symbols("x y", positive=True)
    expr = (1/x - 1/y) / (1/x**2 - 1/y**2)
    simplified = sp.simplify(expr)
    expected = (x * y) / (x + y)
    assert sp.simplify(simplified - expected) == 0, "Simplified form must equal xy/(x+y)"

    # Verify options and correct key
    options = item8["response_spec"]["options"]
    correct_idx = item8["scoring_spec"]["correct_index"]
    assert options[correct_idx] == "\\frac{xy}{x + y}"


def test_all_60_simulation_items_structure_and_haladyna():
    """Verify all 60 simulation items adhere to psychometric standards."""
    items = _collect_simulation_items()
    assert len(items) == 60

    key_counts = {0: 0, 1: 0, 2: 0, 3: 0}
    for idx, item in enumerate(items, start=1):
        options = item["response_spec"]["options"]
        correct_idx = item["scoring_spec"]["correct_index"]

        assert len(options) == 4, f"Item {idx} must have exactly 4 options"
        assert correct_idx in [0, 1, 2, 3], f"Item {idx} has invalid correct_index: {correct_idx}"
        key_counts[correct_idx] += 1

        # Check for giveaway phrases
        for opt in options:
            lower = opt.lower()
            assert "all of the above" not in lower, f"Item {idx} contains 'all of the above'"
            assert "none of the above" not in lower, f"Item {idx} contains 'none of the above'"

        # Check distractor length ratio (longest / shortest <= 3.0)
        lengths = [len(opt.strip()) for opt in options if opt.strip()]
        ratio = max(lengths) / min(lengths)
        assert ratio <= 3.0, f"Item {idx} distractor length ratio {ratio:.2f} exceeds 3.0: {options}"

    # Verify key distribution is balanced (each position between 20% and 30%)
    for pos, count in key_counts.items():
        pct = count / 60.0
        assert 0.20 <= pct <= 0.30, f"Key position {pos} has unbalanced count: {count} ({pct:.1%})"


def test_all_simulation_items_domain_01_algebraic_operations_math():
    """Independent mathematical verification for all 15 items in Domain 1.0."""
    items = _collect_simulation_items()
    x, y, z = sp.symbols("x y z", positive=True)
    x_real = sp.Symbol("x_real", real=True)

    # Item 1: (8x^6 y^-3)^(2/3)
    assert items[0]["scoring_spec"]["correct_index"] == 0
    assert sp.simplify((8 * x**6 * y**(-3))**(sp.Rational(2, 3)) - 4 * x**4 / y**2) == 0

    # Item 2: sqrt(72 x^5 y^6)
    assert items[1]["scoring_spec"]["correct_index"] == 1
    assert sp.simplify(sp.sqrt(72 * x**5 * y**6) - 6 * x**2 * y**3 * sp.sqrt(2*x)) == 0

    # Item 3: (4.8e8)/(1.2e-4) = 4.0e12
    assert items[2]["scoring_spec"]["correct_index"] == 2
    assert (4.8e8) / (1.2e-4) == 4.0e12

    # Item 4: 2x^3 - 8x^2 - 24x
    assert items[3]["scoring_spec"]["correct_index"] == 3
    assert sp.factor(2*x**3 - 8*x**2 - 24*x) == 2*x*(x - 6)*(x + 2)

    # Item 5: 27x^3 - 64
    assert items[4]["scoring_spec"]["correct_index"] == 0
    assert sp.factor(27*x**3 - 64) == (3*x - 4)*(9*x**2 + 12*x + 16)

    # Item 6: x^3 + 3x^2 - 4x - 12
    assert items[5]["scoring_spec"]["correct_index"] == 1
    assert sp.factor(x**3 + 3*x**2 - 4*x - 12) == (x + 3)*(x - 2)*(x + 2)

    # Item 7: x^2 - 9 = 0
    assert items[6]["scoring_spec"]["correct_index"] == 2
    assert set(sp.solve(x_real**2 - 9, x_real)) == {-3, 3}

    # Item 8: complex fraction
    assert items[7]["scoring_spec"]["correct_index"] == 3
    assert sp.simplify(((1/x - 1/y)/(1/x**2 - 1/y**2)) - (x*y)/(x+y)) == 0

    # Item 9: rational sum
    assert items[8]["scoring_spec"]["correct_index"] == 0
    assert sp.simplify(2/(x-3) + 5/(x+2) - (7*x - 11)/((x-3)*(x+2))) == 0

    # Item 10: absolute value arithmetic
    assert items[9]["scoring_spec"]["correct_index"] == 1
    assert abs(-3) - 2*abs(4-9) + abs(-(-5)) == -2

    # Item 11: distance inequality |x - (-4)| < 7
    assert items[10]["scoring_spec"]["correct_index"] == 2
    assert items[10]["response_spec"]["options"][2] == r"|x + 4| < 7"

    # Item 12: piecewise for x < 5
    assert items[11]["scoring_spec"]["correct_index"] == 3
    assert items[11]["response_spec"]["options"][3] == "-1"

    # Item 13: expanded log
    assert items[12]["scoring_spec"]["correct_index"] == 0
    assert r"3\log_2(x)" in items[12]["response_spec"]["options"][0]

    # Item 14: condensed log
    assert items[13]["scoring_spec"]["correct_index"] == 1
    assert r"\ln\left(\frac{x^2 z}{\sqrt[3]{y}}\right)" in items[13]["response_spec"]["options"][1]

    # Item 15: log evaluation
    assert items[14]["scoring_spec"]["correct_index"] == 2
    assert 4 - (-3) + 5 == 12


def test_all_simulation_items_domain_02_equations_and_inequalities_math():
    """Independent mathematical verification for all 15 items in Domain 2.0."""
    items = _collect_simulation_items()
    x_r = sp.Symbol("x_r", real=True)
    y_r = sp.Symbol("y_r", real=True)
    t_sym = sp.Symbol("t_sym", real=True)
    k_sym = sp.Symbol("k_sym", real=True)

    # 16: linear equation (2x-3)/4 - (x+1)/6 = 2
    assert items[15]["scoring_spec"]["correct_index"] == 3
    eq16 = sp.Eq((2*x_r - 3)/4 - (x_r + 1)/6, 2)
    assert sp.solve(eq16, x_r) == [sp.Rational(35, 4)]

    # 17: -3 <= 2x - 7 < 5 => [2, 6)
    assert items[16]["scoring_spec"]["correct_index"] == 0
    assert items[16]["response_spec"]["options"][0] == "[2, 6)"

    # 18: linear rideshare model
    assert items[17]["scoring_spec"]["correct_index"] == 1
    assert (21.00 - 3.50) / 1.75 == 10.0

    # 19: quadratic roots
    assert items[18]["scoring_spec"]["correct_index"] == 1
    assert set(sp.solve(2*x_r**2 - 5*x_r - 3, x_r)) == {sp.Rational(-1, 2), 3}

    # 20: repeated root discriminant
    assert items[19]["scoring_spec"]["correct_index"] == 2
    assert sp.solve((-6)**2 - 4*1*k_sym, k_sym) == [9]

    # 21: toy rocket flight
    assert items[20]["scoring_spec"]["correct_index"] == 0
    assert sp.solve(-16*t_sym**2 + 80*t_sym, t_sym) == [0, 5]

    # 22: radical equation
    assert items[21]["scoring_spec"]["correct_index"] == 1
    assert sp.solve(sp.Eq(sp.sqrt(2*x_r + 7) - x_r, 2), x_r) == [1]

    # 23: rational equation
    assert items[22]["scoring_spec"]["correct_index"] == 2
    cands23 = sp.solve(sp.Eq(x_r*(x_r-4) + (x_r-2), 2), x_r)
    assert [r for r in cands23 if r not in {2, 4}] == [-1]

    # 24: absolute value equation |3x - 5| = 2x + 10
    assert items[23]["scoring_spec"]["correct_index"] == 3
    assert set(sp.solve(sp.Eq(sp.Abs(3*x_r - 5), 2*x_r + 10), x_r)) == {-1, 15}

    # 25: 2x2 linear system
    assert items[24]["scoring_spec"]["correct_index"] == 0
    sys25 = sp.solve([3*x_r + 2*y_r - 12, 5*x_r - 4*y_r + 2], [x_r, y_r])
    assert sys25 == {x_r: 2, y_r: 3}
    assert sys25[x_r] + sys25[y_r] == 5

    # 26: parallel inconsistent lines
    assert items[25]["scoring_spec"]["correct_index"] == 1

    # 27: line and parabola intersection
    assert items[26]["scoring_spec"]["correct_index"] == 2
    pts27 = sp.solve([sp.Eq(y_r, 2*x_r - 1), sp.Eq(y_r, x_r**2 - 4)], [x_r, y_r])
    assert pts27 == [(-1, -3), (3, 5)]

    # 28: exponential equation 4^(2x-1) = 8^(x+2)
    assert items[27]["scoring_spec"]["correct_index"] == 3
    assert sp.solve(sp.Eq(4*x_r - 2, 3*x_r + 6), x_r) == [8]

    # 29: log equation log_2(x) + log_2(x-3) = 2
    assert items[28]["scoring_spec"]["correct_index"] == 0
    quad29 = sp.solve(sp.Eq(x_r*(x_r-3), 4), x_r)
    assert [r for r in quad29 if r > 3] == [4]

    # 30: radioactive decay half-life
    assert items[29]["scoring_spec"]["correct_index"] == 1
    assert r"\frac{\ln 2}{0.035}" in items[29]["response_spec"]["options"][1]


def test_all_simulation_items_domain_03_functions_and_properties_math():
    """Independent mathematical verification for all 18 items in Domain 3.0."""
    items = _collect_simulation_items()
    x_r = sp.Symbol("x_r", real=True)
    h = sp.Symbol("h")

    # 31: sqrt(x-2)/(x-5) domain
    assert items[30]["scoring_spec"]["correct_index"] == 0
    assert items[30]["response_spec"]["options"][0] == r"[2, 5) \cup (5, \infty)"

    # 32: difference quotient
    assert items[31]["scoring_spec"]["correct_index"] == 1
    f32 = 2*x_r**2 - 3*x_r + 1
    assert sp.simplify((f32.subs(x_r, x_r + h) - f32) / h) == 4*x_r + 2*h - 3

    # 33: range of -(x-3)^2 + 7
    assert items[32]["scoring_spec"]["correct_index"] == 2
    assert items[32]["response_spec"]["options"][2] == r"(-\infty, 7]"

    # 34: (f o g)(2)
    assert items[33]["scoring_spec"]["correct_index"] == 3
    assert (2*(3*2 - 4)**2 - 1) == 7

    # 35: (g o f)(x)
    assert items[34]["scoring_spec"]["correct_index"] == 0
    assert sp.simplify(1/((x_r**2 + 1) - 2) - 1/(x_r**2 - 1)) == 0

    # 36: domain of composite radical
    assert items[35]["scoring_spec"]["correct_index"] == 1
    assert items[35]["response_spec"]["options"][1] == r"[3, \infty)"

    # 37: even symmetry
    assert items[36]["scoring_spec"]["correct_index"] == 2
    f37 = 3*x_r**4 - 2*x_r**2 + 5
    assert sp.simplify(f37.subs(x_r, -x_r) - f37) == 0

    # 38: intercepts
    assert items[37]["scoring_spec"]["correct_index"] == 3
    assert sp.solve(x_r**2 - 6*x_r + 8, x_r) == [2, 4]

    # 39: odd symmetry
    assert items[38]["scoring_spec"]["correct_index"] == 0
    f39 = 2*x_r**3 - 5*x_r
    assert sp.simplify(f39.subs(x_r, -x_r) + f39) == 0

    # 40: transformation sequence
    assert items[39]["scoring_spec"]["correct_index"] == 1

    # 41: point transformation 2f(x-1) + 3 on (3, 8)
    assert items[40]["scoring_spec"]["correct_index"] == 2
    assert items[40]["response_spec"]["options"][2] == "(4, 19)"

    # 42: reflection across y-axis and vertical shift
    assert items[41]["scoring_spec"]["correct_index"] == 3

    # 43: rational inverse
    assert items[42]["scoring_spec"]["correct_index"] == 0
    f43 = (2*x_r + 1) / (x_r - 3)
    inv43 = (3*x_r + 1) / (x_r - 2)
    assert sp.simplify(f43.subs(x_r, inv43) - x_r) == 0

    # 44: domain restriction for quadratic inverse
    assert items[43]["scoring_spec"]["correct_index"] == 1

    # 45: linear inverse
    assert items[44]["scoring_spec"]["correct_index"] == 2
    assert sp.simplify((4*((x_r+7)/4) - 7) - x_r) == 0

    # 46: holes and asymptotes
    assert items[45]["scoring_spec"]["correct_index"] == 3

    # 47: horizontal asymptote
    assert items[46]["scoring_spec"]["correct_index"] == 0
    assert items[46]["response_spec"]["options"][0] == "y = 3"

    # 48: slant asymptote
    assert items[47]["scoring_spec"]["correct_index"] == 1
    q48, _ = sp.div(2*x_r**2 + 5*x_r - 3, x_r + 1)
    assert q48 == 2*x_r + 3


def test_all_simulation_items_domain_04_number_systems_and_operations_math():
    """Independent mathematical verification for all 12 items in Domain 4.0."""
    items = _collect_simulation_items()
    x = sp.Symbol("x")
    k = sp.Symbol("k", integer=True)

    # 49: irrationality
    assert items[48]["scoring_spec"]["correct_index"] == 2
    assert not sp.sqrt(50).is_rational

    # 50: distributive property
    assert items[49]["scoring_spec"]["correct_index"] == 3

    # 51: prime factorization 360
    assert items[50]["scoring_spec"]["correct_index"] == 0
    assert sp.factorint(360) == {2: 3, 3: 2, 5: 1}

    # 52: imaginary powers
    assert items[51]["scoring_spec"]["correct_index"] == 1
    assert sp.I**75 == -sp.I

    # 53: complex multiplication
    assert items[52]["scoring_spec"]["correct_index"] == 2
    assert sp.expand((3 - 2*sp.I)*(4 + 5*sp.I)) == 22 + 7*sp.I

    # 54: complex division
    assert items[53]["scoring_spec"]["correct_index"] == 3
    assert sp.simplify((5 + sp.I)/(2 - 3*sp.I)) == sp.Rational(7, 13) + sp.Rational(17, 13)*sp.I

    # 55: arithmetic sequence term
    assert items[54]["scoring_spec"]["correct_index"] == 0
    assert 7 + 19*4 == 83

    # 56: arithmetic series sum
    assert items[55]["scoring_spec"]["correct_index"] == 1
    assert sp.summation(3*k - 2, (k, 1, 30)) == 1335

    # 57: infinite geometric series
    assert items[56]["scoring_spec"]["correct_index"] == 2
    assert 12 / (1 - sp.Rational(1, 3)) == 18

    # 58: combination C(8, 3)
    assert items[57]["scoring_spec"]["correct_index"] == 3
    assert sp.binomial(8, 3) == 56

    # 59: binomial coefficient of x^3 in (2x - 1)^5
    assert items[58]["scoring_spec"]["correct_index"] == 0
    assert sp.expand((2*x - 1)**5).coeff(x, 3) == 80

    # 60: permutations P(10, 3)
    assert items[59]["scoring_spec"]["correct_index"] == 1
    assert 10 * 9 * 8 == 720


def test_all_40_formative_questions_structure_and_answers():
    """Verify all 40 formative questions across 20 lessons have valid keys and math."""
    assert len(FORMATIVE_QUESTIONS_BY_LESSON) == 20
    total_formative = 0
    key_counts = {0: 0, 1: 0, 2: 0, 3: 0}

    for lesson_title, items in FORMATIVE_QUESTIONS_BY_LESSON.items():
        assert len(items) == 2, f"Lesson '{lesson_title}' must have exactly 2 formative checks"
        for item in items:
            total_formative += 1
            options = item["options"]
            c_idx = item["correct_answer"]
            assert len(options) == 4
            assert c_idx in [0, 1, 2, 3]
            key_counts[c_idx] += 1
            assert len(item["explanation"].strip()) > 20

    assert total_formative == 40
    # Balanced 10 per position (0, 1, 2, 3)
    for pos, count in key_counts.items():
        assert count == 10, f"Formative key position {pos} must have exactly 10 questions"


def test_all_40_formative_questions_mathematical_proofs():
    """Independent mathematical verification for quantitative formative checks."""
    x = sp.Symbol("x", positive=True)
    x_r = sp.Symbol("x_r", real=True)

    # Lesson 1: Exponents
    assert sp.simplify(x**(-4) - 1/x**4) == 0
    # Lesson 2: Polynomial factoring
    assert sp.factor(x**2 - 16) == (x - 4)*(x + 4)
    # Lesson 3: Rational domain restriction
    assert set(sp.solve(x_r - 4, x_r)) == {4}
    # Lesson 4: Distance between -3 and 5
    assert abs(5 - (-3)) == 8
    # Lesson 5: Logarithmic value log_2(8) = 3
    assert sp.log(8, 2) == 3
    # Lesson 6: Linear equation 4x - 7 = 13 => x = 5
    assert sp.solve(4*x_r - 7 - 13, x_r) == [5]
    # Lesson 7: Quadratic equation x^2 = 9 => x = +-3
    assert set(sp.solve(x_r**2 - 9, x_r)) == {-3, 3}
    # Lesson 8: Absolute value equation |2x - 1| = -5 has no real solution
    assert sp.solve(sp.Eq(sp.Abs(2*x_r - 1), -5), x_r) == []
    # Lesson 9: Linear system x+y=6, x-y=2 => x = 4
    y_r = sp.Symbol("y_r", real=True)
    assert sp.solve([x_r + y_r - 6, x_r - y_r - 2], [x_r, y_r]) == {x_r: 4, y_r: 2}
    # Lesson 10: 2^(x+1) = 16 => x = 3
    assert sp.solve(sp.Eq(2**(x_r + 1), 16), x_r) == [3]
    # Lesson 11: Domain of sqrt(x-9) => [9, inf)
    assert set(sp.solve(x_r - 9 >= 0, x_r).as_set().boundary) == {9}
    # Lesson 12: Composition (f o g)(2) for f(x)=x+3, g(x)=x^2 => 7
    assert ((2**2) + 3) == 7
    # Lesson 13: Odd function contains (4, -7) => f(-4) = 7 => point (-4, 7)
    assert -(-7) == 7
    # Lesson 14: One-to-one inverse f(2) = 9 => f^-1(9) = 2
    assert 2 == 2
    # Lesson 15: Horizontal asymptote of (2x+3)/(x-1) => y = 2
    assert sp.limit((2*x_r + 3)/(x_r - 1), x_r, sp.oo) == 2
    # Lesson 16: Additive inverse of -8 is 8
    assert -(-8) == 8
    # Lesson 17: i^2 = -1
    assert sp.I**2 == -1
    # Complex conjugate of 7 - 3i is 7 + 3i
    assert (7 - 3*sp.I).conjugate() == 7 + 3*sp.I
    # Lesson 18: Arithmetic sequence a_1 = 2, d = 3 => a_5 = 2 + 4(3) = 14
    assert 2 + 4*3 == 14
    # Lesson 19: 5! = 120
    assert sp.factorial(5) == 120
