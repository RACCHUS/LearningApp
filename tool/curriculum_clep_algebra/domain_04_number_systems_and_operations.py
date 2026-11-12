"""Domain 4.0: Number Systems and Operations (Quota: 12 questions, 20% official blueprint).

Covers:
- Real number properties, subsets, and divisibility
- Complex numbers: arithmetic, complex conjugates, and powers of i
- Arithmetic and geometric sequences and series formulas (finite and infinite)
- Factorials, permutations, combinations, and the Binomial Theorem
Authoritative Source: OpenStax College Algebra 1e (CC BY 4.0).
"""
from __future__ import annotations

DOMAIN_04 = {
    "code": "4.0",
    "title": "Number systems and operations",
    "description": "Real number properties, complex numbers and operations, arithmetic and geometric sequences/series, and the Binomial Theorem.",
    "weight": 0.200,
    "sort_order": 4,
    "importance": "core",
    "citation": "College Board CLEP College Algebra Domain 4.0 (20%); OpenStax College Algebra 1e Chapters 1, 2, & 9",
    "objectives": [
        {
            "code": "4.1",
            "title": "Classify real numbers, apply field axioms, and analyze divisibility and prime factorizations",
            "description": "Distinguish rational and irrational numbers, apply commutative, associative, distributive, and identity properties, and find prime factorizations.",
            "sort_order": 1,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 1.1: Real Numbers: Algebra Essentials",
            "concepts": [
                {
                    "slug": "alg-real-number-subsets",
                    "name": "Subsets of the Real Numbers",
                    "short_definition": "Classification into natural numbers, whole numbers, integers, rational numbers, and irrational numbers.",
                    "description": "Rational numbers can be written as a/b (terminating or repeating decimals); irrational numbers cannot be expressed as fractions (non-terminating, non-repeating).",
                    "citation": "OpenStax College Algebra 1e, Section 1.1",
                },
                {
                    "slug": "alg-field-properties",
                    "name": "Field Axioms and Algebraic Properties",
                    "short_definition": "Commutative, associative, distributive, identity, and inverse properties for addition and multiplication.",
                    "description": "The foundational operational axioms of algebra governing real number arithmetic.",
                    "citation": "OpenStax College Algebra 1e, Section 1.1",
                    "prerequisites": ["alg-real-number-subsets"],
                },
                {
                    "slug": "alg-divisibility-primes",
                    "name": "Divisibility and Prime Factorization",
                    "short_definition": "The Fundamental Theorem of Arithmetic and prime factor decomposition.",
                    "description": "Every integer greater than 1 factors uniquely into a product of prime powers, used to find GCF and LCM.",
                    "citation": "OpenStax College Algebra 1e, Section 1.1",
                    "prerequisites": ["alg-real-number-subsets"],
                },
            ],
            "lessons": [
                {
                    "title": "Real Number System and Fundamental Properties",
                    "description": "Classification of real numbers (rational vs. irrational), field axioms (commutative, associative, distributive), and prime factorization.",
                    "emoji": "🔢",
                    "tags": ["real-numbers", "properties", "primes"],
                    "concept_slugs": [
                        "alg-real-number-subsets",
                        "alg-field-properties",
                        "alg-divisibility-primes",
                    ],
                    "citation": "OpenStax College Algebra 1e, Section 1.1",
                    "terms": [
                        {"term": "Rational Number", "definition": "A number that can be expressed as a ratio a/b of two integers with b != 0, yielding a terminating or repeating decimal."},
                        {"term": "Irrational Number", "definition": "A real number that cannot be written as a simple fraction, yielding a non-terminating, non-repeating decimal expansion (e.g. sqrt(2), pi)."},
                        {"term": "Commutative Property", "definition": "The order of addition or multiplication does not affect the result: a + b = b + a and ab = ba."},
                        {"term": "Associative Property", "definition": "The grouping of numbers does not affect the result: (a + b) + c = a + (b + c) and (ab)c = a(bc)."},
                        {"term": "Distributive Property", "definition": "Multiplication distributes across addition: a(b + c) = ab + ac."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Real Number Hierarchy\n\n"
                                    "The set of real numbers $\\mathbb{R}$ is organized into a nested hierarchy of number subsets:\n\n"
                                    "- **Natural Numbers** $\\mathbb{N}$: Counting numbers $\\{1, 2, 3, 4, \\dots\\}$\n"
                                    "- **Whole Numbers** $\\mathbb{W}$: Natural numbers plus zero $\\{0, 1, 2, 3, \\dots\\}$\n"
                                    "- **Integers** $\\mathbb{Z}$: Positive and negative whole numbers $\\{\\dots, -3, -2, -1, 0, 1, 2, 3, \\dots\\}$\n"
                                    "- **Rational Numbers** $\\mathbb{Q}$: Numbers expressible as $\\frac{a}{b}$ where $a, b \\in \\mathbb{Z}$ and $b \\neq 0$. In decimal form, rationals either **terminate** (e.g. $0.75 = 3/4$) or **repeat indefinitely** (e.g. $0.333\\dots = 1/3$).\n"
                                    "- **Irrational Numbers** $\\mathbb{I}$: Real numbers that cannot be expressed as a fraction of integers; their decimal expansions are **non-terminating and non-repeating** (e.g. $\\sqrt{2}, \\sqrt{5}, \\pi, e$).\n\n"
                                    "### Fundamental Field Properties\n\n"
                                    "For all real numbers $a, b, c$:\n"
                                    "- **Commutative**: $a + b = b + a$ and $a \\cdot b = b \\cdot a$\n"
                                    "- **Associative**: $(a + b) + c = a + (b + c)$ and $(ab)c = a(bc)$\n"
                                    "- **Distributive**: $a(b + c) = ab + ac$\n"
                                    "- **Identities**: $a + 0 = a$ (additive identity $0$) and $a \\cdot 1 = a$ (multiplicative identity $1$)\n"
                                    "- **Inverses**: $a + (-a) = 0$ (additive inverse) and $a \\cdot \\frac{1}{a} = 1$ ($a \\neq 0$, multiplicative inverse/reciprocal)"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Commutative vs. Associative",
                                "body": "• **Commutative** changes the **ORDER** of the elements: $a + b = b + a$.\n• **Associative** changes the **GROUPING (parentheses)** while keeping order fixed: $(a + b) + c = a + (b + c)$.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Real Number System Overview\n\n"
                                    "| Subset Name | Symbol | Defining Characteristics | Examples |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Natural** | $\\mathbb{N}$ | Positive counting integers | $1, 2, 100, 450$ |\n"
                                    "| **Whole** | $\\mathbb{W}$ | Non-negative integers | $0, 1, 2, 15$ |\n"
                                    "| **Integers** | $\\mathbb{Z}$ | Signed whole numbers | $-17, -3, 0, 8$ |\n"
                                    "| **Rational** | $\\mathbb{Q}$ | Fraction of integers $a/b$ | $-3/4, 0.625, 0.444\\dots, 7$ |\n"
                                    "| **Irrational** | $\\mathbb{I}$ | Non-repeating decimal | $\\sqrt{3}, \\sqrt{11}, \\pi, e$ |\n"
                                    "| **Real** | $\\mathbb{R}$ | Union of Rationals and Irrationals | All points on continuous number line |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Cryptographic Prime Decomposition\n\n"
                                    "In cybersecurity, public-key encryption relies on the **Fundamental Theorem of Arithmetic**, which states that every composite integer factors uniquely into a product of prime powers. "
                                    "For example, a security hashing algorithm groups access keys based on the prime decomposition of a verification code $N = 360$:\n\n"
                                    "$$360 = 36 \\times 10 = (6^2) \\times (2 \\times 5) = (2 \\times 3)^2 \\times 2 \\times 5 = 2^3 \\times 3^2 \\times 5^1$$\n\n"
                                    "The total number of positive integer divisors of $N$ is calculated directly from the exponents: $(3 + 1)(2 + 1)(1 + 1) = 4 \\times 3 \\times 2 = 24$ divisors. "
                                    "This systematic prime structure ensures predictable and collision-free algebraic partitioning."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Number System Misconceptions",
                                "body": "1. **Square roots are not always irrational**: $\\sqrt{49} = 7$, which is a natural, integer, and rational number! Only square roots of non-perfect squares (e.g. $\\sqrt{50}$) are irrational.\n2. **Repeating decimals are rational**: Numbers like $0.121212\\dots$ are rational numbers ($12/99 = 4/33$). Only decimals that never terminate AND never repeat are irrational.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "id": "alg-sim-identify-irrational-number",
                            "prompt": "Which of the following numbers is an irrational number?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "\\frac{\\sqrt{49}}{7}",
                                    "0.121212\\dots",
                                    "\\sqrt{50}",
                                    "-\\frac{3}{8}",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Evaluate each number: (A) sqrt(49)/7 = 7/7 = 1 (rational); (B) 0.1212... is a repeating decimal = 12/99 = 4/33 (rational); (C) 50 is not a perfect square, so sqrt(50) = 5 sqrt(2) is an irrational number; (D) -3/8 is a ratio of integers (rational).",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 1.1",
                            "concept_slugs": ["alg-real-number-subsets"],
                        },
                        {
                            "id": "alg-sim-distributive-property",
                            "prompt": "Which algebraic field property is demonstrated by the equation $3(x + 4) = 3x + 12$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Commutative property of multiplication",
                                    "Associative property of addition",
                                    "Multiplicative identity property",
                                    "Distributive property of multiplication over addition",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "The distributive property states that a(b + c) = ab + ac. Distributing 3 across the binomial sum (x + 4) yields 3*x + 3*4 = 3x + 12.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax College Algebra 1e, Section 1.1",
                            "concept_slugs": ["alg-field-properties"],
                        },
                        {
                            "id": "alg-sim-prime-factorization-360",
                            "prompt": "What is the unique prime factorization of the integer $360$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "2^3 \\times 3^2 \\times 5",
                                    "2^2 \\times 3^3 \\times 5",
                                    "2^4 \\times 3 \\times 5",
                                    "2^3 \\times 3 \\times 15",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Decompose 360 into prime factors: 360 = 10 * 36 = (2 * 5) * (4 * 9) = 2 * 5 * 2^2 * 3^2 = 2^3 * 3^2 * 5. All bases (2, 3, 5) are prime.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 1.1",
                            "concept_slugs": ["alg-divisibility-primes"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the difference between a rational and an irrational number?",
                    "back": "A rational number can be written as a fraction of integers a/b (terminating or repeating decimal); an irrational number cannot (non-terminating, non-repeating decimal).",
                    "concept_slugs": ["alg-real-number-subsets"],
                },
                {
                    "front": "What does the commutative property of addition state?",
                    "back": "a + b = b + a (the order of terms can be switched without changing the sum).",
                    "concept_slugs": ["alg-field-properties"],
                },
                {
                    "front": "What is the multiplicative inverse (reciprocal) of a non-zero real number a?",
                    "back": "1/a, because a * (1/a) = 1 (the multiplicative identity).",
                    "concept_slugs": ["alg-field-properties"],
                },
            ],
        },
        {
            "code": "4.2",
            "title": "Perform complex number arithmetic, simplify powers of i, and apply complex conjugates",
            "description": "Add, subtract, multiply, and divide complex numbers in standard form a + bi, evaluate cyclic powers of i, and compute the modulus of complex numbers.",
            "sort_order": 2,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 2.4: Complex Numbers",
            "concepts": [
                {
                    "slug": "alg-imaginary-unit",
                    "name": "The Imaginary Unit and Powers of i",
                    "short_definition": "Definition i = sqrt(-1) such that i^2 = -1, exhibiting a 4-step cyclic pattern.",
                    "description": "Powers repeat every 4: i^1 = i, i^2 = -1, i^3 = -i, i^4 = 1. Evaluated by computing exponent mod 4.",
                    "citation": "OpenStax College Algebra 1e, Section 2.4",
                },
                {
                    "slug": "alg-complex-arithmetic",
                    "name": "Complex Arithmetic Operations",
                    "short_definition": "Addition, subtraction, and multiplication of complex numbers in standard form a + bi.",
                    "description": "Combine real parts and imaginary parts; multiply using FOIL and simplify i^2 to -1.",
                    "citation": "OpenStax College Algebra 1e, Section 2.4",
                    "prerequisites": ["alg-imaginary-unit"],
                },
                {
                    "slug": "alg-complex-conjugates",
                    "name": "Complex Conjugates and Division",
                    "short_definition": "The complex conjugate of a + bi is a - bi, with product (a + bi)(a - bi) = a^2 + b^2.",
                    "description": "Division of complex numbers is performed by multiplying numerator and denominator by the conjugate of the denominator.",
                    "citation": "OpenStax College Algebra 1e, Section 2.4",
                    "prerequisites": ["alg-complex-arithmetic"],
                },
            ],
            "lessons": [
                {
                    "title": "Complex Numbers and Imaginary Arithmetic",
                    "description": "Operations with the imaginary unit i, cyclical powers of i, complex addition/multiplication, complex conjugates, and division.",
                    "emoji": "🔮",
                    "tags": ["complex-numbers", "imaginary-unit", "conjugates"],
                    "concept_slugs": [
                        "alg-imaginary-unit",
                        "alg-complex-arithmetic",
                        "alg-complex-conjugates",
                    ],
                    "citation": "OpenStax College Algebra 1e, Section 2.4",
                    "terms": [
                        {"term": "Imaginary Unit i", "definition": "The number defined such that i = sqrt(-1) and i^2 = -1."},
                        {"term": "Complex Number", "definition": "A number in standard form a + bi, where a is the real part and b is the imaginary part."},
                        {"term": "Complex Conjugate", "definition": "For a complex number z = a + bi, its conjugate is z* = a - bi."},
                        {"term": "Modulus (Absolute Value)", "definition": "The distance of a complex number from the origin in the complex plane: |a + bi| = sqrt(a^2 + b^2)."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Imaginary Unit and Cyclic Powers of $i$\n\n"
                                    "The **imaginary unit** $i$ is defined such that $i = \\sqrt{-1}$ and $i^2 = -1$. "
                                    "Higher integer powers of $i$ follow a clean **4-step repeating cycle**:\n\n"
                                    "- $i^1 = i$\n"
                                    "- $i^2 = -1$\n"
                                    "- $i^3 = i^2 \\cdot i = (-1)i = -i$\n"
                                    "- $i^4 = (i^2)^2 = (-1)^2 = 1$\n\n"
                                    "To evaluate $i^n$ for any positive integer $n$, divide $n$ by $4$ and look at the remainder $r$: $i^n = i^r$ (where a remainder of $0$ corresponds to $i^4 = 1$).\n\n"
                                    "### Complex Arithmetic in Standard Form $a + bi$\n\n"
                                    "- **Addition/Subtraction**: $(a + bi) \\pm (c + di) = (a \\pm c) + (b \\pm d)i$\n"
                                    "- **Multiplication**: Apply the distributive property (FOIL), then replace $i^2$ with $-1$:\n"
                                    "$$(a + bi)(c + di) = ac + adi + bci + bdi^2 = (ac - bd) + (ad + bc)i$$\n"
                                    "- **Division**: Multiply numerator and denominator by the **complex conjugate** of the denominator $(c - di)$:\n"
                                    "$$\\frac{a + bi}{c + di} = \\frac{(a + bi)(c - di)}{(c + di)(c - di)} = \\frac{(ac + bd) + (bc - ad)i}{c^2 + d^2}$$"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Conjugate Product Property",
                                "body": "Multiplying any complex number by its conjugate ALWAYS yields a non-negative real number: $(a + bi)(a - bi) = a^2 - (bi)^2 = a^2 - b^2(-1) = a^2 + b^2$. Notice there is no $i$ remaining!",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Cyclic Powers of $i$ Calculation Reference\n\n"
                                    "| Exponent $\\div 4$ Remainder | Equivalent Power | Simplified Value | Example |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| Remainder $1$ | $i^1$ | $i$ | $i^{25} = i^{4(6) + 1} = i$ |\n"
                                    "| Remainder $2$ | $i^2$ | $-1$ | $i^{50} = i^{4(12) + 2} = -1$ |\n"
                                    "| Remainder $3$ | $i^3$ | $-i$ | $i^{75} = i^{4(18) + 3} = -i$ |\n"
                                    "| Remainder $0$ | $i^4$ | $1$ | $i^{100} = i^{4(25) + 0} = 1$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Alternating Current Electrical Impedance\n\n"
                                    "Electrical engineers model alternating current (AC) circuit resistance and reactance using complex impedance $Z = R + X i$, where $R$ is resistance in ohms and $X$ is reactance. "
                                    "By Ohm's Law for AC circuits, voltage $V$ equals current $I$ times impedance $Z$: $V = I \\cdot Z$. "
                                    "If a circuit carries current $I = 3 - 2i$ amperes and has impedance $Z = 4 + 5i$ ohms, we calculate the total voltage $V$:\n\n"
                                    "$$V = (3 - 2i)(4 + 5i) = 12 + 15i - 8i - 10i^2 = 12 + 7i - 10(-1) = 22 + 7i\\text{ volts}$$\n\n"
                                    "The magnitude (modulus) of the voltage is $|V| = \\sqrt{22^2 + 7^2} = \\sqrt{484 + 49} = \\sqrt{533} \\approx 23.09$ volts."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Complex Number Pitfalls",
                                "body": "1. **Multiplying negative radicals**: $\\sqrt{-4} \\cdot \\sqrt{-9} \\neq \\sqrt{36} = 6$. You MUST convert to $i$ notation first: $\\sqrt{-4} \\cdot \\sqrt{-9} = (2i)(3i) = 6i^2 = -6$.\n2. **Conjugate sign**: The complex conjugate of $a + bi$ changes the sign of the IMAGINARY part only ($a - bi$). Do NOT change the sign of $a$!",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "id": "alg-sim-power-of-imaginary-unit",
                            "prompt": "Evaluate the value of the power $i^{75}$, where $i = \\sqrt{-1}$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "1",
                                    "-i",
                                    "i",
                                    "-1",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Divide the exponent 75 by 4: 75 = 4 * 18 + 3. The remainder is 3. Since powers of i cycle every 4 powers, i^75 = i^3 = i^2 * i = (-1) * i = -i.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 2.4",
                            "concept_slugs": ["alg-imaginary-unit"],
                        },
                        {
                            "id": "alg-sim-multiply-complex-numbers",
                            "prompt": "Multiply the complex numbers $(3 - 2i)(4 + 5i)$ and write the result in standard form $a + bi$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "2 + 7i",
                                    "12 - 10i",
                                    "22 + 7i",
                                    "22 - 7i",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Expand using FOIL: (3)(4) + (3)(5i) + (-2i)(4) + (-2i)(5i) = 12 + 15i - 8i - 10i^2. Since i^2 = -1, this becomes 12 + 7i - 10(-1) = 12 + 7i + 10 = 22 + 7i.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 2.4",
                            "concept_slugs": ["alg-complex-arithmetic"],
                        },
                        {
                            "id": "alg-sim-divide-complex-numbers",
                            "prompt": "Divide the complex numbers $\\frac{5 + i}{2 - 3i}$ and express the quotient in standard form $a + bi$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "\\frac{7}{5} + \\frac{17}{5}i",
                                    "\\frac{5}{13} + \\frac{15}{13}i",
                                    "\\frac{13}{13} + \\frac{17}{13}i",
                                    "\\frac{7}{13} + \\frac{17}{13}i",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Multiply numerator and denominator by the conjugate of the denominator, (2 + 3i): [(5 + i)(2 + 3i)] / [(2 - 3i)(2 + 3i)]. Numerator: 10 + 15i + 2i + 3i^2 = 10 + 17i - 3 = 7 + 17i. Denominator: 2^2 + 3^2 = 4 + 9 = 13. Dividing gives 7/13 + (17/13)i.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 2.4",
                            "concept_slugs": ["alg-complex-conjugates"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the definition of i and what is i^2?",
                    "back": "i = sqrt(-1), and i^2 = -1.",
                    "concept_slugs": ["alg-imaginary-unit"],
                },
                {
                    "front": "How do you divide two complex numbers: (a + bi) / (c + di)?",
                    "back": "Multiply numerator and denominator by the complex conjugate of the denominator, (c - di).",
                    "concept_slugs": ["alg-complex-conjugates"],
                },
                {
                    "front": "What is the value of (3 + 4i)(3 - 4i)?",
                    "back": "3^2 + 4^2 = 9 + 16 = 25.",
                    "concept_slugs": ["alg-complex-conjugates"],
                },
            ],
        },
        {
            "code": "4.3",
            "title": "Evaluate arithmetic and geometric sequences and calculate finite and infinite series sums",
            "description": "Find nth terms of arithmetic and geometric sequences, compute partial sums of arithmetic and geometric series, and determine convergence of infinite geometric series.",
            "sort_order": 3,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 9.1: Sequences and Notations; Section 9.2: Arithmetic Sequences; Section 9.3: Geometric Sequences",
            "concepts": [
                {
                    "slug": "alg-arithmetic-sequences",
                    "name": "Arithmetic Sequences and Series",
                    "short_definition": "Sequences with constant difference d; an = a1 + (n - 1)d and sum Sn = n/2(a1 + an).",
                    "description": "Linear growth pattern; partial sum equals average of first and last terms multiplied by number of terms.",
                    "citation": "OpenStax College Algebra 1e, Section 9.2",
                },
                {
                    "slug": "alg-geometric-sequences",
                    "name": "Geometric Sequences and Finite Series",
                    "short_definition": "Sequences with constant ratio r; an = a1 * r^(n - 1) and sum Sn = a1(1 - r^n) / (1 - r).",
                    "description": "Exponential growth or decay pattern where each term is multiplied by common ratio r.",
                    "citation": "OpenStax College Algebra 1e, Section 9.3",
                    "prerequisites": ["alg-arithmetic-sequences"],
                },
                {
                    "slug": "alg-infinite-geometric-series",
                    "name": "Infinite Geometric Series Convergence",
                    "short_definition": "An infinite geometric series converges if and only if |r| < 1, with sum S_inf = a1 / (1 - r).",
                    "description": "If |r| >= 1, the infinite series diverges and has no finite sum.",
                    "citation": "OpenStax College Algebra 1e, Section 9.3",
                    "prerequisites": ["alg-geometric-sequences"],
                },
            ],
            "lessons": [
                {
                    "title": "Arithmetic and Geometric Sequences and Series",
                    "description": "General nth term formulas for arithmetic and geometric sequences, finite series summation formulas, and infinite geometric series convergence.",
                    "emoji": "🔄",
                    "tags": ["sequences", "series", "geometric-series", "convergence"],
                    "concept_slugs": [
                        "alg-arithmetic-sequences",
                        "alg-geometric-sequences",
                        "alg-infinite-geometric-series",
                    ],
                    "citation": "OpenStax College Algebra 1e, Sections 9.1, 9.2, & 9.3",
                    "terms": [
                        {"term": "Sequence", "definition": "An ordered list of numbers a1, a2, a3, ..., an defined by a rule or formula."},
                        {"term": "Common Difference (d)", "definition": "In an arithmetic sequence, the constant value d = a_(k+1) - a_k added to each term to produce the next."},
                        {"term": "Common Ratio (r)", "definition": "In a geometric sequence, the constant ratio r = a_(k+1) / a_k by which each term is multiplied to produce the next."},
                        {"term": "Series", "definition": "The sum of the terms of a sequence, often written with summation notation Sigma."},
                        {"term": "Infinite Geometric Series", "definition": "A sum a1 + a1 r + a1 r^2 + ... that converges to a1 / (1 - r) if and only if |r| < 1."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Arithmetic Sequences and Series\n\n"
                                    "An **arithmetic sequence** progresses by adding a constant **common difference** $d$ to each successive term:\n\n"
                                    "- **$n$-th term formula**: $a_n = a_1 + (n - 1)d$\n"
                                    "- **Finite arithmetic series sum**: The sum of the first $n$ terms $S_n = \\sum_{k=1}^n a_k$ is given by:\n"
                                    "$$S_n = \\frac{n}{2}(a_1 + a_n) = \\frac{n}{2}[2a_1 + (n - 1)d]$$\n\n"
                                    "### Geometric Sequences and Series\n\n"
                                    "A **geometric sequence** progresses by multiplying each term by a constant **common ratio** $r \\neq 0$:\n\n"
                                    "- **$n$-th term formula**: $a_n = a_1 \\cdot r^{n - 1}$\n"
                                    "- **Finite geometric series sum**: For $r \\neq 1$, the sum of the first $n$ terms is:\n"
                                    "$$S_n = \\frac{a_1(1 - r^n)}{1 - r}$$\n"
                                    "- **Infinite geometric series**: As $n \\to \\infty$, $r^n \\to 0$ if and only if $|r| < 1$. The infinite sum converges to:\n"
                                    "$$S_\\infty = \\frac{a_1}{1 - r}\\quad (|r| < 1)$$\n"
                                    "If $|r| \\geq 1$, the infinite series **diverges**."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Convergence Criterion for Infinite Series",
                                "body": "An infinite geometric series converges to a finite number IF AND ONLY IF $|r| < 1$ ($-1 < r < 1$). If $r = 1.05$ or $r = -2$, the series diverges and the formula $a_1 / (1 - r)$ is INVALID.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Sequences and Series Formulas Master Matrix\n\n"
                                    "| Feature | Arithmetic Progression | Geometric Progression |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Defining Property** | Constant difference $d = a_{n+1} - a_n$ | Constant ratio $r = a_{n+1}/a_n$ |\n"
                                    "| **$n$-th Term ($a_n$)** | $a_n = a_1 + (n - 1)d$ | $a_n = a_1 r^{n-1}$ |\n"
                                    "| **Finite Sum ($S_n$)** | $S_n = \\frac{n}{2}(a_1 + a_n)$ | $S_n = \\frac{a_1(1 - r^n)}{1 - r}$ |\n"
                                    "| **Infinite Sum ($S_\\infty$)** | Diverges (unless all $a_k = 0$) | $S_\\infty = \\frac{a_1}{1 - r}$ ($|r| < 1$) |\n"
                                    "| **Growth Nature** | Linear growth | Exponential growth/decay |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Bouncing Ball Infinite Distance Model\n\n"
                                    "A tennis ball is dropped from an initial height of $12$ meters. "
                                    "On each subsequent bounce, it rebounds to exactly $\\frac{1}{3}$ of its previous height. "
                                    "We model the total vertical distance traveled by the ball before coming to rest. "
                                    "The initial drop is $12$ meters. On each subsequent bounce $k$, the ball travels up and down: $2 \\cdot 12(1/3)^k = 24(1/3)^k$. "
                                    "The total distance is:\n\n"
                                    "$$D = 12 + \\sum_{k=1}^\\infty 24\\left(\\frac{1}{3}\\right)^k = 12 + \\frac{24(1/3)}{1 - 1/3} = 12 + \\frac{8}{2/3} = 12 + 12 = 24\\text{ meters}$$\n\n"
                                    "Because $|r| = 1/3 < 1$, the infinite geometric series converges to an exact finite total distance of $24$ meters."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Sequence and Series Pitfalls",
                                "body": "1. **Off-by-one in geometric power**: The $n$-th term is $a_1 r^{n-1}$, NOT $a_1 r^n$. For instance, the first term ($n = 1$) is $a_1 r^0 = a_1$.\n2. **Divergent series trap**: Applying $S = a_1 / (1 - r)$ when $r = 2$ gives $S = a_1 / (1 - 2) = -a_1$, which is absurd for positive terms. Always check $|r| < 1$ first.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "id": "alg-sim-arithmetic-sequence-nth-term",
                            "prompt": "Find the 20th term ($a_{20}$) of an arithmetic sequence whose first term is $a_1 = 7$ and whose common difference is $d = 4$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "83",
                                    "87",
                                    "80",
                                    "79",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Use the arithmetic sequence formula: a_n = a_1 + (n - 1)d. For n = 20: a_20 = 7 + (20 - 1)(4) = 7 + (19)(4) = 7 + 76 = 83.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 9.2",
                            "concept_slugs": ["alg-arithmetic-sequences"],
                        },
                        {
                            "id": "alg-sim-arithmetic-series-sum",
                            "prompt": "Calculate the sum of the first 30 terms of the arithmetic series $\\sum_{k=1}^{30} (3k - 2)$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "1305",
                                    "1335",
                                    "1365",
                                    "1410",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Find first term: a_1 = 3(1) - 2 = 1. Find 30th term: a_30 = 3(30) - 2 = 90 - 2 = 88. Use arithmetic series sum formula S_n = (n/2)(a_1 + a_n): S_30 = (30/2)(1 + 88) = 15(89) = 1335.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 9.2",
                            "concept_slugs": ["alg-arithmetic-sequences"],
                        },
                        {
                            "id": "alg-sim-infinite-geometric-series-sum",
                            "prompt": "Evaluate the exact sum of the infinite geometric series $12 + 4 + \\frac{4}{3} + \\frac{4}{9} + \\dots$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "16",
                                    "24",
                                    "18",
                                    "20",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Identify first term a_1 = 12 and common ratio r = 4/12 = 1/3. Since |r| = 1/3 < 1, the infinite geometric series converges. Use sum formula S_inf = a_1 / (1 - r): S_inf = 12 / (1 - 1/3) = 12 / (2/3) = 12 * (3/2) = 18.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 9.3",
                            "concept_slugs": ["alg-infinite-geometric-series"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the formula for the nth term of an arithmetic sequence?",
                    "back": "a_n = a_1 + (n - 1)d",
                    "concept_slugs": ["alg-arithmetic-sequences"],
                },
                {
                    "front": "What is the formula for the nth term of a geometric sequence?",
                    "back": "a_n = a_1 * r^(n - 1)",
                    "concept_slugs": ["alg-geometric-sequences"],
                },
                {
                    "front": "Under what condition does an infinite geometric series converge, and what is its sum?",
                    "back": "It converges if and only if |r| < 1; its sum is S_inf = a_1 / (1 - r).",
                    "concept_slugs": ["alg-infinite-geometric-series"],
                },
            ],
        },
        {
            "code": "4.4",
            "title": "Apply factorials, permutations, combinations, and the Binomial Theorem",
            "description": "Compute factorials and combinations nCr, apply the Binomial Theorem to expand powers of binomials, and find specific coefficients and terms.",
            "sort_order": 4,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 9.5: Counting Principles; Section 9.6: The Binomial Theorem",
            "concepts": [
                {
                    "slug": "alg-factorials-permutations",
                    "name": "Factorials and Permutations",
                    "short_definition": "Factorial n! = n(n-1)...(1) with 0! = 1; permutations P(n, r) where order matters.",
                    "description": "P(n, r) = n! / (n - r)! represents arrangements of r distinct items selected from n items.",
                    "citation": "OpenStax College Algebra 1e, Section 9.5",
                },
                {
                    "slug": "alg-combinations",
                    "name": "Combinations and Binomial Coefficients",
                    "short_definition": "Combinations C(n, r) = n! / [r!(n - r)!] where selection order does not matter.",
                    "description": "Identical to binomial coefficients (n choose r) appearing in Pascal's triangle.",
                    "citation": "OpenStax College Algebra 1e, Section 9.5",
                    "prerequisites": ["alg-factorials-permutations"],
                },
                {
                    "slug": "alg-binomial-theorem",
                    "name": "The Binomial Theorem",
                    "short_definition": "Formula (a + b)^n = Sum_{k=0}^n (n choose k) a^(n-k) b^k for expanding binomial powers.",
                    "description": "Allows finding any individual term in an expansion without multiplying out the entire polynomial.",
                    "citation": "OpenStax College Algebra 1e, Section 9.6",
                    "prerequisites": ["alg-combinations"],
                },
            ],
            "lessons": [
                {
                    "title": "Combinatorics and the Binomial Theorem",
                    "description": "Factorial definitions, permutations vs. combinations, Pascal's triangle, and algebraic expansion via the Binomial Theorem.",
                    "emoji": "🎲",
                    "tags": ["combinatorics", "permutations", "combinations", "binomial-theorem"],
                    "concept_slugs": [
                        "alg-factorials-permutations",
                        "alg-combinations",
                        "alg-binomial-theorem",
                    ],
                    "citation": "OpenStax College Algebra 1e, Sections 9.5 & 9.6",
                    "terms": [
                        {"term": "Factorial (n!)", "definition": "The product of all positive integers less than or equal to n: n! = n * (n - 1) * ... * 1, with 0! = 1."},
                        {"term": "Permutation P(n, r)", "definition": "The number of ways to arrange r distinct objects selected from a set of n objects where ORDER MATTERS: P(n, r) = n! / (n - r)!."},
                        {"term": "Combination C(n, r)", "definition": "The number of ways to select r objects from a set of n objects where ORDER DOES NOT MATTER: C(n, r) = n! / [r!(n - r)!]."},
                        {"term": "Binomial Theorem", "definition": "The algebraic theorem stating (a + b)^n = Sum_{k=0}^n (n choose k) a^(n-k) b^k."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Factorials and Counting Principles\n\n"
                                    "The **factorial** of a non-negative integer $n$ is defined as $n! = n(n - 1)(n - 2) \\dots (2)(1)$, with the special convention **$0! = 1$**. "
                                    "Two foundational counting formulas govern selection of $r$ objects from $n$ available objects:\n\n"
                                    "- **Permutation (Order Matters)**: Used for rankings, positions, sequences:\n"
                                    "$$P(n, r) = \\frac{n!}{(n - r)!}$$\n"
                                    "- **Combination (Order Does NOT Matter)**: Used for groups, committees, subsets:\n"
                                    "$$\\binom{n}{r} = C(n, r) = \\frac{n!}{r!(n - r)!}$$\n\n"
                                    "### The Binomial Theorem\n\n"
                                    "For any positive integer $n$ and algebraic terms $a, b$, the expansion of $(a + b)^n$ is given by:\n\n"
                                    "$$(a + b)^n = \\sum_{k=0}^n \\binom{n}{k} a^{n - k} b^k = \\binom{n}{0}a^n + \\binom{n}{1}a^{n-1}b + \\binom{n}{2}a^{n-2}b^2 + \\dots + \\binom{n}{n}b^n$$\n\n"
                                    "The $(k + 1)$-th term of the expansion is given specifically by the formula $\\binom{n}{k} a^{n - k} b^k$."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Permutation vs. Combination Decision",
                                "body": "Ask: *Does changing the order create a different outcome?*\n• **YES** (e.g. 1st, 2nd, 3rd place, or passcode digits) $\\implies$ **Permutation** $P(n, r)$.\n• **NO** (e.g. choosing 3 people for a committee or 5 cards in a hand) $\\implies$ **Combination** $C(n, r)$.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Pascal's Triangle and Binomial Coefficients\n\n"
                                    "| Row $n$ | Pascal's Triangle Numbers | Binomial Expansion $(a + b)^n$ |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| $n = 0$ | $1$ | $(a + b)^0 = 1$ |\n"
                                    "| $n = 1$ | $1 \\quad 1$ | $(a + b)^1 = a + b$ |\n"
                                    "| $n = 2$ | $1 \\quad 2 \\quad 1$ | $(a + b)^2 = a^2 + 2ab + b^2$ |\n"
                                    "| $n = 3$ | $1 \\quad 3 \\quad 3 \\quad 1$ | $(a + b)^3 = a^3 + 3a^2 b + 3ab^2 + b^3$ |\n"
                                    "| $n = 4$ | $1 \\quad 4 \\quad 6 \\quad 4 \\quad 1$ | $(a + b)^4 = a^4 + 4a^3 b + 6a^2 b^2 + 4ab^3 + b^4$ |\n"
                                    "| $n = 5$ | $1 \\quad 5 \\quad 10 \\quad 10 \\quad 5 \\quad 1$ | $(a + b)^5 = a^5 + 5a^4 b + 10a^3 b^2 + 10a^2 b^3 + 5ab^4 + b^5$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Committee Selection and Routing Combinations\n\n"
                                    "A university academic senate forms a cross-disciplinary steering committee. "
                                    "From a candidate pool of $8$ faculty members and $6$ student representatives, the senate must select a committee of $3$ faculty and $2$ students. "
                                    "Because individual committee roles are not ranked (order does not matter), we apply the Fundamental Counting Principle with combinations:\n\n"
                                    "$$N = \\binom{8}{3} \\times \\binom{6}{2} = \\frac{8 \\times 7 \\times 6}{3 \\times 2 \\times 1} \\times \\frac{6 \\times 5}{2 \\times 1} = 56 \\times 15 = 840\\text{ possible committees}$$\n\n"
                                    "This combinatorial model illustrates how combinations quantify multi-stage group selection."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Binomial Expansion Pitfalls",
                                "body": "1. **Negative signs in binomials**: When expanding $(2x - 3)^4$, set $a = 2x$ and $b = -3$. Odd powers of $b$ will produce negative signs: $(2x)^3(-3)^1 = 8x^3(-3) = -24x^3$.\n2. **Off-by-one in finding the $r$-th term**: The 4th term corresponds to $k = 3$ in $\\binom{n}{k} a^{n-k} b^k$, because the expansion starts at $k = 0$.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "id": "alg-sim-evaluate-combination-8-choose-3",
                            "prompt": "Evaluate the combination $\\binom{8}{3}$, which represents the number of ways to choose 3 items from a set of 8.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "24",
                                    "336",
                                    "28",
                                    "56",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Use the combination formula C(8, 3) = 8! / [3!(8 - 3)!] = 8! / (3! 5!) = (8 * 7 * 6) / (3 * 2 * 1) = 336 / 6 = 56.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 9.5",
                            "concept_slugs": ["alg-combinations"],
                        },
                        {
                            "id": "alg-sim-binomial-expansion-coefficient",
                            "prompt": "Find the numerical coefficient of the $x^3$ term in the binomial expansion of $(2x - 1)^5$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "80",
                                    "-80",
                                    "40",
                                    "-40",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "In (a + b)^5 with a = 2x and b = -1, the general term is C(5, k) a^(5 - k) b^k. To obtain x^3, we need a^3 = (2x)^3, which means 5 - k = 3 => k = 2. Compute the term: C(5, 2) * (2x)^3 * (-1)^2 = [5! / (2! 3!)] * (8x^3) * (1) = 10 * 8x^3 = 80x^3. The coefficient is 80.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 9.6",
                            "concept_slugs": ["alg-binomial-theorem"],
                        },
                        {
                            "id": "alg-sim-ordered-medal-permutations",
                            "prompt": "In a regional track meet with 10 competitors, how many different ways can the 1st, 2nd, and 3rd place medals be awarded?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "120",
                                    "720",
                                    "240",
                                    "1000",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Because medal positions represent distinct rankings (1st, 2nd, 3rd), order matters, so this is a permutation P(10, 3) = 10! / (10 - 3)! = 10! / 7! = 10 * 9 * 8 = 720 ways.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 9.5",
                            "concept_slugs": ["alg-factorials-permutations"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the key difference between a permutation and a combination?",
                    "back": "In a permutation, ORDER MATTERS (P(n, r) = n!/(n-r)!); in a combination, ORDER DOES NOT MATTER (C(n, r) = n!/[r!(n-r)!]).",
                    "concept_slugs": ["alg-factorials-permutations", "alg-combinations"],
                },
                {
                    "front": "What is the value of 0! by definition?",
                    "back": "0! = 1.",
                    "concept_slugs": ["alg-factorials-permutations"],
                },
                {
                    "front": "In the expansion of (a + b)^n using the Binomial Theorem, what is the formula for the (k + 1)-th term?",
                    "back": "C(n, k) * a^(n - k) * b^k",
                    "concept_slugs": ["alg-binomial-theorem"],
                },
            ],
        },
    ],
}
