"""Domain 8.0: Developmental Psychology Across the Lifespan (Quota: 8 questions, 8–9% blueprint)."""
from __future__ import annotations

DOMAIN_08 = {
    "code": "8.0",
    "title": "Developmental Psychology Across the Lifespan",
    "description": "Prenatal development, infant reflexes, Piaget's cognitive stages, Vygotsky's sociocultural theory, attachment, Erikson's psychosocial stages, and Kohlberg's moral reasoning.",
    "weight": 0.085,
    "sort_order": 8,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 8.0 (8–9%)",
    "objectives": [
        {
            "code": "8.1",
            "title": "Analyze prenatal development, infant reflexes, and Piagetian/Vygotskian cognitive models",
            "description": "Examine teratogenic impacts, neonatal reflexes, Piaget's four developmental stages, assimilation vs. accommodation, and Vygotsky's scaffolding.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 8.1",
            "concepts": [
                {
                    "slug": "psyc-prenatal-infant-development",
                    "name": "Prenatal Development and Infancy Reflexes",
                    "short_definition": "Stages of prenatal growth (germinal, embryonic, fetal), teratogenic vulnerabilities, and neonatal survival reflexes.",
                    "description": "The embryonic phase represents the critical period of organogenesis vulnerable to teratogens like alcohol; neonates exhibit rooting, Moro, and grasping reflexes.",
                    "citation": "OpenStax Psychology 2e, Section 9.1 & 9.2",
                },
                {
                    "slug": "psyc-cognitive-development-stages",
                    "name": "Piagetian and Vygotskian Cognitive Development",
                    "short_definition": "Piaget's stages (sensorimotor, preoperational, concrete, formal) and Vygotsky's sociocultural scaffolding model.",
                    "description": "Piaget focuses on schema assimilation/accommodation, object permanence, egocentrism, and conservation; Vygotsky highlights the Zone of Proximal Development.",
                    "citation": "OpenStax Psychology 2e, Section 9.2",
                    "prerequisites": ["psyc-prenatal-infant-development"],
                },
            ],
            "lessons": [
                {
                    "title": "Cognitive and Motor Development Across Childhood",
                    "description": "Teratogens, neonatal reflexes, Piaget's four cognitive stages, object permanence, conservation, and Vygotsky's ZPD.",
                    "emoji": "🚼",
                    "tags": ["development", "piaget", "vygotsky", "conservation", "teratogens"],
                    "concept_slugs": [
                        "psyc-prenatal-infant-development",
                        "psyc-cognitive-development-stages",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 9.1 & 9.2",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Prenatal Growth and Neonatal Reflexes\n\n"
                                    "1. **Germinal Stage (Weeks 1–2):** Zygote divides rapidly and implants into the uterine wall.\n"
                                    "2. **Embryonic Stage (Weeks 3–8):** Critical period of rapid **organogenesis** (heart, brain, limbs develop). Highly vulnerable to **teratogens** (environmental toxins like alcohol, which causes Fetal Alcohol Spectrum Disorder).\n"
                                    "3. **Fetal Stage (Week 9 to Birth):** Rapid somatic growth, muscular development, and brain myelination.\n\n"
                                    "**Newborn Reflexes:** Innate motor responses present at birth including **rooting** (turning head toward cheek touch to nurse), **Moro** (startle response with arms thrown outward), and **Babinski** (toes splaying upward when the sole is stroked)."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Jean Piaget's Four Stages of Cognitive Development\n\n"
                                    "Children construct knowledge through **schemas**, updating them via **assimilation** (interpreting new experiences using existing schemas) and **accommodation** (adapting schemas to incorporate new information):\n\n"
                                    "| Stage | Typical Age | Key Developmental Milestones | Diagnostic Limitations |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Sensorimotor** | 0–2 years | Exploring through senses/motor actions; **Object Permanence** (~8 months); Stranger anxiety | Lacks symbolic mental representation |\n"
                                    "| **Preoperational** | 2–7 years | Symbolic play, language expansion, intuitive reasoning | **Egocentrism** (3-mountains task); Animism; Centration; **Lacks Conservation** |\n"
                                    "| **Concrete Operational** | 7–11 years | **Conservation** mastery (volume, mass, number); Mathematical reversibility; Hierarchical classification | Cannot perform abstract hypothetical deductive logic |\n"
                                    "| **Formal Operational** | 12+ years | **Abstract logic**, hypothetical-deductive reasoning, moral ideals, systemic problem solving | Post-formal cognitive expansion continues into adulthood |"
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Conservation and Centration",
                                "body": "A preoperational child viewing identical amounts of water poured from a short wide glass into a tall thin beaker insists the tall beaker holds *more* water due to **centration** (focusing on one dimension: height) and an inability to mentally **reverse** the physical transformation.",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Educational Case Study: Vygotsky's Zone of Proximal Development (ZPD)",
                                "text": (
                                    "A 6-year-old struggles to assemble a complex 100-piece puzzle alone. "
                                    "Her teacher introduces **scaffolding**: demonstrating how to find corner border pieces first, "
                                    "then letting the child match edge pieces, and gradually removing assistance as mastery increases. "
                                    "The task lay squarely within the child's **Zone of Proximal Development**."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Assimilation vs. Accommodation",
                                "body": "**Assimilation** is seeing a zebra and calling it a 'horse' (fitting the new animal into an existing schema). **Accommodation** is learning the animal has stripes and lives in Africa, thereby creating a brand new 'zebra' schema.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Object Permanence",
                            "definition": "The cognitive awareness that physical objects continue to exist even when they are obscured from view, heard, or touched.",
                            "example": "An infant searching beneath a blanket when a toy ball is hidden under it.",
                        },
                        {
                            "term": "Conservation",
                            "definition": "The Piagetian principle that properties such as mass, volume, and number remain identical despite changes in the physical form or appearance of objects.",
                            "example": "Recognizing that squishing a clay ball into a flat pancake does not alter the total quantity of clay.",
                        },
                        {
                            "term": "Zone of Proximal Development (ZPD)",
                            "definition": "Vygotsky's concept of the difference between what a child can accomplish independently versus what they can achieve with skilled adult guidance.",
                            "example": "A student reading a 4th-grade book with a teacher's assistance even though their independent reading level is 3rd-grade.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "A four-year-old child observes a researcher pour liquid from a wide container into a tall, narrow beaker and insists that the beaker now holds more liquid because it is taller. What developmental stage is the child exhibiting?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Preoperational stage",
                                    "Sensorimotor stage",
                                    "Concrete operational stage",
                                    "Formal operational stage",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "In Piaget's theory, children in the preoperational stage (ages 2–7) lack the principle of conservation. They demonstrate centration—focusing exclusively on the single visual dimension of height while failing to recognize that mass and volume remain conserved.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 9.2",
                            "concept_slugs": ["psyc-cognitive-development-stages"],
                        },
                        {
                            "prompt": "An infant searches vigorously for a rattle after an adult covers it completely with an opaque dishcloth. What developmental cognitive milestone has this infant achieved?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Conservation of volume",
                                    "Object permanence",
                                    "Egocentric operational thinking",
                                    "Abstract hypothetico-deductive logic",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Object permanence is the awareness that objects continue to exist even when they cannot be perceived directly. It emerges during the sensorimotor stage, typically around 8 months of age.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 9.2",
                            "concept_slugs": ["psyc-cognitive-development-stages"],
                        },
                        {
                            "prompt": "A toddler who knows the word 'dog' sees a four-legged goat on a farm and shouts 'Dog!' According to Jean Piaget, what cognitive process is the child employing?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Accommodation",
                                    "Scaffolding",
                                    "Assimilation",
                                    "Centration",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Assimilation occurs when a child interprets novel environmental experiences in terms of their existing cognitive schemas (in this case, forcing the new goat into the existing four-legged 'dog' schema).",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 9.2",
                            "concept_slugs": ["psyc-cognitive-development-stages"],
                        },
                        {
                            "prompt": "Exposure to maternal alcohol consumption during the embryonic stage of prenatal development is most likely to produce which teratogenic outcome?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Color blindness and loss of retinal foveal cones",
                                    "Sudden onset infantile Tay-Sachs neurodegeneration",
                                    "Hypertrophy of the pituitary somatotropic axis",
                                    "Facial dysmorphology and long-term cognitive impairment",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Alcohol is a potent teratogen that crosses the placenta. Exposure during the critical embryonic organogenesis window causes Fetal Alcohol Spectrum Disorder (FASD), characterized by flattened philtrum, small eye openings, microcephaly, and permanent intellectual disability.",
                            "difficulty": "intermediate",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 9.1",
                            "concept_slugs": ["psyc-prenatal-infant-development"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the key milestone achieved in Piaget's concrete operational stage?",
                    "back": "Conservation (understanding volume/mass remain constant across physical transformations).",
                    "concept_slugs": ["psyc-cognitive-development-stages"],
                },
                {
                    "front": "What did Lev Vygotsky term the gap between independent ability and assisted potential?",
                    "back": "The Zone of Proximal Development (ZPD).",
                    "concept_slugs": ["psyc-cognitive-development-stages"],
                },
            ],
        },
        {
            "code": "8.2",
            "title": "Analyze attachment theory, parenting styles, Erikson's psychosocial stages, and Kohlberg's moral development",
            "description": "Evaluate Harlow's monkey study, compare Ainsworth's attachment classifications, contrast Baumrind's parenting styles, and trace Erikson's and Kohlberg's stages.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 8.2",
            "concepts": [
                {
                    "slug": "psyc-attachment-parenting",
                    "name": "Attachment Bonds and Baumrind Parenting Styles",
                    "short_definition": "Emotional bonding in infancy (Harlow's contact comfort, Ainsworth's Strange Situation) and Baumrind's four parenting frameworks.",
                    "description": "Harlow disproved nourishment-based bonding; Ainsworth classified secure, avoidant, and resistant attachments; authoritative parenting yields optimal autonomy.",
                    "citation": "OpenStax Psychology 2e, Section 9.3",
                },
                {
                    "slug": "psyc-psychosocial-moral-development",
                    "name": "Eriksonian Psychosocial and Kohlberg Moral Development",
                    "short_definition": "Erikson's eight lifelong psychosocial crises and Kohlberg's preconventional, conventional, and postconventional moral reasoning stages.",
                    "description": "Erikson spans Trust vs. Mistrust through Integrity vs. Despair; Kohlberg evaluates moral justice reasoning, contrasted with Gilligan's care ethics.",
                    "citation": "OpenStax Psychology 2e, Section 9.3",
                    "prerequisites": ["psyc-attachment-parenting"],
                },
            ],
            "lessons": [
                {
                    "title": "Attachment, Parenting Styles, and Psychosocial Moral Development",
                    "description": "Harlow's contact comfort, Ainsworth's Strange Situation, Baumrind's 4 parenting styles, Erikson's 8 crises, and Kohlberg's Heinz dilemma.",
                    "emoji": "🌱",
                    "tags": ["attachment", "harlow", "ainsworth", "erikson", "kohlberg", "parenting"],
                    "concept_slugs": [
                        "psyc-attachment-parenting",
                        "psyc-psychosocial-moral-development",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 9.3",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Attachment Foundations: Harlow and Ainsworth\n\n"
                                    "- **Harry Harlow's Surrogate Mother Experiment:** Separated infant rhesus monkeys from biological mothers and provided two artificial surrogates: a wire mother with a feeding bottle and a soft terrycloth mother without food. The monkeys overwhelmingly preferred the cloth mother, demonstrating that **contact comfort**, not feeding nourishment, forms the foundation of attachment.\n"
                                    "- **Mary Ainsworth's Strange Situation Paradigm:** Observed mother-infant interactions across structured separation and reunion episodes:\n"
                                    "  * **Secure Attachment (~65%):** Explores comfortably with mother present; distressed when mother leaves; warmly comforted upon reunion.\n"
                                    "  * **Insecure-Avoidant (~20%):** Shows little outward distress upon separation; actively avoids or ignores mother upon reunion.\n"
                                    "  * **Insecure-Resistant / Ambivalent (~10–15%):** Clings anxiously, extremely distressed by separation; seeks contact yet kicks or pushes mother away upon reunion."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Diana Baumrind's Four Parenting Styles\n\n"
                                    "| Parenting Style | Warmth & Responsiveness | Demandingness & Discipline | Long-Term Child Outcomes |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Authoritative** | High | High (reasonable, democratic rules) | Highest self-esteem, self-reliance, and social competence |\n"
                                    "| **Authoritarian** | Low | High (rigid, coercive, 'because I said so') | Lower self-esteem, higher anxiety, obedient but unhappy |\n"
                                    "| **Permissive** | High | Low (few demands, zero discipline) | Impulsive, demanding, poor academic self-regulation |\n"
                                    "| **Neglectful / Uninvolved** | Low | Low (absent, indifferent) | Poorest outcomes: delinquency, emotional detachment |\n\n"
                                    "### Erik Erikson's Psychosocial Crises Across the Lifespan\n\n"
                                    "- **Infancy (0–1 yr):** Trust vs. Mistrust\n"
                                    "- **Toddlerhood (1–3 yr):** Autonomy vs. Shame and Doubt\n"
                                    "- **Preschool (3–6 yr):** Initiative vs. Guilt\n"
                                    "- **Elementary (6–12 yr):** Industry vs. Inferiority\n"
                                    "- **Adolescence (12–18 yr):** **Identity vs. Role Confusion**\n"
                                    "- **Young Adulthood (20s–30s):** **Intimacy vs. Isolation**\n"
                                    "- **Middle Adulthood (40s–60s):** **Generativity vs. Stagnation**\n"
                                    "- **Late Adulthood (65+ yr):** **Integrity vs. Despair**"
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Lawrence Kohlberg's Levels of Moral Reasoning\n\n"
                                    "Evaluated through moral dilemmas like the **Heinz Dilemma** (stealing an unaffordable drug to save a dying wife):\n"
                                    "1. **Preconventional Morality (Before age 9):** Governed by self-interest. Morality is judged by avoiding physical punishment (Stage 1) or gaining tangible rewards (Stage 2).\n"
                                    "2. **Conventional Morality (Early adolescence):** Governed by social conformity. Morality is judged by gaining social approval ('good boy/girl', Stage 3) or upholding societal laws and order (Stage 4).\n"
                                    "3. **Postconventional Morality (Adolescence and beyond):** Governed by abstract ethical principles. Morality reflects basic human rights and universal ethical principles (Stages 5 and 6)."
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Clinical Case: Adolescence Identity Resolution",
                                "text": (
                                    "A 16-year-old high school student experiments with different peer groups, musical styles, and career ambitions. "
                                    "According to Erikson, the adolescent is actively resolving the **Identity vs. Role Confusion** crisis, "
                                    "synthesizing childhood values with future adult aspirations to forge a coherent self-identity."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Authoritative vs. Authoritarian",
                                "body": "Remember that **AuthoritaTIVE** parents are like a warm, supportive **tent** (democratic and responsive). **AuthoritaRIAN** parents are strict like a **totalitarian** regime (cold and demanding).",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Contact Comfort",
                            "definition": "The physical and emotional comfort that an infant receives from being in direct physical contact with a warm, soft caregiver.",
                            "example": "Harlow's infant monkeys clinging to the cloth mother for hours when terrified by an automated mechanical toy.",
                        },
                        {
                            "term": "Authoritative Parenting",
                            "definition": "A parenting style characterized by high responsiveness and high demands, featuring open communication, clear standards, and warm support.",
                            "example": "Setting consistent curfews while discussing the reasons behind them and listening to the teenager's perspective.",
                        },
                        {
                            "term": "Postconventional Morality",
                            "definition": "The third and highest level of Kohlberg's moral reasoning, where decisions are based on self-chosen abstract ethical principles and universal human rights.",
                            "example": "Stealing medication because human life possesses greater moral value than corporate property rights.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Harry Harlow's classic experiments with infant rhesus monkeys separated from their mothers demonstrated that social attachment is primarily formed through which mechanism?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Physical contact comfort provided by a soft surface",
                                    "Consistent delivery of primary nutritional reinforcement",
                                    "Imprinting during the first twenty-four hours post-birth",
                                    "Operant conditioning of instinctive maternal vocalizations",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Harlow showed that infant monkeys clung almost continuously to a soft, terrycloth surrogate mother rather than a wire mother that dispensed milk, demonstrating that contact comfort (not feeding reinforcement) is the primary foundation of infant attachment.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 9.3",
                            "concept_slugs": ["psyc-attachment-parenting"],
                        },
                        {
                            "prompt": "In Mary Ainsworth's Strange Situation paradigm, a one-year-old explores the room with their mother present, cries intensely when she departs, but immediately seeks her embrace and is quickly soothed upon her return. What attachment pattern is illustrated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Insecure-avoidant attachment",
                                    "Secure attachment",
                                    "Insecure-resistant attachment",
                                    "Disorganized attachment",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Secure attachment is characterized by using the caregiver as a safe base for exploration, displaying distress upon separation, and actively seeking contact and being readily comforted upon the caregiver's return.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 9.3",
                            "concept_slugs": ["psyc-attachment-parenting"],
                        },
                        {
                            "prompt": "When asked why one should not steal merchandise from a store, an individual responds: 'Because stealing violates societal laws, and if everyone broke the rules, society would descend into total disorder.' At which level of Kohlberg's moral development is this individual reasoning?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Preconventional morality",
                                    "Postconventional morality",
                                    "Conventional morality",
                                    "Universal ethical morality",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Conventional morality (Kohlberg's second level, Stage 4) emphasizes maintaining social order, respecting authority, and obeying laws for the collective stability of the social system.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 2e, Section 9.3",
                            "concept_slugs": ["psyc-psychosocial-moral-development"],
                        },
                        {
                            "prompt": "According to Erik Erikson's eight stages of psychosocial development, which core psychological crisis confronts an adolescent transitioning into young adulthood?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Industry versus inferiority",
                                    "Generativity versus stagnation",
                                    "Autonomy versus shame and doubt",
                                    "Identity versus role confusion",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "During adolescence (ages 12–18), individuals confront Erikson's crisis of Identity vs. Role Confusion, testing and integrating various roles to develop a stable, unified sense of personal self.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 9.3",
                            "concept_slugs": ["psyc-psychosocial-moral-development"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What did Harry Harlow's study with rhesus monkeys disprove about attachment?",
                    "back": "It disproved that attachment is based merely on who feeds the infant, proving contact comfort is foundational.",
                    "concept_slugs": ["psyc-attachment-parenting"],
                },
                {
                    "front": "What characterizes authoritative parenting?",
                    "back": "High warmth paired with clear, firm, democratic standards and rules.",
                    "concept_slugs": ["psyc-attachment-parenting"],
                },
            ],
        },
    ],
}

