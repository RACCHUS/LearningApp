"""Domain 1.0: Algebraic Operations (Quota: 15 questions, 25% official blueprint).

Covers:
- Operations with integer and rational exponents, radicals, and scientific notation
- Polynomial arithmetic, factoring techniques, and special products
- Operations on rational expressions and domain restrictions
- Absolute value operations and distance on the real line
- Logarithmic expressions, properties, and change of base
Authoritative Source: OpenStax College Algebra 1e (CC BY 4.0).
"""
from __future__ import annotations

DOMAIN_01 = {
    "code": "1.0",
    "title": "Algebraic operations",
    "description": "Operations with exponents, radicals, polynomials, rational expressions, absolute value, and logarithms.",
    "weight": 0.250,
    "sort_order": 1,
    "importance": "core",
    "citation": "College Board CLEP College Algebra Domain 1.0 (25%); OpenStax College Algebra 1e Chapters 1 & 6",
    "objectives": [
        {
            "code": "1.1",
            "title": "Apply rules of integer and rational exponents, simplify radicals, and compute in scientific notation",
            "description": "Master product, quotient, and power rules of exponents, convert between radical and rational exponent forms, and perform arithmetic using scientific notation.",
            "sort_order": 1,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 1.2: Exponents and Scientific Notation; Section 1.3: Radicals and Rational Exponents",
            "concepts": [
                {
                    "slug": "alg-exponent-rules",
                    "name": "Laws of Exponents",
                    "short_definition": "Fundamental rules governing multiplication, division, powers, and negative exponents for algebraic terms.",
                    "description": "Includes product rule a^m * a^n = a^(m+n), quotient rule a^m / a^n = a^(m-n), power rule (a^m)^n = a^(mn), and negative exponent rule a^(-n) = 1/a^n for non-zero bases.",
                    "citation": "OpenStax College Algebra 1e, Section 1.2",
                },
                {
                    "slug": "alg-rational-exponents",
                    "name": "Rational Exponents and Radical Expressions",
                    "short_definition": "Equivalence between fractional exponents a^(m/n) and nth roots of powers.",
                    "description": "Rational exponents satisfy a^(m/n) = (n-th root of a)^m = n-th root of (a^m). Radicals can be simplified by factoring out perfect n-th powers.",
                    "citation": "OpenStax College Algebra 1e, Section 1.3",
                    "prerequisites": ["alg-exponent-rules"],
                },
                {
                    "slug": "alg-scientific-notation",
                    "name": "Scientific Notation",
                    "short_definition": "Expression of numbers in the form a * 10^n where 1 <= |a| < 10 and n is an integer.",
                    "description": "Facilitates calculation with extremely large or small quantities through exponent addition and subtraction.",
                    "citation": "OpenStax College Algebra 1e, Section 1.2",
                    "prerequisites": ["alg-exponent-rules"],
                },
            ],
            "lessons": [
                {
                    "title": "Exponents, Radicals, and Scientific Notation",
                    "description": "Comprehensive rules for simplifying expressions with integer exponents, rational exponents, radicals, and scientific notation.",
                    "emoji": "🔢",
                    "tags": ["exponents", "radicals", "algebraic-operations"],
                    "concept_slugs": [
                        "alg-exponent-rules",
                        "alg-rational-exponents",
                        "alg-scientific-notation",
                    ],
                    "citation": "OpenStax College Algebra 1e, Sections 1.2 & 1.3",
                    "terms": [
                        {"term": "Base", "definition": "The number or variable that is being raised to a power."},
                        {"term": "Exponent", "definition": "The number that indicates how many times the base is multiplied by itself."},
                        {"term": "Radicand", "definition": "The expression located under a radical symbol."},
                        {"term": "Index", "definition": "The positive integer n in an n-th root expression indicating which root is being taken."},
                        {"term": "Scientific Notation", "definition": "A standard format writing numbers as a product of a number between 1 and 10 and an integer power of 10."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Laws of Exponents and Radical Foundations\n\n"
                                    "Exponential notation represents repeated multiplication: for any real number $a$ and positive integer $n$, $a^n = a \\cdot a \\dots a$ ($n$ factors). "
                                    "The fundamental operational rules for all real bases $a, b \\neq 0$ and rational exponents $m, n$ include:\n\n"
                                    "- **Product Rule**: $a^m \\cdot a^n = a^{m+n}$\n"
                                    "- **Quotient Rule**: $\\frac{a^m}{a^n} = a^{m-n}$\n"
                                    "- **Power Rule**: $(a^m)^n = a^{mn}$\n"
                                    "- **Power of a Product**: $(ab)^n = a^n b^n$\n"
                                    "- **Power of a Quotient**: $\\left(\\frac{a}{b}\\right)^n = \\frac{a^n}{b^n}$\n"
                                    "- **Zero Exponent**: $a^0 = 1$ ($a \\neq 0$)\n"
                                    "- **Negative Exponent**: $a^{-n} = \\frac{1}{a^n}$ and $\\frac{1}{a^{-n}} = a^n$\n\n"
                                    "### Rational Exponents and Radicals\n\n"
                                    "A rational exponent represents both a power and a root: $a^{m/n} = \\sqrt[n]{a^m} = (\\sqrt[n]{a})^m$. "
                                    "When simplifying radical expressions $\\sqrt[n]{x}$, we extract any factor that is a perfect $n$-th power: $\\sqrt[n]{c^n \\cdot k} = |c|\\sqrt[n]{k}$ (for even $n$) or $c\\sqrt[n]{k}$ (for odd $n$)."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Rational Exponents vs. Radical Notation",
                                "body": "Always remember that the denominator of a rational exponent is the index of the radical root, while the numerator is the integer power: $x^{3/5} = \\sqrt[5]{x^3} = (\\sqrt[5]{x})^3$.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Summary of Exponent and Radical Equivalence\n\n"
                                    "| Exponential Form | Radical Form | Simplified Example |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| $a^{1/2}$ | $\\sqrt{a}$ | $36^{1/2} = \\sqrt{36} = 6$ |\n"
                                    "| $a^{1/n}$ | $\\sqrt[n]{a}$ | $8^{1/3} = \\sqrt[3]{8} = 2$ |\n"
                                    "| $a^{m/n}$ | $(\\sqrt[n]{a})^m$ | $27^{2/3} = (\\sqrt[3]{27})^2 = 3^2 = 9$ |\n"
                                    "| $a^{-m/n}$ | $\\frac{1}{(\\sqrt[n]{a})^m}$ | $16^{-3/4} = \\frac{1}{(\\sqrt[4]{16})^3} = \\frac{1}{2^3} = \\frac{1}{8}$ |\n"
                                    "| $\\sqrt[n]{a} \\cdot \\sqrt[n]{b}$ | $\\sqrt[n]{ab}$ | $\\sqrt{8} \\cdot \\sqrt{2} = \\sqrt{16} = 4$ |\n"
                                    "| $\\frac{\\sqrt[n]{a}}{\\sqrt[n]{b}}$ | $\\sqrt[n]{\\frac{a}{b}}$ | $\\frac{\\sqrt{75}}{\\sqrt{3}} = \\sqrt{25} = 5$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Scientific Notation in Astronomical Scale\n\n"
                                    "Astronomers and computational scientists routinely model distances across the cosmos using scientific notation. "
                                    "For example, the distance light travels in one year (one light-year) is approximately $9.46 \\times 10^{12}$ kilometers. "
                                    "If a distant star cluster is located $4.73 \\times 10^{14}$ kilometers from Earth, we calculate the travel time in years by computing the quotient:\n\n"
                                    "$$t = \\frac{4.73 \\times 10^{14}}{9.46 \\times 10^{12}} = \\left(\\frac{4.73}{9.46}\\right) \\times 10^{14 - 12} = 0.50 \\times 10^2 = 5.0 \\times 10^1 = 50\\text{ light-years}$$\n\n"
                                    "This operational efficiency illustrates how the quotient rule of exponents converts complex division into elementary decimal division and exponent subtraction."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Exponent Misconceptions and Pitfalls",
                                "body": "1. **Distributing powers over addition**: $(a + b)^2 \\neq a^2 + b^2$. Powers do NOT distribute across sums or differences.\n2. **Negative exponents**: A negative exponent does NOT make a number negative; it indicates a reciprocal: $2^{-3} = \\frac{1}{2^3} = \\frac{1}{8} > 0$.\n3. **Base sign convention**: $-3^2 = -(3^2) = -9$, whereas $(-3)^2 = 9$. Parentheses dictate whether the negative sign is part of the base.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Which of the following is equivalent to the expression $(8x^6 y^{-3})^{2/3}$ for all positive real values of $x$ and $y$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "\\frac{4x^4}{y^2}",
                                    "\\frac{4x^9}{y^2}",
                                    "\\frac{8x^4}{y^2}",
                                    "4x^4 y^2",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Applying the power of a product rule: (8)^(2/3) * (x^6)^(2/3) * (y^(-3))^(2/3). Since 8^(2/3) = (cbrt(8))^2 = 2^2 = 4, (x^6)^(2/3) = x^(6 * 2/3) = x^4, and (y^(-3))^(2/3) = y^(-3 * 2/3) = y^(-2) = 1/y^2, the simplified expression is 4x^4 / y^2.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 1.3",
                            "concept_slugs": ["alg-exponent-rules", "alg-rational-exponents"],
                        },
                        {
                            "prompt": "Which expression represents the fully simplified radical form of \\sqrt{72x^5 y^6} where $x > 0$ and $y > 0$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "36x^2 y^3 \\sqrt{2x}",
                                    "6x^2 y^3 \\sqrt{2x}",
                                    "12x^2 y^3 \\sqrt{x}",
                                    "6x^4 y^6 \\sqrt{2x}",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Factor the radicand into perfect squares and remaining factors: 72 = 36 * 2, x^5 = x^4 * x, and y^6 = (y^3)^2. Taking square roots gives sqrt(36 * x^4 * y^6 * 2x) = 6x^2 y^3 sqrt(2x).",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 1.3",
                            "concept_slugs": ["alg-rational-exponents"],
                        },
                        {
                            "prompt": "Evaluate the quotient \\frac{4.8 \\times 10^8}{1.2 \\times 10^{-4}} and express the result in proper scientific notation.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "4.0 \\times 10^4",
                                    "4.0 \\times 10^{-12}",
                                    "4.0 \\times 10^{12}",
                                    "4.0 \\times 10^{2}",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Divide the numerical coefficients and subtract the exponents of 10: (4.8 / 1.2) * 10^(8 - (-4)) = 4.0 * 10^(8 + 4) = 4.0 * 10^12.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 1.2",
                            "concept_slugs": ["alg-scientific-notation"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What does a negative exponent indicate (e.g., a^(-n))?",
                    "back": "It indicates the reciprocal of the base raised to the positive power: 1 / a^n.",
                    "concept_slugs": ["alg-exponent-rules"],
                },
                {
                    "front": "In the rational exponent expression x^(m/n), what do m and n represent?",
                    "back": "n is the index of the root (nth root), and m is the power to which the base (or root) is raised.",
                    "concept_slugs": ["alg-rational-exponents"],
                },
                {
                    "front": "What is the result of dividing two powers with the same base: a^m / a^n?",
                    "back": "a^(m - n) (subtract the denominator exponent from the numerator exponent).",
                    "concept_slugs": ["alg-exponent-rules"],
                },
            ],
        },
        {
            "code": "1.2",
            "title": "Perform polynomial arithmetic, factor polynomials, and apply special product formulas",
            "description": "Add, subtract, multiply, and divide polynomials; factor using GCF, grouping, difference of squares, sum/difference of cubes, and quadratic trinomial factoring.",
            "sort_order": 2,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 1.4: Polynomials; Section 1.5: Factoring Polynomials",
            "concepts": [
                {
                    "slug": "alg-polynomial-arithmetic",
                    "name": "Polynomial Arithmetic",
                    "short_definition": "Addition, subtraction, multiplication, and long/synthetic division of polynomial expressions.",
                    "description": "Polynomials are combined by combining like terms and multiplied using the distributive property across terms.",
                    "citation": "OpenStax College Algebra 1e, Section 1.4",
                },
                {
                    "slug": "alg-special-products",
                    "name": "Special Product and Factoring Formulas",
                    "short_definition": "Algebraic identities for perfect square trinomials, difference of squares, and sum/difference of cubes.",
                    "description": "Formulas: (a ± b)^2 = a^2 ± 2ab + b^2, a^2 - b^2 = (a - b)(a + b), a^3 - b^3 = (a - b)(a^2 + ab + b^2), and a^3 + b^3 = (a + b)(a^2 - ab + b^2).",
                    "citation": "OpenStax College Algebra 1e, Section 1.4 & 1.5",
                    "prerequisites": ["alg-polynomial-arithmetic"],
                },
                {
                    "slug": "alg-factoring-techniques",
                    "name": "Comprehensive Factoring Techniques",
                    "short_definition": "Systematic factoring including GCF extraction, grouping, ac-method for trinomials, and substitution.",
                    "description": "A systematic approach: 1. Factor out GCF; 2. Count terms (2 terms: special forms; 3 terms: trinomial ac-method; 4 terms: grouping); 3. Verify each factor is prime over the integers.",
                    "citation": "OpenStax College Algebra 1e, Section 1.5",
                    "prerequisites": ["alg-special-products"],
                },
            ],
            "lessons": [
                {
                    "title": "Polynomial Operations, Factoring, and Special Products",
                    "description": "Techniques for polynomial expansion, special algebraic products, and exhaustive factoring strategies.",
                    "emoji": "📐",
                    "tags": ["polynomials", "factoring", "special-products"],
                    "concept_slugs": [
                        "alg-polynomial-arithmetic",
                        "alg-special-products",
                        "alg-factoring-techniques",
                    ],
                    "citation": "OpenStax College Algebra 1e, Sections 1.4 & 1.5",
                    "terms": [
                        {"term": "Degree of a Polynomial", "definition": "The highest exponent of the variable in any non-zero term of the polynomial."},
                        {"term": "Greatest Common Factor (GCF)", "definition": "The largest monomial that divides evenly into every term of the polynomial."},
                        {"term": "Difference of Squares", "definition": "An expression of the form a^2 - b^2 which factors into (a - b)(a + b)."},
                        {"term": "Sum of Cubes", "definition": "An expression of the form a^3 + b^3 which factors into (a + b)(a^2 - ab + b^2)."},
                        {"term": "Factoring by Grouping", "definition": "A technique grouping pairs of terms with common factors, typically used for four-term polynomials."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Polynomial Operations and Special Products\n\n"
                                    "A polynomial in one variable $x$ is an algebraic expression of the form $a_n x^n + a_{n-1} x^{n-1} + \\dots + a_1 x + a_0$, where each $a_i$ is a real coefficient and $n$ is a non-negative integer. "
                                    "Polynomials are added and subtracted by grouping like terms (terms with the exact same variable powers). "
                                    "Multiplication requires repeated application of the distributive property, giving rise to essential **special product formulas**:\n\n"
                                    "- **Difference of Squares**: $(a - b)(a + b) = a^2 - b^2$\n"
                                    "- **Square of a Binomial**: $(a \\pm b)^2 = a^2 \\pm 2ab + b^2$\n"
                                    "- **Sum of Cubes**: $(a + b)(a^2 - ab + b^2) = a^3 + b^3$\n"
                                    "- **Difference of Cubes**: $(a - b)(a^2 + ab + b^2) = a^3 - b^3$"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "The SOAP Mnemonic for Cubes",
                                "body": "When factoring $a^3 \\pm b^3 = (a \\text{ [S]} b)(a^2 \\text{ [O]} ab \\text{ [AP]} b^2)$, the signs follow **SOAP**: **S**ame sign as binomial, **O**pposite sign, **A**lways **P**ositive.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Factoring Strategy Hierarchy\n\n"
                                    "| Term Count | Target Pattern | Algebraic Identity / Strategy |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Any** | Greatest Common Factor | $ax + ay = a(x + y)$ |\n"
                                    "| **2 Terms** | Difference of Squares | $a^2 - b^2 = (a - b)(a + b)$ |\n"
                                    "| **2 Terms** | Sum of Cubes | $a^3 + b^3 = (a + b)(a^2 - ab + b^2)$ |\n"
                                    "| **2 Terms** | Difference of Cubes | $a^3 - b^3 = (a - b)(a^2 + ab + b^2)$ |\n"
                                    "| **3 Terms** | Trinomial Factoring | $x^2 + bx + c = (x + p)(x + q)$ where $p+q=b, pq=c$ |\n"
                                    "| **4 Terms** | Grouping | $ax + ay + bx + by = a(x+y) + b(x+y) = (a+b)(x+y)$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Geometric Volume Optimization Model\n\n"
                                    "Consider a classic manufacturing optimization model: an open-top storage container is constructed from a rectangular sheet of metal measuring $20$ inches by $14$ inches by cutting equal squares of side length $x$ inches from each corner and folding up the sides. "
                                    "The resulting container volume $V(x)$ is given by the polynomial model:\n\n"
                                    "$$V(x) = x(20 - 2x)(14 - 2x) = x(280 - 68x + 4x^2) = 4x^3 - 68x^2 + 280x$$\n\n"
                                    "Factoring out the greatest common monomial factor $4x$ yields $V(x) = 4x(x^2 - 17x + 70) = 4x(x - 7)(x - 10)$. "
                                    "Analyzing these linear factors reveals the physical domain restrictions: because side lengths must be positive, $x > 0$ and $14 - 2x > 0 \\implies 0 < x < 7$ inches."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Factoring Pitfalls",
                                "body": "1. **Sum of squares over reals**: $a^2 + b^2$ is **prime** over the real numbers. It does NOT factor into $(a + b)(a + b)$ or $(a + b)(a - b)$.\n2. **Omitting the GCF**: Always factor out the greatest common numerical and variable factor before applying trinomial or grouping rules.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Which of the following represents the complete factorization over the real numbers of the polynomial $2x^3 - 8x^2 - 24x$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "2x(x - 4)(x + 3)",
                                    "2x(x^2 - 4x - 12)",
                                    "2(x - 6)(x + 2)",
                                    "2x(x - 6)(x + 2)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "First factor out the GCF 2x: 2x(x^2 - 4x - 12). Next, factor the quadratic trinomial by finding two numbers that multiply to -12 and sum to -4: these are -6 and 2. Hence, the complete factorization is 2x(x - 6)(x + 2).",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 1.5",
                            "concept_slugs": ["alg-factoring-techniques"],
                        },
                        {
                            "prompt": "Which expression represents the complete factorization of $27x^3 - 64$ over the real numbers?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "(3x - 4)(9x^2 + 12x + 16)",
                                    "(3x - 4)(9x^2 - 12x + 16)",
                                    "(3x - 4)^3",
                                    "(3x - 4)(3x^2 + 12x + 16)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "This is a difference of cubes a^3 - b^3 with a = 3x and b = 4. Using the identity (a - b)(a^2 + ab + b^2): (3x - 4)((3x)^2 + (3x)(4) + 4^2) = (3x - 4)(9x^2 + 12x + 16).",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 1.5",
                            "concept_slugs": ["alg-special-products", "alg-factoring-techniques"],
                        },
                        {
                            "prompt": "Factor the four-term polynomial $x^3 + 3x^2 - 4x - 12$ completely over the integers.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "(x + 3)(x^2 + 4)",
                                    "(x + 3)(x - 2)(x + 2)",
                                    "(x - 3)(x - 2)(x + 2)",
                                    "(x^2 - 4)(x - 3)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Group the terms in pairs: (x^3 + 3x^2) - (4x + 12) = x^2(x + 3) - 4(x + 3) = (x^2 - 4)(x + 3). The factor (x^2 - 4) is a difference of squares that further factors into (x - 2)(x + 2). Thus the completely factored form is (x + 3)(x - 2)(x + 2).",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax College Algebra 1e, Section 1.5",
                            "concept_slugs": ["alg-factoring-techniques"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the factored form of the difference of squares a^2 - b^2?",
                    "back": "(a - b)(a + b)",
                    "concept_slugs": ["alg-special-products"],
                },
                {
                    "front": "What is the factored form of the sum of cubes a^3 + b^3?",
                    "back": "(a + b)(a^2 - ab + b^2)",
                    "concept_slugs": ["alg-special-products"],
                },
                {
                    "front": "Can the sum of squares a^2 + b^2 be factored into real linear factors?",
                    "back": "No, a^2 + b^2 is prime (irreducible) over the set of real numbers.",
                    "concept_slugs": ["alg-special-products"],
                },
            ],
        },
        {
            "code": "1.3",
            "title": "Simplify, combine, and determine domain restrictions for rational expressions",
            "description": "Determine excluded values, multiply, divide, add, and subtract rational expressions with unlike denominators, and simplify complex fractions.",
            "sort_order": 3,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 1.6: Rational Expressions",
            "concepts": [
                {
                    "slug": "alg-domain-restrictions",
                    "name": "Domain Restrictions of Rational Expressions",
                    "short_definition": "Identification of real values that cause denominators to equal zero.",
                    "description": "Division by zero is undefined. The domain of a rational expression P(x)/Q(x) consists of all real numbers except values where Q(x) = 0.",
                    "citation": "OpenStax College Algebra 1e, Section 1.6",
                },
                {
                    "slug": "alg-rational-operations",
                    "name": "Arithmetic Operations on Rational Expressions",
                    "short_definition": "Multiplication, division, and addition/subtraction using common denominators.",
                    "description": "Multiplication multiplies numerators and denominators; division multiplies by the reciprocal; addition requires finding the Least Common Denominator (LCD).",
                    "citation": "OpenStax College Algebra 1e, Section 1.6",
                    "prerequisites": ["alg-domain-restrictions"],
                },
                {
                    "slug": "alg-complex-fractions",
                    "name": "Simplification of Complex Rational Fractions",
                    "short_definition": "Methods for simplifying fractions containing rational expressions in numerator and denominator.",
                    "description": "Simplified either by multiplying entire fraction by the LCD of all inner denominators, or by combining numerator and denominator into single fractions and dividing.",
                    "citation": "OpenStax College Algebra 1e, Section 1.6",
                    "prerequisites": ["alg-rational-operations"],
                },
            ],
            "lessons": [
                {
                    "title": "Rational Expressions and Domain Restrictions",
                    "description": "Operational rules for simplifying, multiplying, dividing, adding, and resolving complex rational expressions while identifying domain restrictions.",
                    "emoji": "➗",
                    "tags": ["rational-expressions", "domain", "fractions"],
                    "concept_slugs": [
                        "alg-domain-restrictions",
                        "alg-rational-operations",
                        "alg-complex-fractions",
                    ],
                    "citation": "OpenStax College Algebra 1e, Section 1.6",
                    "terms": [
                        {"term": "Rational Expression", "definition": "A quotient of two polynomials P(x)/Q(x) where Q(x) is not the zero polynomial."},
                        {"term": "Domain Restriction", "definition": "Any value of the variable that makes the denominator of an algebraic expression equal to zero."},
                        {"term": "Least Common Denominator (LCD)", "definition": "The least common multiple of the polynomial denominators in a collection of rational expressions."},
                        {"term": "Complex Fraction", "definition": "A rational expression that contains one or more rational expressions in its numerator, denominator, or both."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Defining Rational Expressions and Identifying Domain Exclusions\n\n"
                                    "A **rational expression** is an algebraic quotient $\\frac{P(x)}{Q(x)}$ where $P(x)$ and $Q(x)$ are polynomials and $Q(x) \\neq 0$. "
                                    "Because division by zero is undefined in mathematics, the **domain** of a rational expression consists of all real numbers *except* those that make any denominator zero. "
                                    "To find domain restrictions, set every denominator equal to zero and solve before canceling any common factors.\n\n"
                                    "### Operations on Rational Expressions\n\n"
                                    "- **Multiplication**: $\\frac{P}{Q} \\cdot \\frac{R}{S} = \\frac{P \\cdot R}{Q \\cdot S}$\n"
                                    "- **Division**: $\\frac{P}{Q} \\div \\frac{R}{S} = \\frac{P}{Q} \\cdot \\frac{S}{R} = \\frac{P \\cdot S}{Q \\cdot R}$ ($R \\neq 0$)\n"
                                    "- **Addition/Subtraction**: To compute $\\frac{P}{Q} \\pm \\frac{R}{S}$, factor both denominators, find the **Least Common Denominator (LCD)**, rewrite each fraction with the LCD, and combine numerators over the common denominator."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Golden Rule of Rational Simplification",
                                "body": "You can only cancel **factors** (quantities multiplied together), never **terms** (quantities added or subtracted). Always factor completely before attempting to simplify.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Operational Comparison for Rational Expressions\n\n"
                                    "| Operation | Algebraic Procedure | Key Step |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Simplification** | Factor numerator and denominator | Cancel common polynomial factors |\n"
                                    "| **Multiplication** | Factor all terms; multiply across | Cancel common factors before multiplying |\n"
                                    "| **Division** | Invert the divisor fraction | Multiply by the reciprocal |\n"
                                    "| **Addition** | Find LCD of all denominators | Convert each fraction to LCD; combine numerators |\n"
                                    "| **Complex Fraction** | Multiply top and bottom by LCD of all minor fractions | Eliminates all minor denominators in one step |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Parallel Electrical Resistance and Rate Modeling\n\n"
                                    "In electronic engineering, the total equivalent resistance $R_T$ of two resistors $R_1$ and $R_2$ wired in parallel is modeled by the rational rate equation:\n\n"
                                    "$$\\frac{1}{R_T} = \\frac{1}{R_1} + \\frac{1}{R_2}$$\n\n"
                                    "Combining the right-hand side using the LCD $R_1 R_2$ yields $\\frac{1}{R_T} = \\frac{R_2 + R_1}{R_1 R_2}$. "
                                    "Taking the reciprocal of both sides gives the equivalent single rational expression $R_T = \\frac{R_1 R_2}{R_1 + R_2}$. "
                                    "If $R_1 = x$ ohms and $R_2 = x + 6$ ohms, the total resistance is $R_T(x) = \\frac{x(x+6)}{2x+6}$, with physical domain restrictions $x > 0$."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Rational Expression Misconceptions",
                                "body": "1. **Universal cancellation error**: In $\\frac{x + 5}{x}$, students mistakenly cancel $x$ to get $5$. This is incorrect because $x$ is a term, not a factor. In fact, $\\frac{x+5}{x} = 1 + \\frac{5}{x}$.\n2. **Forgetting domain exclusions after canceling**: If $\\frac{(x-2)(x+3)}{x-2} = x+3$, the domain restriction $x \\neq 2$ remains in effect even after the factor is canceled.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "What are all real values of $x$ excluded from the domain of the rational expression $\\frac{x - 4}{x^2 - 9}$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "x = 4 only",
                                    "x = 3 only",
                                    "x = -3 and x = 3",
                                    "x = -3, x = 3, and x = 4",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Domain exclusions occur where the denominator equals zero: x^2 - 9 = 0. Factoring gives (x - 3)(x + 3) = 0, which yields x = 3 and x = -3. The numerator root x = 4 is in the domain (it simply makes the expression 0).",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 1.6",
                            "concept_slugs": ["alg-domain-restrictions"],
                        },
                        {
                            "prompt": "Which of the following is equivalent to the complex fraction $\\frac{\\frac{1}{x} - \\frac{1}{y}}{\\frac{1}{x^2} - \\frac{1}{y^2}}$ for all non-zero real numbers $x, y$ with $x \\neq \\pm y$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "\\frac{1}{x + y}",
                                    "\\frac{x + y}{xy}",
                                    "\\frac{xy}{x - y}",
                                    "\\frac{xy}{x + y}",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Multiply numerator and denominator by the LCD of all inner fractions, which is x^2 y^2 (valid for all non-zero x, y with x != \\pm y): Numerator becomes (1/x - 1/y) * x^2 y^2 = xy^2 - x^2 y = xy(y - x). Denominator becomes (1/x^2 - 1/y^2) * x^2 y^2 = y^2 - x^2 = (y - x)(y + x). Dividing gives [xy(y - x)] / [(y - x)(y + x)] = xy / (x + y). Note that x != \\pm y ensures that neither (y - x) nor (y + x) equals zero.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax College Algebra 1e, Section 1.6",
                            "concept_slugs": ["alg-complex-fractions"],
                        },
                        {
                            "prompt": "Combine and simplify the rational expression $\\frac{2}{x - 3} + \\frac{5}{x + 2}$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "\\frac{7x - 11}{(x - 3)(x + 2)}",
                                    "\\frac{7}{2x - 1}",
                                    "\\frac{7x + 19}{(x - 3)(x + 2)}",
                                    "\\frac{7x - 1}{(x - 3)(x + 2)}",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "The LCD is (x - 3)(x + 2). Rewrite each fraction over the LCD: 2(x + 2)/[(x - 3)(x + 2)] + 5(x - 3)/[(x - 3)(x + 2)] = [2x + 4 + 5x - 15] / [(x - 3)(x + 2)] = (7x - 11)/[(x - 3)(x + 2)].",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 1.6",
                            "concept_slugs": ["alg-rational-operations"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "How do you find the domain restrictions of a rational expression?",
                    "back": "Set the denominator polynomial equal to zero and solve; the resulting roots are excluded from the domain.",
                    "concept_slugs": ["alg-domain-restrictions"],
                },
                {
                    "front": "Why can terms in (x + 3) / (x + 5) not be simplified by canceling x?",
                    "back": "Because x is an added term, not a factor. Only common factors that multiply the entire numerator and denominator can be canceled.",
                    "concept_slugs": ["alg-rational-operations"],
                },
                {
                    "front": "What is the fastest way to simplify a complex rational fraction?",
                    "back": "Multiply both the primary numerator and primary denominator by the LCD of all inner minor denominators.",
                    "concept_slugs": ["alg-complex-fractions"],
                },
            ],
        },
        {
            "code": "1.4",
            "title": "Evaluate absolute value expressions and interpret distance on the real number line",
            "description": "Apply the piecewise definition of absolute value, calculate algebraic distance between real numbers, and simplify expressions with nested absolute values.",
            "sort_order": 4,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 1.1: Real Numbers; Section 2.6: Absolute Value",
            "concepts": [
                {
                    "slug": "alg-absolute-value-definition",
                    "name": "Piecewise Definition of Absolute Value",
                    "short_definition": "Algebraic definition |x| = x for x >= 0 and |x| = -x for x < 0.",
                    "description": "Geometrically represents distance from zero on the real number line, which is always non-negative.",
                    "citation": "OpenStax College Algebra 1e, Section 1.1",
                },
                {
                    "slug": "alg-distance-real-line",
                    "name": "Distance on the Real Number Line",
                    "short_definition": "The distance between any two points a and b on the real line is given by d(a, b) = |a - b| = |b - a|.",
                    "description": "Allows geometric inequalities and intervals to be represented compactly using absolute value notation.",
                    "citation": "OpenStax College Algebra 1e, Section 1.1",
                    "prerequisites": ["alg-absolute-value-definition"],
                },
                {
                    "slug": "alg-absolute-value-properties",
                    "name": "Properties of Absolute Value",
                    "short_definition": "Product, quotient, and triangle inequalities for absolute values.",
                    "description": "Properties: |ab| = |a||b|, |a/b| = |a|/|b| (b != 0), |-a| = |a|, and the triangle inequality |a + b| <= |a| + |b|.",
                    "citation": "OpenStax College Algebra 1e, Section 1.1 & 2.6",
                    "prerequisites": ["alg-absolute-value-definition"],
                },
            ],
            "lessons": [
                {
                    "title": "Absolute Value Operations and Real Line Distance",
                    "description": "Piecewise algebraic definition of absolute value, geometric distance representation on the real line, and nested evaluation.",
                    "emoji": "📏",
                    "tags": ["absolute-value", "real-line", "distance"],
                    "concept_slugs": [
                        "alg-absolute-value-definition",
                        "alg-distance-real-line",
                        "alg-absolute-value-properties",
                    ],
                    "citation": "OpenStax College Algebra 1e, Sections 1.1 & 2.6",
                    "terms": [
                        {"term": "Absolute Value", "definition": "The magnitude of a real number without regard to its sign; algebraically, |x| = x if x >= 0 and |x| = -x if x < 0."},
                        {"term": "Distance on the Real Line", "definition": "The non-negative difference |a - b| between two real coordinates a and b."},
                        {"term": "Triangle Inequality", "definition": "The theorem stating that for all real numbers a and b, |a + b| <= |a| + |b|."},
                        {"term": "Tolerance Interval", "definition": "An interval of the form |x - c| <= d representing all values within distance d of target center c."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Algebraic and Geometric Nature of Absolute Value\n\n"
                                    "The absolute value of a real number $x$, denoted $|x|$, represents its non-negative distance from $0$ along the real number line. "
                                    "Algebraically, it is defined piecewise as:\n\n"
                                    "$$|x| = \\begin{cases} x & \\text{if } x \\geq 0 \\\\ -x & \\text{if } x < 0 \\end{cases}$$\n\n"
                                    "Notice that if $x$ is negative (e.g., $x = -5$), then $-x = -(-5) = 5 > 0$. Therefore, $-x$ does not mean the output is negative; it ensures the resulting value is positive. "
                                    "Fundamental algebraic properties include:\n\n"
                                    "1. $|-a| = |a|$\n"
                                    "2. $|ab| = |a| \\cdot |b|$\n"
                                    "3. $\\left|\\frac{a}{b}\\right| = \\frac{|a|}{|b|}$ for $b \\neq 0$\n"
                                    "4. $|a + b| \\leq |a| + |b|$ (**Triangle Inequality**)"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Distance Translation Principle",
                                "body": "The geometric phrase *'the distance between $x$ and $c$ is less than $d$*' translates directly into the algebraic inequality $|x - c| < d$. The center is $c$ and the radius is $d$.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Geometric Distance and Absolute Value Equivalence\n\n"
                                    "| Verbal Description | Geometric Interval | Absolute Value Inequality |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| Distance from $0$ is at most $5$ | $[-5, 5]$ | $|x| \\leq 5$ |\n"
                                    "| Distance from $3$ is less than $4$ | $(-1, 7)$ | $|x - 3| < 4$ |\n"
                                    "| Distance from $-2$ is at most $6$ | $[-8, 4]$ | $|x - (-2)| \\leq 6 \\iff |x + 2| \\leq 6$ |\n"
                                    "| Distance from $c$ is at least $r$ | $(-\\infty, c - r] \\cup [c + r, \\infty)$ | $|x - c| \\geq r$ |\n"
                                    "| Exact distance between $a$ and $b$ | Length of segment | $d = |a - b| = |b - a|$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Quality Control Manufacturing Tolerances\n\n"
                                    "In precision manufacturing, a machine produces steel ball bearings whose target diameter is $25.00$ mm with an allowable tolerance of $0.05$ mm. "
                                    "Any bearing outside this range must be rejected. We formulate this quality control problem algebraically:\n\n"
                                    "$$|d - 25.00| \\leq 0.05$$\n\n"
                                    "Unfolding this absolute value inequality produces $-0.05 \\leq d - 25.00 \\leq 0.05$. Adding $25.00$ to all three parts gives $24.95 \\leq d \\leq 25.05$ mm. "
                                    "If a sample bearing measures $d = 25.08$ mm, its deviation is $|25.08 - 25.00| = 0.08 > 0.05$, correctly flagging it for rejection."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Absolute Value Pitfalls",
                                "body": "1. **Distributing absolute value over sums**: $|a + b| \\neq |a| + |b|$ in general. For instance, $|3 + (-5)| = |-2| = 2$, but $|3| + |-5| = 3 + 5 = 8$.\n2. **Sign of variables**: Assuming that $|x - 5| = x - 5$. If $x < 5$, then $x - 5$ is negative, so $|x - 5| = -(x - 5) = 5 - x$.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Evaluate the arithmetic expression $|-3| - 2|4 - 9| + |-(-5)|$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "12",
                                    "-2",
                                    "8",
                                    "-12",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Compute each absolute value term: |-3| = 3; |4 - 9| = |-5| = 5; |-(-5)| = |5| = 5. Substituting back into the expression: 3 - 2(5) + 5 = 3 - 10 + 5 = -2.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 1.1",
                            "concept_slugs": ["alg-absolute-value-definition"],
                        },
                        {
                            "prompt": "Which inequality expresses the condition that the distance between a real number $x$ and $-4$ on the number line is strictly less than $7$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "|x - 4| < 7",
                                    "|x - 7| < 4",
                                    "|x + 4| < 7",
                                    "|x + 7| < 4",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "The distance between two numbers a and b on the real line is |a - b|. The distance between x and -4 is |x - (-4)| = |x + 4|. Requiring this distance to be strictly less than 7 gives |x + 4| < 7.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 1.1",
                            "concept_slugs": ["alg-distance-real-line"],
                        },
                        {
                            "prompt": "For any real number $x < 5$, which expression is equivalent to $\\frac{|x - 5|}{x - 5}$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "1",
                                    "x",
                                    "0",
                                    "-1",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "By definition, |u| = -u whenever u < 0. Since x < 5, the quantity (x - 5) is strictly negative. Therefore, |x - 5| = -(x - 5). Dividing by (x - 5) yields -(x - 5) / (x - 5) = -1.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax College Algebra 1e, Section 2.6",
                            "concept_slugs": ["alg-absolute-value-definition"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the piecewise definition of the absolute value function |x|?",
                    "back": "|x| = x when x >= 0, and |x| = -x when x < 0.",
                    "concept_slugs": ["alg-absolute-value-definition"],
                },
                {
                    "front": "How is the distance between two numbers a and b on the real line represented algebraically?",
                    "back": "|a - b| (or equivalently |b - a|).",
                    "concept_slugs": ["alg-distance-real-line"],
                },
                {
                    "front": "What does the triangle inequality state for real numbers a and b?",
                    "back": "|a + b| <= |a| + |b|.",
                    "concept_slugs": ["alg-absolute-value-properties"],
                },
            ],
        },
        {
            "code": "1.5",
            "title": "Evaluate logarithmic expressions, apply operational properties, and use change of base",
            "description": "Convert between logarithmic and exponential forms, apply product, quotient, and power properties of logarithms, and compute with change of base.",
            "sort_order": 5,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 6.3: Logarithmic Functions; Section 6.5: Logarithmic Properties",
            "concepts": [
                {
                    "slug": "alg-log-definition",
                    "name": "Definition of Logarithm",
                    "short_definition": "The equivalence y = log_b(x) <=> b^y = x for base b > 0, b != 1, and argument x > 0.",
                    "description": "A logarithm is an exponent: log_b(x) is the power to which base b must be raised to produce x.",
                    "citation": "OpenStax College Algebra 1e, Section 6.3",
                },
                {
                    "slug": "alg-log-properties",
                    "name": "Operational Properties of Logarithms",
                    "short_definition": "Product, quotient, and power rules expanding and condensing logarithmic expressions.",
                    "description": "Rules: log_b(xy) = log_b(x) + log_b(y), log_b(x/y) = log_b(x) - log_b(y), and log_b(x^k) = k * log_b(x).",
                    "citation": "OpenStax College Algebra 1e, Section 6.5",
                    "prerequisites": ["alg-log-definition"],
                },
                {
                    "slug": "alg-change-of-base",
                    "name": "Change-of-Base Formula",
                    "short_definition": "Formula log_b(x) = log_a(x) / log_a(b) converting logarithms to any convenient base such as 10 or e.",
                    "description": "Allows evaluation of logarithms of arbitrary base using common logarithms (log) or natural logarithms (ln).",
                    "citation": "OpenStax College Algebra 1e, Section 6.5",
                    "prerequisites": ["alg-log-properties"],
                },
            ],
            "lessons": [
                {
                    "title": "Logarithmic Expressions and Properties",
                    "description": "Equivalence between exponential and logarithmic forms, the laws of logarithms (product, quotient, power), and the change-of-base formula.",
                    "emoji": "📈",
                    "tags": ["logarithms", "properties", "change-of-base"],
                    "concept_slugs": [
                        "alg-log-definition",
                        "alg-log-properties",
                        "alg-change-of-base",
                    ],
                    "citation": "OpenStax College Algebra 1e, Sections 6.3 & 6.5",
                    "terms": [
                        {"term": "Logarithm", "definition": "The exponent to which a specified base must be raised to yield a given number: y = log_b(x) <=> b^y = x."},
                        {"term": "Common Logarithm", "definition": "A logarithm with base 10, typically written simply as log(x)."},
                        {"term": "Natural Logarithm", "definition": "A logarithm with base e (Euler's number ~ 2.71828), written as ln(x)."},
                        {"term": "Change of Base Formula", "definition": "An identity stating log_b(x) = ln(x) / ln(b) = log(x) / log(b)."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Definition of a Logarithm\n\n"
                                    "For any base $b > 0$ with $b \\neq 1$, and any positive argument $x > 0$, the logarithmic equation is defined by its exponential equivalence:\n\n"
                                    "$$y = \\log_b(x) \\iff b^y = x$$\n\n"
                                    "Because logarithms are exponents, each law of exponents has an exact counterpart in the **laws of logarithms**:\n\n"
                                    "- **Product Property**: $\\log_b(M \\cdot N) = \\log_b(M) + \\log_b(N)$\n"
                                    "- **Quotient Property**: $\\log_b\\left(\\frac{M}{N}\\right) = \\log_b(M) - \\log_b(N)$\n"
                                    "- **Power Property**: $\\log_b(M^p) = p \\log_b(M)$\n"
                                    "- **Identity Properties**: $\\log_b(b) = 1$ and $\\log_b(1) = 0$\n"
                                    "- **Inverse Properties**: $\\log_b(b^x) = x$ and $b^{\\log_b(x)} = x$ ($x > 0$)\n"
                                    "- **Change-of-Base Formula**: $\\log_b(M) = \\frac{\\log_c(M)}{\\log_c(b)} = \\frac{\\ln(M)}{\\ln(b)} = \\frac{\\log(M)}{\\log(b)}$"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Expanding vs. Condensing",
                                "body": "**Expanding** breaks a single logarithm of a complex product/quotient into a sum and difference of simpler logarithms. **Condensing** combines multiple logarithmic terms into a single logarithm using product, quotient, and power rules.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Exponent Laws vs. Logarithm Laws Correspondence\n\n"
                                    "| Exponent Rule | Corresponding Logarithm Rule | Example |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| $b^m \\cdot b^n = b^{m+n}$ | $\\log_b(MN) = \\log_b(M) + \\log_b(N)$ | $\\log_2(8 \\cdot 4) = \\log_2(8) + \\log_2(4) = 3 + 2 = 5$ |\n"
                                    "| $\\frac{b^m}{b^n} = b^{m-n}$ | $\\log_b(M/N) = \\log_b(M) - \\log_b(N)$ | $\\log_3(81/9) = \\log_3(81) - \\log_3(9) = 4 - 2 = 2$ |\n"
                                    "| $(b^m)^p = b^{mp}$ | $\\log_b(M^p) = p \\log_b(M)$ | $\\log_{10}(100^4) = 4 \\log_{10}(100) = 4(2) = 8$ |\n"
                                    "| $b^0 = 1$ | $\\log_b(1) = 0$ | $\\ln(1) = 0$ |\n"
                                    "| $b^1 = b$ | $\\log_b(b) = 1$ | $\\log_5(5) = 1$ |\n"
                                    "| Arbitrary Base | $\\log_b(x) = \\frac{\\ln x}{\\ln b}$ | $\\log_2(10) = \\frac{\\ln 10}{\\ln 2} \\approx \\frac{2.3026}{0.6931} \\approx 3.3219$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Sound Intensity and Decibel Measurement\n\n"
                                    "A classic real-world model using logarithmic scaling is the measurement of sound loudness in decibels ($dB$). "
                                    "Loudness $L$ is modeled by $L = 10 \\log_{10}\\left(\\frac{I}{I_0}\\right)$, where $I$ is the physical sound intensity (in watts per square meter) and $I_0 = 10^{-12}\\text{ W/m}^2$ is the threshold of human hearing. "
                                    "If a busy street has intensity $I_1 = 10^{-5}\\text{ W/m}^2$ and a jet engine has intensity $I_2 = 10^{2}\\text{ W/m}^2$, we evaluate the decibel difference using the quotient property of logarithms:\n\n"
                                    "$$L_2 - L_1 = 10 \\log_{10}\\left(\\frac{I_2}{I_0}\\right) - 10 \\log_{10}\\left(\\frac{I_1}{I_0}\\right) = 10 \\log_{10}\\left(\\frac{I_2}{I_1}\\right)$$\n\n"
                                    "Substituting values gives $10 \\log_{10}\\left(\\frac{10^2}{10^{-5}}\\right) = 10 \\log_{10}(10^7) = 10(7) = 70\\text{ dB}$ difference."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Logarithm Pitfalls",
                                "body": "1. **Log of a sum**: $\\log_b(x + y) \\neq \\log_b(x) + \\log_b(y)$. The sum of logs is the log of a **product**.\n2. **Quotient of logs**: $\\frac{\\log_b(x)}{\\log_b(y)} \\neq \\log_b(x - y)$ and does NOT equal $\\log_b(x/y)$. Note that $\\frac{\\log_b(x)}{\\log_b(y)} = \\log_y(x)$ by the change-of-base formula.\n3. **Negative arguments**: The domain of $\\log_b(x)$ requires $x > 0$. Expressions like $\\log_2(-4)$ or $\\ln(0)$ are undefined over the real numbers.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Which of the following expressions represents the expanded form of $\\log_2\\left(\\frac{x^3 \\sqrt{y}}{z^4}\\right)$ for all positive real numbers $x, y, z$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "3\\log_2(x) + \\frac{1}{2}\\log_2(y) - 4\\log_2(z)",
                                    "3\\log_2(x) + 2\\log_2(y) - 4\\log_2(z)",
                                    "\\frac{3\\log_2(x) \\cdot \\frac{1}{2}\\log_2(y)}{4\\log_2(z)}",
                                    "3\\log_2(x) - \\frac{1}{2}\\log_2(y) - 4\\log_2(z)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Apply the quotient rule: log_2(x^3 sqrt(y)) - log_2(z^4). Next apply the product rule to the numerator: log_2(x^3) + log_2(y^(1/2)) - log_2(z^4). Finally apply the power rule to bring exponents to the front: 3 log_2(x) + (1/2) log_2(y) - 4 log_2(z).",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 6.5",
                            "concept_slugs": ["alg-log-properties"],
                        },
                        {
                            "prompt": "Condense the expression $2\\ln(x) - \\frac{1}{3}\\ln(y) + \\ln(z)$ into a single logarithm with coefficient 1 for positive real numbers $x, y, z$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "\\ln\\left(\\frac{x^2 \\sqrt[3]{y}}{z}\\right)",
                                    "\\ln\\left(\\frac{x^2 z}{\\sqrt[3]{y}}\\right)",
                                    "\\ln\\left(\\frac{2x z}{\\frac{1}{3}y}\\right)",
                                    "\\ln\\left(x^2 - \\sqrt[3]{y} + z\\right)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "First apply the power rule to move coefficients into exponents: ln(x^2) - ln(y^(1/3)) + ln(z). Next group positive terms: ln(x^2) + ln(z) = ln(x^2 z). Finally apply the quotient rule for the subtracted term: ln[(x^2 z) / y^(1/3)] = ln[(x^2 z) / cbrt(y)].",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax College Algebra 1e, Section 6.5",
                            "concept_slugs": ["alg-log-properties"],
                        },
                        {
                            "prompt": "Evaluate the exact numerical value of the expression $\\log_3(81) - \\log_2\\left(\\frac{1}{8}\\right) + \\ln(e^5)$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "6",
                                    "8",
                                    "12",
                                    "4",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Evaluate each term individually: log_3(81) = 4 because 3^4 = 81; log_2(1/8) = -3 because 2^(-3) = 1/8; ln(e^5) = 5 because ln and e are inverse operations. Substituting back gives: 4 - (-3) + 5 = 4 + 3 + 5 = 12.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 6.3",
                            "concept_slugs": ["alg-log-definition"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the equivalent exponential form of y = log_b(x)?",
                    "back": "b^y = x (where b > 0, b != 1, and x > 0).",
                    "concept_slugs": ["alg-log-definition"],
                },
                {
                    "front": "What does the product rule of logarithms state: log_b(MN)?",
                    "back": "log_b(M) + log_b(N).",
                    "concept_slugs": ["alg-log-properties"],
                },
                {
                    "front": "What is the change-of-base formula for log_b(x)?",
                    "back": "log_b(x) = ln(x) / ln(b) = log(x) / log(b).",
                    "concept_slugs": ["alg-change-of-base"],
                },
            ],
        },
    ],
}
