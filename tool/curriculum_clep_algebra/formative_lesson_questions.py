"""Formative check-for-understanding practice questions for CLEP College Algebra lessons.

Provides 2 genuine, original formative questions per lesson (40 total across 20 lessons)
for immediate in-lesson retrieval practice. These are strictly separated from the 60-question
protected simulation exam pool.
"""
from __future__ import annotations

RAW_FORMATIVE_QUESTIONS_BY_LESSON: dict[str, list[dict]] = {
    # Domain 1.0: Algebraic Operations
    "Exponents, Radicals, and Scientific Notation": [
        {
            "question_text": "Which expression is equivalent to $x^{-4}$ for all non-zero real numbers $x$?",
            "correct_text": "\\frac{1}{x^4}",
            "distractors": [
                "-x^4",
                "-4x",
                "\\frac{4}{x}",
            ],
            "explanation": "By definition of negative exponents, a^(-n) = 1 / a^n for any non-zero base a. Thus x^(-4) = 1 / x^4.",
            "concept_slugs": ["alg-exponent-rules"],
        },
        {
            "question_text": "What is the radical equivalent of the rational exponent expression $x^{2/5}$ for $x \\geq 0$?",
            "correct_text": "\\sqrt[5]{x^2}",
            "distractors": [
                "\\sqrt{x^5}",
                "5x^2",
                "2\\sqrt[5]{x}",
            ],
            "explanation": "In rational exponents a^(m/n), the denominator n is the root index and the numerator m is the power: x^(2/5) = cbrt5(x^2) = (cbrt5(x))^2.",
            "concept_slugs": ["alg-rational-exponents"],
        },
    ],
    "Polynomial Operations, Factoring, and Special Products": [
        {
            "question_text": "What is the complete factorization of the difference of squares $x^2 - 16$ over the real numbers?",
            "correct_text": "(x - 4)(x + 4)",
            "distractors": [
                "(x - 4)^2",
                "(x + 4)^2",
                "(x - 8)(x + 2)",
            ],
            "explanation": "The difference of squares formula states a^2 - b^2 = (a - b)(a + b). Here a = x and b = 4, yielding (x - 4)(x + 4).",
            "concept_slugs": ["alg-special-products"],
        },
        {
            "question_text": "Which algebraic identity gives the factored form of the sum of cubes $a^3 + b^3$?",
            "correct_text": "(a + b)(a^2 - ab + b^2)",
            "distractors": [
                "(a + b)(a^2 + ab + b^2)",
                "(a + b)^3",
                "(a - b)(a^2 + ab + b^2)",
            ],
            "explanation": "The sum of cubes factors as (a + b)(a^2 - ab + b^2), following the SOAP sign rule: Same sign (+), Opposite sign (-), Always Positive (+).",
            "concept_slugs": ["alg-special-products"],
        },
    ],
    "Rational Expressions and Domain Restrictions": [
        {
            "question_text": "What real value of $x$ must be excluded from the domain of the rational expression $\\frac{3x + 1}{2x - 8}$?",
            "correct_text": "x = 4",
            "distractors": [
                "x = -4",
                "x = -\\frac{1}{3}",
                "x = 0",
            ],
            "explanation": "Domain restrictions occur where the denominator is zero: 2x - 8 = 0 => 2x = 8 => x = 4. Division by zero is undefined.",
            "concept_slugs": ["alg-domain-restrictions"],
        },
        {
            "question_text": "Why is canceling $x$ in the expression $\\frac{x + 7}{x}$ algebraically invalid?",
            "correct_text": "Because x in the numerator is an added term, not a common factor multiplying the entire numerator",
            "distractors": [
                "Because variables can never appear in denominators of rational expressions",
                "Because rational expressions can only be simplified if x is a negative integer",
                "Because canceling is only permitted when the numerator degree is strictly greater than 2",
            ],
            "explanation": "Cancellation is only valid for common factors that multiply the entire numerator and denominator. In x + 7, x is an added term.",
            "concept_slugs": ["alg-rational-operations"],
        },
    ],
    "Absolute Value Operations and Real Line Distance": [
        {
            "question_text": "What is the geometric distance between the coordinates $-5$ and $3$ on the real number line?",
            "correct_text": "8",
            "distractors": [
                "-2",
                "2",
                "-8",
            ],
            "explanation": "The distance between two numbers a and b on the real line is given by d = |a - b|. Here d = |-5 - 3| = |-8| = 8.",
            "concept_slugs": ["alg-distance-real-line"],
        },
        {
            "question_text": "If $x$ is a strictly negative real number ($x < 0$), what does the absolute value $|x|$ simplify to algebraically?",
            "correct_text": "-x",
            "distractors": [
                "x",
                "0",
                "1",
            ],
            "explanation": "By the piecewise definition of absolute value, |x| = -x when x < 0. Since x is negative, -x is positive.",
            "concept_slugs": ["alg-absolute-value-definition"],
        },
    ],
    "Logarithmic Expressions and Properties": [
        {
            "question_text": "What is the exact numerical value of the logarithm $\\log_4(64)$?",
            "correct_text": "3",
            "distractors": [
                "16",
                "4",
                "12",
            ],
            "explanation": "By definition, y = log_4(64) <=> 4^y = 64. Since 4^3 = 64, the value of log_4(64) is 3.",
            "concept_slugs": ["alg-log-definition"],
        },
        {
            "question_text": "According to the power property of logarithms, which expression is equivalent to $\\log_b(x^5)$ for $x > 0$?",
            "correct_text": "5\\log_b(x)",
            "distractors": [
                "(\\log_b x)^5",
                "\\log_b(5x)",
                "\\log_b(x) + 5",
            ],
            "explanation": "The power property of logarithms states that log_b(M^p) = p * log_b(M). Bringing the exponent to the front gives 5 log_b(x).",
            "concept_slugs": ["alg-log-properties"],
        },
    ],

    # Domain 2.0: Equations and Inequalities
    "Linear Equations, Applications, and Inequalities": [
        {
            "question_text": "Solve the linear equation $4x - 7 = 13$ for $x$.",
            "correct_text": "x = 5",
            "distractors": [
                "x = 1.5",
                "x = 20",
                "x = -5",
            ],
            "explanation": "Add 7 to both sides: 4x = 20. Divide both sides by 4: x = 5.",
            "concept_slugs": ["alg-linear-equations"],
        },
        {
            "question_text": "When solving the inequality $-3x \\leq 12$, what is the correct resulting inequality?",
            "correct_text": "x \\geq -4",
            "distractors": [
                "x \\leq -4",
                "x \\geq 4",
                "x \\leq 4",
            ],
            "explanation": "Dividing both sides of an inequality by a negative number reverses the inequality direction: -3x / (-3) >= 12 / (-3) => x >= -4.",
            "concept_slugs": ["alg-linear-inequalities"],
        },
    ],
    "Quadratic Equations and Discriminant Analysis": [
        {
            "question_text": "What does a discriminant value of $\\Delta = b^2 - 4ac = 0$ indicate about the solutions of a quadratic equation?",
            "correct_text": "The equation has exactly one repeated real rational solution",
            "distractors": [
                "The equation has two distinct irrational real solutions",
                "The equation has two complex conjugate non-real solutions",
                "The equation has no mathematical solutions whatsoever",
            ],
            "explanation": "When Delta = 0, the plus-or-minus radical term becomes 0, leaving x = -b / (2a) as a single repeated real rational root of multiplicity 2.",
            "concept_slugs": ["alg-discriminant-nature"],
        },
        {
            "question_text": "What are all real roots of the quadratic equation $x^2 - 9 = 0$?",
            "correct_text": "x = 3 and x = -3",
            "distractors": [
                "x = 3 only",
                "x = 9 and x = -9",
                "x = 0 and x = 9",
            ],
            "explanation": "Using the square root property: x^2 = 9 => x = ±sqrt(9) = ±3. Thus the roots are x = 3 and x = -3.",
            "concept_slugs": ["alg-quadratic-methods"],
        },
    ],
    "Radical, Rational, and Absolute Value Equations": [
        {
            "question_text": "Why must candidate solutions to radical equations always be checked in the original un-squared equation?",
            "correct_text": "Squaring both sides is not a one-to-one operation and can introduce extraneous solutions",
            "distractors": [
                "Radical roots can only be calculated with approximate decimal precision",
                "Quadratic factoring introduces false positive roots into every polynomial",
                "Radical expressions cannot be simplified over integer coefficients",
            ],
            "explanation": "Because (-k)^2 = k^2, squaring both sides can create roots that satisfy the squared equation but not the original radical equation (extraneous roots).",
            "concept_slugs": ["alg-radical-equations"],
        },
        {
            "question_text": "What is the solution set to the absolute value equation $|2x + 1| = -7$?",
            "correct_text": "No solution (empty set)",
            "distractors": [
                "x = -4 and x = 3",
                "x = -4 only",
                "x = 3 only",
            ],
            "explanation": "The absolute value of any real expression is non-negative (|u| >= 0). It can never equal -7, so the equation has no solution.",
            "concept_slugs": ["alg-abs-equations"],
        },
    ],
    "Systems of Linear and Non-Linear Equations": [
        {
            "question_text": "Graphically, what does an inconsistent linear system in two variables represent?",
            "correct_text": "Two distinct parallel lines that never intersect",
            "distractors": [
                "Two perpendicular lines that intersect at right angles",
                "Two coincident lines that share every point in common",
                "A line tangent to a circle at a single point",
            ],
            "explanation": "An inconsistent system has zero solutions. In two dimensions, this corresponds to two distinct parallel lines with equal slopes and different intercepts.",
            "concept_slugs": ["alg-system-classification"],
        },
        {
            "question_text": "In the linear system $x + y = 6$ and $x - y = 2$, what is the value of $x$?",
            "correct_text": "x = 4",
            "distractors": [
                "x = 2",
                "x = 3",
                "x = 5",
            ],
            "explanation": "Add the two equations together using elimination: (x + y) + (x - y) = 6 + 2 => 2x = 8 => x = 4.",
            "concept_slugs": ["alg-linear-systems"],
        },
    ],
    "Exponential and Logarithmic Equations and Models": [
        {
            "question_text": "Solve the exponential equation $2^{x + 1} = 16$ for $x$.",
            "correct_text": "x = 3",
            "distractors": [
                "x = 4",
                "x = 7",
                "x = 8",
            ],
            "explanation": "Express 16 as a power of 2: 2^(x + 1) = 2^4. By the one-to-one property of exponents, x + 1 = 4 => x = 3.",
            "concept_slugs": ["alg-exponential-equations"],
        },
        {
            "question_text": "What is the standard continuous compound interest formula for accumulated amount $A$?",
            "correct_text": "A = P e^{rt}",
            "distractors": [
                "A = P(1 + r)^t",
                "A = P r t",
                "A = P \\ln(rt)",
            ],
            "explanation": "Continuous compound interest is modeled by A = P e^(rt), where P is principal, r is the annual interest rate, and t is time in years.",
            "concept_slugs": ["alg-growth-decay-models"],
        },
    ],

    # Domain 3.0: Functions and Their Properties
    "Functions, Domain, Range, and Evaluation": [
        {
            "question_text": "Which geometric test verifies whether a curve in the coordinate plane represents a function $y = f(x)$?",
            "correct_text": "Vertical Line Test",
            "distractors": [
                "Horizontal Line Test",
                "Diagonal Reflection Test",
                "Parallel Axis Test",
            ],
            "explanation": "The Vertical Line Test states that if every vertical line crosses the graph at most once, each input x has exactly one output y, defining a function.",
            "concept_slugs": ["alg-function-definition"],
        },
        {
            "question_text": "What is the domain of the function $f(x) = \\sqrt{x - 9}$ in interval notation?",
            "correct_text": "[9, \\infty)",
            "distractors": [
                "(9, \\infty)",
                "(-\\infty, 9]",
                "(-\\infty, \\infty)",
            ],
            "explanation": "The radicand of a square root must be non-negative: x - 9 >= 0 => x >= 9. In interval notation, this is [9, infinity).",
            "concept_slugs": ["alg-domain-algebraic"],
        },
    ],
    "Operations and Composition of Functions": [
        {
            "question_text": "If $f(x) = x + 3$ and $g(x) = x^2$, what is the value of the composite function $(f \\circ g)(2)$?",
            "correct_text": "7",
            "distractors": [
                "25",
                "10",
                "13",
            ],
            "explanation": "Evaluate the inner function first: g(2) = 2^2 = 4. Now evaluate the outer function: f(g(2)) = f(4) = 4 + 3 = 7.",
            "concept_slugs": ["alg-function-composition"],
        },
        {
            "question_text": "Is function composition $(f \\circ g)(x)$ commutative in general?",
            "correct_text": "No, (f o g)(x) does not generally equal (g o f)(x)",
            "distractors": [
                "Yes, composition is commutative for all pairs of functions",
                "Yes, but only when both functions have identical domain restrictions",
                "No, but only when functions contain rational exponents",
            ],
            "explanation": "Function composition is not commutative; the order of application matters. In general, f(g(x)) != g(f(x)).",
            "concept_slugs": ["alg-function-composition"],
        },
    ],
    "Graphical Behavior, Intercepts, and Symmetry": [
        {
            "question_text": "What algebraic condition defines an even function $f(x)$ for all $x$ in its domain?",
            "correct_text": "f(-x) = f(x)",
            "distractors": [
                "f(-x) = -f(x)",
                "f(x) = -f(x)",
                "f(1/x) = f(x)",
            ],
            "explanation": "An even function satisfies f(-x) = f(x) for all x in its domain, which geometrically gives reflectional symmetry across the y-axis.",
            "concept_slugs": ["alg-function-symmetry"],
        },
        {
            "question_text": "If an odd function $f(x)$ contains the point $(4, -7)$ on its graph, what other point must also lie on the graph?",
            "correct_text": "(-4, 7)",
            "distractors": [
                "(-4, -7)",
                "(4, 7)",
                "(7, -4)",
            ],
            "explanation": "For an odd function, f(-x) = -f(x). If f(4) = -7, then f(-4) = -f(4) = -(-7) = 7, giving the point (-4, 7).",
            "concept_slugs": ["alg-function-symmetry"],
        },
    ],
    "Transformations of Parent Functions": [
        {
            "question_text": "What geometric shift does the transformation $g(x) = f(x - 5)$ represent relative to $f(x)$?",
            "correct_text": "Horizontal shift to the right by 5 units",
            "distractors": [
                "Horizontal shift to the left by 5 units",
                "Vertical shift up by 5 units",
                "Vertical shift down by 5 units",
            ],
            "explanation": "Replacing x with (x - h) where h = 5 shifts the graph horizontally to the right by 5 units.",
            "concept_slugs": ["alg-shifts"],
        },
        {
            "question_text": "How does the graph of $y = -f(x)$ compare geometrically to the graph of $y = f(x)$?",
            "correct_text": "It is reflected across the x-axis",
            "distractors": [
                "It is reflected across the y-axis",
                "It is reflected across the diagonal line y = x",
                "It is shifted downward by 1 unit",
            ],
            "explanation": "Negating the outside of a function negates all y-coordinates, which geometrically reflects the graph across the horizontal x-axis.",
            "concept_slugs": ["alg-reflections"],
        },
    ],
    "Inverse Functions and One-to-One Criteria": [
        {
            "question_text": "Which geometric test verifies whether a function has an inverse that is also a function?",
            "correct_text": "Horizontal Line Test",
            "distractors": [
                "Vertical Line Test",
                "First Derivative Test",
                "Symmetry Axis Test",
            ],
            "explanation": "The Horizontal Line Test verifies whether a function is one-to-one. If no horizontal line crosses the graph more than once, its inverse is a valid function.",
            "concept_slugs": ["alg-one-to-one-functions"],
        },
        {
            "question_text": "If $f(2) = 9$ for a one-to-one function $f$, what is the value of $f^{-1}(9)$?",
            "correct_text": "2",
            "distractors": [
                "\\frac{1}{9}",
                "\\frac{1}{2}",
                "-9",
            ],
            "explanation": "By definition of an inverse function, if f(a) = b, then f^(-1)(b) = a. Since f(2) = 9, f^(-1)(9) = 2.",
            "concept_slugs": ["alg-inverse-algebraic"],
        },
    ],
    "Rational Functions and Asymptotic Behavior": [
        {
            "question_text": "What is the horizontal asymptote of the rational function $f(x) = \\frac{4x - 1}{2x + 5}$?",
            "correct_text": "y = 2",
            "distractors": [
                "y = 0",
                "y = -\\frac{5}{2}",
                "y = 4",
            ],
            "explanation": "Because the numerator and denominator have the same degree (degree 1), the horizontal asymptote is the ratio of their leading coefficients: y = 4/2 = 2.",
            "concept_slugs": ["alg-horizontal-asymptotes"],
        },
        {
            "question_text": "What is the horizontal asymptote of the rational function $f(x) = \\frac{7x + 2}{x^2 - 9}$?",
            "correct_text": "y = 0",
            "distractors": [
                "y = 7",
                "y = 3",
                "No horizontal asymptote",
            ],
            "explanation": "Because the degree of the numerator (1) is strictly less than the degree of the denominator (2), the horizontal asymptote is y = 0 (the x-axis).",
            "concept_slugs": ["alg-horizontal-asymptotes"],
        },
    ],

    # Domain 4.0: Number Systems and Operations
    "Real Number System and Fundamental Properties": [
        {
            "question_text": "To which subsets of the real number system does the integer $-4$ belong?",
            "correct_text": "Integers, rational numbers, and real numbers",
            "distractors": [
                "Natural numbers and whole numbers only",
                "Irrational numbers and real numbers only",
                "Whole numbers and integers only",
            ],
            "explanation": "-4 is an integer (Z), a rational number (-4/1 in Q), and a real number (R). It is not a natural or whole number because it is negative.",
            "concept_slugs": ["alg-real-number-subsets"],
        },
        {
            "question_text": "What is the additive inverse of $-8$ in the real number system?",
            "correct_text": "8",
            "distractors": [
                "-\\frac{1}{8}",
                "\\frac{1}{8}",
                "0",
            ],
            "explanation": "The additive inverse of a real number a is -a such that a + (-a) = 0. The additive inverse of -8 is -(-8) = 8.",
            "concept_slugs": ["alg-field-properties"],
        },
    ],
    "Complex Numbers and Imaginary Arithmetic": [
        {
            "question_text": "What is the value of $i^2$ by definition of the imaginary unit $i$?",
            "correct_text": "-1",
            "distractors": [
                "1",
                "-i",
                "i",
            ],
            "explanation": "By definition, the imaginary unit i satisfies i = sqrt(-1) and i^2 = -1.",
            "concept_slugs": ["alg-imaginary-unit"],
        },
        {
            "question_text": "What is the complex conjugate of the number $7 - 3i$?",
            "correct_text": "7 + 3i",
            "distractors": [
                "-7 + 3i",
                "-7 - 3i",
                "3 - 7i",
            ],
            "explanation": "The complex conjugate of a + bi is a - bi. For 7 - 3i = 7 + (-3)i, the conjugate is 7 - (-3)i = 7 + 3i.",
            "concept_slugs": ["alg-complex-conjugates"],
        },
    ],
    "Arithmetic and Geometric Sequences and Series": [
        {
            "question_text": "In an arithmetic sequence with initial term $a_1 = 5$ and common difference $d = 3$, what is the 4th term $a_4$?",
            "correct_text": "14",
            "distractors": [
                "17",
                "12",
                "15",
            ],
            "explanation": "Using a_n = a_1 + (n - 1)d: a_4 = 5 + (4 - 1)(3) = 5 + 3(3) = 5 + 9 = 14.",
            "concept_slugs": ["alg-arithmetic-sequences"],
        },
        {
            "question_text": "Under what condition does an infinite geometric series with common ratio $r$ converge to a finite sum?",
            "correct_text": "|r| < 1",
            "distractors": [
                "|r| > 1",
                "r > 0",
                "r = 1",
            ],
            "explanation": "An infinite geometric series converges if and only if |r| < 1 (-1 < r < 1). If |r| >= 1, the series diverges.",
            "concept_slugs": ["alg-infinite-geometric-series"],
        },
    ],
    "Combinatorics and the Binomial Theorem": [
        {
            "question_text": "What is the numerical value of $5!$ (five factorial)?",
            "correct_text": "120",
            "distractors": [
                "24",
                "60",
                "720",
            ],
            "explanation": "By definition, 5! = 5 * 4 * 3 * 2 * 1 = 120.",
            "concept_slugs": ["alg-factorials-permutations"],
        },
        {
            "question_text": "When selecting a 4-person committee from 10 volunteers, which counting method is appropriate and why?",
            "correct_text": "Combinations, because the order of selection within the committee does not matter",
            "distractors": [
                "Permutations, because committee members have distinct names",
                "Factorials only, because all 10 volunteers are assigned roles",
                "Powers of 10, because the pool size is 10 volunteers",
            ],
            "explanation": "A committee without designated ranks or offices is an un-ordered subset. Therefore, combinations C(10, 4) must be used.",
            "concept_slugs": ["alg-combinations"],
        },
    ],
}


def build_balanced_formative_questions() -> dict[str, list[dict]]:
    """Builds formative questions with perfectly balanced answer-key positions (0, 1, 2, 3)."""
    balanced: dict[str, list[dict]] = {}
    q_index = 0

    for title, raw_qs in RAW_FORMATIVE_QUESTIONS_BY_LESSON.items():
        lesson_qs = []
        for raw in raw_qs:
            target_pos = q_index % 4
            correct_text = raw["correct_text"]
            distractors = raw["distractors"]
            options = distractors[:target_pos] + [correct_text] + distractors[target_pos:]

            lesson_qs.append({
                "question_text": raw["question_text"],
                "options": options,
                "correct_answer": target_pos,
                "explanation": raw["explanation"],
                "concept_slugs": raw["concept_slugs"],
                "citation": "OpenStax College Algebra 1e, CC BY 4.0",
            })
            q_index += 1
        balanced[title] = lesson_qs

    return balanced


FORMATIVE_QUESTIONS_BY_LESSON = build_balanced_formative_questions()
