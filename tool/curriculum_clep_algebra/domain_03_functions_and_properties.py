"""Domain 3.0: Functions and Their Properties (Quota: 18 questions, 30% official blueprint).

Covers:
- Function definitions, evaluation, domain, and range
- Operations on functions and composition of functions
- Graphical representations, intercepts, symmetry (even/odd), and extrema
- Transformations of functions (shifts, reflections, stretches, compressions)
- Inverse functions and one-to-one criteria (horizontal line test)
- Rational functions, vertical/horizontal/slant asymptotes, and end behavior
Authoritative Source: OpenStax College Algebra 1e (CC BY 4.0).
"""
from __future__ import annotations

DOMAIN_03 = {
    "code": "3.0",
    "title": "Functions and their properties",
    "description": "Definition, evaluation, domain, range, operations, composition, graphs, transformations, inverses, and asymptotes of functions.",
    "weight": 0.300,
    "sort_order": 3,
    "importance": "core",
    "citation": "College Board CLEP College Algebra Domain 3.0 (30%); OpenStax College Algebra 1e Chapters 3, 4, & 5",
    "objectives": [
        {
            "code": "3.1",
            "title": "Evaluate functions and determine their algebraic domain and range in interval notation",
            "description": "Distinguish functions using the vertical line test, evaluate functions for algebraic arguments, and identify domain restrictions from formulas.",
            "sort_order": 1,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 3.1: Functions and Function Notation; Section 3.2: Domain and Range",
            "concepts": [
                {
                    "slug": "alg-function-definition",
                    "name": "Definition of a Function",
                    "short_definition": "A relation pairing each input x in the domain with exactly one output y in the range.",
                    "description": "Verified graphically using the Vertical Line Test: no vertical line may intersect the graph in more than one point.",
                    "citation": "OpenStax College Algebra 1e, Section 3.1",
                },
                {
                    "slug": "alg-domain-algebraic",
                    "name": "Algebraic Determination of Domain",
                    "short_definition": "Finding all real numbers for which a function's formula is mathematically defined.",
                    "description": "Rules: Denominators cannot equal zero; radicands of even roots must be non-negative (>= 0); arguments of logarithms must be strictly positive (> 0).",
                    "citation": "OpenStax College Algebra 1e, Section 3.2",
                    "prerequisites": ["alg-function-definition"],
                },
                {
                    "slug": "alg-range-intervals",
                    "name": "Determination of Range",
                    "short_definition": "The set of all possible resulting output values y produced by a function across its domain.",
                    "description": "Determined by examining graph behavior, vertices of parabolas, or inverse function domains.",
                    "citation": "OpenStax College Algebra 1e, Section 3.2",
                    "prerequisites": ["alg-domain-algebraic"],
                },
            ],
            "lessons": [
                {
                    "title": "Functions, Domain, Range, and Evaluation",
                    "description": "Core definition of a function, evaluation of expressions, vertical line test, and algebraic domain determination.",
                    "emoji": "📊",
                    "tags": ["functions", "domain", "range"],
                    "concept_slugs": [
                        "alg-function-definition",
                        "alg-domain-algebraic",
                        "alg-range-intervals",
                    ],
                    "citation": "OpenStax College Algebra 1e, Sections 3.1 & 3.2",
                    "terms": [
                        {"term": "Function", "definition": "A rule that assigns to each element x in a set (domain) exactly one element f(x) in a second set (range)."},
                        {"term": "Domain", "definition": "The set of all permissible input values for which a function produces a real output."},
                        {"term": "Range", "definition": "The set of all actual output values produced by a function."},
                        {"term": "Vertical Line Test", "definition": "A visual test stating that a curve in the coordinate plane represents a function if and only if no vertical line intersects the curve more than once."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Mathematical Nature of Functions\n\n"
                                    "A **function** $f$ from a set $X$ to a set $Y$ is a relation that associates each element $x \\in X$ with **exactly one** element $y = f(x) \\in Y$. "
                                    "Graphically, this single-output rule is verified by the **Vertical Line Test**: if every vertical line $x = c$ intersects a graph at most once, the graph represents a function.\n\n"
                                    "### Determining Algebraic Domains\n\n"
                                    "When a function is defined by a formula with real coefficients, its **implied domain** consists of all real numbers for which the formula produces a real number. "
                                    "Three primary restrictions govern domain analysis:\n\n"
                                    "1. **Fractions**: Denominators cannot equal zero. For $f(x) = \\frac{P(x)}{Q(x)}$, set $Q(x) \\neq 0$.\n"
                                    "2. **Even Roots**: Radicands of even roots must be non-negative. For $f(x) = \\sqrt[2k]{g(x)}$, set $g(x) \\geq 0$.\n"
                                    "3. **Logarithms**: Arguments of logarithmic functions must be strictly positive. For $f(x) = \\log_b(h(x))$, set $h(x) > 0$."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Even Roots vs. Odd Roots Domain Rule",
                                "body": "Radicands of **even roots** ($\\sqrt{x}, \\sqrt[4]{x}$) must be $\\geq 0$. However, **odd roots** ($\\sqrt[3]{x}, \\sqrt[5]{x}$) are defined for ALL real numbers, positive, zero, and negative. The domain of $\\sqrt[3]{x}$ is $(-\\infty, \\infty)$.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Domain and Range Restrictions by Parent Function\n\n"
                                    "| Parent Function | Mathematical Formula | Implied Domain | Implied Range |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| Linear | $f(x) = mx + b$ ($m \\neq 0$) | $(-\\infty, \\infty)$ | $(-\\infty, \\infty)$ |\n"
                                    "| Quadratic | $f(x) = x^2$ | $(-\\infty, \\infty)$ | $[0, \\infty)$ |\n"
                                    "| Absolute Value | $f(x) = |x|$ | $(-\\infty, \\infty)$ | $[0, \\infty)$ |\n"
                                    "| Square Root | $f(x) = \\sqrt{x}$ | $[0, \\infty)$ | $[0, \\infty)$ |\n"
                                    "| Cube Root | $f(x) = \\sqrt[3]{x}$ | $(-\\infty, \\infty)$ | $(-\\infty, \\infty)$ |\n"
                                    "| Reciprocal | $f(x) = 1/x$ | $(-\\infty, 0) \\cup (0, \\infty)$ | $(-\\infty, 0) \\cup (0, \\infty)$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Economic Demand and Feasible Domain\n\n"
                                    "A manufacturing firm models its monthly revenue $R(p)$ as a quadratic function of unit price $p$ (in dollars):\n\n"
                                    "$$R(p) = -5p^2 + 300p$$\n\n"
                                    "While the purely algebraic domain of a polynomial is all real numbers $(-\\infty, \\infty)$, real-world physical and financial constraints require both price $p \\geq 0$ and revenue $R(p) \\geq 0$. "
                                    "Factoring yields $R(p) = -5p(p - 60) \\geq 0$. "
                                    "The revenue is zero at $p = 0$ and $p = 60$, and strictly positive between them. "
                                    "Therefore, the **practical business domain** of the model is the closed interval $[0, 60]$ dollars."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Function Evaluation Errors",
                                "body": "1. **Evaluating $f(x + h)$**: In $f(x) = x^2 - 3$, evaluating $f(x + h)$ requires replacing every $x$ with $(x + h)$: $f(x + h) = (x + h)^2 - 3 = x^2 + 2xh + h^2 - 3$. It does NOT equal $f(x) + h = x^2 - 3 + h$.\n2. **Radical in denominator**: In $f(x) = \\frac{1}{\\sqrt{x - 4}}$, the condition is $x - 4 > 0$ (strict inequality), NOT $x - 4 \\geq 0$, because the denominator cannot be zero.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "id": "alg-sim-domain-sqrt-over-linear",
                            "prompt": "What is the domain of the function $f(x) = \\frac{\\sqrt{x - 2}}{x - 5}$ expressed in interval notation?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "[2, 5) \\cup (5, \\infty)",
                                    "[2, 5) \\cup [5, \\infty)",
                                    "(2, 5) \\cup (5, \\infty)",
                                    "[2, 5) \\cup (5, 10]",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Two conditions must be met: (1) The radicand under the square root must be non-negative: x - 2 >= 0 => x >= 2. (2) The denominator cannot equal zero: x - 5 != 0 => x != 5. Combining both conditions gives all real numbers greater than or equal to 2 except 5: [2, 5) U (5, infinity).",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 3.2",
                            "concept_slugs": ["alg-domain-algebraic"],
                        },
                        {
                            "id": "alg-sim-difference-quotient-quadratic",
                            "prompt": "Given the function $f(x) = 2x^2 - 3x + 1$, evaluate the difference quotient $\\frac{f(x + h) - f(x)}{h}$ for $h \\neq 0$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "4x - 3 + h",
                                    "4x - 3 + 2h",
                                    "4x + 2h",
                                    "2h - 3",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Compute f(x + h) = 2(x + h)^2 - 3(x + h) + 1 = 2(x^2 + 2xh + h^2) - 3x - 3h + 1 = 2x^2 + 4xh + 2h^2 - 3x - 3h + 1. Subtract f(x): f(x + h) - f(x) = [2x^2 + 4xh + 2h^2 - 3x - 3h + 1] - [2x^2 - 3x + 1] = 4xh + 2h^2 - 3h. Divide by h: (4xh + 2h^2 - 3h) / h = 4x - 3 + 2h.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 3.1",
                            "concept_slugs": ["alg-function-definition"],
                        },
                        {
                            "id": "alg-sim-range-of-downward-parabola",
                            "prompt": "What is the range of the quadratic function $f(x) = -(x - 3)^2 + 7$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "[7, \\infty)",
                                    "[3, \\infty)",
                                    "(-\\infty, 7]",
                                    "(-\\infty, 3]",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "The function is in vertex form a(x - h)^2 + k with vertex (3, 7) and a = -1 < 0. Because a is negative, the parabola opens downward, meaning the vertex represents the absolute maximum output value of 7. Thus, the range consists of all real numbers less than or equal to 7: (-infinity, 7].",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 3.2",
                            "concept_slugs": ["alg-range-intervals"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What does the Vertical Line Test determine about a relation's graph?",
                    "back": "Whether the graph represents a function (no vertical line may cross the curve more than once).",
                    "concept_slugs": ["alg-function-definition"],
                },
                {
                    "front": "What are the two most common algebraic causes of domain restrictions?",
                    "back": "Division by zero (denominators = 0) and taking even roots of negative numbers (radicand < 0).",
                    "concept_slugs": ["alg-domain-algebraic"],
                },
                {
                    "front": "What is the domain of f(x) = cbrt(x - 5)?",
                    "back": "All real numbers (-infinity, infinity), because cube roots (and all odd roots) can take negative radicands.",
                    "concept_slugs": ["alg-domain-algebraic"],
                },
            ],
        },
        {
            "code": "3.2",
            "title": "Perform algebraic operations on functions and evaluate and compose composite functions",
            "description": "Compute sum, difference, product, and quotient of functions, evaluate composite functions (f o g)(x), and determine the domain of composite functions.",
            "sort_order": 2,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 3.4: Composition of Functions",
            "concepts": [
                {
                    "slug": "alg-function-arithmetic",
                    "name": "Function Arithmetic Operations",
                    "short_definition": "Rules defining (f + g)(x), (f - g)(x), (fg)(x), and (f/g)(x).",
                    "description": "Functions can be combined algebraically; the domain of the combined function is the intersection of their individual domains, with g(x) != 0 for quotients.",
                    "citation": "OpenStax College Algebra 1e, Section 3.4",
                },
                {
                    "slug": "alg-function-composition",
                    "name": "Composition of Functions",
                    "short_definition": "The operation (f o g)(x) = f(g(x)) applying function f to the output of function g.",
                    "description": "The inner function g is evaluated first, and its output becomes the input for the outer function f.",
                    "citation": "OpenStax College Algebra 1e, Section 3.4",
                    "prerequisites": ["alg-function-arithmetic"],
                },
                {
                    "slug": "alg-composition-domain",
                    "name": "Domain of Composite Functions",
                    "short_definition": "The set of all x in the domain of g such that g(x) is in the domain of f.",
                    "description": "Requires two conditions: x must be in Domain(g), and the resulting value g(x) must be in Domain(f).",
                    "citation": "OpenStax College Algebra 1e, Section 3.4",
                    "prerequisites": ["alg-function-composition"],
                },
            ],
            "lessons": [
                {
                    "title": "Operations and Composition of Functions",
                    "description": "Algebraic combination of functions (sum, difference, product, quotient) and evaluation and domain of composite functions.",
                    "emoji": "🔗",
                    "tags": ["composition", "composite-functions", "operations"],
                    "concept_slugs": [
                        "alg-function-arithmetic",
                        "alg-function-composition",
                        "alg-composition-domain",
                    ],
                    "citation": "OpenStax College Algebra 1e, Section 3.4",
                    "terms": [
                        {"term": "Composite Function", "definition": "A function (f o g)(x) defined by f(g(x)), where the output of function g serves as the input to function f."},
                        {"term": "Inner Function", "definition": "In f(g(x)), the function g that operates directly on input x first."},
                        {"term": "Outer Function", "definition": "In f(g(x)), the function f that operates on the output of g(x)."},
                        {"term": "Domain of Composition", "definition": "The set of all x such that x is in the domain of g AND g(x) is in the domain of f."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Function Operations and Composite Functions\n\n"
                                    "Given two functions $f$ and $g$, we can create new functions through standard algebraic operations:\n\n"
                                    "- **Sum**: $(f + g)(x) = f(x) + g(x)$\n"
                                    "- **Difference**: $(f - g)(x) = f(x) - g(x)$\n"
                                    "- **Product**: $(f \\cdot g)(x) = f(x) \\cdot g(x)$\n"
                                    "- **Quotient**: $\\left(\\frac{f}{g}\\right)(x) = \\frac{f(x)}{g(x)}$ ($g(x) \\neq 0$)\n\n"
                                    "### Composition of Functions\n\n"
                                    "The **composition** of function $f$ with function $g$, denoted $(f \\circ g)(x)$, is defined as:\n\n"
                                    "$$(f \\circ g)(x) = f(g(x))$$\n\n"
                                    "In this process, $x$ is first input into $g$ to yield $g(x)$, which is then input into $f$. "
                                    "Crucially, function composition is **not commutative**: in general, $(f \\circ g)(x) \\neq (g \\circ f)(x)$."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Two-Step Domain Rule for $(f \\circ g)(x)$",
                                "body": "To find the domain of $(f \\circ g)(x)$:\n1. Find the domain of the **inner function** $g(x)$.\n2. Find where the output $g(x)$ is permitted in the domain of the **outer function** $f(u)$.\n3. Take the intersection of both conditions.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Step-by-Step Evaluation of $(f \\circ g)(c)$\n\n"
                                    "| Step | Action | Example: $f(u) = 2u + 1$, $g(x) = x^2 - 3$, evaluate $(f \\circ g)(4)$ |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **1. Evaluate Inner** | Calculate $g(c)$ | $g(4) = 4^2 - 3 = 16 - 3 = 13$ |\n"
                                    "| **2. Substitute to Outer** | Calculate $f(g(c))$ | $f(13) = 2(13) + 1 = 26 + 1 = 27$ |\n"
                                    "| **3. Reverse Composition** | Calculate $(g \\circ f)(4)$ | $f(4) = 2(4)+1 = 9 \\implies g(9) = 9^2 - 3 = 78$ |\n"
                                    "| **Conclusion** | Verify Non-commutativity | $(f \\circ g)(4) = 27 \\neq 78 = (g \\circ f)(4)$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Multi-Stage Commercial Discounts and Taxes\n\n"
                                    "A computer retailer offers a promotional $\\$50$ instant coupon on a new laptop. "
                                    "In addition, an educational storewide discount reduces the price by $10\\%$. "
                                    "Let $x$ be the original laptop price. We define the two pricing functions:\n\n"
                                    "$$C(x) = x - 50\\quad\\text{and}\\quad D(x) = 0.90x$$\n\n"
                                    "If the store applies the $10\\%$ discount *first* and then applies the $\\$50$ coupon, the customer pays $(C \\circ D)(x) = C(D(x)) = 0.90x - 50$. "
                                    "If the coupon is applied *first* and then the discount, the customer pays $(D \\circ C)(x) = D(C(x)) = 0.90(x - 50) = 0.90x - 45$. "
                                    "Comparing the compositions shows that applying the coupon first costs the buyer $\\$5$ more because the $10\\%$ discount is applied to a smaller base."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Function Composition Pitfalls",
                                "body": "1. **Multiplying instead of composing**: $(f \\circ g)(x) \\neq f(x) \\cdot g(x)$. Composition feeds one function inside the other; multiplication multiplies their outputs.\n2. **Ignoring inner function domain**: If $f(x) = x^2$ and $g(x) = \\sqrt{x}$, the composition $f(g(x)) = (\\sqrt{x})^2 = x$. Although $x$ alone has domain $(-\\infty, \\infty)$, the domain of $f \\circ g$ remains $[0, \\infty)$ because the inner function requires $x \\geq 0$.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "id": "alg-sim-composition-evaluate-at-point",
                            "prompt": "If $f(x) = 2x^2 - 1$ and $g(x) = 3x - 4$, what is the value of $(f \\circ g)(2)$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "13",
                                    "17",
                                    "3",
                                    "7",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Evaluate the inner function first at x = 2: g(2) = 3(2) - 4 = 6 - 4 = 2. Now substitute this output into the outer function f: f(g(2)) = f(2) = 2(2)^2 - 1 = 2(4) - 1 = 8 - 1 = 7.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 3.4",
                            "concept_slugs": ["alg-function-composition"],
                        },
                        {
                            "id": "alg-sim-composition-formula-g-of-f",
                            "prompt": "Given $f(x) = x^2 + 1$ and $g(x) = \\frac{1}{x - 2}$, what is the algebraic formula for $(g \\circ f)(x)$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "\\frac{1}{x^2 - 1}",
                                    "\\frac{1}{x^2 + 1} - 2",
                                    "\\frac{x^2 + 1}{x - 2}",
                                    "\\frac{1}{(x - 2)^2 + 1}",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "By definition, (g o f)(x) = g(f(x)). Substitute f(x) into g: g(x^2 + 1) = 1 / [(x^2 + 1) - 2] = 1 / (x^2 - 1).",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 3.4",
                            "concept_slugs": ["alg-function-composition"],
                        },
                        {
                            "id": "alg-sim-composition-domain-sqrt-linear",
                            "prompt": "What is the domain of $(f \\circ g)(x)$ where $f(x) = \\sqrt{x}$ and $g(x) = 2x - 6$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "[0, \\infty)",
                                    "[3, \\infty)",
                                    "(-\\infty, 3]",
                                    "(3, \\infty)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "For (f o g)(x) = f(g(x)) = sqrt(2x - 6), two conditions must hold: (1) x is in the domain of g(x) = 2x - 6, which is all real numbers; (2) g(x) must be in the domain of f(u) = sqrt(u), which requires u >= 0 => 2x - 6 >= 0 => 2x >= 6 => x >= 3. In interval notation, this is [3, infinity).",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax College Algebra 1e, Section 3.4",
                            "concept_slugs": ["alg-composition-domain"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What does (f o g)(x) represent?",
                    "back": "f(g(x)): the function f evaluated at the output of function g.",
                    "concept_slugs": ["alg-function-composition"],
                },
                {
                    "front": "Is function composition commutative: does (f o g)(x) always equal (g o f)(x)?",
                    "back": "No, in general (f o g)(x) != (g o f)(x).",
                    "concept_slugs": ["alg-function-composition"],
                },
                {
                    "front": "How do you find the domain of (f o g)(x)?",
                    "back": "Find values of x in the domain of g such that g(x) lies within the domain of f.",
                    "concept_slugs": ["alg-composition-domain"],
                },
            ],
        },
        {
            "code": "3.3",
            "title": "Analyze function graphs, determine intercepts, test symmetry, and identify extrema",
            "description": "Find x- and y-intercepts algebraically, determine even/odd function symmetry, and identify local extrema and intervals of increase and decrease.",
            "sort_order": 3,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 3.3: Rates of Change and Behavior of Graphs",
            "concepts": [
                {
                    "slug": "alg-function-intercepts",
                    "name": "Intercepts of Functions",
                    "short_definition": "Algebraic determination of y-intercept f(0) and x-intercepts f(x) = 0.",
                    "description": "The y-intercept is where graph crosses the y-axis (at most one for functions); x-intercepts are real zeros of the function.",
                    "citation": "OpenStax College Algebra 1e, Section 3.3",
                },
                {
                    "slug": "alg-function-symmetry",
                    "name": "Even and Odd Function Symmetry",
                    "short_definition": "Even functions f(-x) = f(x) have y-axis symmetry; odd functions f(-x) = -f(x) have origin symmetry.",
                    "description": "Tested algebraically by replacing x with -x and simplifying. Most functions are neither even nor odd.",
                    "citation": "OpenStax College Algebra 1e, Section 3.3",
                    "prerequisites": ["alg-function-intercepts"],
                },
                {
                    "slug": "alg-extrema-intervals",
                    "name": "Extrema and Increasing/Decreasing Intervals",
                    "short_definition": "Identifying local maxima, local minima, and intervals where f(x) rises or falls.",
                    "description": "A function is increasing on an interval if f(a) < f(b) whenever a < b, and decreasing if f(a) > f(b).",
                    "citation": "OpenStax College Algebra 1e, Section 3.3",
                    "prerequisites": ["alg-function-intercepts"],
                },
            ],
            "lessons": [
                {
                    "title": "Graphical Behavior, Intercepts, and Symmetry",
                    "description": "Determination of intercepts, even/odd symmetry analysis, local extrema, and intervals of increase and decrease.",
                    "emoji": "📉",
                    "tags": ["symmetry", "intercepts", "even-odd", "extrema"],
                    "concept_slugs": [
                        "alg-function-intercepts",
                        "alg-function-symmetry",
                        "alg-extrema-intervals",
                    ],
                    "citation": "OpenStax College Algebra 1e, Section 3.3",
                    "terms": [
                        {"term": "x-intercept (Zero)", "definition": "A real number c such that f(c) = 0, where the graph crosses or touches the x-axis."},
                        {"term": "y-intercept", "definition": "The point (0, f(0)) where the graph crosses the vertical y-axis."},
                        {"term": "Even Function", "definition": "A function satisfying f(-x) = f(x) for all x in its domain, exhibiting symmetry across the y-axis."},
                        {"term": "Odd Function", "definition": "A function satisfying f(-x) = -f(x) for all x in its domain, exhibiting 180-degree rotational symmetry about the origin."},
                        {"term": "Local Maximum", "definition": "A point (c, f(c)) where f(c) >= f(x) for all x in an open neighborhood around c."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Intercepts of Functions\n\n"
                                    "The points where a function's graph intersects the coordinate axes are foundational features:\n\n"
                                    "- **$y$-intercept**: Set $x = 0$ and evaluate $f(0)$. A function can have **at most one** $y$-intercept (by the Vertical Line Test).\n"
                                    "- **$x$-intercepts (Zeros)**: Set $f(x) = 0$ and solve for all real values of $x$. A function may have zero, one, or multiple $x$-intercepts.\n\n"
                                    "### Symmetry of Functions: Even vs. Odd\n\n"
                                    "To test whether a function is even, odd, or neither, evaluate $f(-x)$ algebraically:\n\n"
                                    "1. **Even Function**: $f(-x) = f(x)$ for all $x$. The graph has **reflectional symmetry across the $y$-axis** (e.g. $f(x) = x^2, \\cos(x), |x|$).\n"
                                    "2. **Odd Function**: $f(-x) = -f(x)$ for all $x$. The graph has **rotational symmetry of $180^\\circ$ about the origin** (e.g. $f(x) = x^3, \\sin(x), 1/x$).\n"
                                    "3. **Neither**: If $f(-x) \\neq f(x)$ and $f(-x) \\neq -f(x)$, the function has neither symmetry."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Testing Even vs. Odd Algebraically",
                                "body": "Always replace every $x$ with $(-x)$ and simplify carefully with parentheses:\n• If the expression returns to original $f(x) \\implies$ **Even**.\n• If every single sign is negated to $-f(x) \\implies$ **Odd**.\n• If some signs change and others do not $\\implies$ **Neither**.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Symmetry Comparison Table\n\n"
                                    "| Classification | Algebraic Identity | Geometric Symmetry | Canonical Example |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Even** | $f(-x) = f(x)$ | Symmetric across $y$-axis | $f(x) = x^4 - 2x^2 + 5$ |\n"
                                    "| **Odd** | $f(-x) = -f(x)$ | Symmetric about origin $(0, 0)$ | $f(x) = x^5 - 4x$ |\n"
                                    "| **Neither** | $f(-x) \\neq \\pm f(x)$ | Asymmetric / general | $f(x) = x^2 + 3x - 4$ |\n"
                                    "| **Increasing** | $x_1 < x_2 \\implies f(x_1) < f(x_2)$ | Graph rises from left to right | Linear with $m > 0$ |\n"
                                    "| **Decreasing** | $x_1 < x_2 \\implies f(x_1) > f(x_2)$ | Graph falls from left to right | Linear with $m < 0$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Optimization and Parabolic Vertex\n\n"
                                    "A civil engineering contractor analyzes the structural load capacity of an arched pedestrian bridge. "
                                    "The vertical clearance $y$ in meters above ground as a function of horizontal distance $x$ across the 20-meter span is modeled by:\n\n"
                                    "$$y(x) = -0.05x^2 + x$$\n\n"
                                    "The $x$-intercepts represent the bridge foundation anchor points at ground level: $-0.05x(x - 20) = 0 \\implies x = 0$ and $x = 20$ meters. "
                                    "By parabolic symmetry, the maximum clearance occurs exactly halfway between the intercepts at $x = 10$ meters. "
                                    "Evaluating $y(10) = -0.05(10)^2 + 10 = -5 + 10 = 5$ meters gives the bridge's maximum clearance."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Symmetry Misconceptions",
                                "body": "1. **Even/Odd is not like integer numbers**: An integer is either even or odd. Functions are usually NEITHER even nor odd!\n2. **Origin vs x-axis symmetry**: A function can NEVER have symmetry across the $x$-axis (except the zero function $y = 0$), because any non-zero point $(x, y)$ reflected to $(x, -y)$ would violate the Vertical Line Test.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "id": "alg-sim-even-odd-quartic-polynomial",
                            "prompt": "Determine whether the function $f(x) = 3x^4 - 2x^2 + 5$ is even, odd, or neither.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Odd function",
                                    "Neither even nor odd",
                                    "Even function",
                                    "Both even and odd",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Substitute (-x) for x: f(-x) = 3(-x)^4 - 2(-x)^2 + 5. Since (-x)^4 = x^4 and (-x)^2 = x^2, this simplifies to 3x^4 - 2x^2 + 5 = f(x). Because f(-x) = f(x) for all x, the function is even (and symmetric across the y-axis).",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 3.3",
                            "concept_slugs": ["alg-function-symmetry"],
                        },
                        {
                            "id": "alg-sim-quadratic-intercepts",
                            "prompt": "What are all $x$-intercepts and the $y$-intercept of the quadratic function $f(x) = x^2 - 6x + 8$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "x-intercepts at (-2, 0) and (-4, 0); y-intercept at (0, 8)",
                                    "x-intercepts at (2, 0) and (4, 0); y-intercept at (0, -8)",
                                    "x-intercepts at (1, 0) and (8, 0); y-intercept at (0, 8)",
                                    "x-intercepts at (2, 0) and (4, 0); y-intercept at (0, 8)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "For x-intercepts, set f(x) = 0: x^2 - 6x + 8 = 0 => (x - 2)(x - 4) = 0 => x = 2 and x = 4, yielding points (2, 0) and (4, 0). For the y-intercept, set x = 0: f(0) = 0^2 - 6(0) + 8 = 8, yielding point (0, 8).",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 3.3",
                            "concept_slugs": ["alg-function-intercepts"],
                        },
                        {
                            "id": "alg-sim-even-odd-cubic-polynomial",
                            "prompt": "Determine whether the function $g(x) = 2x^3 - 5x$ is even, odd, or neither.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Odd function",
                                    "Even function",
                                    "Neither even nor odd",
                                    "Linear function",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Compute g(-x) = 2(-x)^3 - 5(-x) = 2(-x^3) + 5x = -2x^3 + 5x = -(2x^3 - 5x) = -g(x). Because g(-x) = -g(x) for all x, the function is odd (symmetric about the origin).",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 3.3",
                            "concept_slugs": ["alg-function-symmetry"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What algebraic condition defines an even function, and what is its graph symmetry?",
                    "back": "f(-x) = f(x); the graph is symmetric across the y-axis.",
                    "concept_slugs": ["alg-function-symmetry"],
                },
                {
                    "front": "What algebraic condition defines an odd function, and what is its graph symmetry?",
                    "back": "f(-x) = -f(x); the graph has 180-degree rotational symmetry about the origin.",
                    "concept_slugs": ["alg-function-symmetry"],
                },
                {
                    "front": "How do you find the x-intercepts of a function y = f(x)?",
                    "back": "Set f(x) = 0 and solve for the real values of x.",
                    "concept_slugs": ["alg-function-intercepts"],
                },
            ],
        },
        {
            "code": "3.4",
            "title": "Apply vertical and horizontal shifts, reflections, and scaling transformations",
            "description": "Transform parent functions using g(x) = a f(b(x - h)) + k, identifying vertical/horizontal shifts, reflections across axes, and stretches/compressions.",
            "sort_order": 4,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 3.5: Transformation of Functions",
            "concepts": [
                {
                    "slug": "alg-shifts",
                    "name": "Vertical and Horizontal Shifts",
                    "short_definition": "Translations f(x) + k shifting vertically and f(x - h) shifting horizontally.",
                    "description": "Adding k shifts up (k>0) or down (k<0); subtracting h inside the function shifts right (h>0) or left (h<0).",
                    "citation": "OpenStax College Algebra 1e, Section 3.5",
                },
                {
                    "slug": "alg-reflections",
                    "name": "Reflections Across Axes",
                    "short_definition": "-f(x) reflects across the x-axis; f(-x) reflects across the y-axis.",
                    "description": "Negating the outside negates y-coordinates; negating the inside negates x-coordinates.",
                    "citation": "OpenStax College Algebra 1e, Section 3.5",
                    "prerequisites": ["alg-shifts"],
                },
                {
                    "slug": "alg-stretches-compressions",
                    "name": "Vertical and Horizontal Stretches and Compressions",
                    "short_definition": "Scaling transformations a f(x) and f(b x).",
                    "description": "|a| > 1 stretches vertically; 0 < |a| < 1 compresses vertically. |b| > 1 compresses horizontally; 0 < |b| < 1 stretches horizontally.",
                    "citation": "OpenStax College Algebra 1e, Section 3.5",
                    "prerequisites": ["alg-reflections"],
                },
            ],
            "lessons": [
                {
                    "title": "Transformations of Parent Functions",
                    "description": "Rigorous rules for transforming parent functions: vertical and horizontal translations, reflections, and non-rigid scalings.",
                    "emoji": "🔀",
                    "tags": ["transformations", "shifts", "reflections", "stretches"],
                    "concept_slugs": [
                        "alg-shifts",
                        "alg-reflections",
                        "alg-stretches-compressions",
                    ],
                    "citation": "OpenStax College Algebra 1e, Section 3.5",
                    "terms": [
                        {"term": "Parent Function", "definition": "The simplest function in a family of functions that preserves the shape of the family (e.g. y = x^2, y = |x|)."},
                        {"term": "Rigid Transformation", "definition": "A transformation that changes only the position of the graph without changing its size or shape (translations and reflections)."},
                        {"term": "Non-Rigid Transformation", "definition": "A transformation that distorts the shape of the graph by stretching or compressing it vertically or horizontally."},
                        {"term": "Horizontal Shift", "definition": "Replacing x with (x - h) in f(x), which shifts the graph right by h units if h > 0, and left if h < 0."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Anatomy of Function Transformations\n\n"
                                    "Starting from a basic parent function $y = f(x)$, any transformed function can be expressed in general form as:\n\n"
                                    "$$g(x) = a \\cdot f(b(x - h)) + k$$\n\n"
                                    "Each parameter controls a specific geometric alteration of the graph:\n\n"
                                    "- **$k$ (Vertical Shift)**: Shifts the graph up if $k > 0$ and down if $k < 0$.\n"
                                    "- **$h$ (Horizontal Shift)**: Shifts the graph right if $h > 0$ (i.e. $x - h$) and left if $h < 0$ (i.e. $x + |h|$).\n"
                                    "- **$a$ (Vertical Scaling / Reflection)**: If $a < 0$, reflects the graph across the **$x$-axis**. Stretches vertically if $|a| > 1$; compresses vertically if $0 < |a| < 1$.\n"
                                    "- **$b$ (Horizontal Scaling / Reflection)**: If $b < 0$, reflects the graph across the **$y$-axis**. Compresses horizontally by factor $\\frac{1}{|b|}$ if $|b| > 1$; stretches horizontally if $0 < |b| < 1$."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "The Horizontal Shift Sign Counter-Intuition",
                                "body": "Transformations applied **inside** the function with $x$ act counter-intuitively:\n• $f(x - 3)$ shifts **RIGHT** 3 units.\n• $f(x + 3)$ shifts **LEFT** 3 units.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Coordinate Transformation Mapping Rule\n\n"
                                    "| Transformation | Algebraic Expression | Coordinate Mapping $(x, y) \\mapsto$ |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| Vertical shift up $k$ | $f(x) + k$ | $(x, y + k)$ |\n"
                                    "| Horizontal shift right $h$ | $f(x - h)$ | $(x + h, y)$ |\n"
                                    "| Reflection across $x$-axis | $-f(x)$ | $(x, -y)$ |\n"
                                    "| Reflection across $y$-axis | $f(-x)$ | $(-x, y)$ |\n"
                                    "| Vertical stretch by factor $a$ | $a f(x)$ ($a > 1$) | $(x, a y)$ |\n"
                                    "| Horizontal compression by $b$ | $f(bx)$ ($b > 1$) | $(x/b, y)$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Sound Wave Amplitude and Phase Shift Modeling\n\n"
                                    "In audio signal processing, an acoustic sound wave pulse modeled by a parent envelope function $f(t)$ is passed through an audio amplifier and delay filter. "
                                    "The amplifier doubles the output signal intensity, inverts the signal phase (reflection across the time axis), delays the pulse by $4$ milliseconds, and raises the baseline voltage by $1.5$ volts. "
                                    "Using our transformation parameters, we construct the resulting output wave function $V(t)$:\n\n"
                                    "$$V(t) = -2 \\cdot f(t - 4) + 1.5$$\n\n"
                                    "Here $a = -2$ (vertical stretch by 2 and reflection across $t$-axis), $h = 4$ (horizontal shift right by 4 ms delay), and $k = 1.5$ (vertical shift up by 1.5 V)."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Transformation Pitfalls",
                                "body": "1. **Order of transformations**: When multiple transformations occur, follow the standard order: (1) horizontal shift, (2) horizontal scaling/reflection, (3) vertical scaling/reflection, (4) vertical shift.\n2. **Factoring the inside**: In $f(2x - 6)$, the horizontal shift is NOT 6! You must factor out 2: $f(2(x - 3))$, which reveals a horizontal compression by 2 and a shift right by 3 units.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "id": "alg-sim-parent-quadratic-transformation-sequence",
                            "prompt": "Which sequence of geometric transformations transforms the graph of the parent function $f(x) = x^2$ into the graph of $g(x) = -(x + 4)^2 - 5$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Shift right 4 units, reflect across the x-axis, shift up 5 units",
                                    "Shift left 4 units, reflect across the x-axis, shift down 5 units",
                                    "Shift left 4 units, reflect across the y-axis, shift down 5 units",
                                    "Shift right 4 units, reflect across the y-axis, shift down 5 units",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Examining g(x) = -(x + 4)^2 - 5: (1) Replacing x with (x + 4) shifts the graph left 4 units. (2) The negative sign in front of the square reflects the graph across the x-axis. (3) Subtracting 5 shifts the graph down 5 units.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 3.5",
                            "concept_slugs": ["alg-shifts", "alg-reflections"],
                        },
                        {
                            "id": "alg-sim-point-under-combined-transformation",
                            "prompt": "If the point $(3, 8)$ lies on the graph of $y = f(x)$, what point must lie on the graph of $y = 2f(x - 1) + 3$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "(2, 19)",
                                    "(4, 11)",
                                    "(4, 19)",
                                    "(2, 13)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Using coordinate mapping: The replacement (x - 1) shifts x coordinates to the right by 1, so the new x is 3 + 1 = 4. The vertical operations multiply y by 2 and add 3, so the new y is 2(8) + 3 = 16 + 3 = 19. The resulting point is (4, 19).",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 3.5",
                            "concept_slugs": ["alg-shifts", "alg-stretches-compressions"],
                        },
                        {
                            "id": "alg-sim-reflect-and-shift-square-root",
                            "prompt": "Write the equation of the function $g(x)$ resulting from reflecting the parent square root function $f(x) = \\sqrt{x}$ across the $y$-axis and shifting it up $2$ units.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "g(x) = -\\sqrt{x} + 2",
                                    "g(x) = \\sqrt{x + 2}",
                                    "g(x) = -\\sqrt{x - 2}",
                                    "g(x) = \\sqrt{-x} + 2",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Reflecting across the y-axis requires replacing x with -x inside the radical: sqrt(-x). Shifting up 2 units adds 2 outside the radical: sqrt(-x) + 2.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 3.5",
                            "concept_slugs": ["alg-reflections", "alg-shifts"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the effect of replacing x with (x - h) in f(x) when h > 0?",
                    "back": "The graph shifts horizontally to the RIGHT by h units.",
                    "concept_slugs": ["alg-shifts"],
                },
                {
                    "front": "What is the difference between -f(x) and f(-x)?",
                    "back": "-f(x) reflects the graph across the x-axis; f(-x) reflects the graph across the y-axis.",
                    "concept_slugs": ["alg-reflections"],
                },
                {
                    "front": "What transformation does 3f(x) produce on the graph of f(x)?",
                    "back": "A vertical stretch by a factor of 3 (all y-values are multiplied by 3).",
                    "concept_slugs": ["alg-stretches-compressions"],
                },
            ],
        },
        {
            "code": "3.5",
            "title": "Determine one-to-one status, verify inverse functions, and find inverse equations",
            "description": "Apply the horizontal line test for one-to-one functions, algebraically find inverse formulas f^(-1)(x), and verify inverse properties via composition.",
            "sort_order": 5,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 3.7: Inverse Functions",
            "concepts": [
                {
                    "slug": "alg-one-to-one-functions",
                    "name": "One-to-One Functions and Horizontal Line Test",
                    "short_definition": "A function is one-to-one if each output y corresponds to exactly one input x.",
                    "description": "Verified graphically by the Horizontal Line Test: no horizontal line may intersect the graph more than once.",
                    "citation": "OpenStax College Algebra 1e, Section 3.7",
                },
                {
                    "slug": "alg-inverse-algebraic",
                    "name": "Algebraic Determination of Inverse Functions",
                    "short_definition": "Finding f^(-1)(x) by replacing f(x) with y, swapping x and y, and solving for y.",
                    "description": "The domain of f equals the range of f^(-1), and the range of f equals the domain of f^(-1).",
                    "citation": "OpenStax College Algebra 1e, Section 3.7",
                    "prerequisites": ["alg-one-to-one-functions"],
                },
                {
                    "slug": "alg-inverse-verification",
                    "name": "Verification of Inverses via Composition",
                    "short_definition": "Two functions f and g are inverses if and only if f(g(x)) = x and g(f(x)) = x.",
                    "description": "The graphs of inverse functions are reflections of each other across the line y = x.",
                    "citation": "OpenStax College Algebra 1e, Section 3.7",
                    "prerequisites": ["alg-inverse-algebraic"],
                },
            ],
            "lessons": [
                {
                    "title": "Inverse Functions and One-to-One Criteria",
                    "description": "One-to-one function criteria, the horizontal line test, algebraic methods for finding inverse functions, and composition verification.",
                    "emoji": "🪞",
                    "tags": ["inverse-functions", "one-to-one", "horizontal-line-test"],
                    "concept_slugs": [
                        "alg-one-to-one-functions",
                        "alg-inverse-algebraic",
                        "alg-inverse-verification",
                    ],
                    "citation": "OpenStax College Algebra 1e, Section 3.7",
                    "terms": [
                        {"term": "One-to-One Function", "definition": "A function where no two distinct inputs produce the same output: if f(a) = f(b), then a = b."},
                        {"term": "Horizontal Line Test", "definition": "A visual test stating that a function has an inverse if and only if no horizontal line intersects its graph more than once."},
                        {"term": "Inverse Function", "definition": "A function denoted f^(-1) that undoes the action of f: f(f^(-1)(x)) = x and f^(-1)(f(x)) = x."},
                        {"term": "Line of Reflection y = x", "definition": "The diagonal line across which the graph of a function and its inverse are symmetric."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### One-to-One Functions and Invertibility\n\n"
                                    "A function $f$ has an **inverse function**, denoted $f^{-1}$, if and only if it is **one-to-one (injective)**: each $y$-value in the range corresponds to exactly one $x$-value in the domain. "
                                    "Graphically, a function is one-to-one if it passes the **Horizontal Line Test**: no horizontal line intersects the graph at more than one point.\n\n"
                                    "### Systematic Procedure to Find $f^{-1}(x)$\n\n"
                                    "1. Verify that $f$ is one-to-one (restrict domain if necessary, as with parabolas $x \\geq 0$).\n"
                                    "2. Replace $f(x)$ with $y$: $y = f(x)$.\n"
                                    "3. **Interchange variables**: Swap $x$ and $y$ ($x = f(y)$).\n"
                                    "4. **Solve for $y$** in terms of $x$.\n"
                                    "5. Replace $y$ with $f^{-1}(x)$.\n"
                                    "6. Verify using composition: $(f \\circ f^{-1})(x) = x$ and $(f^{-1} \\circ f)(x) = x$."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "The Notation $f^{-1}(x)$ is NOT an Exponent",
                                "body": "Do not confuse $f^{-1}(x)$ with a reciprocal exponent! $f^{-1}(x) \\neq \\frac{1}{f(x)}$. For example, if $f(x) = 2x + 1$, then $f^{-1}(x) = \\frac{x - 1}{2}$, whereas $\\frac{1}{f(x)} = \\frac{1}{2x + 1}$.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Function and Inverse Relationship Properties\n\n"
                                    "| Property | Function $f$ | Inverse Function $f^{-1}$ |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Domain** | $\\text{Domain}(f)$ | Equal to $\\text{Range}(f)$ |\n"
                                    "| **Range** | $\\text{Range}(f)$ | Equal to $\\text{Domain}(f)$ |\n"
                                    "| **Ordered Pair** | $(a, b)$ on graph | $(b, a)$ on graph |\n"
                                    "| **Symmetry** | Reflected across line $y = x$ | Reflected across line $y = x$ |\n"
                                    "| **Composition Identity** | $(f \\circ f^{-1})(x) = x$ | $(f^{-1} \\circ f)(x) = x$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Temperature Conversion Inverse Functions\n\n"
                                    "A meteorological laboratory converts temperature readings between Celsius ($C$) and Fahrenheit ($F$). "
                                    "The standard conversion formula is $F(C) = \\frac{9}{5}C + 32$. "
                                    "To find the inverse function giving Celsius as a function of Fahrenheit, we solve for $C$:\n\n"
                                    "$$F - 32 = \\frac{9}{5}C \\implies C(F) = \\frac{5}{9}(F - 32)$$\n\n"
                                    "Verifying via composition:\n\n"
                                    "$$C(F(C)) = \\frac{5}{9}\\left(\\left(\\frac{9}{5}C + 32\\right) - 32\\right) = \\frac{5}{9}\\left(\\frac{9}{5}C\\right) = C$$\n\n"
                                    "This confirms that $C(F)$ is the exact mathematical inverse of $F(C)$."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Inverse Function Pitfalls",
                                "body": "1. **Inverting non-one-to-one functions**: Quadratic functions like $f(x) = x^2$ do NOT have an inverse on $(-\\infty, \\infty)$ because they fail the horizontal line test. The domain must be restricted (e.g. $x \\geq 0$) to make the function one-to-one.\n2. **Rational algebra in swapping**: When solving for $y$ in $x = \\frac{ay + b}{cy + d}$, you must cross-multiply, collect all terms with $y$ on one side, factor out $y$, and divide.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "id": "alg-sim-inverse-of-rational-function",
                            "prompt": "Find the inverse function $f^{-1}(x)$ for the one-to-one rational function $f(x) = \\frac{2x + 1}{x - 3}$ for $x \\neq 3$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "f^{-1}(x) = \\frac{3x + 1}{x - 2}",
                                    "f^{-1}(x) = \\frac{x - 3}{2x + 1}",
                                    "f^{-1}(x) = \\frac{3x - 1}{x + 2}",
                                    "f^{-1}(x) = \\frac{2x - 1}{x + 3}",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Write as y = (2x + 1)/(x - 3). Interchange x and y: x = (2y + 1)/(y - 3). Multiply both sides by (y - 3): x(y - 3) = 2y + 1 => xy - 3x = 2y + 1. Collect y terms on one side: xy - 2y = 3x + 1. Factor out y: y(x - 2) = 3x + 1. Divide by (x - 2): y = (3x + 1)/(x - 2). Thus f^(-1)(x) = (3x + 1)/(x - 2).",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 3.7",
                            "concept_slugs": ["alg-inverse-algebraic"],
                        },
                        {
                            "id": "alg-sim-quadratic-inverse-domain-restriction",
                            "prompt": "What domain restriction must be placed on the quadratic function $f(x) = (x - 2)^2 + 3$ so that its inverse $f^{-1}(x)$ exists as a function?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "x \\geq -2",
                                    "x \\geq 2",
                                    "x \\leq 3",
                                    "All real numbers x",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "A parabola fails the horizontal line test on its full domain (-infinity, infinity). To make it one-to-one, we restrict the domain to values on one side of its vertex (x = 2). Restricting to x >= 2 (or x <= 2) makes the function strictly increasing (or decreasing) and therefore one-to-one.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax College Algebra 1e, Section 3.7",
                            "concept_slugs": ["alg-one-to-one-functions"],
                        },
                        {
                            "id": "alg-sim-inverse-of-linear-function",
                            "prompt": "If $f(x) = 4x - 7$, which of the following is the inverse function $f^{-1}(x)$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "f^{-1}(x) = \\frac{1}{4x - 7}",
                                    "f^{-1}(x) = \\frac{x - 7}{4}",
                                    "f^{-1}(x) = \\frac{x + 7}{4}",
                                    "f^{-1}(x) = 4x + 7",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Set y = 4x - 7. Swap variables: x = 4y - 7. Solve for y: x + 7 = 4y => y = (x + 7)/4. Therefore f^(-1)(x) = (x + 7)/4.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 3.7",
                            "concept_slugs": ["alg-inverse-algebraic"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What does the Horizontal Line Test verify?",
                    "back": "Whether a function is one-to-one, which determines if its inverse is also a function.",
                    "concept_slugs": ["alg-one-to-one-functions"],
                },
                {
                    "front": "What is the relationship between the graphs of f(x) and f^(-1)(x)?",
                    "back": "They are reflections of each other across the diagonal line y = x.",
                    "concept_slugs": ["alg-inverse-verification"],
                },
                {
                    "front": "What is the domain of f^(-1)(x) in terms of f(x)?",
                    "back": "The domain of f^(-1) is the RANGE of f.",
                    "concept_slugs": ["alg-inverse-algebraic"],
                },
            ],
        },
        {
            "code": "3.6",
            "title": "Analyze rational functions, identify vertical and horizontal asymptotes, and evaluate end behavior",
            "description": "Distinguish vertical asymptotes from removable holes, apply degree tests to determine horizontal and slant asymptotes, and analyze asymptotic end behavior.",
            "sort_order": 6,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 5.6: Rational Functions",
            "concepts": [
                {
                    "slug": "alg-vertical-asymptotes",
                    "name": "Vertical Asymptotes and Removable Discontinuities",
                    "short_definition": "Vertical lines x = c where function values approach ±infinity; holes occur where numerator and denominator share a canceled zero.",
                    "description": "After simplifying, real zeros of the denominator correspond to vertical asymptotes x = c.",
                    "citation": "OpenStax College Algebra 1e, Section 5.6",
                },
                {
                    "slug": "alg-horizontal-asymptotes",
                    "name": "Horizontal and Slant Asymptotes",
                    "short_definition": "Horizontal lines y = L describing end behavior as x -> ±infinity based on numerator and denominator degrees.",
                    "description": "Rules: deg(num) < deg(den) => y = 0; deg(num) = deg(den) => y = an/bd; deg(num) = deg(den) + 1 => slant asymptote found by polynomial division.",
                    "citation": "OpenStax College Algebra 1e, Section 5.6",
                    "prerequisites": ["alg-vertical-asymptotes"],
                },
                {
                    "slug": "alg-rational-end-behavior",
                    "name": "End Behavior of Rational Functions",
                    "short_definition": "Analysis of function values as x approaches positive or negative infinity.",
                    "description": "Governed entirely by the ratio of leading terms of the numerator and denominator polynomials.",
                    "citation": "OpenStax College Algebra 1e, Section 5.6",
                    "prerequisites": ["alg-horizontal-asymptotes"],
                },
            ],
            "lessons": [
                {
                    "title": "Rational Functions and Asymptotic Behavior",
                    "description": "Determining vertical asymptotes, removable holes, horizontal asymptotes by degree comparison, slant asymptotes, and end behavior.",
                    "emoji": "📐",
                    "tags": ["rational-functions", "asymptotes", "end-behavior"],
                    "concept_slugs": [
                        "alg-vertical-asymptotes",
                        "alg-horizontal-asymptotes",
                        "alg-rational-end-behavior",
                    ],
                    "citation": "OpenStax College Algebra 1e, Section 5.6",
                    "terms": [
                        {"term": "Vertical Asymptote", "definition": "A vertical line x = c where the function values approach +infinity or -infinity as x approaches c."},
                        {"term": "Horizontal Asymptote", "definition": "A horizontal line y = L that the graph approaches as x approaches +infinity or -infinity."},
                        {"term": "Removable Discontinuity (Hole)", "definition": "A point (c, L) where a rational function is undefined because a common factor (x - c) cancels from both numerator and denominator."},
                        {"term": "Slant (Oblique) Asymptote", "definition": "A non-horizontal linear asymptote y = mx + b occurring when the degree of the numerator is exactly 1 greater than the degree of the denominator."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Vertical Asymptotes vs. Removable Holes\n\n"
                                    "For a rational function $f(x) = \\frac{P(x)}{Q(x)}$ factored completely:\n\n"
                                    "1. **Removable Hole**: If a factor $(x - c)$ appears in **both** numerator and denominator, canceling it leaves a hole at $x = c$. The $y$-coordinate is found by evaluating the simplified expression at $x = c$.\n"
                                    "2. **Vertical Asymptote**: If $(x - c)$ is a factor of the denominator that does **not** cancel completely, the line $x = c$ is a **vertical asymptote** ($f(x) \\to \\pm\\infty$ as $x \\to c$).\n\n"
                                    "### Horizontal and Slant Asymptotes: Degree Rules\n\n"
                                    "Let $n = \\text{degree}(P)$ and $d = \\text{degree}(Q)$, with leading terms $a_n x^n$ and $b_d x^d$:\n\n"
                                    "- **Case 1 ($n < d$)**: The denominator grows faster. The **horizontal asymptote is $y = 0$** ($x$-axis).\n"
                                    "- **Case 2 ($n = d$)**: Degrees are equal. The **horizontal asymptote is $y = \\frac{a_n}{b_d}$** (ratio of leading coefficients).\n"
                                    "- **Case 3 ($n = d + 1$)**: Degree of numerator is exactly 1 higher. There is **no horizontal asymptote**, but there is a **slant (oblique) asymptote** $y = mx + b$, found by polynomial division.\n"
                                    "- **Case 4 ($n > d + 1$)**: No horizontal or slant asymptote (end behavior resembles a polynomial curve)."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Crossing Asymptotes Rule",
                                "body": "A graph can **NEVER** cross a vertical asymptote, because the function is undefined there ($x = c$ is outside the domain). However, a graph **CAN** cross a horizontal or slant asymptote, which only governs end behavior as $x \\to \\pm\\infty$.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Asymptote Determination Hierarchy\n\n"
                                    "| Degree Relationship | Asymptote Type | Equation Formula | Example |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| $\\text{deg}(P) < \\text{deg}(Q)$ | Horizontal Asymptote | $y = 0$ | $f(x) = \\frac{3x + 1}{x^2 - 4} \\implies y = 0$ |\n"
                                    "| $\\text{deg}(P) = \\text{deg}(Q)$ | Horizontal Asymptote | $y = \\frac{a_n}{b_d}$ | $f(x) = \\frac{6x^2 - 1}{2x^2 + 5} \\implies y = 3$ |\n"
                                    "| $\\text{deg}(P) = \\text{deg}(Q) + 1$ | Slant (Oblique) Asymptote | $y = \\text{Quotient}(x)$ | $f(x) = \\frac{2x^2 + 3x}{x - 1} \\implies y = 2x + 5$ |\n"
                                    "| Denominator root (non-canceled) | Vertical Asymptote | $x = c$ | $f(x) = \\frac{1}{x - 4} \\implies x = 4$ |\n"
                                    "| Common factor canceled | Removable Discontinuity | Hole at $(c, L)$ | $f(x) = \\frac{(x-2)(x+3)}{x-2} \\implies (2, 5)$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Average Manufacturing Cost Model\n\n"
                                    "An industrial manufacturing facility produces custom mechanical components. "
                                    "The total monthly cost $C(x)$ (in dollars) to manufacture $x$ units is given by $C(x) = 15000 + 45x$, where $\\$15,000$ is fixed overhead and $\\$45$ is unit variable cost. "
                                    "The **average cost per unit** $\\bar{C}(x)$ is the rational function:\n\n"
                                    "$$\\bar{C}(x) = \\frac{C(x)}{x} = \\frac{15000 + 45x}{x} = \\frac{15000}{x} + 45$$\n\n"
                                    "Here $\\text{degree}(15000 + 45x) = 1$ and $\\text{degree}(x) = 1$. "
                                    "The horizontal asymptote is $y = \\frac{45}{1} = 45$. "
                                    "As production volume increases indefinitely ($x \\to \\infty$), the fixed overhead per unit $\\frac{15000}{x} \\to 0$, meaning the average unit cost approaches a minimum asymptotic floor of $\\$45$."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Rational Function Pitfalls",
                                "body": "1. **Declaring a hole as a vertical asymptote**: In $f(x) = \\frac{x^2 - 9}{x - 3} = \\frac{(x-3)(x+3)}{x-3}$, the factor $(x - 3)$ cancels completely. There is NO vertical asymptote at $x = 3$; instead, there is a removable hole at $(3, 6)$.\n2. **Ignoring the remainder in slant asymptotes**: When finding a slant asymptote via long division, the slant asymptote is strictly the linear quotient $y = mx + b$; discard the fractional remainder.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "id": "alg-sim-rational-function-asymptotes-and-holes",
                            "prompt": "Identify all vertical asymptotes and holes for the rational function $f(x) = \\frac{x^2 - 4}{x^2 - x - 2}$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Vertical asymptotes at x = 2 and x = -1; no holes",
                                    "Vertical asymptote at x = 2; hole at x = -1",
                                    "Vertical asymptote at x = -2; hole at x = 2",
                                    "Vertical asymptote at x = -1; hole at x = 2",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Factor numerator and denominator completely: f(x) = [(x - 2)(x + 2)] / [(x - 2)(x + 1)]. The common factor (x - 2) cancels, creating a removable discontinuity (hole) at x = 2. The remaining factor in the denominator is (x + 1), which produces a vertical asymptote at x = -1.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax College Algebra 1e, Section 5.6",
                            "concept_slugs": ["alg-vertical-asymptotes"],
                        },
                        {
                            "id": "alg-sim-horizontal-asymptote-equal-degree",
                            "prompt": "Find the horizontal asymptote of the rational function $f(x) = \\frac{6x^2 - 5x + 1}{2x^2 + 7}$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "y = 3",
                                    "y = 0",
                                    "y = 7",
                                    "y = 2",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Compare the degrees of numerator and denominator: degree of numerator is 2, and degree of denominator is 2. Because the degrees are equal, the horizontal asymptote is the ratio of their leading coefficients: y = 6/2 = 3.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 5.6",
                            "concept_slugs": ["alg-horizontal-asymptotes"],
                        },
                        {
                            "id": "alg-sim-slant-asymptote",
                            "prompt": "Find the slant (oblique) asymptote of the rational function $f(x) = \\frac{2x^2 + 5x - 3}{x + 1}$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "y = 2x",
                                    "y = 2x + 3",
                                    "y = 2x + 5",
                                    "y = 2x - 3",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Perform polynomial division (or synthetic division with -1): (2x^2 + 5x - 3) / (x + 1). Dividing gives 2x + 3 with a remainder of -6. As x approaches infinity, the remainder -6/(x + 1) approaches 0. Therefore, the slant asymptote is the linear quotient y = 2x + 3.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 5.6",
                            "concept_slugs": ["alg-horizontal-asymptotes"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "How do you distinguish between a vertical asymptote and a hole in a rational function?",
                    "back": "A hole occurs where a common factor cancels from both numerator and denominator; a vertical asymptote occurs where a denominator factor does not cancel.",
                    "concept_slugs": ["alg-vertical-asymptotes"],
                },
                {
                    "front": "What is the horizontal asymptote rule when degree of numerator equals degree of denominator?",
                    "back": "The horizontal asymptote is y = (leading coefficient of numerator) / (leading coefficient of denominator).",
                    "concept_slugs": ["alg-horizontal-asymptotes"],
                },
                {
                    "front": "When does a rational function have a slant (oblique) asymptote?",
                    "back": "When the degree of the numerator is exactly 1 greater than the degree of the denominator.",
                    "concept_slugs": ["alg-horizontal-asymptotes"],
                },
            ],
        },
    ],
}
