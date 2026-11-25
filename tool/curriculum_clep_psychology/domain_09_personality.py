"""Domain 9.0: Personality (Quota: 7 questions, 7–8% blueprint)."""
from __future__ import annotations

DOMAIN_09 = {
    "code": "9.0",
    "title": "Personality",
    "description": "Psychoanalytic and psychodynamic models (id/ego/superego, defense mechanisms), humanistic growth, Big Five trait theory, and personality assessments.",
    "weight": 0.075,
    "sort_order": 9,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 9.0 (7–8%)",
    "objectives": [
        {
            "code": "9.1",
            "title": "Analyze psychodynamic defense mechanisms, psychosexual stages, and humanistic self-actualization",
            "description": "Evaluate Freud's tripartite mind structure and psychosexual stages, classify ego defense mechanisms, review neo-Freudian perspectives, and explain Rogers's unconditional positive regard and Maslow's self-actualization.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 9.1",
            "concepts": [
                {
                    "slug": "psyc-freudian-psychodynamics",
                    "name": "Freudian Personality Structure and Defense Mechanisms",
                    "short_definition": "Psychoanalytic personality model balancing the id (pleasure), ego (reality), and superego (morality) via unconscious defense mechanisms.",
                    "description": "In Freud's theory the ego mediates psychic conflict through defense mechanisms including repression, projection, displacement, reaction formation, and sublimation; personality forms through psychosexual stages, and neo-Freudians such as Jung, Adler, and Horney revised the model.",
                    "citation": "OpenStax Psychology 1e, Section 11.2",
                },
                {
                    "slug": "psyc-humanistic-personality",
                    "name": "Humanistic Self-Concept and Unconditional Regard",
                    "short_definition": "Person-centered perspective emphasizing free will, actual vs. ideal self-concept congruence, and unconditional positive regard.",
                    "description": "Carl Rogers established that therapeutic growth requires genuineness, empathy, and unconditional positive regard to resolve self-concept incongruence.",
                    "citation": "OpenStax Psychology 1e, Section 11.4",
                    "prerequisites": ["psyc-freudian-psychodynamics"],
                },
            ],
            "lessons": [
                {
                    "title": "Psychodynamic and Humanistic Perspectives on Personality",
                    "description": "Id, ego, superego, psychosexual stages, defense mechanisms, Jung's collective unconscious, Rogers's self-concept, and Maslow's self-actualization.",
                    "emoji": "🎭",
                    "tags": ["personality", "freud", "defense-mechanisms", "humanism", "rogers"],
                    "concept_slugs": [
                        "psyc-freudian-psychodynamics",
                        "psyc-humanistic-personality",
                    ],
                    "citation": "OpenStax Psychology 1e, Section 11.2 & 11.4",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Sigmund Freud's Tripartite Personality Architecture\n\n"
                                    "Freud conceptualized personality as a continuous unconscious conflict among three psychic systems:\n"
                                    "- **The Id:** Resides entirely in the unconscious. Operates on the **pleasure principle**, demanding immediate gratification of primal sexual (libido/Eros) and aggressive (Thanatos) drives.\n"
                                    "- **The Ego:** Operates on the **reality principle**. Acts as the pragmatic, conscious executive mediator balancing the id's impulses against external social constraints.\n"
                                    "- **The Superego:** The internalized moral compass and conscience, representing societal values and ethical ideals. Punishes the ego with feelings of guilt when moral codes are violated."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Major Ego Defense Mechanisms\n\n"
                                    "When the ego experiences anxiety from id-superego conflict, it unconsciously distorts reality:\n\n"
                                    "| Defense Mechanism | Psychological Definition | Clinical Example |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Repression** | In Freud's theory, the basic defense: pushing anxiety-arousing thoughts out of awareness | 'Forgetting' an unpleasant dentist appointment you were dreading |\n"
                                    "| **Projection** | Attributing one's own unacceptable impulses onto others | A deceitful person constantly accusing coworkers of being dishonest |\n"
                                    "| **Reaction Formation** | Switching unacceptable impulses into their exact opposites | Masking unconscious romantic attraction behind exaggerated hostility |\n"
                                    "| **Displacement** | Shifting aggressive/sexual impulses toward a less threatening target | Yelling at your child after receiving a harsh reprimand from your boss |\n"
                                    "| **Sublimation** | Channeling unacceptable impulses into socially constructive pursuits | Channeling aggressive hostility into professional contact sports or surgery |\n"
                                    "| **Regression** | Retreating to an earlier, more infantile psychosexual stage | An adult throwing a screaming temper tantrum when denied a promotion |\n\n"
                                    "**A caution about repression:** repression is a Freudian concept with limited empirical support. Traumatic events are usually remembered all too well rather than forgotten, and therapy techniques aimed at 'recovering' supposedly repressed memories have produced vivid false memories (as Elizabeth Loftus's research showed)."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Carl Rogers and Unconditional Positive Regard",
                                "body": "Carl Rogers asserted that psychological health requires **congruence** between an individual's **actual self** (how they see themselves) and their **ideal self** (who they wish to be). Parents and therapists nurture growth through **unconditional positive regard**—an attitude of total, nonjudgmental acceptance.",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Clinical Case Illustration: Projection vs. Reaction Formation",
                                "text": (
                                    "An employee harboring unconscious hostility toward a supervisor: "
                                    "If using **projection**, the employee insists: *'My supervisor hates me and is trying to get me fired.'* "
                                    "If using **reaction formation**, the employee acts with effusive, saccharine praise toward the supervisor, "
                                    "overcompensating to conceal the underlying hostility."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Sublimation is Considered Adaptive",
                                "body": "Unlike most defense mechanisms, which are often maladaptive, **sublimation** is considered one of the more mature, adaptive defenses (along with humor, for example) because it channels forbidden primal drives into culturally productive and praised outcomes (e.g., artistic creation or athletic prowess).",
                            },
                        },
                        {
                            "sort_order": 6,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Freud's Psychosexual Stages\n\n"
                                    "Freud proposed that personality forms in childhood as pleasure-seeking energy (libido) centers on different body zones. Unresolved conflict at a stage could leave a **fixation**, an adult trait tied to that stage:\n"
                                    "1. **Oral (0–1 yr):** Pleasure from sucking and feeding; fixation was said to show up as smoking, overeating, or dependency.\n"
                                    "2. **Anal (1–3 yr):** Conflict centers on toilet training; fixation was said to produce excessive orderliness (anal-retentive) or messiness.\n"
                                    "3. **Phallic (3–6 yr):** Focus on the genitals; Freud's **Oedipus complex**, resolved by identifying with the same-sex parent, which forms the superego.\n"
                                    "4. **Latency (6 yr–puberty):** Sexual feelings are dormant; energy goes into school, friendships, and skills.\n"
                                    "5. **Genital (puberty on):** Mature sexual interests directed toward others.\n\n"
                                    "### The Neo-Freudians\n\n"
                                    "Followers who kept Freud's focus on the unconscious but placed less weight on sexual drives:\n"
                                    "- **Carl Jung:** Added the **collective unconscious**, a shared, inherited layer of the mind containing **archetypes**, universal images and themes (such as the shadow, the hero, and the persona) that Jung believed came from our species' ancestral history and explain recurring symbols in myths across cultures. He also described introversion and extraversion.\n"
                                    "- **Alfred Adler:** Emphasized social motives and the drive to overcome childhood feelings of **inferiority**.\n"
                                    "- **Karen Horney:** Argued that **basic anxiety** from insecure childhood relationships, along with social and cultural forces, shapes personality, and challenged Freud's views of women.\n\n"
                                    "### Maslow and Self-Actualization\n\n"
                                    "Abraham Maslow, like Rogers a founder of **humanistic psychology**, studied healthy, accomplished people rather than patients. He described **self-actualization** as fulfilling one's potential, at the top of his hierarchy of needs; self-actualizing people tended to be realistic, accepting, spontaneous, and focused on problems beyond themselves.\n\n"
                                    "**Evaluating these theories:** Psychodynamic ideas drew attention to unconscious processes and childhood, but many specific claims (psychosexual stages, the collective unconscious) are hard to test and have little empirical support. Humanistic ideas shaped counseling but were criticized as vague and overly optimistic."
                                )
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Superego",
                            "definition": "The component of personality that represents internalized societal ideals, moral standards, and conscience, striving for perfection.",
                            "example": "Feeling intense moral guilt after contemplating an unethical shortcut at work.",
                        },
                        {
                            "term": "Unconditional Positive Regard",
                            "definition": "According to Carl Rogers, an attitude of total acceptance, nonjudgmental warmth, and respect toward another person.",
                            "example": "A parent affirming their love for a child even while correcting a specific inappropriate behavior.",
                        },
                        {
                            "term": "Reaction Formation",
                            "definition": "A psychoanalytic defense mechanism where the ego unconsciously transforms unacceptable desires into their exact behavioral opposites.",
                            "example": "Becoming a vocal anti-gambling crusader to suppress one's own compulsive gambling impulses.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "An executive who was reprimanded by the board of directors returns home and severely scolds their child for dropping a fork. What psychoanalytic defense mechanism is operating?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Displacement",
                                    "Reaction formation",
                                    "Projection",
                                    "Sublimation",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Displacement shifts sexual or aggressive impulses toward a safer, less threatening target when expressing them toward the original instigator (the board of directors) is deemed too dangerous.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 1e, Section 11.2",
                            "concept_slugs": ["psyc-freudian-psychodynamics"],
                        },
                        {
                            "prompt": "According to Carl Rogers, what fundamental interpersonal condition must parents and psychotherapists provide to enable healthy personality development and resolve incongruence?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Conditional moral contingencies",
                                    "Unconditional positive regard",
                                    "Authoritarian behavioral guidance",
                                    "Objective psychometric analysis",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Carl Rogers maintained that people flourish when provided with unconditional positive regard—an attitude of total acceptance and valuing of a person regardless of their specific failures or flaws.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 1e, Section 11.4",
                            "concept_slugs": ["psyc-humanistic-personality"],
                        },
                        {
                            "prompt": "Carl Jung expanded psychoanalytic theory by proposing that all human beings share a reservoir of universal memory traces and archetypes derived from our species' ancestral history. What did Jung call this reservoir?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "The preconscious cognitive buffer",
                                    "The id pleasure reservoir",
                                    "The collective unconscious",
                                    "The reciprocal determinism schema",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Carl Jung proposed the collective unconscious, which he described as an inherited layer of the unconscious mind containing archetypes (universal images such as the shadow, the hero, and the persona) shared across human cultures. It is an influential idea but difficult to test and has little empirical support.",
                            "difficulty": "intermediate",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 1e, Section 11.2",
                            "concept_slugs": ["psyc-freudian-psychodynamics"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What principle governs the id versus the ego?",
                    "back": "The id operates on the pleasure principle; the ego operates on the reality principle.",
                    "concept_slugs": ["psyc-freudian-psychodynamics"],
                },
                {
                    "front": "What is projection in Freud's defense mechanisms?",
                    "back": "Disguising one's own threatening impulses by attributing them to others.",
                    "concept_slugs": ["psyc-freudian-psychodynamics"],
                },
            ],
        },
        {
            "code": "9.2",
            "title": "Analyze the Big Five trait taxonomy, social-cognitive theory, and personality assessments",
            "description": "Evaluate the OCEAN trait dimensions, explain Bandura's reciprocal determinism and locus of control, and contrast projective tests with the MMPI-2.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 9.2",
            "concepts": [
                {
                    "slug": "psyc-big-five-traits",
                    "name": "Big Five Trait Taxonomy (OCEAN)",
                    "short_definition": "Five broad empirical dimensions of personality: Openness, Conscientiousness, Extraversion, Agreeableness, and Neuroticism.",
                    "description": "The OCEAN five-factor model, refined by Paul Costa and Robert McCrae among others, is the most widely accepted taxonomy for describing individual trait differences, though rival models and cross-cultural exceptions are debated.",
                    "citation": "OpenStax Psychology 1e, Section 11.7",
                },
                {
                    "slug": "psyc-social-cognitive-assessment",
                    "name": "Reciprocal Determinism, Locus of Control, and Personality Testing",
                    "short_definition": "Interaction of cognition, environment, and behavior (Bandura, Rotter) alongside projective tests (Rorschach, TAT) and objective inventories (MMPI-2).",
                    "description": "Reciprocal determinism and locus of control evaluate behavioral agency; personality measurement contrasts subjective projective tests with empirical inventories.",
                    "citation": "OpenStax Psychology 1e, Section 11.8 & 11.9",
                    "prerequisites": ["psyc-big-five-traits"],
                },
            ],
            "lessons": [
                {
                    "title": "Trait Perspectives, Social-Cognitive Theory, and Personality Testing",
                    "description": "The OCEAN five-factor model, Bandura's reciprocal determinism, internal vs. external locus of control, projective tests, and the MMPI-2.",
                    "emoji": "📊",
                    "tags": ["traits", "ocean", "big-five", "bandura", "mmpi", "rorschach"],
                    "concept_slugs": [
                        "psyc-big-five-traits",
                        "psyc-social-cognitive-assessment",
                    ],
                    "citation": "OpenStax Psychology 1e, Section 11.7, 11.8, & 11.9",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Big Five Trait Taxonomy (OCEAN)\n\n"
                                    "Built up through factor analysis of trait descriptions and refined by Paul Costa and Robert McCrae, among others, the **Five-Factor Model (OCEAN)** is the most widely accepted trait taxonomy in contemporary psychology (rivals such as the six-factor HEXACO model exist, and the five factors replicate less cleanly in some non-Western samples):\n\n"
                                    "| Dimension | High End Characteristics | Low End Characteristics |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Openness** | Imaginative, intellectually curious, prefers variety | Practical, concrete, prefers routine and familiarity |\n"
                                    "| **Conscientiousness** | Highly organized, dependable, disciplined, goal-oriented | Disorganized, careless, impulsive, prone to procrastination |\n"
                                    "| **Extraversion** | Sociable, talkative, energized by social groups, assertive | Reserved, quiet, reflective, energized by solitude |\n"
                                    "| **Agreeableness** | Trusting, empathetic, cooperative, warm, soft-hearted | Suspicious, antagonistic, competitive, irritable |\n"
                                    "| **Neuroticism** | Emotionally reactive, prone to anxiety, mood swings, insecurity | Calm, emotionally resilient, secure, self-satisfied |"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Social-Cognitive Theory: Bandura and Rotter\n\n"
                                    "- **Reciprocal Determinism (Albert Bandura):** Personality is shaped by the dynamic, continuous three-way interaction between **cognitive/personal factors** (beliefs, self-efficacy), **behavioral actions**, and **environmental contexts**.\n"
                                    "- **Locus of Control (Julian Rotter):**\n"
                                    "  * **Internal Locus of Control:** Belief that one's personal choices, hard work, and actions directly determine life outcomes.\n"
                                    "  * **External Locus of Control:** Belief that chance, luck, systemic forces, or powerful others determine one's fate.\n\n"
                                    "### Evaluating Personality Assessments\n\n"
                                    "- **Projective Tests (Rorschach Inkblot, TAT):** Present ambiguous visual stimuli onto which examinees project unconscious conflicts. Subject to scorer subjectivity and low psychometric reliability.\n"
                                    "- **Objective Inventories (MMPI-2):** Standardized 567-item true/false questionnaire developed via **empirical criterion keying**. Features clinical scales and built-in validity/lie scales to detect deception."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "The Big Five Mnemonic: OCEAN or CANOE",
                                "body": "Remember the five dimensions with the acronym **OCEAN**:\n- **O**penness\n- **C**onscientiousness\n- **E**xtraversion\n- **A**greeableness\n- **N**euroticism",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Applied Workplace Case: Predicting Occupational Performance",
                                "text": (
                                    "An industrial-organizational psychologist evaluates candidate profiles for an airline pilot position. "
                                    "Research confirms that **Conscientiousness** is the most consistent Big Five predictor of job performance across diverse occupations. "
                                    "For pilots, high Conscientiousness (methodical adherence to preflight checklists) and low Neuroticism (emotional stability during turbulence) are paramount."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Projective vs. Objective Tests",
                                "body": "Do not confuse the **Thematic Apperception Test (TAT)** (projective: asking subjects to create stories about ambiguous black-and-white interpersonal drawings) with the **MMPI-2** (objective: standardized true/false inventory scored by computer with empirical validity scales).",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Reciprocal Determinism",
                            "definition": "Bandura's concept that cognitive personal factors, observable behavior, and environmental context continuously interact and influence one another.",
                            "example": "A student's love of biology (cognition) leads to joining the science club (environment), which reinforces studying habits (behavior).",
                        },
                        {
                            "term": "Conscientiousness",
                            "definition": "A Big Five personality dimension characterized by self-discipline, organization, carefulness, and a strong drive for achievement.",
                            "example": "A project manager who consistently completes milestones ahead of deadlines with meticulous documentation.",
                        },
                        {
                            "term": "Minnesota Multiphasic Personality Inventory (MMPI-2)",
                            "definition": "The most widely researched and clinically used objective personality test, originally developed to identify emotional and psychological disorders.",
                            "example": "Using MMPI-2 validity scales to detect whether a job applicant is 'faking good' to appear exceptionally virtuous.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Which dimension of the Big Five personality taxonomy is characterized by being disciplined, dependable, highly organized, and achievement-oriented?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Openness to experience",
                                    "Extraversion",
                                    "Agreeableness",
                                    "Conscientiousness",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Conscientiousness describes an individual's degree of organization, persistence, responsibility, and goal-directed behavior. Individuals high in conscientiousness are reliable, systematic, and self-disciplined.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 1e, Section 11.7",
                            "concept_slugs": ["psyc-big-five-traits"],
                        },
                        {
                            "prompt": "Albert Bandura's concept of reciprocal determinism proposes that personality is shaped through the dynamic, ongoing interaction among which three components?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Cognitive factors, behavioral actions, and environmental context",
                                    "Id impulses, ego reality boundaries, and superego moral ideals",
                                    "Genetic predispositions, neuroendocrine status, and physical traits",
                                    "Sensory iconic inputs, working memory buffers, and long-term storage",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Reciprocal determinism describes the bidirectional, interacting influences between personal cognitive factors (beliefs, expectations), behavior, and environmental influences, each constantly shaping the other two.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 1e, Section 11.8",
                            "concept_slugs": ["psyc-social-cognitive-assessment"],
                        },
                        {
                            "prompt": "A student attributes their high grade on an exam to their diligent study routine and analytical preparation. Julian Rotter would describe this student as possessing which cognitive mindset?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "An external locus of control",
                                    "An internal locus of control",
                                    "An avoidant attachment schema",
                                    "A reaction formation defense",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "An internal locus of control is the perception that one controls their own fate and that life outcomes are determined by personal effort, decisions, and capabilities rather than chance or powerful external forces.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 1e, Section 11.8",
                            "concept_slugs": ["psyc-social-cognitive-assessment"],
                        },
                        {
                            "prompt": "In contrast to projective instruments like the Rorschach Inkblot test, the Minnesota Multiphasic Personality Inventory (MMPI-2) is classified as an objective test primarily because it features which psychometric property?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Empirically keyed standardized questions with objective scoring",
                                    "Open-ended free association prompts interpreted qualitatively",
                                    "Unstructured storytelling about ambiguous interpersonal drawings",
                                    "Neurological functional magnetic resonance imaging validation",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "The MMPI-2 is an objective self-report inventory comprising 567 standardized true/false questions that are scored objectively (often by computer) using empirical criterion keying, minimizing subjective examiner interpretation.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 1e, Section 11.9",
                            "concept_slugs": ["psyc-social-cognitive-assessment"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What are the Big Five personality traits in the OCEAN model?",
                    "back": "Openness, Conscientiousness, Extraversion, Agreeableness, Neuroticism.",
                    "concept_slugs": ["psyc-big-five-traits"],
                },
                {
                    "front": "What does Julian Rotter's internal locus of control mean?",
                    "back": "Believing that you are the master of your own destiny and responsible for your outcomes.",
                    "concept_slugs": ["psyc-social-cognitive-assessment"],
                },
            ],
        },
    ],
}

