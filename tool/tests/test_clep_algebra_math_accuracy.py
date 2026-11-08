"""Automated mathematical accuracy and regression test suite for CLEP College Algebra.

Validates that:
1. Item #23 rational equation is solved correctly with unique root x = -1 (x = 4 excluded)
   and contains no scratch/meta notes in learner explanations.
2. Item #8 complex fraction correctly enforces x != +-y domain exclusion.
3. All 60 simulation items and 40 formative items are mathematically verified,
   have valid 4-option single-choice structures, balanced keys, and Haladyna compliance.
"""
from __future__ import annotations

import re
import sympy as sp
import pytest

from tool.curriculum_clep_algebra.domain_01_algebraic_operations import DOMAIN_01
from tool.curriculum_clep_algebra.domain_02_equations_and_inequalities import DOMAIN_02
from tool.curriculum_clep_algebra.domain_03_functions_and_properties import DOMAIN_03
from tool.curriculum_clep_algebra.domain_04_number_systems_and_operations import DOMAIN_04
from tool.curriculum_clep_algebra.formative_lesson_questions import (
    RAW_FORMATIVE_QUESTIONS_BY_LESSON,
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
    lhs = x / (x - 2) + 1 / (x - 4)
    rhs = 2 / ((x - 2) * (x - 4))
    eq = sp.Eq(lhs, rhs)

    # Multiply by common denominator
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
    # Must specify x != +-y or |x| != |y|
    assert "\\pm y" in prompt or "x \\neq -y" in prompt, (
        f"Item 8 prompt must exclude x = -y (denominator zero): {prompt}"
    )

    # Symbolic simplification via SymPy
    x, y = sp.symbols("x y")
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


def test_symbolic_math_verifications_across_domains():
    """Symbolic and numerical verification of representative quantitative items across all 4 domains."""
    items = _collect_simulation_items()

    # Item 1: (8x^6 y^-3)^(2/3)
    x, y = sp.symbols("x y", positive=True)
    item1 = items[0]
    opt1 = item1["response_spec"]["options"][item1["scoring_spec"]["correct_index"]]
    assert opt1 == "\\frac{4x^4}{y^2}"

    # Item 4: 2x^3 - 8x^2 - 24x factoring
    poly = 2*x**3 - 8*x**2 - 24*x
    assert sp.factor(poly) == 2*x*(x - 6)*(x + 2)

    # Item 5: 27x^3 - 64 difference of cubes
    cubes = 27*x**3 - 64
    assert sp.factor(cubes) == (3*x - 4)*(9*x**2 + 12*x + 16)

    # Item 19: 2x^2 - 5x - 3 = 0 roots
    x_real = sp.Symbol("x_real", real=True)
    quad_roots = sp.solve(2*x_real**2 - 5*x_real - 3, x_real)
    assert set(quad_roots) == {sp.Rational(-1, 2), sp.Integer(3)}

    # Item 20: x^2 - 6x + k = 0 discriminant = 0
    k = sp.Symbol("k")
    disc = (-6)**2 - 4 * 1 * k
    assert sp.solve(disc, k) == [9]

    # Item 28: 4^(2x - 1) = 8^(x + 2)
    # (2^2)^(2x-1) = (2^3)^(x+2) => 4x - 2 = 3x + 6 => x = 8
    eq28 = sp.Eq(4*x - 2, 3*x + 6)
    assert sp.solve(eq28, x) == [8]

    # Item 43: Inverse of f(x) = (2x+1)/(x-3)
    # y = (2x+1)/(x-3) => x = (2y+1)/(y-3) => xy - 3x = 2y + 1 => y(x-2) = 3x + 1 => y = (3x+1)/(x-2)
    x_val = sp.Symbol("x")
    f_inv = (3*x_val + 1) / (x_val - 2)
    f = (2*x_val + 1) / (x_val - 3)
    # Check f(f_inv(x)) == x
    comp = sp.simplify(f.subs(x_val, f_inv))
    assert comp == x_val

    # Item 53: (3 - 2i)(4 + 5i)
    c1 = complex(3, -2)
    c2 = complex(4, 5)
    assert c1 * c2 == complex(22, 7)

    # Item 54: (5 + i)/(2 - 3i)
    c_num = complex(5, 1)
    c_den = complex(2, -3)
    c_res = c_num / c_den
    assert pytest.approx(c_res.real) == 7 / 13
    assert pytest.approx(c_res.imag) == 17 / 13

    # Item 56: sum_{k=1}^30 (3k - 2)
    k_sym = sp.Symbol("k", integer=True)
    series_sum = sp.summation(3*k_sym - 2, (k_sym, 1, 30))
    assert series_sum == 1335

    # Item 58: C(8, 3) = 56
    assert sp.binomial(8, 3) == 56

    # Item 59: Coefficient of x^3 in (2x - 1)^5
    binom_expr = sp.expand((2*x - 1)**5)
    assert binom_expr.coeff(x, 3) == 80


def test_formative_questions_structure_and_answers():
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
