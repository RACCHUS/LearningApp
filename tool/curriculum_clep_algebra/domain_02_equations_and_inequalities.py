"""Domain 2.0: Equations and Inequalities (Quota: 15 questions, 25% official blueprint).

Covers:
- Linear equations, slope-intercept applications, and linear inequalities
- Quadratic equations: factoring, quadratic formula, and discriminant analysis
- Radical, rational, and absolute value equations (extraneous roots)
- Systems of linear and non-linear equations in two variables
- Exponential and logarithmic equations and applied growth/decay models
Authoritative Source: OpenStax College Algebra 1e (CC BY 4.0).
"""
from __future__ import annotations

DOMAIN_02 = {
    "code": "2.0",
    "title": "Equations and inequalities",
    "description": "Linear, quadratic, radical, rational, absolute value, exponential, and logarithmic equations; inequalities and systems.",
    "weight": 0.250,
    "sort_order": 2,
    "importance": "core",
    "citation": "College Board CLEP College Algebra Domain 2.0 (25%); OpenStax College Algebra 1e Chapters 2, 6, & 7",
    "objectives": [
        {
            "code": "2.1",
            "title": "Solve linear equations, formulate real-world linear models, and solve linear inequalities",
            "description": "Solve multi-step linear equations in one variable, apply slope-intercept models to practical scenarios, and express linear inequality solutions in interval notation.",
            "sort_order": 1,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 2.1: Linear Equations; Section 2.2: Linear Models; Section 2.7: Linear Inequalities",
            "concepts": [
                {
                    "slug": "alg-linear-equations",
                    "name": "Solving Linear Equations in One Variable",
                    "short_definition": "Algebraic methods for solving equations of the form ax + b = c using inverse operations.",
                    "description": "Clearing denominators with the LCD, expanding parentheses with the distributive property, collecting like terms, and isolating the variable.",
                    "citation": "OpenStax College Algebra 1e, Section 2.1",
                },
                {
                    "slug": "alg-linear-models",
                    "name": "Linear Applications and Rate Models",
                    "short_definition": "Translating verbal descriptions into linear equations y = mx + b where m represents constant rate of change and b represents initial value.",
                    "description": "Formulating models for cost, revenue, distance-rate-time, and mixture problems.",
                    "citation": "OpenStax College Algebra 1e, Section 2.2",
                    "prerequisites": ["alg-linear-equations"],
                },
                {
                    "slug": "alg-linear-inequalities",
                    "name": "Linear Inequalities and Interval Notation",
                    "short_definition": "Solving single and compound linear inequalities and representing solution sets in interval notation.",
                    "description": "Remembering to reverse inequality direction when multiplying or dividing by a negative number. Representing solutions using parentheses and brackets.",
                    "citation": "OpenStax College Algebra 1e, Section 2.7",
                    "prerequisites": ["alg-linear-equations"],
                },
            ],
            "lessons": [
                {
                    "title": "Linear Equations, Applications, and Inequalities",
                    "description": "Techniques for solving multi-step linear equations, building linear rate models, and solving compound inequalities in interval notation.",
                    "emoji": "📏",
                    "tags": ["linear-equations", "inequalities", "applications"],
                    "concept_slugs": [
                        "alg-linear-equations",
                        "alg-linear-models",
                        "alg-linear-inequalities",
                    ],
                    "citation": "OpenStax College Algebra 1e, Sections 2.1, 2.2, & 2.7",
                    "terms": [
                        {"term": "Linear Equation", "definition": "An equation in which the highest power of the variable is 1, in standard form ax + b = 0 with a != 0."},
                        {"term": "Identity Equation", "definition": "An equation that is true for all values in the domain, having infinitely many real solutions."},
                        {"term": "Contradiction Equation", "definition": "An equation that is never true for any value, having no solution (empty set)."},
                        {"term": "Interval Notation", "definition": "A standard mathematical notation using brackets [ ] for included endpoints and parentheses ( ) for excluded endpoints to represent intervals of numbers."},
                        {"term": "Inequality Reversal Rule", "definition": "The algebraic principle stating that multiplying or dividing both sides of an inequality by a negative quantity reverses the direction of the inequality sign."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Solving Linear Equations in One Variable\n\n"
                                    "A **linear equation in one variable** can be written in the form $ax + b = c$, where $a, b, c$ are real numbers and $a \\neq 0$. "
                                    "Solving linear equations follows a clear systematic protocol:\n\n"
                                    "1. **Clear fractions**: Multiply every term on both sides by the least common denominator (LCD).\n"
                                    "2. **Simplify each side**: Distribute across parentheses and combine like terms.\n"
                                    "3. **Isolate variable terms**: Use addition/subtraction to place all variable terms on one side and constant terms on the other.\n"
                                    "4. **Isolate the variable**: Divide or multiply by the variable's coefficient.\n"
                                    "5. **Classify outcome**: A unique solution ($x = k$, conditional); true statement ($0 = 0$, identity / infinitely many solutions); or false statement ($0 = 7$, contradiction / no solution).\n\n"
                                    "### Linear Inequalities and Interval Notation\n\n"
                                    "Solving linear inequalities follows identical addition and subtraction properties as equations. "
                                    "However, the **fundamental inequality rule** dictates: *multiplying or dividing both sides of an inequality by a negative number reverses the inequality symbol* ($<$ becomes $>$, and $\\leq$ becomes $\\geq$)."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Inequality Symbol Reversal",
                                "body": "Whenever you multiply or divide both sides of an inequality by a negative real number, you MUST flip the direction of the inequality: $-2x < 10 \\implies x > -5$.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Interval Notation and Inequality Representations\n\n"
                                    "| Inequality | Interval Notation | Number Line Representation |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| $x > a$ | $(a, \\infty)$ | Open circle at $a$, shaded right toward $+\\infty$ |\n"
                                    "| $x \\geq a$ | $[a, \\infty)$ | Closed circle at $a$, shaded right toward $+\\infty$ |\n"
                                    "| $x < b$ | $(-\\infty, b)$ | Open circle at $b$, shaded left toward $-\\infty$ |\n"
                                    "| $x \\leq b$ | $(-\\infty, b]$ | Closed circle at $b$, shaded left toward $-\\infty$ |\n"
                                    "| $a < x < b$ | $(a, b)$ | Open circles at $a$ and $b$, segment between shaded |\n"
                                    "| $a \\leq x \\leq b$ | $[a, b]$ | Closed circles at $a$ and $b$, segment between shaded |\n"
                                    "| $x < a$ or $x \\geq b$ | $(-\\infty, a) \\cup [b, \\infty)$ | Disjoint union of two rays |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Linear Cost-Volume-Profit Decision Model\n\n"
                                    "A commercial print shop produces customized academic study manuals. "
                                    "The fixed overhead costs (facility lease, machinery depreciation) are $\\$1,800$ per month, while the variable cost to print and bind each manual is $\\$4.50$. "
                                    "The business sells each manual for $\\$12.00$. We formulate the monthly profit model $P(x)$ as revenue minus total cost:\n\n"
                                    "$$P(x) = R(x) - C(x) = 12.00x - (4.50x + 1800) = 7.50x - 1800$$\n\n"
                                    "To find the break-even production volume (where profit is zero), we set $P(x) = 0$:\n\n"
                                    "$$7.50x - 1800 = 0 \\implies 7.50x = 1800 \\implies x = \\frac{1800}{7.50} = 240\\text{ manuals}$$\n\n"
                                    "If the print shop wants a minimum monthly profit of at least $\\$1,200$, we set up the linear inequality $7.50x - 1800 \\geq 1200 \\implies 7.50x \\geq 3000 \\implies x \\geq 400$ manuals."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Linear Equation Pitfalls",
                                "body": "1. **Distributing negative signs**: In an expression like $5 - (2x - 3)$, the negative sign must distribute to BOTH terms: $5 - 2x + 3 = 8 - 2x$.\n2. **Fraction multiplication**: When clearing fractions by multiplying by the LCD, ensure that EVERY single term on both sides is multiplied by the LCD, including constant terms with denominator 1.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Solve the linear equation $\\frac{2x - 3}{4} - \\frac{x + 1}{6} = 2$ for $x$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "x = \\frac{27}{4}",
                                    "x = \\frac{29}{4}",
                                    "x = \\frac{31}{4}",
                                    "x = \\frac{35}{4}",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Multiply the entire equation by the LCD of 4 and 6, which is 12: 12 * [(2x - 3)/4] - 12 * [(x + 1)/6] = 12 * 2. This simplifies to 3(2x - 3) - 2(x + 1) = 24. Distribute: 6x - 9 - 2x - 2 = 24. Combine like terms: 4x - 11 = 24. Add 11 to both sides: 4x = 35. Divide by 4: x = 35/4.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 2.1",
                            "concept_slugs": ["alg-linear-equations"],
                        },
                        {
                            "prompt": "What is the solution set in interval notation for the compound inequality $-3 \\leq 2x - 7 < 5$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "[2, 6)",
                                    "[-2, 6)",
                                    "(2, 6]",
                                    "[-3, 5)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Add 7 to all three parts: -3 + 7 <= 2x < 5 + 7, which gives 4 <= 2x < 12. Divide all three parts by 2: 2 <= x < 6. In interval notation, the inclusive lower bound is marked with a bracket [2, and the strict upper bound is marked with a parenthesis 6), yielding [2, 6).",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax College Algebra 1e, Section 2.7",
                            "concept_slugs": ["alg-linear-inequalities"],
                        },
                        {
                            "prompt": "A rideshare service charges a flat reservation fee of $\\$3.50$ plus $\\$2.25$ per mile traveled. A traveler has a strict maximum budget of $\\$26.00$. What is the maximum integer number of whole miles the traveler can travel?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "9 miles",
                                    "10 miles",
                                    "11 miles",
                                    "12 miles",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Let m be the number of miles. The linear cost model is C(m) = 3.50 + 2.25m <= 26.00. Subtract 3.50 from both sides: 2.25m <= 22.50. Divide by 2.25: m <= 10. Thus, the traveler can travel a maximum of 10 whole miles without exceeding the budget.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 2.2",
                            "concept_slugs": ["alg-linear-models", "alg-linear-inequalities"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What happens to an inequality sign when both sides are multiplied or divided by a negative number?",
                    "back": "The direction of the inequality sign is reversed (< becomes >, <= becomes >=).",
                    "concept_slugs": ["alg-linear-inequalities"],
                },
                {
                    "front": "How do you clear fractions when solving a linear equation?",
                    "back": "Multiply every term on both sides of the equation by the Least Common Denominator (LCD).",
                    "concept_slugs": ["alg-linear-equations"],
                },
                {
                    "front": "What does an outcome of 0 = 5 mean when solving a linear equation?",
                    "back": "The equation is a contradiction and has no solution (the solution set is the empty set).",
                    "concept_slugs": ["alg-linear-equations"],
                },
            ],
        },
        {
            "code": "2.2",
            "title": "Solve quadratic equations by multiple methods and analyze roots using the discriminant",
            "description": "Solve quadratic equations by factoring, completing the square, and the quadratic formula, and determine the nature of solutions using the discriminant Delta = b^2 - 4ac.",
            "sort_order": 2,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 2.5: Quadratic Equations",
            "concepts": [
                {
                    "slug": "alg-quadratic-methods",
                    "name": "Solving Quadratic Equations",
                    "short_definition": "Factoring, square root property, completing the square, and the quadratic formula.",
                    "description": "Methods to solve ax^2 + bx + c = 0. The quadratic formula x = (-b ± sqrt(b^2 - 4ac)) / (2a) solves any quadratic equation.",
                    "citation": "OpenStax College Algebra 1e, Section 2.5",
                },
                {
                    "slug": "alg-discriminant-nature",
                    "name": "The Discriminant and Nature of Solutions",
                    "short_definition": "Using Delta = b^2 - 4ac to determine whether solutions are two real, one repeated real, or two complex conjugate roots.",
                    "description": "If Delta > 0: two distinct real roots; if Delta = 0: one repeated real root; if Delta < 0: two complex conjugate non-real roots.",
                    "citation": "OpenStax College Algebra 1e, Section 2.5",
                    "prerequisites": ["alg-quadratic-methods"],
                },
                {
                    "slug": "alg-quadratic-projectile-model",
                    "name": "Quadratic Applications and Projectile Motion",
                    "short_definition": "Kinematic projectile height models h(t) = -1/2 g t^2 + v_0 t + h_0 and parabolic optimization.",
                    "description": "Solving for time of flight (roots), maximum height (vertex), and ground impact.",
                    "citation": "OpenStax College Algebra 1e, Section 2.5",
                    "prerequisites": ["alg-quadratic-methods"],
                },
            ],
            "lessons": [
                {
                    "title": "Quadratic Equations and Discriminant Analysis",
                    "description": "Comprehensive methods for solving quadratic equations (factoring, completing the square, quadratic formula) and discriminant analysis.",
                    "emoji": "🎯",
                    "tags": ["quadratics", "quadratic-formula", "discriminant"],
                    "concept_slugs": [
                        "alg-quadratic-methods",
                        "alg-discriminant-nature",
                        "alg-quadratic-projectile-model",
                    ],
                    "citation": "OpenStax College Algebra 1e, Section 2.5",
                    "terms": [
                        {"term": "Quadratic Equation", "definition": "A second-degree polynomial equation written in standard form ax^2 + bx + c = 0 with a != 0."},
                        {"term": "Zero-Product Property", "definition": "If AB = 0 for real or complex numbers A and B, then A = 0, B = 0, or both equal zero."},
                        {"term": "Quadratic Formula", "definition": "The universal solution x = (-b ± sqrt(b^2 - 4ac)) / (2a) for ax^2 + bx + c = 0."},
                        {"term": "Discriminant", "definition": "The algebraic quantity Delta = b^2 - 4ac under the square root in the quadratic formula indicating the number and nature of roots."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Solving Quadratic Equations: The Core Methods\n\n"
                                    "A **quadratic equation** in standard form is $ax^2 + bx + c = 0$ with $a \\neq 0$. "
                                    "Four fundamental methods exist for finding its solutions (roots or zeros):\n\n"
                                    "1. **Factoring**: If $ax^2 + bx + c = (px + q)(rx + s) = 0$, the zero-product property yields $px + q = 0$ or $rx + s = 0$.\n"
                                    "2. **Square Root Property**: If $(x - h)^2 = k$, then $x - h = \\pm \\sqrt{k} \\implies x = h \\pm \\sqrt{k}$.\n"
                                    "3. **Completing the Square**: Divide by $a$, move the constant term to the right, and add $\\left(\\frac{b}{2a}\\right)^2$ to both sides.\n"
                                    "4. **The Quadratic Formula**: Universally solves any quadratic equation:\n\n"
                                    "$$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$\n\n"
                                    "### The Discriminant and the Nature of Roots\n\n"
                                    "The radicand expression $\\Delta = b^2 - 4ac$ is the **discriminant**. It completely characterizes the nature of the solutions without having to solve the equation."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Discriminant Root Diagnostic",
                                "body": "• $\\Delta > 0$: Two distinct real solutions (graph crosses $x$-axis twice).\n• $\\Delta = 0$: Exactly one repeated real rational solution (parabola vertex touches $x$-axis).\n• $\\Delta < 0$: Two complex conjugate non-real solutions (graph has no $x$-intercepts).",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Discriminant Classification Summary\n\n"
                                    "| Value of $\\Delta = b^2 - 4ac$ | Algebraic Nature of Roots | Parabolic Graph Interaction |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| $\\Delta > 0$, perfect square | Two distinct rational roots | Two rational $x$-intercepts |\n"
                                    "| $\\Delta > 0$, not a square | Two distinct irrational roots | Two irrational $x$-intercepts |\n"
                                    "| $\\Delta = 0$ | One repeated rational root (multiplicity 2) | Exactly one tangent $x$-intercept (vertex) |\n"
                                    "| $\\Delta < 0$ | Two complex conjugate roots: $u \\pm vi$ | Zero real $x$-intercepts (entirely above/below axis) |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Projectile Motion and Impact Time\n\n"
                                    "A physics model tracks the trajectory of a projectile launched upward from the roof of an academic building. "
                                    "The height $h(t)$ in feet after $t$ seconds is modeled by the quadratic equation:\n\n"
                                    "$$h(t) = -16t^2 + 48t + 64$$\n\n"
                                    "To find when the projectile impacts the ground, we set height $h(t) = 0$:\n\n"
                                    "$$-16t^2 + 48t + 64 = 0$$\n\n"
                                    "Factoring out the greatest common factor $-16$ gives $-16(t^2 - 3t - 4) = 0$. "
                                    "Factoring the quadratic trinomial yields $-16(t - 4)(t + 1) = 0$. "
                                    "The mathematical roots are $t = 4$ and $t = -1$. Because time elapsed after launch must be non-negative ($t \\geq 0$), the physical impact occurs at exactly $t = 4$ seconds."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Quadratic Formula Pitfalls",
                                "body": "1. **Sign of $-b$**: If $b = -6$, then $-b = -(-6) = +6$. Forgetting to negate a negative $b$ is the single most frequent algebraic error.\n2. **Division by $2a$**: The division by $2a$ spans the ENTIRE numerator $(-b \\pm \\sqrt{\\Delta})$, not just the radical term.\n3. **Calculation of $-4ac$**: When $c$ is negative (e.g. $a=2, c=-3$), $-4ac = -4(2)(-3) = +24$. The sign becomes positive.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Find all real solutions to the quadratic equation $2x^2 - 5x - 3 = 0$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "x = -3 and x = \\frac{1}{2}",
                                    "x = 3 and x = -\\frac{1}{2}",
                                    "x = -3 and x = -\\frac{1}{2}",
                                    "x = 3 and x = \\frac{1}{2}",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Factor the quadratic trinomial using the ac method: a*c = 2*(-3) = -6. Find two numbers multiplying to -6 and summing to -5: these are -6 and 1. Rewrite: 2x^2 - 6x + x - 3 = 2x(x - 3) + 1(x - 3) = (2x + 1)(x - 3) = 0. Setting each factor to 0 gives 2x + 1 = 0 => x = -1/2, and x - 3 = 0 => x = 3.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 2.5",
                            "concept_slugs": ["alg-quadratic-methods"],
                        },
                        {
                            "prompt": "For what real value of $k$ does the quadratic equation $x^2 - 6x + k = 0$ have exactly one repeated real solution?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "k = -9",
                                    "k = 36",
                                    "k = 9",
                                    "k = 3",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "A quadratic equation has exactly one repeated real root when its discriminant Delta = b^2 - 4ac equals zero. Here a = 1, b = -6, and c = k. Compute: Delta = (-6)^2 - 4(1)(k) = 36 - 4k = 0. Solving gives 4k = 36 => k = 9.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax College Algebra 1e, Section 2.5",
                            "concept_slugs": ["alg-discriminant-nature"],
                        },
                        {
                            "prompt": "A toy rocket launched from ground level follows the height trajectory $h(t) = -16t^2 + 80t$ where $h(t)$ is in feet and $t$ is in seconds. At what positive time $t$ will the rocket hit the ground?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "t = 5 seconds",
                                    "t = 2.5 seconds",
                                    "t = 10 seconds",
                                    "t = 16 seconds",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Set the height equal to 0 for ground level: -16t^2 + 80t = 0. Factor out -16t: -16t(t - 5) = 0. The solutions are t = 0 (launch) and t = 5 (landing). Thus, the rocket returns to the ground at t = 5 seconds.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 2.5",
                            "concept_slugs": ["alg-quadratic-projectile-model"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the quadratic formula used to solve ax^2 + bx + c = 0?",
                    "back": "x = (-b ± sqrt(b^2 - 4ac)) / (2a)",
                    "concept_slugs": ["alg-quadratic-methods"],
                },
                {
                    "front": "What does a negative discriminant (b^2 - 4ac < 0) tell you about the solutions of a quadratic equation?",
                    "back": "The equation has two complex conjugate non-real solutions and no real x-intercepts.",
                    "concept_slugs": ["alg-discriminant-nature"],
                },
                {
                    "front": "When does a quadratic equation have exactly one repeated real solution?",
                    "back": "When its discriminant Delta = b^2 - 4ac is exactly equal to zero.",
                    "concept_slugs": ["alg-discriminant-nature"],
                },
            ],
        },
        {
            "code": "2.3",
            "title": "Solve radical, rational, and absolute value equations and eliminate extraneous solutions",
            "description": "Isolate radicals and powers, clear rational denominators with LCD, branch absolute value equations, and rigorously verify candidate roots against domain restrictions.",
            "sort_order": 3,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 2.6: Other Types of Equations",
            "concepts": [
                {
                    "slug": "alg-radical-equations",
                    "name": "Solving Radical Equations",
                    "short_definition": "Techniques isolating radicals and raising both sides to powers to eliminate roots.",
                    "description": "Squaring both sides can introduce extraneous solutions; all candidate roots must be tested in the original equation.",
                    "citation": "OpenStax College Algebra 1e, Section 2.6",
                },
                {
                    "slug": "alg-rational-equations",
                    "name": "Solving Rational Equations",
                    "short_definition": "Multiplying by the LCD to convert rational equations to polynomial equations.",
                    "description": "Any candidate root that makes an original denominator zero is an extraneous solution and must be discarded.",
                    "citation": "OpenStax College Algebra 1e, Section 2.6",
                    "prerequisites": ["alg-radical-equations"],
                },
                {
                    "slug": "alg-abs-equations",
                    "name": "Solving Absolute Value Equations",
                    "short_definition": "Splitting |ax + b| = c into dual linear equations ax + b = c or ax + b = -c.",
                    "description": "If c < 0, there is no real solution because absolute value is non-negative.",
                    "citation": "OpenStax College Algebra 1e, Section 2.6",
                    "prerequisites": ["alg-radical-equations"],
                },
            ],
            "lessons": [
                {
                    "title": "Radical, Rational, and Absolute Value Equations",
                    "description": "Procedures for solving radical, rational, and absolute value equations while identifying and rejecting extraneous solutions.",
                    "emoji": "🔍",
                    "tags": ["radical-equations", "rational-equations", "extraneous-solutions"],
                    "concept_slugs": [
                        "alg-radical-equations",
                        "alg-rational-equations",
                        "alg-abs-equations",
                    ],
                    "citation": "OpenStax College Algebra 1e, Section 2.6",
                    "terms": [
                        {"term": "Extraneous Solution", "definition": "A solution that emerges through valid algebraic operations (like squaring both sides or multiplying by an LCD) but does not satisfy the original equation."},
                        {"term": "Radical Equation", "definition": "An equation in which the variable appears under a radical sign or with a rational exponent."},
                        {"term": "Rational Equation", "definition": "An equation containing one or more rational expressions with variables in denominators."},
                        {"term": "Absolute Value Branching", "definition": "The procedure of replacing |u| = c with the dual system u = c or u = -c (for c >= 0)."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Radical Equations and Extraneous Solutions\n\n"
                                    "A **radical equation** contains a variable within a radicand. The standard solution procedure involves:\n\n"
                                    "1. **Isolate the radical**: Rearrange terms so that a single radical term sits alone on one side: $\\sqrt{P(x)} = Q(x)$.\n"
                                    "2. **Eliminate the radical**: Raise both sides to the power equal to the index (e.g. square both sides if index is 2).\n"
                                    "3. **Solve the resulting polynomial equation**.\n"
                                    "4. **MANDATORY: Check for extraneous solutions**: Squaring is not a one-to-one operation ($(-3)^2 = 3^2$, but $-3 \\neq 3$). Therefore, candidate roots can be false artifacts.\n\n"
                                    "### Absolute Value Equations\n\n"
                                    "For any algebraic expression $u$ and real constant $c$:\n"
                                    "- If $c < 0$, $|u| = c$ has **no solution** (empty set $\\emptyset$).\n"
                                    "- If $c = 0$, $|u| = 0 \\iff u = 0$.\n"
                                    "- If $c > 0$, $|u| = c \\iff u = c$ or $u = -c$."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "The Danger of Squaring Both Sides",
                                "body": "Whenever you square both sides of an equation, you MUST substitute all candidate values back into the ORIGINAL un-squared equation. Extraneous solutions appear frequently on the CLEP exam.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Equation Type and Solution Protocols\n\n"
                                    "| Equation Category | Primary Algebraic Move | Potential Pitfall / Invalidation |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Radical** $\\sqrt{ax+b} = cx+d$ | Isolate radical, square both sides | Squaring introduces extraneous roots; test every root |\n"
                                    "| **Rational** $\\frac{P(x)}{Q(x)} = R(x)$ | Multiply by LCD of all denominators | Zero denominator ($Q(r) = 0$) makes candidate root invalid |\n"
                                    "| **Absolute Value** $|ax+b| = c$ ($c>0$) | Branch into $ax+b = c$ or $ax+b = -c$ | Overlooking sign branches or setting equal to negative |\n"
                                    "| **Variable RHS** $|ax+b| = cx+d$ | Branch into $\\pm$, test both branches | Right side $cx+d$ must be $\\geq 0$ for solution to be valid |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Shared Work Rate Modeling\n\n"
                                    "In civil project management, two construction crews are assigned to pave an access road. "
                                    "Crew A working alone takes $x$ days, while Crew B working alone takes $x + 5$ days. "
                                    "Working simultaneously, both crews complete the road in $6$ days. We formulate the rational rate equation:\n\n"
                                    "$$\\frac{1}{x} + \\frac{1}{x + 5} = \\frac{1}{6}$$\n\n"
                                    "Multiplying by the LCD $6x(x + 5)$ yields $6(x + 5) + 6x = x(x + 5)$, which expands to $12x + 30 = x^2 + 5x$. "
                                    "Rearranging into standard quadratic form gives $x^2 - 7x - 30 = 0$. "
                                    "Factoring produces $(x - 10)(x + 3) = 0$. The roots are $x = 10$ and $x = -3$. "
                                    "Since days cannot be negative, $x = -3$ is rejected, concluding that Crew A takes $10$ days alone."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Extraneous Root Errors",
                                "body": "1. **Failing to isolate before squaring**: In $\\sqrt{x + 2} - x = 4$, squaring both sides immediately as $(x + 2) + x^2 = 16$ is algebraically FALSE. You must isolate: $\\sqrt{x + 2} = x + 4$ before squaring.\n2. **Absolute value with negative target**: $|2x - 3| = -5$ has **no real solution**. Writing $2x - 3 = -5$ and solving produces an invalid answer.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Find all real solutions to the radical equation $\\sqrt{2x + 7} - x = 2$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "x = 1 and x = -3",
                                    "x = 1 only",
                                    "x = -3 only",
                                    "No real solution",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Isolate the radical: sqrt(2x + 7) = x + 2. Square both sides: 2x + 7 = (x + 2)^2 = x^2 + 4x + 4. Rearrange into standard quadratic form: x^2 + 2x - 3 = 0. Factor: (x + 3)(x - 1) = 0, giving candidate roots x = 1 and x = -3. CHECK in original equation: For x = 1: sqrt(2(1) + 7) - 1 = sqrt(9) - 1 = 3 - 1 = 2 (TRUE). For x = -3: sqrt(2(-3) + 7) - (-3) = sqrt(1) + 3 = 1 + 3 = 4 != 2 (EXTRANEOUS). Thus x = 1 is the sole valid solution.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax College Algebra 1e, Section 2.6",
                            "concept_slugs": ["alg-radical-equations"],
                        },
                        {
                            "prompt": "Solve the rational equation $\\frac{x}{x - 2} + \\frac{1}{x - 4} = \\frac{2}{(x - 2)(x - 4)}$ for $x$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "x = 4 only",
                                    "x = -1 and x = 4",
                                    "x = -1 only",
                                    "No real solution",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Domain restrictions are x != 2 and x != 4 to prevent division by zero. Multiply both sides by the LCD (x - 2)(x - 4): x(x - 4) + 1(x - 2) = 2. Expand and simplify: x^2 - 4x + x - 2 = 2 => x^2 - 3x - 4 = 0. Factor: (x - 4)(x + 1) = 0, giving candidate roots x = 4 and x = -1. Because x = 4 makes denominators zero in the original equation, it is extraneous. Substituting x = -1: (-1)/(-3) + 1/(-5) = 1/3 - 1/5 = 2/15, and 2/[(-3)(-5)] = 2/15. Therefore, x = -1 is the unique valid real solution.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 2.6",
                            "concept_slugs": ["alg-rational-equations"],
                        },
                        {
                            "prompt": "Find all real solutions to the absolute value equation $|3x - 5| = 2x + 10$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "x = 15 only",
                                    "x = -1 only",
                                    "No real solution",
                                    "x = 15 and x = -1",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Split into two linear branches: Branch 1: 3x - 5 = 2x + 10 => x = 15. Check: |3(15) - 5| = |40| = 40; 2(15) + 10 = 40 (Valid). Branch 2: 3x - 5 = -(2x + 10) = -2x - 10 => 5x = -5 => x = -1. Check: |3(-1) - 5| = |-8| = 8; 2(-1) + 10 = 8 (Valid). Both solutions are valid.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 2.6",
                            "concept_slugs": ["alg-abs-equations"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is an extraneous solution in algebraic equations?",
                    "back": "A solution that arises through valid steps (such as squaring both sides) that does not satisfy the original equation.",
                    "concept_slugs": ["alg-radical-equations"],
                },
                {
                    "front": "Why must you check candidate roots of rational equations?",
                    "back": "Because candidate roots may cause a denominator in the original equation to equal zero (division by zero).",
                    "concept_slugs": ["alg-rational-equations"],
                },
                {
                    "front": "What is the solution to |2x - 7| = -4?",
                    "back": "No solution (empty set), because an absolute value cannot equal a negative number.",
                    "concept_slugs": ["alg-abs-equations"],
                },
            ],
        },
        {
            "code": "2.4",
            "title": "Solve systems of linear and non-linear equations in two variables",
            "description": "Apply substitution and elimination methods to linear systems, classify systems by consistency and dependence, and solve non-linear systems.",
            "sort_order": 4,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 7.1: Systems of Linear Equations (Two Variables); Section 7.3: Systems of Nonlinear Equations",
            "concepts": [
                {
                    "slug": "alg-linear-systems",
                    "name": "Linear Systems in Two Variables",
                    "short_definition": "Solving pairs of linear equations a1 x + b1 y = c1 and a2 x + b2 y = c2 using substitution and elimination.",
                    "description": "Finding the simultaneous point of intersection (x, y) that satisfies both linear equations.",
                    "citation": "OpenStax College Algebra 1e, Section 7.1",
                },
                {
                    "slug": "alg-system-classification",
                    "name": "Classification: Consistent, Inconsistent, and Dependent Systems",
                    "short_definition": "Determining whether a system has one unique solution, no solution (parallel lines), or infinitely many solutions (coincident lines).",
                    "description": "Consistent independent: unique point; Inconsistent: parallel lines, no solution; Consistent dependent: identical line, infinitely many solutions.",
                    "citation": "OpenStax College Algebra 1e, Section 7.1",
                    "prerequisites": ["alg-linear-systems"],
                },
                {
                    "slug": "alg-nonlinear-systems",
                    "name": "Nonlinear Systems of Equations",
                    "short_definition": "Solving systems where one or more equations are quadratic or higher order.",
                    "description": "Typically solved by substituting a linear expression into a quadratic equation to find points of intersection between lines and parabolas or circles.",
                    "citation": "OpenStax College Algebra 1e, Section 7.3",
                    "prerequisites": ["alg-linear-systems"],
                },
            ],
            "lessons": [
                {
                    "title": "Systems of Linear and Non-Linear Equations",
                    "description": "Analytical methods for solving 2x2 linear and non-linear systems using substitution and elimination, with geometric classifications.",
                    "emoji": "🔄",
                    "tags": ["systems-of-equations", "elimination", "substitution"],
                    "concept_slugs": [
                        "alg-linear-systems",
                        "alg-system-classification",
                        "alg-nonlinear-systems",
                    ],
                    "citation": "OpenStax College Algebra 1e, Sections 7.1 & 7.3",
                    "terms": [
                        {"term": "System of Equations", "definition": "A set of two or more equations containing the same set of variables."},
                        {"term": "Substitution Method", "definition": "An algebraic method solving one equation for a variable and substituting that expression into the other equation."},
                        {"term": "Elimination (Addition) Method", "definition": "Multiplying equations by strategic constants so that adding equations eliminates one variable."},
                        {"term": "Inconsistent System", "definition": "A system of equations with no common solution, geometrically representing parallel lines."},
                        {"term": "Dependent System", "definition": "A system of equations with infinitely many solutions, geometrically representing the exact same line."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Solving $2 \\times 2$ Linear Systems\n\n"
                                    "A linear system in two variables consists of two equations: $a_1 x + b_1 y = c_1$ and $a_2 x + b_2 y = c_2$. "
                                    "The two primary algebraic techniques are:\n\n"
                                    "1. **Substitution**: Solve one equation for either $x$ or $y$ in terms of the other, substitute that expression into the remaining equation, solve the single-variable result, and back-substitute.\n"
                                    "2. **Elimination (Addition)**: Multiply one or both equations by non-zero constants so that the coefficients of one variable become additive opposites. Add the equations to eliminate that variable, solve, and back-substitute.\n\n"
                                    "### System Classifications\n\n"
                                    "- **Consistent and Independent**: Exactly **one unique solution** $(x, y)$. Lines intersect at one point.\n"
                                    "- **Inconsistent**: **No solution** ($\text{lines are parallel}$, identical slopes, different $y$-intercepts). Algebraic result: false statement like $0 = 12$.\n"
                                    "- **Consistent and Dependent**: **Infinitely many solutions** (coincident lines, identical slopes and $y$-intercepts). Algebraic result: true statement like $0 = 0$."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Parallel Lines Criterion",
                                "body": "Two lines are parallel (yielding an inconsistent system with 0 solutions) if and only if they have the exact same slope ($m_1 = m_2$) but different $y$-intercepts ($b_1 \\neq b_2$).",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Classification Matrix for $2 \\times 2$ Linear Systems\n\n"
                                    "| Classification | Number of Solutions | Geometric Relationship | Algebraic Indicator |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Independent** | Exactly One $(x, y)$ | Intersecting lines | Unique coordinates obtained |\n"
                                    "| **Inconsistent** | Zero (Empty set $\\emptyset$) | Parallel lines ($m_1 = m_2, b_1 \\neq b_2$) | Contradiction: $0 = k$ ($k \\neq 0$) |\n"
                                    "| **Dependent** | Infinitely Many | Coincident identical lines | Identity: $0 = 0$ |\n"
                                    "| **Nonlinear (Line & Parabola)** | $0, 1$, or $2$ Points | Secant, tangent, or disjoint line | Quadratic discriminant $\\Delta > 0, = 0, < 0$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Supply and Demand Market Equilibrium\n\n"
                                    "In microeconomics, the market equilibrium price $P$ and quantity $Q$ occur at the intersection of linear supply and demand equations. "
                                    "Suppose the market supply and demand functions for a consumer tech device are given by:\n\n"
                                    "$$\\begin{cases} P = 2Q + 10 & \\text{(Supply curve)} \\\\ P = -3Q + 60 & \\text{(Demand curve)} \\end{cases}$$\n\n"
                                    "Since both equations are solved for $P$, we equate the right-hand sides using substitution: $2Q + 10 = -3Q + 60$. "
                                    "Adding $3Q$ to both sides yields $5Q + 10 = 60$. Subtracting $10$ gives $5Q = 50 \\implies Q = 10$ units. "
                                    "Substituting $Q = 10$ into either equation gives $P = 2(10) + 10 = \\$30$. "
                                    "The unique equilibrium occurs at $(Q, P) = (10, 30)$."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common System Solving Pitfalls",
                                "body": "1. **Incomplete solutions**: Solving for $x$ and forgetting to calculate $y$. A solution to a 2-variable system is always an ordered pair $(x, y)$.\n2. **Multiplication errors in elimination**: Forgetting to multiply the constant term on the right side of the equation when multiplying by a factor.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Solve the linear system of equations: $3x + 2y = 12$ and $5x - 4y = -2$. What is the value of $x + y$?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "5",
                                    "6",
                                    "4",
                                    "7",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Use elimination by multiplying the first equation by 2: 2(3x + 2y) = 2(12) => 6x + 4y = 24. Add this to the second equation: (6x + 4y) + (5x - 4y) = 24 + (-2) => 11x = 22 => x = 2. Substitute x = 2 into the first equation: 3(2) + 2y = 12 => 6 + 2y = 12 => 2y = 6 => y = 3. The ordered pair is (2, 3), and x + y = 2 + 3 = 5.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 7.1",
                            "concept_slugs": ["alg-linear-systems"],
                        },
                        {
                            "prompt": "For what real value of $k$ will the system of equations $2x - 3y = 8$ and $4x - 6y = k$ be inconsistent (have no solution)?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "k = 16 only",
                                    "Any real number k \\neq 16",
                                    "k = -16 only",
                                    "Any real number k \\neq 8",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Multiply the first equation by 2: 4x - 6y = 16. The second equation is 4x - 6y = k. If k = 16, the two equations are identical (dependent system with infinitely many solutions). If k != 16, the lines have identical slopes but different y-intercepts (parallel lines, inconsistent system with no solution).",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax College Algebra 1e, Section 7.1",
                            "concept_slugs": ["alg-system-classification"],
                        },
                        {
                            "prompt": "Find all points of intersection between the line $y = 2x - 1$ and the parabola $y = x^2 - 4$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "(3, 5) only",
                                    "(-1, -3) only",
                                    "(3, 5) and (-1, -3)",
                                    "(2, 3) and (-2, 0)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Equate the expressions for y: x^2 - 4 = 2x - 1. Rearrange into standard form: x^2 - 2x - 3 = 0. Factor: (x - 3)(x + 1) = 0 => x = 3 or x = -1. For x = 3: y = 2(3) - 1 = 5, giving point (3, 5). For x = -1: y = 2(-1) - 1 = -3, giving point (-1, -3). The points of intersection are (3, 5) and (-1, -3).",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 7.3",
                            "concept_slugs": ["alg-nonlinear-systems"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What characterizes an inconsistent linear system in two variables?",
                    "back": "The equations represent parallel lines with the same slope but different intercepts; there is no solution (empty set).",
                    "concept_slugs": ["alg-system-classification"],
                },
                {
                    "front": "What characterizes a dependent linear system in two variables?",
                    "back": "The equations represent the exact same line; there are infinitely many solutions.",
                    "concept_slugs": ["alg-system-classification"],
                },
                {
                    "front": "How do you solve a system consisting of a linear equation and a quadratic equation?",
                    "back": "Solve the linear equation for one variable and substitute that expression into the quadratic equation.",
                    "concept_slugs": ["alg-nonlinear-systems"],
                },
            ],
        },
        {
            "code": "2.5",
            "title": "Solve exponential and logarithmic equations and formulate growth and decay models",
            "description": "Solve equations using the one-to-one properties of exponents and logarithms, apply natural logarithms to unlike bases, and model continuous compound interest and radioactive decay.",
            "sort_order": 5,
            "importance": "core",
            "citation": "OpenStax College Algebra 1e, Section 6.6: Exponential and Logarithmic Equations; Section 6.7: Exponential and Logarithmic Models",
            "concepts": [
                {
                    "slug": "alg-exponential-equations",
                    "name": "Solving Exponential Equations",
                    "short_definition": "Techniques for solving b^u = b^v and a^u = c using logarithms.",
                    "description": "If bases match, equate exponents. If bases differ, take the natural logarithm of both sides and isolate the variable.",
                    "citation": "OpenStax College Algebra 1e, Section 6.6",
                },
                {
                    "slug": "alg-logarithmic-equations",
                    "name": "Solving Logarithmic Equations",
                    "short_definition": "Using condensing properties and converting to exponential form to solve equations with log terms.",
                    "description": "Condense multiple log terms into a single log, convert to exponential form, and reject any solution yielding a non-positive argument.",
                    "citation": "OpenStax College Algebra 1e, Section 6.6",
                    "prerequisites": ["alg-exponential-equations"],
                },
                {
                    "slug": "alg-growth-decay-models",
                    "name": "Exponential Growth, Decay, and Compound Interest",
                    "short_definition": "Continuous compounding A = P e^(rt) and exponential decay N(t) = N0 e^(-kt) models.",
                    "description": "Calculating doubling time, half-life, and interest growth using natural logarithms.",
                    "citation": "OpenStax College Algebra 1e, Section 6.7",
                    "prerequisites": ["alg-exponential-equations"],
                },
            ],
            "lessons": [
                {
                    "title": "Exponential and Logarithmic Equations and Models",
                    "description": "Systematic protocols for solving exponential and logarithmic equations, with applied models for continuous interest, growth, and half-life.",
                    "emoji": "🌱",
                    "tags": ["exponential-equations", "log-equations", "growth-decay"],
                    "concept_slugs": [
                        "alg-exponential-equations",
                        "alg-logarithmic-equations",
                        "alg-growth-decay-models",
                    ],
                    "citation": "OpenStax College Algebra 1e, Sections 6.6 & 6.7",
                    "terms": [
                        {"term": "One-to-One Property of Exponents", "definition": "If b^u = b^v for b > 0 and b != 1, then u = v."},
                        {"term": "One-to-One Property of Logarithms", "definition": "If log_b(u) = log_b(v) for b > 0, b != 1, and u, v > 0, then u = v."},
                        {"term": "Continuous Compound Interest", "definition": "The interest model A(t) = P e^(rt) where P is principal, r is annual rate, and t is time in years."},
                        {"term": "Half-Life", "definition": "The time required for half of the atoms of a radioactive substance to disintegrate: t_half = ln(2) / k."},
                    ],
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Solving Exponential Equations\n\n"
                                    "Exponential equations feature variables in exponents. Two primary scenarios arise:\n\n"
                                    "1. **Bases can be expressed identically**: Rewrite both sides with a common base and equate exponents using the one-to-one property:\n"
                                    "$$b^{f(x)} = b^{g(x)} \\implies f(x) = g(x)$$\n"
                                    "2. **Bases cannot be made identical** (e.g. $3^x = 20$): Isolate the exponential expression, take the natural logarithm ($\\ln$) of both sides, bring down the exponent using the power rule, and solve:\n"
                                    "$$\\ln(3^x) = \\ln(20) \\implies x \\ln(3) = \\ln(20) \\implies x = \\frac{\\ln(20)}{\\ln(3)}$$\n\n"
                                    "### Solving Logarithmic Equations\n\n"
                                    "1. Use logarithmic properties (product, quotient, power) to **condense** all logarithmic expressions into a single logarithm: $\\log_b(M) = c$.\n"
                                    "2. Convert to **exponential form**: $M = b^c$.\n"
                                    "3. Solve for the variable.\n"
                                    "4. **CHECK for extraneous solutions**: Discard any candidate root that makes the argument of any original logarithm $\\leq 0$."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Logarithmic Domain Checking is Mandatory",
                                "body": "Because $\\log_b(x)$ is defined ONLY for $x > 0$, any candidate algebraic solution that produces a negative argument or zero in an original logarithm is extraneous and MUST be eliminated.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Exponential and Logarithmic Model Formulas\n\n"
                                    "| Model Type | Mathematical Equation | Key Variables / Parameters |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Continuous Growth** | $A(t) = A_0 e^{kt}$ ($k > 0$) | $A_0 = \\text{initial value}, k = \\text{continuous growth rate}$ |\n"
                                    "| **Continuous Decay** | $N(t) = N_0 e^{-kt}$ ($k > 0$) | $N_0 = \\text{initial quantity}, k = \\text{decay constant}$ |\n"
                                    "| **Doubling Time** | $t_{\\text{double}} = \\frac{\\ln 2}{k}$ | Time required for quantity to double |\n"
                                    "| **Half-Life** | $t_{\\text{half}} = \\frac{\\ln 2}{k}$ | Time required for quantity to decay to $50\\%$ |\n"
                                    "| **Discrete Compound** | $A(t) = P\\left(1 + \\frac{r}{n}\\right)^{nt}$ | $n = \\text{compounding periods per year}$ |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Applied Problem: Financial Doubling Time Model\n\n"
                                    "An investor deposits $\\$5,000$ into a high-yield retirement bond earning an annual interest rate of $6\\%$ compounded continuously. "
                                    "The accumulated value after $t$ years is modeled by $A(t) = 5000 e^{0.06t}$. "
                                    "To calculate the exact time required for the investment to double to $\\$10,000$, we set $A(t) = 10000$:\n\n"
                                    "$$10000 = 5000 e^{0.06t} \\implies 2 = e^{0.06t}$$\n\n"
                                    "Taking the natural logarithm of both sides gives $\\ln(2) = \\ln(e^{0.06t}) = 0.06t$. "
                                    "Dividing by $0.06$ yields:\n\n"
                                    "$$t = \\frac{\\ln(2)}{0.06} \\approx \\frac{0.6931}{0.06} \\approx 11.55\\text{ years}$$\n\n"
                                    "This classic rule illustrates how exponential growth equations reduce directly to logarithmic ratios."
                                )
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Common Exponential Pitfalls",
                                "body": "1. **Multiplying base before exponent**: In $3 \\cdot 2^x = 24$, you CANNOT multiply $3 \\cdot 2 = 6^x$. You must first divide by 3: $2^x = 8 \\implies x = 3$.\n2. **Confusing continuous vs discrete models**: Continuous compounding uses base $e$ ($A = P e^{rt}$); discrete compounding uses $(1 + r/n)^{nt}$. Do not interchange them.",
                            },
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Solve the exponential equation $4^{2x - 1} = 8^{x + 2}$ for $x$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "x = 5",
                                    "x = 6",
                                    "x = 7",
                                    "x = 8",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Express both bases as powers of 2: 4 = 2^2 and 8 = 2^3. Rewrite: (2^2)^(2x - 1) = (2^3)^(x + 2) => 2^(4x - 2) = 2^(3x + 6). By the one-to-one property of exponents, equate the powers: 4x - 2 = 3x + 6. Subtract 3x and add 2: x = 8.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 6.6",
                            "concept_slugs": ["alg-exponential-equations"],
                        },
                        {
                            "prompt": "Solve the logarithmic equation $\\log_2(x) + \\log_2(x - 3) = 2$ for $x$.",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "x = 4 only",
                                    "x = 4 and x = -1",
                                    "x = 2 only",
                                    "x = -1 only",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Apply the product rule of logarithms: log_2[x(x - 3)] = 2. Convert to equivalent exponential form: x(x - 3) = 2^2 = 4. Expand and rearrange: x^2 - 3x - 4 = 0. Factor: (x - 4)(x + 1) = 0 => candidate roots x = 4 and x = -1. Check in original equation: x = 4 produces log_2(4) + log_2(1) = 2 + 0 = 2 (Valid). For x = -1, log_2(-1) is undefined (extraneous). Therefore, x = 4 is the sole valid solution.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax College Algebra 1e, Section 6.6",
                            "concept_slugs": ["alg-logarithmic-equations"],
                        },
                        {
                            "prompt": "An initial sample of $200$ grams of a radioactive isotope decays according to the model $A(t) = 200 e^{-0.035t}$, where $t$ is in years. Which expression gives the half-life of the isotope in years?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "\\frac{200}{\\ln 2}",
                                    "\\frac{\\ln 2}{0.035}",
                                    "\\frac{0.035}{\\ln 2}",
                                    "\\frac{\\ln 0.5}{-200}",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Half-life occurs when the amount remaining is half the initial value: 100 = 200 e^(-0.035t) => 0.5 = e^(-0.035t). Take the natural log of both sides: ln(0.5) = -0.035t. Since ln(0.5) = ln(1/2) = -ln(2), we have -ln(2) = -0.035t => t = ln(2) / 0.035.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax College Algebra 1e, Section 6.7",
                            "concept_slugs": ["alg-growth-decay-models"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "How do you solve an exponential equation with different bases that cannot be rewritten as common powers (e.g. 5^x = 12)?",
                    "back": "Take the natural logarithm (ln) of both sides, bring down the exponent using the power rule, and solve for x: x = ln(12) / ln(5).",
                    "concept_slugs": ["alg-exponential-equations"],
                },
                {
                    "front": "Why must solutions to logarithmic equations be checked for extraneous roots?",
                    "back": "Because the domain of a logarithm is strictly positive numbers (arguments > 0); any root resulting in log of zero or a negative number is invalid.",
                    "concept_slugs": ["alg-logarithmic-equations"],
                },
                {
                    "front": "What is the continuous compounding formula?",
                    "back": "A = P e^(rt), where P is principal, r is annual rate, and t is time in years.",
                    "concept_slugs": ["alg-growth-decay-models"],
                },
            ],
        },
    ],
}
