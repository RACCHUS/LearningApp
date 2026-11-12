"""Independent answer oracles for every shipped CLEP College Algebra item.

Keyed by the stable authored item ID (plan PR-2c, §0A.2 steps 6-8). For each
item the oracle records:

* ``truth``: the answer computed from the *prompt's own mathematics* with
  SymPy (or, for a few definitional items, a reviewed label with a rationale
  and, where possible, a computed witness). It is never read from
  ``correct_index`` / ``correct_answer``.
* ``options``: every option's exact text mapped to what it means
  mathematically. The test proves exactly one option matches the truth and
  that it is the keyed one, so distractors are proven false too.

Prompt wording is pinned separately by ``PROMPT_SHA256`` (see the test), so a
changed prompt fails until someone re-derives its oracle.

Editing rule: when an item's prompt, options or key change, recompute its
truth from the new prompt by hand. Never copy the new key into the oracle.
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import Any, Callable

import sympy as sp
from sympy import (
    Abs, E, FiniteSet, I, Interval, Rational, S, Symbol, Union, exp, log, oo, sqrt, symbols,
)

# Symbols. Positive symbols model "for all positive real x, y, z" prompts.
xp, yp, zp = symbols("x y z", positive=True)
x = Symbol("x")
xr = Symbol("x", real=True)
yr = Symbol("y", real=True)
t = Symbol("t", real=True)
k = Symbol("k", real=True)
h = Symbol("h")
n = Symbol("n", integer=True, nonnegative=True)
a, b, P, r = symbols("a b P r")
EMPTY = S.EmptySet
REALS = S.Reals


@dataclass(frozen=True)
class Oracle:
    truth: Any
    options: dict[str, Any]
    # Optional predicate replacing equality: option is correct iff check(value).
    check: Callable[[Any], bool] | None = None
    reviewed: str = ""  # rationale for definitional (non-computed) truths


def same(u: Any, v: Any) -> bool:
    """Mathematical equality across the value kinds used below."""
    if u is None or v is None:
        return u is v
    if isinstance(u, str) or isinstance(v, str):
        return u == v
    if isinstance(u, dict) or isinstance(v, dict):
        return u == v
    if isinstance(u, (tuple, list)) and isinstance(v, (tuple, list)):
        return len(u) == len(v) and all(same(p, q) for p, q in zip(u, v))
    if isinstance(u, frozenset) and isinstance(v, frozenset):
        return u == v
    u, v = sp.sympify(u), sp.sympify(v)
    if isinstance(u, sp.Set) or isinstance(v, sp.Set):
        return isinstance(u, sp.Set) and isinstance(v, sp.Set) and u.symmetric_difference(v) == EMPTY
    diff = sp.simplify(sp.expand_log(u - v, force=True))
    return diff == 0


def solve_set(expr, var=xr, domain=REALS):
    return sp.solveset(expr, var, domain)


def complete_factorization_of(poly) -> Callable[[Any], bool]:
    """Option equals the polynomial AND is already fully factored."""
    return lambda opt: sp.expand(opt - poly) == 0 and sp.factor(opt) == opt


def parity(f, var) -> str:
    if sp.simplify(f.subs(var, -var) - f) == 0:
        return "even"
    if sp.simplify(f.subs(var, -var) + f) == 0:
        return "odd"
    return "neither"


def vertex_form_moves(g):
    """Match g to A*(x - H)**2 + K and describe the moves from x**2."""
    A, H, K = symbols("A H K")
    sol = sp.solve(sp.Poly(sp.expand(A * (x - H) ** 2 + K - g), x).coeffs(), [A, H, K], dict=True)[0]
    return (
        ("left" if sol[H] < 0 else "right", abs(sol[H])),
        "x-axis" if sol[A] < 0 else None,
        ("down" if sol[K] < 0 else "up", abs(sol[K])),
    )


def asymptotes_and_holes(num, den):
    common = sp.gcd(num, den)
    holes = solve_set(common, x, sp.Reals) if sp.degree(common, x) > 0 else EMPTY
    vertical = solve_set(sp.cancel(den / common), x, sp.Reals)
    return (vertical, holes)


def injective_on(f, interval) -> bool:
    vertex = sp.solve(sp.diff(f, x), x)[0]
    return not (interval.inf < vertex < interval.sup)


# Witness functions for definitional items about function symmetry.
EVEN_WITNESSES = [xr**2, sp.cos(xr), Abs(xr) + 3]
NON_EVEN_WITNESSES = [xr**3, xr + 1, sp.exp(xr)]

ORACLES: dict[str, Oracle] = {
    # ---------------- Domain 1.0 Algebraic operations ----------------
    "alg-sim-rational-exponent-power-of-monomial": Oracle(
        truth=(8 * xp**6 * yp**-3) ** Rational(2, 3),
        options={
            r"\frac{4x^4}{y^2}": 4 * xp**4 / yp**2,
            r"\frac{4x^9}{y^2}": 4 * xp**9 / yp**2,
            r"\frac{8x^4}{y^2}": 8 * xp**4 / yp**2,
            r"4x^4 y^2": 4 * xp**4 * yp**2,
        },
    ),
    "alg-sim-simplify-radical-72x5y6": Oracle(
        truth=sqrt(72 * xp**5 * yp**6),
        options={
            r"36x^2 y^3 \sqrt{2x}": 36 * xp**2 * yp**3 * sqrt(2 * xp),
            r"6x^2 y^3 \sqrt{2x}": 6 * xp**2 * yp**3 * sqrt(2 * xp),
            r"12x^2 y^3 \sqrt{x}": 12 * xp**2 * yp**3 * sqrt(xp),
            r"6x^4 y^6 \sqrt{2x}": 6 * xp**4 * yp**6 * sqrt(2 * xp),
        },
    ),
    "alg-sim-scientific-notation-quotient": Oracle(
        truth=(Rational(48, 10) * 10**8) / (Rational(12, 10) * Rational(1, 10**4)),
        options={
            r"4.0 \times 10^4": 4 * 10**4,
            r"4.0 \times 10^{-12}": 4 * Rational(1, 10**12),
            r"4.0 \times 10^{12}": 4 * 10**12,
            r"4.0 \times 10^{2}": 4 * 10**2,
        },
    ),
    "alg-sim-factor-gcf-then-difference-of-squares": Oracle(
        truth=None,
        check=complete_factorization_of(2 * x**3 - 8 * x**2 - 24 * x),
        options={
            r"2x(x - 4)(x + 3)": 2 * x * (x - 4) * (x + 3),
            r"2x(x^2 - 4x - 12)": 2 * x * (x**2 - 4 * x - 12),
            r"2(x - 6)(x + 2)": 2 * (x - 6) * (x + 2),
            r"2x(x - 6)(x + 2)": 2 * x * (x - 6) * (x + 2),
        },
    ),
    "alg-sim-factor-difference-of-cubes": Oracle(
        truth=None,
        check=complete_factorization_of(27 * x**3 - 64),
        options={
            r"(3x - 4)(9x^2 + 12x + 16)": (3 * x - 4) * (9 * x**2 + 12 * x + 16),
            r"(3x - 4)(9x^2 - 12x + 16)": (3 * x - 4) * (9 * x**2 - 12 * x + 16),
            r"(3x - 4)^3": (3 * x - 4) ** 3,
            r"(3x - 4)(3x^2 + 12x + 16)": (3 * x - 4) * (3 * x**2 + 12 * x + 16),
        },
    ),
    "alg-sim-factor-by-grouping-four-terms": Oracle(
        truth=None,
        check=complete_factorization_of(x**3 + 3 * x**2 - 4 * x - 12),
        options={
            r"(x + 3)(x^2 + 4)": (x + 3) * (x**2 + 4),
            r"(x + 3)(x - 2)(x + 2)": (x + 3) * (x - 2) * (x + 2),
            r"(x - 3)(x - 2)(x + 2)": (x - 3) * (x - 2) * (x + 2),
            r"(x^2 - 4)(x - 3)": (x**2 - 4) * (x - 3),
        },
    ),
    "alg-sim-rational-expression-excluded-values": Oracle(
        truth=solve_set(xr**2 - 9),
        options={
            "x = 4 only": FiniteSet(4),
            "x = 3 only": FiniteSet(3),
            "x = -3 and x = 3": FiniteSet(-3, 3),
            "x = -3, x = 3, and x = 4": FiniteSet(-3, 3, 4),
        },
    ),
    "alg-sim-complex-fraction-domain-exclusion": Oracle(
        truth=(1 / xp - 1 / yp) / (1 / xp**2 - 1 / yp**2),
        options={
            r"\frac{1}{x + y}": 1 / (xp + yp),
            r"\frac{x + y}{xy}": (xp + yp) / (xp * yp),
            r"\frac{xy}{x - y}": xp * yp / (xp - yp),
            r"\frac{xy}{x + y}": xp * yp / (xp + yp),
        },
    ),
    "alg-sim-add-rational-expressions": Oracle(
        truth=2 / (x - 3) + 5 / (x + 2),
        options={
            r"\frac{7x - 11}{(x - 3)(x + 2)}": (7 * x - 11) / ((x - 3) * (x + 2)),
            r"\frac{7}{2x - 1}": 7 / (2 * x - 1),
            r"\frac{7x + 19}{(x - 3)(x + 2)}": (7 * x + 19) / ((x - 3) * (x + 2)),
            r"\frac{7x - 1}{(x - 3)(x + 2)}": (7 * x - 1) / ((x - 3) * (x + 2)),
        },
    ),
    "alg-sim-evaluate-nested-absolute-values": Oracle(
        truth=Abs(-3) - 2 * Abs(4 - 9) + Abs(-(-5)),
        options={"12": 12, "-2": -2, "8": 8, "-12": -12},
    ),
    "alg-sim-absolute-value-distance-inequality": Oracle(
        truth=solve_set(Abs(xr - (-4)) < 7),
        options={
            "|x - 4| < 7": solve_set(Abs(xr - 4) < 7),
            "|x - 7| < 4": solve_set(Abs(xr - 7) < 4),
            "|x + 4| < 7": solve_set(Abs(xr + 4) < 7),
            "|x + 7| < 4": solve_set(Abs(xr + 7) < 4),
        },
    ),
    # x < 5 modelled as x = 5 - u with u > 0.
    "alg-sim-absolute-value-quotient-sign": Oracle(
        truth=sp.simplify(Abs((5 - yp) - 5) / ((5 - yp) - 5)),
        options={"1": 1, "x": 5 - yp, "0": 0, "-1": -1},
    ),
    "alg-sim-expand-logarithm-quotient-product": Oracle(
        truth=log(xp**3 * sqrt(yp) / zp**4, 2),
        options={
            r"3\log_2(x) + \frac{1}{2}\log_2(y) - 4\log_2(z)": 3 * log(xp, 2) + log(yp, 2) / 2 - 4 * log(zp, 2),
            r"3\log_2(x) + 2\log_2(y) - 4\log_2(z)": 3 * log(xp, 2) + 2 * log(yp, 2) - 4 * log(zp, 2),
            r"\frac{3\log_2(x) \cdot \frac{1}{2}\log_2(y)}{4\log_2(z)}": (3 * log(xp, 2) * log(yp, 2) / 2) / (4 * log(zp, 2)),
            r"3\log_2(x) - \frac{1}{2}\log_2(y) - 4\log_2(z)": 3 * log(xp, 2) - log(yp, 2) / 2 - 4 * log(zp, 2),
        },
    ),
    "alg-sim-condense-natural-logarithms": Oracle(
        truth=2 * log(xp) - log(yp) / 3 + log(zp),
        options={
            r"\ln\left(\frac{x^2 \sqrt[3]{y}}{z}\right)": log(xp**2 * yp ** Rational(1, 3) / zp),
            r"\ln\left(\frac{x^2 z}{\sqrt[3]{y}}\right)": log(xp**2 * zp / yp ** Rational(1, 3)),
            r"\ln\left(\frac{2x z}{\frac{1}{3}y}\right)": log(2 * xp * zp / (yp / 3)),
            r"\ln\left(x^2 - \sqrt[3]{y} + z\right)": log(xp**2 - yp ** Rational(1, 3) + zp),
        },
    ),
    "alg-sim-evaluate-mixed-logarithms": Oracle(
        truth=log(81, 3) - log(Rational(1, 8), 2) + log(exp(5)),
        options={"6": 6, "8": 8, "12": 12, "4": 4},
    ),
    # ---------------- Domain 2.0 Equations and inequalities ----------------
    "alg-sim-linear-equation-with-fractions": Oracle(
        truth=solve_set((2 * xr - 3) / 4 - (xr + 1) / 6 - 2),
        options={
            r"x = \frac{27}{4}": FiniteSet(Rational(27, 4)),
            r"x = \frac{29}{4}": FiniteSet(Rational(29, 4)),
            r"x = \frac{31}{4}": FiniteSet(Rational(31, 4)),
            r"x = \frac{35}{4}": FiniteSet(Rational(35, 4)),
        },
    ),
    "alg-sim-compound-inequality-interval": Oracle(
        truth=solve_set(-3 <= 2 * xr - 7).intersect(solve_set(2 * xr - 7 < 5)),
        options={
            "[2, 6)": Interval.Ropen(2, 6),
            "[-2, 6)": Interval.Ropen(-2, 6),
            "(2, 6]": Interval.Lopen(2, 6),
            "[-3, 5)": Interval.Ropen(-3, 5),
        },
    ),
    "alg-sim-rideshare-linear-budget-inequality": Oracle(
        truth=sp.floor((Rational(2600, 100) - Rational(350, 100)) / Rational(225, 100)),
        options={"9 miles": 9, "10 miles": 10, "11 miles": 11, "12 miles": 12},
    ),
    "alg-sim-quadratic-by-factoring": Oracle(
        truth=solve_set(2 * xr**2 - 5 * xr - 3),
        options={
            r"x = -3 and x = \frac{1}{2}": FiniteSet(-3, Rational(1, 2)),
            r"x = 3 and x = -\frac{1}{2}": FiniteSet(3, -Rational(1, 2)),
            r"x = -3 and x = -\frac{1}{2}": FiniteSet(-3, -Rational(1, 2)),
            r"x = 3 and x = \frac{1}{2}": FiniteSet(3, Rational(1, 2)),
        },
    ),
    "alg-sim-discriminant-repeated-root-k": Oracle(
        truth=solve_set((-6) ** 2 - 4 * 1 * k, k),
        options={"k = -9": FiniteSet(-9), "k = 36": FiniteSet(36), "k = 9": FiniteSet(9), "k = 3": FiniteSet(3)},
    ),
    "alg-sim-projectile-quadratic-model": Oracle(
        truth=solve_set(-16 * t**2 + 80 * t, t, Interval.open(0, oo)),
        options={
            "t = 5 seconds": FiniteSet(5),
            "t = 2.5 seconds": FiniteSet(Rational(5, 2)),
            "t = 10 seconds": FiniteSet(10),
            "t = 16 seconds": FiniteSet(16),
        },
    ),
    "alg-sim-radical-equation-extraneous-root": Oracle(
        truth=solve_set(sqrt(2 * xr + 7) - xr - 2),
        options={
            "x = 1 and x = -3": FiniteSet(1, -3),
            "x = 1 only": FiniteSet(1),
            "x = -3 only": FiniteSet(-3),
            "No real solution": EMPTY,
        },
    ),
    "alg-sim-rational-equation-extraneous-root": Oracle(
        truth=solve_set(xr / (xr - 2) + 1 / (xr - 4) - 2 / ((xr - 2) * (xr - 4))),
        options={
            "x = 4 only": FiniteSet(4),
            "x = -1 and x = 4": FiniteSet(-1, 4),
            "x = -1 only": FiniteSet(-1),
            "No real solution": EMPTY,
        },
    ),
    "alg-sim-absolute-value-equation-linear-rhs": Oracle(
        truth=solve_set(Abs(3 * xr - 5) - (2 * xr + 10)),
        options={
            "x = 15 only": FiniteSet(15),
            "x = -1 only": FiniteSet(-1),
            "No real solution": EMPTY,
            "x = 15 and x = -1": FiniteSet(15, -1),
        },
    ),
    "alg-sim-linear-system-sum-of-solution": Oracle(
        truth=sum(sp.solve([3 * xr + 2 * yr - 12, 5 * xr - 4 * yr + 2], [xr, yr]).values()),
        options={"5": 5, "6": 6, "4": 4, "7": 7},
    ),
    # 4x - 6y = k is 2 x (2x - 3y = 8) on the left, so it is the same line iff k = 2*8.
    "alg-sim-inconsistent-system-parameter": Oracle(
        truth=REALS - FiniteSet(Rational(4, 2) * 8) if Rational(-6, -3) == Rational(4, 2) else None,
        options={
            "k = 16 only": FiniteSet(16),
            r"Any real number k \neq 16": REALS - FiniteSet(16),
            "k = -16 only": FiniteSet(-16),
            r"Any real number k \neq 8": REALS - FiniteSet(8),
        },
    ),
    "alg-sim-line-parabola-intersection": Oracle(
        truth=frozenset(sp.solve([yr - (2 * xr - 1), yr - (xr**2 - 4)], [xr, yr])),
        options={
            "(3, 5) only": frozenset({(3, 5)}),
            "(-1, -3) only": frozenset({(-1, -3)}),
            "(3, 5) and (-1, -3)": frozenset({(3, 5), (-1, -3)}),
            "(2, 3) and (-2, 0)": frozenset({(2, 3), (-2, 0)}),
        },
    ),
    "alg-sim-exponential-equation-common-base": Oracle(
        truth=solve_set(4 ** (2 * xr - 1) - 8 ** (xr + 2)),
        options={"x = 5": FiniteSet(5), "x = 6": FiniteSet(6), "x = 7": FiniteSet(7), "x = 8": FiniteSet(8)},
    ),
    # Product rule turns the sum into log2(x(x - 3)) = 2, valid only where both logs exist (x > 3).
    "alg-sim-logarithmic-equation-domain-check": Oracle(
        truth=solve_set(xr * (xr - 3) - 2**2, xr, Interval.open(3, oo)),
        options={
            "x = 4 only": FiniteSet(4),
            "x = 4 and x = -1": FiniteSet(4, -1),
            "x = 2 only": FiniteSet(2),
            "x = -1 only": FiniteSet(-1),
        },
    ),
    "alg-sim-radioactive-decay-continuous-model": Oracle(
        truth=sp.solve(sp.Eq(200 * exp(-Rational(35, 1000) * t), 100), t)[0],
        options={
            r"\frac{200}{\ln 2}": 200 / log(2),
            r"\frac{\ln 2}{0.035}": log(2) / Rational(35, 1000),
            r"\frac{0.035}{\ln 2}": Rational(35, 1000) / log(2),
            r"\frac{\ln 0.5}{-200}": log(Rational(1, 2)) / -200,
        },
    ),
    # ---------------- Domain 3.0 Functions ----------------
    "alg-sim-domain-sqrt-over-linear": Oracle(
        truth=sp.calculus.util.continuous_domain(sqrt(xr - 2) / (xr - 5), xr, REALS),
        options={
            r"[2, 5) \cup (5, \infty)": Union(Interval.Ropen(2, 5), Interval.open(5, oo)),
            r"[2, 5) \cup [5, \infty)": Union(Interval.Ropen(2, 5), Interval(5, oo)),
            r"(2, 5) \cup (5, \infty)": Union(Interval.open(2, 5), Interval.open(5, oo)),
            r"[2, 5) \cup (5, 10]": Union(Interval.Ropen(2, 5), Interval.Lopen(5, 10)),
        },
    ),
    "alg-sim-difference-quotient-quadratic": Oracle(
        truth=sp.cancel(((2 * (x + h) ** 2 - 3 * (x + h) + 1) - (2 * x**2 - 3 * x + 1)) / h),
        options={
            "4x - 3 + h": 4 * x - 3 + h,
            "4x - 3 + 2h": 4 * x - 3 + 2 * h,
            "4x + 2h": 4 * x + 2 * h,
            "2h - 3": 2 * h - 3,
        },
    ),
    "alg-sim-range-of-downward-parabola": Oracle(
        truth=sp.calculus.util.function_range(-((xr - 3) ** 2) + 7, xr, REALS),
        options={
            r"[7, \infty)": Interval(7, oo),
            r"[3, \infty)": Interval(3, oo),
            r"(-\infty, 7]": Interval(-oo, 7),
            r"(-\infty, 3]": Interval(-oo, 3),
        },
    ),
    "alg-sim-composition-evaluate-at-point": Oracle(
        truth=(lambda f, g: f(g(2)))(lambda v: 2 * v**2 - 1, lambda v: 3 * v - 4),
        options={"13": 13, "17": 17, "3": 3, "7": 7},
    ),
    "alg-sim-composition-formula-g-of-f": Oracle(
        truth=(1 / (x - 2)).subs(x, x**2 + 1),
        options={
            r"\frac{1}{x^2 - 1}": 1 / (x**2 - 1),
            r"\frac{1}{x^2 + 1} - 2": 1 / (x**2 + 1) - 2,
            r"\frac{x^2 + 1}{x - 2}": (x**2 + 1) / (x - 2),
            r"\frac{1}{(x - 2)^2 + 1}": 1 / ((x - 2) ** 2 + 1),
        },
    ),
    "alg-sim-composition-domain-sqrt-linear": Oracle(
        truth=sp.calculus.util.continuous_domain(sqrt(2 * xr - 6), xr, REALS),
        options={
            r"[0, \infty)": Interval(0, oo),
            r"[3, \infty)": Interval(3, oo),
            r"(-\infty, 3]": Interval(-oo, 3),
            r"(3, \infty)": Interval.open(3, oo),
        },
    ),
    "alg-sim-even-odd-quartic-polynomial": Oracle(
        truth=parity(3 * xr**4 - 2 * xr**2 + 5, xr),
        options={"Odd function": "odd", "Neither even nor odd": "neither", "Even function": "even", "Both even and odd": "both"},
    ),
    "alg-sim-quadratic-intercepts": Oracle(
        truth=(solve_set(xr**2 - 6 * xr + 8), (xr**2 - 6 * xr + 8).subs(xr, 0)),
        options={
            "x-intercepts at (-2, 0) and (-4, 0); y-intercept at (0, 8)": (FiniteSet(-2, -4), 8),
            "x-intercepts at (2, 0) and (4, 0); y-intercept at (0, -8)": (FiniteSet(2, 4), -8),
            "x-intercepts at (1, 0) and (8, 0); y-intercept at (0, 8)": (FiniteSet(1, 8), 8),
            "x-intercepts at (2, 0) and (4, 0); y-intercept at (0, 8)": (FiniteSet(2, 4), 8),
        },
    ),
    "alg-sim-even-odd-cubic-polynomial": Oracle(
        truth=parity(2 * xr**3 - 5 * xr, xr),
        options={"Odd function": "odd", "Even function": "even", "Neither even nor odd": "neither", "Linear function": "linear"},
    ),
    "alg-sim-parent-quadratic-transformation-sequence": Oracle(
        truth=vertex_form_moves(-((x + 4) ** 2) - 5),
        options={
            "Shift right 4 units, reflect across the x-axis, shift up 5 units": (("right", 4), "x-axis", ("up", 5)),
            "Shift left 4 units, reflect across the x-axis, shift down 5 units": (("left", 4), "x-axis", ("down", 5)),
            "Shift left 4 units, reflect across the y-axis, shift down 5 units": (("left", 4), "y-axis", ("down", 5)),
            "Shift right 4 units, reflect across the y-axis, shift down 5 units": (("right", 4), "y-axis", ("down", 5)),
        },
    ),
    # (3, 8) on f: y = 2 f(x - 1) + 3 uses f's input 3 at x = 4.
    "alg-sim-point-under-combined-transformation": Oracle(
        truth=(sp.solve(xr - 1 - 3, xr)[0], 2 * 8 + 3),
        options={"(2, 19)": (2, 19), "(4, 11)": (4, 11), "(4, 19)": (4, 19), "(2, 13)": (2, 13)},
    ),
    "alg-sim-reflect-and-shift-square-root": Oracle(
        truth=(lambda f: f(-x) + 2)(sqrt),
        options={
            r"g(x) = -\sqrt{x} + 2": -sqrt(x) + 2,
            r"g(x) = \sqrt{x + 2}": sqrt(x + 2),
            r"g(x) = -\sqrt{x - 2}": -sqrt(x - 2),
            r"g(x) = \sqrt{-x} + 2": sqrt(-x) + 2,
        },
    ),
    "alg-sim-inverse-of-rational-function": Oracle(
        truth=sp.solve(sp.Eq(h, (2 * x + 1) / (x - 3)), x)[0].subs(h, x),
        options={
            r"f^{-1}(x) = \frac{3x + 1}{x - 2}": (3 * x + 1) / (x - 2),
            r"f^{-1}(x) = \frac{x - 3}{2x + 1}": (x - 3) / (2 * x + 1),
            r"f^{-1}(x) = \frac{3x - 1}{x + 2}": (3 * x - 1) / (x + 2),
            r"f^{-1}(x) = \frac{2x - 1}{x + 3}": (2 * x - 1) / (x + 3),
        },
    ),
    "alg-sim-quadratic-inverse-domain-restriction": Oracle(
        truth=None,
        check=lambda interval: injective_on((x - 2) ** 2 + 3, interval),
        options={
            r"x \geq -2": Interval(-2, oo),
            r"x \geq 2": Interval(2, oo),
            r"x \leq 3": Interval(-oo, 3),
            "All real numbers x": Interval(-oo, oo),
        },
    ),
    "alg-sim-inverse-of-linear-function": Oracle(
        truth=sp.solve(sp.Eq(h, 4 * x - 7), x)[0].subs(h, x),
        options={
            r"f^{-1}(x) = \frac{1}{4x - 7}": 1 / (4 * x - 7),
            r"f^{-1}(x) = \frac{x - 7}{4}": (x - 7) / 4,
            r"f^{-1}(x) = \frac{x + 7}{4}": (x + 7) / 4,
            "f^{-1}(x) = 4x + 7": 4 * x + 7,
        },
    ),
    "alg-sim-rational-function-asymptotes-and-holes": Oracle(
        truth=asymptotes_and_holes(x**2 - 4, x**2 - x - 2),
        options={
            "Vertical asymptotes at x = 2 and x = -1; no holes": (FiniteSet(2, -1), EMPTY),
            "Vertical asymptote at x = 2; hole at x = -1": (FiniteSet(2), FiniteSet(-1)),
            "Vertical asymptote at x = -2; hole at x = 2": (FiniteSet(-2), FiniteSet(2)),
            "Vertical asymptote at x = -1; hole at x = 2": (FiniteSet(-1), FiniteSet(2)),
        },
    ),
    "alg-sim-horizontal-asymptote-equal-degree": Oracle(
        truth=sp.limit((6 * x**2 - 5 * x + 1) / (2 * x**2 + 7), x, oo),
        options={"y = 3": 3, "y = 0": 0, "y = 7": 7, "y = 2": 2},
    ),
    "alg-sim-slant-asymptote": Oracle(
        truth=sp.div(2 * x**2 + 5 * x - 3, x + 1, x)[0],
        options={"y = 2x": 2 * x, "y = 2x + 3": 2 * x + 3, "y = 2x + 5": 2 * x + 5, "y = 2x - 3": 2 * x - 3},
    ),
    # ---------------- Domain 4.0 Number systems ----------------
    "alg-sim-identify-irrational-number": Oracle(
        truth=None,
        check=lambda v: sp.sympify(v).is_rational is False,
        options={
            r"\frac{\sqrt{49}}{7}": sqrt(49) / 7,
            r"0.121212\dots": Rational(12, 99),
            r"\sqrt{50}": sqrt(50),
            r"-\frac{3}{8}": -Rational(3, 8),
        },
    ),
    "alg-sim-distributive-property": Oracle(
        truth="distributive" if sp.expand(3 * (x + 4)) == 3 * x + 12 else None,
        reviewed="3(x + 4) = 3x + 12 rewrites a product over a sum as a sum of products: a(b + c) = ab + ac.",
        options={
            "Commutative property of multiplication": "commutative-multiplication",
            "Associative property of addition": "associative-addition",
            "Multiplicative identity property": "multiplicative-identity",
            "Distributive property of multiplication over addition": "distributive",
        },
    ),
    "alg-sim-prime-factorization-360": Oracle(
        truth=sp.factorint(360),
        options={
            r"2^3 \times 3^2 \times 5": {2: 3, 3: 2, 5: 1},
            r"2^2 \times 3^3 \times 5": {2: 2, 3: 3, 5: 1},
            r"2^4 \times 3 \times 5": {2: 4, 3: 1, 5: 1},
            r"2^3 \times 3 \times 15": {2: 3, 3: 1, 15: 1},
        },
    ),
    "alg-sim-power-of-imaginary-unit": Oracle(truth=I**75, options={"1": 1, "-i": -I, "i": I, "-1": -1}),
    "alg-sim-multiply-complex-numbers": Oracle(
        truth=sp.expand((3 - 2 * I) * (4 + 5 * I)),
        options={"2 + 7i": 2 + 7 * I, "12 - 10i": 12 - 10 * I, "22 + 7i": 22 + 7 * I, "22 - 7i": 22 - 7 * I},
    ),
    "alg-sim-divide-complex-numbers": Oracle(
        truth=(5 + I) / (2 - 3 * I),
        options={
            r"\frac{7}{5} + \frac{17}{5}i": Rational(7, 5) + Rational(17, 5) * I,
            r"\frac{5}{13} + \frac{15}{13}i": Rational(5, 13) + Rational(15, 13) * I,
            r"\frac{13}{13} + \frac{17}{13}i": Rational(13, 13) + Rational(17, 13) * I,
            r"\frac{7}{13} + \frac{17}{13}i": Rational(7, 13) + Rational(17, 13) * I,
        },
    ),
    "alg-sim-arithmetic-sequence-nth-term": Oracle(
        truth=(lambda a1, d, m: a1 + (m - 1) * d)(7, 4, 20),
        options={"83": 83, "87": 87, "80": 80, "79": 79},
    ),
    "alg-sim-arithmetic-series-sum": Oracle(
        truth=sp.summation(3 * n - 2, (n, 1, 30)),
        options={"1305": 1305, "1335": 1335, "1365": 1365, "1410": 1410},
    ),
    "alg-sim-infinite-geometric-series-sum": Oracle(
        truth=sp.summation(12 * Rational(1, 3) ** n, (n, 0, oo)),
        options={"16": 16, "24": 24, "18": 18, "20": 20},
    ),
    "alg-sim-evaluate-combination-8-choose-3": Oracle(
        truth=sp.binomial(8, 3), options={"24": 24, "336": 336, "28": 28, "56": 56}
    ),
    "alg-sim-binomial-expansion-coefficient": Oracle(
        truth=sp.expand((2 * x - 1) ** 5).coeff(x, 3), options={"80": 80, "-80": -80, "40": 40, "-40": -40}
    ),
    "alg-sim-ordered-medal-permutations": Oracle(
        truth=sp.ff(10, 3), options={"120": 120, "720": 720, "240": 240, "1000": 1000}
    ),
    # ---------------- Formative questions ----------------
    "alg-fmt-negative-exponent-definition": Oracle(
        truth=xp**-4,
        options={r"\frac{1}{x^4}": 1 / xp**4, "-x^4": -(xp**4), "-4x": -4 * xp, r"\frac{4}{x}": 4 / xp},
    ),
    "alg-fmt-rational-exponent-to-radical": Oracle(
        truth=xp ** Rational(2, 5),
        options={
            r"\sqrt{x^5}": sqrt(xp**5),
            r"\sqrt[5]{x^2}": sp.root(xp**2, 5),
            "5x^2": 5 * xp**2,
            r"2\sqrt[5]{x}": 2 * sp.root(xp, 5),
        },
    ),
    "alg-fmt-factor-difference-of-squares": Oracle(
        truth=None,
        check=complete_factorization_of(x**2 - 16),
        options={"(x - 4)^2": (x - 4) ** 2, "(x + 4)^2": (x + 4) ** 2, "(x - 4)(x + 4)": (x - 4) * (x + 4), "(x - 8)(x + 2)": (x - 8) * (x + 2)},
    ),
    "alg-fmt-sum-of-cubes-identity": Oracle(
        truth=None,
        check=complete_factorization_of(a**3 + b**3),
        options={
            "(a + b)(a^2 + ab + b^2)": (a + b) * (a**2 + a * b + b**2),
            "(a + b)^3": (a + b) ** 3,
            "(a - b)(a^2 + ab + b^2)": (a - b) * (a**2 + a * b + b**2),
            "(a + b)(a^2 - ab + b^2)": (a + b) * (a**2 - a * b + b**2),
        },
    ),
    "alg-fmt-rational-expression-excluded-value": Oracle(
        truth=solve_set(2 * xr - 8),
        options={"x = 4": FiniteSet(4), "x = -4": FiniteSet(-4), r"x = -\frac{1}{3}": FiniteSet(-Rational(1, 3)), "x = 0": FiniteSet(0)},
    ),
    # Witness: (x + 7)/x at x = 1 is 8, but "cancelling" x leaves 7.
    "alg-fmt-invalid-term-cancellation": Oracle(
        truth="added-term-not-factor" if ((x + 7) / x).subs(x, 1) != 7 else None,
        reviewed="Only common factors of the whole numerator and denominator cancel; x is added to 7, not multiplying it.",
        options={
            "Because variables can never appear in denominators of rational expressions": "no-variable-denominators",
            "Because x in the numerator is an added term, not a common factor multiplying the entire numerator": "added-term-not-factor",
            "Because rational expressions can only be simplified if x is a negative integer": "negative-integer-only",
            "Because canceling is only permitted when the numerator degree is strictly greater than 2": "degree-rule",
        },
    ),
    "alg-fmt-absolute-value-distance": Oracle(truth=Abs(3 - (-5)), options={"-2": -2, "2": 2, "8": 8, "-8": -8}),
    "alg-fmt-absolute-value-of-negative": Oracle(
        truth=Abs(-yp),  # x < 0 modelled as x = -u, u > 0; options use the same model
        options={"x": -yp, "0": 0, "1": 1, "-x": yp},
    ),
    "alg-fmt-evaluate-log-base-4": Oracle(truth=log(64, 4), options={"3": 3, "16": 16, "4": 4, "12": 12}),
    "alg-fmt-log-power-property": Oracle(
        truth=log(xp**5, yp),
        options={
            r"(\log_b x)^5": log(xp, yp) ** 5,
            r"5\log_b(x)": 5 * log(xp, yp),
            r"\log_b(5x)": log(5 * xp, yp),
            r"\log_b(x) + 5": log(xp, yp) + 5,
        },
    ),
    "alg-fmt-solve-two-step-linear-equation": Oracle(
        truth=solve_set(4 * xr - 7 - 13),
        options={"x = 1.5": FiniteSet(Rational(3, 2)), "x = 20": FiniteSet(20), "x = 5": FiniteSet(5), "x = -5": FiniteSet(-5)},
    ),
    "alg-fmt-inequality-sign-flip": Oracle(
        truth=solve_set(-3 * xr <= 12),
        options={
            r"x \leq -4": Interval(-oo, -4),
            r"x \geq 4": Interval(4, oo),
            r"x \leq 4": Interval(-oo, 4),
            r"x \geq -4": Interval(-4, oo),
        },
    ),
    # A quadratic with b^2 - 4ac = 0 has one root of multiplicity 2; for real
    # coefficients it is real (and rational only when a and b are rational).
    "alg-fmt-zero-discriminant-meaning": Oracle(
        truth=(
            "one-repeated-real"
            if sp.roots(sp.Poly(a * x**2 + b * x + b**2 / (4 * a), x)) == {-b / (2 * a): 2}
            else None
        ),
        options={
            "The equation has exactly one repeated real solution": "one-repeated-real",
            "The equation has two distinct irrational real solutions": "two-distinct-real",
            "The equation has two complex conjugate non-real solutions": "two-complex",
            "The equation has no mathematical solutions whatsoever": "none",
        },
    ),
    "alg-fmt-difference-of-squares-roots": Oracle(
        truth=solve_set(xr**2 - 9),
        options={"x = 3 only": FiniteSet(3), "x = 3 and x = -3": FiniteSet(3, -3), "x = 9 and x = -9": FiniteSet(9, -9), "x = 0 and x = 9": FiniteSet(0, 9)},
    ),
    # Witness: sqrt(x) = -1 has no solution, yet squaring gives x = 1.
    "alg-fmt-radical-equation-check-solutions": Oracle(
        truth="squaring-introduces-extraneous"
        if solve_set(sqrt(xr) + 1) == EMPTY and solve_set(xr - 1) == FiniteSet(1)
        else None,
        reviewed="Squaring maps a and -a to the same value, so the squared equation can gain roots the original lacks.",
        options={
            "Radical roots can only be calculated with approximate decimal precision": "decimal-precision",
            "Quadratic factoring introduces false positive roots into every polynomial": "factoring-false-roots",
            "Squaring both sides is not a one-to-one operation and can introduce extraneous solutions": "squaring-introduces-extraneous",
            "Radical expressions cannot be simplified over integer coefficients": "no-integer-simplification",
        },
    ),
    "alg-fmt-absolute-value-equals-negative": Oracle(
        truth=solve_set(Abs(2 * xr + 1) + 7),
        options={"x = -4 and x = 3": FiniteSet(-4, 3), "x = -4 only": FiniteSet(-4), "x = 3 only": FiniteSet(3), "No solution (empty set)": EMPTY},
    ),
    "alg-fmt-inconsistent-system-graph": Oracle(
        truth="parallel-distinct",
        reviewed="A 2x2 linear system has no solution exactly when its lines have equal slope and different intercepts.",
        options={
            "Two distinct parallel lines that never intersect": "parallel-distinct",
            "Two perpendicular lines that intersect at right angles": "perpendicular",
            "Two coincident lines that share every point in common": "coincident",
            "A line tangent to a circle at a single point": "tangent-circle",
        },
    ),
    "alg-fmt-elimination-simple-system": Oracle(
        truth=sp.solve([xr + yr - 6, xr - yr - 2], [xr, yr])[xr],
        options={"x = 2": 2, "x = 4": 4, "x = 3": 3, "x = 5": 5},
    ),
    "alg-fmt-exponential-equation-common-base": Oracle(
        truth=solve_set(2 ** (xr + 1) - 16),
        options={"x = 4": FiniteSet(4), "x = 7": FiniteSet(7), "x = 3": FiniteSet(3), "x = 8": FiniteSet(8)},
    ),
    # Continuous compounding is the limit of n compoundings per period.
    "alg-fmt-continuous-compound-interest-formula": Oracle(
        truth=P * sp.limit((1 + r / Symbol("m", positive=True)) ** (Symbol("m", positive=True) * t), Symbol("m", positive=True), oo),
        options={
            "A = P(1 + r)^t": P * (1 + r) ** t,
            "A = P r t": P * r * t,
            r"A = P \ln(rt)": P * log(r * t),
            "A = P e^{rt}": P * exp(r * t),
        },
    ),
    "alg-fmt-vertical-line-test": Oracle(
        truth="vertical-line",
        reviewed="y = f(x) assigns one y to each x, so every vertical line meets the graph at most once.",
        options={
            "Vertical Line Test": "vertical-line",
            "Horizontal Line Test": "horizontal-line",
            "Diagonal Reflection Test": "diagonal",
            "Parallel Axis Test": "parallel-axis",
        },
    ),
    "alg-fmt-domain-of-square-root": Oracle(
        truth=sp.calculus.util.continuous_domain(sqrt(xr - 9), xr, REALS),
        options={r"(9, \infty)": Interval.open(9, oo), r"[9, \infty)": Interval(9, oo), r"(-\infty, 9]": Interval(-oo, 9), r"(-\infty, \infty)": REALS},
    ),
    "alg-fmt-evaluate-composition": Oracle(
        truth=(lambda f, g: f(g(2)))(lambda v: v + 3, lambda v: v**2), options={"25": 25, "10": 10, "7": 7, "13": 13}
    ),
    # Witness from the lesson's own pair: f = x + 3, g = x^2 do not commute.
    "alg-fmt-composition-not-commutative": Oracle(
        truth="not-commutative" if sp.expand((x**2) + 3 - (x + 3) ** 2) != 0 else None,
        options={
            "Yes, composition is commutative for all pairs of functions": "commutative",
            "Yes, but only when both functions have identical domain restrictions": "commutative-same-domain",
            "No, but only when functions contain rational exponents": "noncommutative-rational-only",
            "No, (f o g)(x) does not generally equal (g o f)(x)": "not-commutative",
        },
    ),
    # A condition defines "even" iff it holds for every even witness and fails for every non-even one.
    "alg-fmt-even-function-definition": Oracle(
        truth=None,
        check=lambda cond: all(cond(f) for f in EVEN_WITNESSES) and not any(cond(f) for f in NON_EVEN_WITNESSES),
        options={
            "f(-x) = f(x)": lambda f: sp.simplify(f.subs(xr, -xr) - f) == 0,
            "f(-x) = -f(x)": lambda f: sp.simplify(f.subs(xr, -xr) + f) == 0,
            "f(x) = -f(x)": lambda f: sp.simplify(2 * f) == 0,
            "f(1/x) = f(x)": lambda f: sp.simplify(f.subs(xr, 1 / xr) - f) == 0,
        },
    ),
    "alg-fmt-odd-function-symmetric-point": Oracle(
        truth=(-4, -(-7)), options={"(-4, -7)": (-4, -7), "(-4, 7)": (-4, 7), "(4, 7)": (4, 7), "(7, -4)": (7, -4)}
    ),
    # g(x) = f(x - 5): g at x = c reproduces f at c - 5, so the graph moves +5 in x.
    "alg-fmt-horizontal-shift": Oracle(
        truth=("horizontal", sp.solve(xr - 5 - 0, xr)[0]),
        options={
            "Horizontal shift to the left by 5 units": ("horizontal", -5),
            "Vertical shift up by 5 units": ("vertical", 5),
            "Horizontal shift to the right by 5 units": ("horizontal", 5),
            "Vertical shift down by 5 units": ("vertical", -5),
        },
    ),
    # (u, v) on f maps to (u, -v) on -f: only the y-coordinate flips sign.
    "alg-fmt-reflection-across-x-axis": Oracle(
        truth="x-axis" if (lambda p: (p[0], -p[1]))((2, 3)) == (2, -3) else None,
        options={
            "It is reflected across the y-axis": "y-axis",
            "It is reflected across the diagonal line y = x": "diagonal",
            "It is shifted downward by 1 unit": "shift-down-1",
            "It is reflected across the x-axis": "x-axis",
        },
    ),
    "alg-fmt-horizontal-line-test": Oracle(
        truth="horizontal-line",
        reviewed="f has an inverse function iff f is one-to-one, i.e. every horizontal line meets its graph at most once.",
        options={
            "Horizontal Line Test": "horizontal-line",
            "Vertical Line Test": "vertical-line",
            "First Derivative Test": "first-derivative",
            "Symmetry Axis Test": "symmetry-axis",
        },
    ),
    # f(2) = 9 means f^-1(9) = 2 by definition of the inverse.
    "alg-fmt-inverse-function-value": Oracle(
        truth=dict([(9, 2)])[9], options={r"\frac{1}{9}": Rational(1, 9), "2": 2, r"\frac{1}{2}": Rational(1, 2), "-9": -9}
    ),
    "alg-fmt-horizontal-asymptote-equal-degree": Oracle(
        truth=sp.limit((4 * x - 1) / (2 * x + 5), x, oo),
        options={"y = 0": 0, r"y = -\frac{5}{2}": -Rational(5, 2), "y = 2": 2, "y = 4": 4},
    ),
    "alg-fmt-horizontal-asymptote-lower-degree": Oracle(
        truth=sp.limit((7 * x + 2) / (x**2 - 9), x, oo),
        options={"y = 7": 7, "y = 3": 3, "No horizontal asymptote": None, "y = 0": 0},
    ),
    "alg-fmt-real-number-subsets": Oracle(
        truth=frozenset(
            name
            for name, s in {
                "naturals": S.Naturals,
                "whole": S.Naturals0,
                "integers": S.Integers,
                "rationals": S.Rationals,
                "irrationals": S.Reals - S.Rationals,
                "reals": S.Reals,
            }.items()
            if s.contains(-4) == sp.true
        ),
        options={
            "Integers, rational numbers, and real numbers": frozenset({"integers", "rationals", "reals"}),
            "Natural numbers and whole numbers only": frozenset({"naturals", "whole"}),
            "Irrational numbers and real numbers only": frozenset({"irrationals", "reals"}),
            "Whole numbers and integers only": frozenset({"whole", "integers"}),
        },
    ),
    "alg-fmt-additive-inverse": Oracle(
        truth=sp.solve(-8 + xr, xr)[0], options={r"-\frac{1}{8}": -Rational(1, 8), "8": 8, r"\frac{1}{8}": Rational(1, 8), "0": 0}
    ),
    "alg-fmt-imaginary-unit-squared": Oracle(truth=I**2, options={"1": 1, "-i": -I, "-1": -1, "i": I}),
    "alg-fmt-complex-conjugate": Oracle(
        truth=sp.conjugate(7 - 3 * I), options={"-7 + 3i": -7 + 3 * I, "-7 - 3i": -7 - 3 * I, "3 - 7i": 3 - 7 * I, "7 + 3i": 7 + 3 * I}
    ),
    "alg-fmt-arithmetic-sequence-term": Oracle(
        truth=(lambda a1, d, m: a1 + (m - 1) * d)(5, 3, 4), options={"14": 14, "17": 17, "12": 12, "15": 15}
    ),
    # Convergence condition SymPy attaches to the geometric series' closed form.
    "alg-fmt-geometric-series-convergence": Oracle(
        truth=sp.solveset(
            sp.summation(Symbol("q", real=True) ** n, (n, 0, oo)).args[0][1], Symbol("q", real=True), REALS
        ),
        options={
            "|r| > 1": Union(Interval.open(-oo, -1), Interval.open(1, oo)),
            "|r| < 1": Interval.open(-1, 1),
            "r > 0": Interval.open(0, oo),
            "r = 1": FiniteSet(1),
        },
    ),
    "alg-fmt-evaluate-factorial": Oracle(truth=sp.factorial(5), options={"24": 24, "60": 60, "120": 120, "720": 720}),
    "alg-fmt-combination-vs-permutation": Oracle(
        truth="combinations-order-irrelevant",
        reviewed="A committee is an unordered set of members, so selections differing only in order are the same committee.",
        options={
            "Permutations, because committee members have distinct names": "permutations",
            "Factorials only, because all 10 volunteers are assigned roles": "factorials",
            "Powers of 10, because the pool size is 10 volunteers": "powers",
            "Combinations, because the order of selection within the committee does not matter": "combinations-order-irrelevant",
        },
    ),
}


def is_correct(oracle: Oracle, value: Any) -> bool:
    if oracle.check is not None:
        return bool(oracle.check(value))
    return same(value, oracle.truth)


def prompt_fingerprint(prompt: str) -> str:
    return hashlib.sha256(prompt.encode("utf-8")).hexdigest()[:16]


# Fingerprints of the prompts each oracle above was derived from (reviewed
# 2026-11-12). A changed prompt fails until its oracle is re-derived by hand
# and the fingerprint updated in the same change.
PROMPT_SHA256: dict[str, str] = {
    "alg-sim-rational-exponent-power-of-monomial": "82123e80e598c618",
    "alg-sim-simplify-radical-72x5y6": "9c84c0ddc6ca233c",
    "alg-sim-scientific-notation-quotient": "b3ff0ab56d79f3cc",
    "alg-sim-factor-gcf-then-difference-of-squares": "dd04ace5918f1ff9",
    "alg-sim-factor-difference-of-cubes": "0f4341217d4378bb",
    "alg-sim-factor-by-grouping-four-terms": "a78231cd1da8c838",
    "alg-sim-rational-expression-excluded-values": "08c646b9208a3a29",
    "alg-sim-complex-fraction-domain-exclusion": "00edfbf444be08e6",
    "alg-sim-add-rational-expressions": "7fc1b6f888d01603",
    "alg-sim-evaluate-nested-absolute-values": "513e08e325cae235",
    "alg-sim-absolute-value-distance-inequality": "5d974e7eb7e2ac66",
    "alg-sim-absolute-value-quotient-sign": "10b13fd0be1d8bd2",
    "alg-sim-expand-logarithm-quotient-product": "44b5d74c738f2c3c",
    "alg-sim-condense-natural-logarithms": "95df12e17b7adc84",
    "alg-sim-evaluate-mixed-logarithms": "3905d622a555f159",
    "alg-sim-linear-equation-with-fractions": "a4925e2b7410aa86",
    "alg-sim-compound-inequality-interval": "96550ddc52a34fcd",
    "alg-sim-rideshare-linear-budget-inequality": "fc72666960c7ef79",
    "alg-sim-quadratic-by-factoring": "fb047747f4d679d8",
    "alg-sim-discriminant-repeated-root-k": "8173a21370ce28af",
    "alg-sim-projectile-quadratic-model": "02b7976b9aa03f07",
    "alg-sim-radical-equation-extraneous-root": "3950c60815f28460",
    "alg-sim-rational-equation-extraneous-root": "00c92d564f48a06e",
    "alg-sim-absolute-value-equation-linear-rhs": "f76e72db93a2b03e",
    "alg-sim-linear-system-sum-of-solution": "5e1971cdbc9020ff",
    "alg-sim-inconsistent-system-parameter": "fb68086f6695baeb",
    "alg-sim-line-parabola-intersection": "998ca564806c228f",
    "alg-sim-exponential-equation-common-base": "2d0882280e58bf2b",
    "alg-sim-logarithmic-equation-domain-check": "122e969b34f902c1",
    "alg-sim-radioactive-decay-continuous-model": "c8012e77d652c159",
    "alg-sim-domain-sqrt-over-linear": "622cfc3762b94093",
    "alg-sim-difference-quotient-quadratic": "44286cc3161dd499",
    "alg-sim-range-of-downward-parabola": "1640f4d10f38f26e",
    "alg-sim-composition-evaluate-at-point": "1d8ee5952ff59eb1",
    "alg-sim-composition-formula-g-of-f": "a73a7f38e0ac4dd2",
    "alg-sim-composition-domain-sqrt-linear": "f8d677077b442d72",
    "alg-sim-even-odd-quartic-polynomial": "4fe541ce011c3983",
    "alg-sim-quadratic-intercepts": "408956110e1c8e89",
    "alg-sim-even-odd-cubic-polynomial": "25d583b677b92672",
    "alg-sim-parent-quadratic-transformation-sequence": "58904b5afa98a2e7",
    "alg-sim-point-under-combined-transformation": "bdac5cedb6e411f6",
    "alg-sim-reflect-and-shift-square-root": "0fda9b664244752e",
    "alg-sim-inverse-of-rational-function": "44129fdfd7f7683c",
    "alg-sim-quadratic-inverse-domain-restriction": "e8d2845dfd9845c1",
    "alg-sim-inverse-of-linear-function": "bfaaa51789bdfc90",
    "alg-sim-rational-function-asymptotes-and-holes": "18514f68ebec416b",
    "alg-sim-horizontal-asymptote-equal-degree": "d776d866fd029c48",
    "alg-sim-slant-asymptote": "045c315b0981dcf7",
    "alg-sim-identify-irrational-number": "83e53a0200263739",
    "alg-sim-distributive-property": "3846530c926cea17",
    "alg-sim-prime-factorization-360": "e40d444680b10812",
    "alg-sim-power-of-imaginary-unit": "e590f2bf74089822",
    "alg-sim-multiply-complex-numbers": "780dfaa7b7b8fec9",
    "alg-sim-divide-complex-numbers": "5674aaad75807c6e",
    "alg-sim-arithmetic-sequence-nth-term": "63a120972038670c",
    "alg-sim-arithmetic-series-sum": "8de90e3949982d59",
    "alg-sim-infinite-geometric-series-sum": "3d75b513192f64fe",
    "alg-sim-evaluate-combination-8-choose-3": "b1e80adae8f697bb",
    "alg-sim-binomial-expansion-coefficient": "e8c556f5ae784787",
    "alg-sim-ordered-medal-permutations": "f2b4648a7a5a729b",
    "alg-fmt-negative-exponent-definition": "c051ca0f2420249d",
    "alg-fmt-rational-exponent-to-radical": "62e13441a8fb7222",
    "alg-fmt-factor-difference-of-squares": "4a63c31bef454346",
    "alg-fmt-sum-of-cubes-identity": "89e896920b325036",
    "alg-fmt-rational-expression-excluded-value": "3ae9023770a0823a",
    "alg-fmt-invalid-term-cancellation": "99ff855828f1d5cd",
    "alg-fmt-absolute-value-distance": "8e285bb7d1dd4159",
    "alg-fmt-absolute-value-of-negative": "8ee7d6fad04babfd",
    "alg-fmt-evaluate-log-base-4": "92d2e5617a9aebbb",
    "alg-fmt-log-power-property": "cc3e92ca693e8419",
    "alg-fmt-solve-two-step-linear-equation": "150abe98df4807da",
    "alg-fmt-inequality-sign-flip": "543c50e8aa5fac19",
    "alg-fmt-zero-discriminant-meaning": "48f8417c1df4c428",
    "alg-fmt-difference-of-squares-roots": "f4f37e0dfa6a3af4",
    "alg-fmt-radical-equation-check-solutions": "b40e2678dee8f683",
    "alg-fmt-absolute-value-equals-negative": "592d3c6e7a3e3fe9",
    "alg-fmt-inconsistent-system-graph": "54599596764501cd",
    "alg-fmt-elimination-simple-system": "28972be02f5a1eaf",
    "alg-fmt-exponential-equation-common-base": "b0a9c2079dd7687c",
    "alg-fmt-continuous-compound-interest-formula": "a6870ad8973f3c41",
    "alg-fmt-vertical-line-test": "2c049400740d7e54",
    "alg-fmt-domain-of-square-root": "7bdb7013534e0233",
    "alg-fmt-evaluate-composition": "3d3c66d905ca838f",
    "alg-fmt-composition-not-commutative": "ce766de0010ad6a6",
    "alg-fmt-even-function-definition": "218bec0bb78e0fdc",
    "alg-fmt-odd-function-symmetric-point": "92d0f6413106fa30",
    "alg-fmt-horizontal-shift": "5c7d73e695492f98",
    "alg-fmt-reflection-across-x-axis": "2486cde27e472206",
    "alg-fmt-horizontal-line-test": "b697c6487b46fc4a",
    "alg-fmt-inverse-function-value": "a12824b3f14a2b8f",
    "alg-fmt-horizontal-asymptote-equal-degree": "767449956a36a695",
    "alg-fmt-horizontal-asymptote-lower-degree": "068bc6c2e32a1c1e",
    "alg-fmt-real-number-subsets": "077542aa690bb761",
    "alg-fmt-additive-inverse": "b925374f6cf45bdd",
    "alg-fmt-imaginary-unit-squared": "527e186c7a9c2a68",
    "alg-fmt-complex-conjugate": "b3639d7d77c95879",
    "alg-fmt-arithmetic-sequence-term": "3f6ca33d521564ce",
    "alg-fmt-geometric-series-convergence": "b14c10b8df9cb104",
    "alg-fmt-evaluate-factorial": "67252b01376ed83a",
    "alg-fmt-combination-vs-permutation": "edd5ed4094f6cdcc",
}


def verify_item(item_id: str, prompt: str, options: list[str], key: int) -> list[str]:
    """Problems with one shipped item against its oracle (empty list = verified)."""
    oracle = ORACLES.get(item_id)
    if oracle is None:
        return [f"{item_id}: no oracle"]
    problems = []
    if PROMPT_SHA256.get(item_id) != prompt_fingerprint(prompt):
        problems.append(f"{item_id}: prompt changed since its oracle was derived; re-derive and update PROMPT_SHA256")
    if len(set(options)) != len(options):
        problems.append(f"{item_id}: duplicate option text")
    if set(options) != set(oracle.options):
        problems.append(f"{item_id}: option text differs from the oracle's reviewed options")
        return problems
    if not isinstance(key, int) or isinstance(key, bool) or not 0 <= key < len(options):
        problems.append(f"{item_id}: answer key out of range")
        return problems
    correct = [i for i, text in enumerate(options) if is_correct(oracle, oracle.options[text])]
    if correct != [key]:
        problems.append(f"{item_id}: oracle-correct option positions {correct} != keyed position {key}")
    return problems
