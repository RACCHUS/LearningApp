"""Domain 1.0: History, Approaches, and Methods (Quota: 11 questions, 11–12% blueprint)."""
from __future__ import annotations

DOMAIN_01 = {
    "code": "1.0",
    "title": "History, Approaches, and Methods",
    "description": "Philosophical foundations, structuralism, functionalism, contemporary psychological perspectives, experimental design, correlational research, and APA ethical standards.",
    "weight": 0.115,
    "sort_order": 1,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 1.0 (11–12%)",
    "objectives": [
        {
            "code": "1.1",
            "title": "Analyze historical foundations, foundational schools of thought, and contemporary perspectives",
            "description": "Trace the transition from philosophy to empirical science, contrasting structuralism and functionalism with modern biological, behavioral, cognitive, humanistic, and psychodynamic perspectives.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 1.1",
            "concepts": [
                {
                    "slug": "psyc-structuralism",
                    "name": "Structuralism",
                    "short_definition": "Early school of thought promoted by Wundt and Titchener using systematic introspection to isolate the basic elements of conscious experience.",
                    "description": "Structuralism sought to map the adult human mind by breaking conscious experience down into basic sensation and perception elements through rigorous introspection.",
                    "citation": "OpenStax Psychology 2e, Section 1.2",
                },
                {
                    "slug": "psyc-functionalism",
                    "name": "Functionalism",
                    "short_definition": "Early school of thought influenced by William James and Charles Darwin examining how mental and behavioral processes function to enable adaptation.",
                    "description": "Functionalism focused on the practical adaptive utility of consciousness, habits, and mental operations in organisms navigating their environments.",
                    "citation": "OpenStax Psychology 2e, Section 1.2",
                    "prerequisites": ["psyc-structuralism"],
                },
                {
                    "slug": "psyc-contemporary-perspectives",
                    "name": "Contemporary Psychological Perspectives",
                    "short_definition": "Modern frameworks including biological, cognitive, behavioral, psychodynamic, humanistic, social-cultural, and evolutionary approaches to understanding behavior.",
                    "description": "Contemporary psychology utilizes multiple complementary levels of analysis (the biopsychosocial model) rather than a single unifying school of thought.",
                    "citation": "OpenStax Psychology 2e, Section 1.2",
                    "prerequisites": ["psyc-functionalism"],
                },
            ],
            "lessons": [
                {
                    "title": "Historical Foundations and Modern Perspectives in Psychology",
                    "description": "From Wundt's 1879 Leipzig laboratory and James's functionalism to the modern biopsychosocial model.",
                    "emoji": "🧠",
                    "tags": ["history", "perspectives", "foundations"],
                    "concept_slugs": [
                        "psyc-structuralism",
                        "psyc-functionalism",
                        "psyc-contemporary-perspectives",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 1.2: History of Psychology",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Birth of Scientific Psychology\n\n"
                                    "Psychology formally transitioned from philosophical epistemology into an independent empirical science in **1879**, "
                                    "when **Wilhelm Wundt** established the first formal psychological research laboratory at the University of Leipzig in Germany. "
                                    "Wundt and his student **Edward Bradford Titchener** championed **structuralism**, an approach that sought to identify the "
                                    "constituent building blocks of conscious awareness through **introspection**—rigorous, trained self-reports of immediate sensory and emotional reactions.\n\n"
                                    "In reaction against structuralism's subjective fragility, American psychologist and philosopher **William James** established **functionalism**, "
                                    "heavily influenced by Charles Darwin's evolutionary theory. Functionalists argued that consciousness cannot be frozen into static sensory slices; "
                                    "instead, psychologists must investigate how mental processes operate as a dynamic, continuous stream enabling organisms to adapt, survive, and thrive."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Core Historical Contrast",
                                "body": "**Structuralism** asks *'What are the basic components of the conscious mind?'* using introspective analysis. **Functionalism** asks *'Why did consciousness evolve and how does it help the organism adapt?'*",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Contemporary Perspectives in Psychology\n\n"
                                    "Modern psychology avoids dogmatic allegiance to a single school of thought, instead employing the **biopsychosocial model**, which integrates biological, psychological, and social-cultural levels of analysis:\n\n"
                                    "| Perspective | Primary Focus | Key Historical Figures |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Biological** | Brain structures, neural circuits, neurotransmitters, genetics, and endocrine regulation | Roger Sperry, Michael Gazzaniga |\n"
                                    "| **Behavioral** | Strictly observable behavioral responses shaped by environmental conditioning and reinforcement | John B. Watson, B. F. Skinner |\n"
                                    "| **Cognitive** | Mental operations: encoding, retrieval, problem solving, decision heuristics, and language | Jean Piaget, Noam Chomsky |\n"
                                    "| **Humanistic** | Innate drive for personal growth, self-actualization, free will, and conscious self-concept | Carl Rogers, Abraham Maslow |\n"
                                    "| **Psychodynamic** | Unconscious conflicts, repressed impulses, early childhood attachment, and defense mechanisms | Sigmund Freud, Carl Jung, Alfred Adler |\n"
                                    "| **Evolutionary** | Natural selection of cognitive and behavioral traits promoting reproductive fitness | David Buss, Charles Darwin |\n"
                                    "| **Sociocultural** | Cultural norms, social pressures, ethnic diversity, and group dynamics | Lev Vygotsky, Solomon Asch |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Humanism vs. Behaviorism",
                                "body": "Do not confuse **behaviorism** (which views human actions as strictly determined by external environmental rewards and punishments) with **humanism** (which emphasizes free will, subjective agency, and the innate drive toward self-actualization).",
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "example",
                            "content": {
                                "title": "Applied Clinical Case Scenario: Explaining Anxiety Across Perspectives",
                                "text": (
                                    "Consider a 24-year-old software engineer experiencing acute public speaking panic. "
                                    "A **biological psychologist** investigates heightened amygdala reactivity and sympathetic norepinephrine surges. "
                                    "A **behavioral therapist** identifies a conditioned fear response paired with negative reinforcement from avoidance. "
                                    "A **cognitive psychologist** identifies catastrophizing beliefs ('I will humiliate myself completely'). "
                                    "A **humanistic counselor** explores incongruence between the client's ideal self and perceived self-worth. "
                                    "The modern biopsychosocial framework synthesizes all these dimensions into an integrated treatment plan."
                                ),
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Introspection",
                            "definition": "A systematic research technique where trained observers verbally report their immediate conscious sensations and perceptions in response to controlled stimuli.",
                            "example": "Titchener asking observers to describe the exact auditory textures and intensities of a metronome beat.",
                        },
                        {
                            "term": "Biopsychosocial Model",
                            "definition": "An integrated, multidisciplinary approach incorporating biological, psychological, and social-cultural factors to explain behavior and mental health.",
                            "example": "Analyzing depression via serotonin receptor genotypes, cognitive rumination habits, and socioeconomic isolation.",
                        },
                        {
                            "term": "Functionalism",
                            "definition": "An early school of psychology championed by William James that examined the adaptive purposes and evolutionary functions of conscious mental activity.",
                            "example": "Studying how fear triggers adaptive physiological arousal that promotes fleeing from predators.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Which historical school of psychology, influenced by Charles Darwin, focused primarily on how mental processes help organisms adapt and survive in their environments?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Functionalism",
                                    "Structuralism",
                                    "Behaviorism",
                                    "Psychoanalysis",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Functionalism, established by William James and influenced by Darwinian evolutionary theory, studied how conscious mental activities enable organisms to adapt and flourish in their environments. Structuralism, by contrast, focused on decomposing consciousness into static sensory elements.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 1.2",
                            "concept_slugs": ["psyc-functionalism"],
                        },
                        {
                            "prompt": "Wilhelm Wundt and Edward Titchener utilized which primary experimental technique to analyze the basic elements of conscious awareness?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Free association",
                                    "Systematic introspection",
                                    "Operant chamber conditioning",
                                    "Naturalistic field observation",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Wundt and Titchener utilized systematic introspection, training subjects to carefully observe and verbally describe their immediate conscious sensory experiences when exposed to controlled physical stimuli.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 1.2",
                            "concept_slugs": ["psyc-structuralism"],
                        },
                        {
                            "prompt": "A clinical psychologist asserts that a client's chronic anxiety stems from an innate conflict between their ideal self and their actual self-concept. Which psychological perspective does this clinician represent?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Behavioral perspective",
                                    "Biological perspective",
                                    "Humanistic perspective",
                                    "Evolutionary perspective",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "The humanistic perspective, developed by Carl Rogers and Abraham Maslow, focuses on conscious self-concept, personal growth, and emotional distress caused by incongruence between the actual self and the ideal self.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 1.2",
                            "concept_slugs": ["psyc-contemporary-perspectives"],
                        },
                        {
                            "prompt": "Which theoretical framework within psychology insists that scientific study must be restricted exclusively to directly observable, measurable actions rather than unobservable mental events?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Cognitive psychology",
                                    "Psychodynamic theory",
                                    "Structuralist introspection",
                                    "Behaviorism",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Behaviorism, pioneered by John B. Watson and expanded by B. F. Skinner, rejected the study of internal mental states, arguing that objective science must focus entirely on observable behaviors and environmental stimuli.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 1.2",
                            "concept_slugs": ["psyc-contemporary-perspectives"],
                        },
                        {
                            "prompt": "A researcher explains aggressive behavior among young adults as an evolved mechanism that historically enhanced reproductive competition and resource acquisition. Which perspective is being applied?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Evolutionary psychology",
                                    "Sociocultural psychology",
                                    "Humanistic psychology",
                                    "Behavioral psychology",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Evolutionary psychology applies Darwinian principles of natural selection, asserting that behavioral patterns such as aggression or mate preferences evolved because they conferred survival and reproductive advantages in ancestral environments.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 1.2",
                            "concept_slugs": ["psyc-contemporary-perspectives"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What milestone occurred in 1879 that marks the formal birth of scientific psychology?",
                    "back": "Wilhelm Wundt founded the first formal experimental psychology laboratory at the University of Leipzig.",
                    "concept_slugs": ["psyc-structuralism"],
                },
                {
                    "front": "How do structuralism and functionalism differ in their core investigative questions?",
                    "back": "Structuralism investigates 'what' the elements of the mind are through introspection; functionalism investigates 'why' mental processes evolved to help organisms adapt.",
                    "concept_slugs": ["psyc-functionalism"],
                },
            ],
        },
        {
            "code": "1.2",
            "title": "Evaluate scientific research designs, variables, and ethical standards in psychological inquiry",
            "description": "Distinguish experimental from correlational designs, identify independent/dependent variables, recognize placebo controls, and evaluate APA ethical mandates.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 1.2",
            "concepts": [
                {
                    "slug": "psyc-experimental-methodology",
                    "name": "Experimental Methodology and Control",
                    "short_definition": "Scientific research design establishing cause-and-effect relationships by manipulating independent variables while controlling confounding variables.",
                    "description": "Experiments require random assignment to experimental and control conditions to isolate the causal impact of the independent variable on the dependent variable.",
                    "citation": "OpenStax Psychology 2e, Chapter 2",
                },
                {
                    "slug": "psyc-correlational-research",
                    "name": "Correlational Research and Directionality",
                    "short_definition": "Statistical assessment measuring the strength and direction of the relationship between two variables, ranging from -1.0 to +1.0.",
                    "description": "Correlations demonstrate co-variation but never prove direct causality due to directionality problems and potential third-variable confounders.",
                    "citation": "OpenStax Psychology 2e, Chapter 2",
                    "prerequisites": ["psyc-experimental-methodology"],
                },
            ],
            "lessons": [
                {
                    "title": "Scientific Methods: Experiments, Correlations, and Ethical Standards",
                    "description": "Experimental control, variables, random assignment, placebo effects, correlation coefficients, and institutional review board mandates.",
                    "emoji": "🔬",
                    "tags": ["research", "experiment", "ethics", "variables"],
                    "concept_slugs": [
                        "psyc-experimental-methodology",
                        "psyc-correlational-research",
                    ],
                    "citation": "OpenStax Psychology 2e, Chapter 2: Psychological Research",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Establishing Causality: The Experimental Method\n\n"
                                    "The **experiment** is the only psychological research method capable of establishing definitive **cause-and-effect relationships**. "
                                    "To achieve internal validity, an experiment must incorporate:\n"
                                    "- **Independent Variable (IV):** The factor systematically manipulated by the experimenter.\n"
                                    "- **Dependent Variable (DV):** The behavioral or cognitive outcome measured to assess the effect of the IV.\n"
                                    "- **Random Assignment:** Allocating participants to experimental or control conditions purely by chance, ensuring that preexisting individual differences (e.g., intelligence, motivation) are distributed evenly across groups.\n"
                                    "- **Placebo Control & Double-Blind Protocol:** A procedure in which neither the participants nor the administering researchers know who is receiving the active treatment versus an inert placebo, preventing participant expectations and experimenter bias."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Critical Research Trap: Random Sampling vs. Random Assignment",
                                "body": "**Random sampling** ensures that a sample fairly represents a broader population (optimizing *external validity*). **Random assignment** assigns members of an existing sample to experimental or control conditions by chance (optimizing *internal validity* and causal inference).",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Comparing Psychological Research Methodologies\n\n"
                                    "| Research Design | Primary Purpose | Key Advantage | Critical Limitation |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Experimental** | Determine cause-and-effect relationships | High internal validity; isolates causal mechanism | Laboratory artificiality; ethical constraints on manipulations |\n"
                                    "| **Correlational** | Assess mathematical association between variables | Identifies relationships and enables prediction | Cannot establish causality (third-variable problem) |\n"
                                    "| **Naturalistic Observation** | Record spontaneous behavior in real-world settings | High ecological validity; unobtrusive | Lacks experimental control; observer bias risk |\n"
                                    "| **Case Study** | In-depth examination of rare individuals or conditions | Rich, exhaustive qualitative detail | Highly vulnerable to idiosyncratic generalization |\n\n"
                                    "### Ethical Mandates in Psychological Research\n\n"
                                    "All research involving human participants must receive prior clearance from an **Institutional Review Board (IRB)** and enforce:\n"
                                    "1. **Informed Consent:** Participants must be informed of the study's procedures, potential risks, and their right to withdraw at any time without penalty.\n"
                                    "2. **Deception Restrictions:** Deception is permitted only when scientifically necessary, and must never involve physical pain or severe emotional distress.\n"
                                    "3. **Debriefing:** Complete explanation of the study's purpose and true nature immediately following participation.\n"
                                    "4. **Confidentiality:** Personal identities and individual participant records must be strictly protected."
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Experimental Design Case: Memory Consolidation Trial",
                                "text": (
                                    "An investigator studies whether caffeine enhances memorization of German vocabulary words. "
                                    "Sixty participants are recruited. Using a random number generator, 30 receive 200 mg caffeine pills (experimental group) "
                                    "and 30 receive identical-looking sugar capsules (control group). Neither the administering assistant nor the participants "
                                    "know who received caffeine (double-blind). The IV is caffeine dosage; the DV is the percentage of vocabulary pairs recalled after 2 hours."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Correlation Coefficient Invariant",
                                "body": "Correlation coefficients ($r$) range from $-1.00$ to $+1.00$. The sign ($+$ or $-$) indicates direction; the absolute value indicates strength. A correlation of $-0.85$ is mathematically stronger than a correlation of $+0.65$.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Independent Variable",
                            "definition": "The experimental factor that is manipulated by the researcher to determine its causal effect on an outcome.",
                            "example": "Administering 10 mg of an active medication versus an identical placebo capsule.",
                        },
                        {
                            "term": "Dependent Variable",
                            "definition": "The outcome factor measured by researchers that may change in response to manipulations of the independent variable.",
                            "example": "Scores earned on a 50-item reading comprehension test following sleep deprivation.",
                        },
                        {
                            "term": "Double-Blind Procedure",
                            "definition": "An experimental protocol in which neither the research participants nor the data-collecting staff know which participants have received the treatment or the placebo.",
                            "example": "A clinical trial evaluating a novel antidepressant where both patients and administering nurses are blind to medication vs. sugar pill allocation.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "In an experiment testing whether listening to Mozart increases spatial reasoning test performance, what serves as the dependent variable?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "The genre of music played to subjects",
                                    "The spatial reasoning test scores earned",
                                    "The volume level of the auditory stimuli",
                                    "The random assignment of study participants",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "The dependent variable is the measured outcome that researchers hypothesize will change as a result of the independent variable. Here, spatial reasoning test scores represent the dependent variable, while the auditory condition is the independent variable.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Chapter 2",
                            "concept_slugs": ["psyc-experimental-methodology"],
                        },
                        {
                            "prompt": "Why is random assignment considered a necessary component of an experiment seeking to prove a causal relationship?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "It ensures the sample perfectly mirrors the population",
                                    "It eliminates the necessity of using an inert placebo",
                                    "It evens out preexisting differences between group members",
                                    "It guarantees that statistical significance will be achieved",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Random assignment minimizes preexisting differences between participants assigned to the experimental and control groups. By ensuring confounding participant variables are distributed evenly, researchers can attribute outcome differences directly to the independent variable.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Chapter 2",
                            "concept_slugs": ["psyc-experimental-methodology"],
                        },
                        {
                            "prompt": "A researcher discovers a correlation of r = -0.82 between hours spent playing competitive video games and grade point average. What is the most accurate interpretation of this finding?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Gaming causes a substantial decline in academic scores",
                                    "Academic decline directly causes students to play games",
                                    "Higher gaming time reliably associates with lower GPAs",
                                    "The relationship between gaming and GPA is very weak",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "A negative correlation indicates an inverse relationship: as one variable increases, the other tends to decrease. Because correlation does not prove causation, researchers cannot claim that gaming caused lower GPAs, only that the two variables reliably co-vary.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 2e, Chapter 2",
                            "concept_slugs": ["psyc-correlational-research"],
                        },
                        {
                            "prompt": "A clinical trial provides half of its participants with an active antidepressant and the other half with an identical starch pill. Neither the prescribing doctors nor the patients know who received which capsule. What experimental technique is illustrated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Naturalistic observational design",
                                    "Cross-sectional developmental design",
                                    "Single-subject reversal design",
                                    "Double-blind procedure",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "A double-blind procedure occurs when neither the participants nor the research staff who interact with them know which group received the active treatment versus the placebo, eliminating both participant expectancy and researcher expectancy biases.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Chapter 2",
                            "concept_slugs": ["psyc-experimental-methodology"],
                        },
                        {
                            "prompt": "Under American Psychological Association (APA) ethical guidelines, what must researchers provide immediately following an experiment that utilized deception?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "A comprehensive debriefing explaining the study",
                                    "Monetary compensation matching minimum wage",
                                    "A formal waiver of all institutional liability",
                                    "Destruction of all raw empirical observation data",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "APA ethical principles mandate that when deception is employed in research, participants must receive a full debriefing as soon as feasible after completion of their participation, explaining the true purpose and hypothesis of the study.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Chapter 2",
                            "concept_slugs": ["psyc-experimental-methodology"],
                        },
                        {
                            "prompt": "Which correlation coefficient demonstrates the strongest predictive relationship between two psychological variables?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "r = +0.55",
                                    "r = +0.78",
                                    "r = -0.15",
                                    "r = -0.89",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "The strength of a correlation coefficient is determined solely by its absolute value, regardless of whether it is positive or negative. The absolute value |-0.89| = 0.89 is greater than |+0.78|, |+0.55|, or |-0.15|, making it the strongest relationship.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 2e, Chapter 2",
                            "concept_slugs": ["psyc-correlational-research"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the key difference between an independent variable and a dependent variable?",
                    "back": "The independent variable is manipulated by the experimenter; the dependent variable is the measured outcome that may change in response.",
                    "concept_slugs": ["psyc-experimental-methodology"],
                },
                {
                    "front": "Why can a strong correlation (e.g., r = +0.91) never establish direct causality?",
                    "back": "Because the direction of effect cannot be determined and an unmeasured third variable may account for the co-variation.",
                    "concept_slugs": ["psyc-correlational-research"],
                },
            ],
        },
    ],
}
