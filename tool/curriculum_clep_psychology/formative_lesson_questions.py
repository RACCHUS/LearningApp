"""Formative check-for-understanding practice questions for CLEP Introductory Psychology lessons.

Provides 2 genuine, original formative questions per lesson (50 total) for immediate
in-lesson retrieval practice. These are strictly separated from the 95-question protected
simulation exam pool.
"""
from __future__ import annotations

RAW_FORMATIVE_QUESTIONS_BY_LESSON: dict[str, list[dict]] = {
    "Historical Foundations and Modern Perspectives in Psychology": [
        {
            "question_text": "Which early school of psychology utilized trained introspection to break conscious experience into its most basic sensory elements?",
            "correct_text": "Structuralism",
            "distractors": [
                "Functionalism",
                "Behaviorism",
                "Psychoanalysis",
            ],
            "explanation": "Structuralism, founded by Wilhelm Wundt and expanded by Edward Titchener, attempted to map conscious experience by breaking it down into basic sensations through systematic introspection.",
            "concept_slugs": ["psyc-structuralism"],
        },
        {
            "question_text": "A researcher who studies how natural selection has shaped human mate preferences is operating primarily from which contemporary perspective?",
            "correct_text": "Evolutionary perspective",
            "distractors": [
                "Behavioral perspective",
                "Psychodynamic perspective",
                "Humanistic perspective",
            ],
            "explanation": "The evolutionary perspective applies principles of natural selection and Darwinian adaptation to explain mental processes and behavioral patterns across generations.",
            "concept_slugs": ["psyc-contemporary-perspectives"],
        },
    ],
    "Scientific Methods: Experiments, Correlations, and Ethical Standards": [
        {
            "question_text": "Why is random assignment essential in experimental psychological research?",
            "correct_text": "It minimizes pre-existing differences between the experimental and control groups",
            "distractors": [
                "It guarantees that the sample is perfectly representative of the entire population",
                "It completely eliminates the possibility of experimental demand characteristics",
                "It allows researchers to calculate Pearson correlation coefficients without bias",
            ],
            "explanation": "Random assignment ensures that participant characteristics (such as baseline intelligence or motivation) are equally distributed across conditions, controlling for confounding variables and enabling causal inferences.",
            "concept_slugs": ["psyc-experimental-methodology"],
        },
        {
            "question_text": "A study finds a correlation of -0.78 between hours spent playing video games and grade point average. What does this statistical correlation indicate?",
            "correct_text": "As gaming hours increase, grade point averages tend to decrease",
            "distractors": [
                "Playing video games directly causes students to perform poorly on exams",
                "Lower grades cause students to spend more time playing video games",
                "There is a very weak and negligible relationship between the two variables",
            ],
            "explanation": "A negative correlation indicates an inverse relationship: as the value of one variable increases, the value of the other tends to decrease. Correlation does not establish causation.",
            "concept_slugs": ["psyc-correlational-research"],
        },
    ],
    "The Neuron and Electrochemical Communication": [
        {
            "question_text": "During the resting potential of a neuron, which ion is concentrated in greater abundance inside the intracellular fluid compared to the extracellular fluid?",
            "correct_text": "Potassium (K+)",
            "distractors": [
                "Sodium (Na+)",
                "Chloride (Cl-)",
                "Calcium (Ca2+)",
            ],
            "explanation": "At rest (approximately -70 mV), potassium ions (K+) are concentrated inside the cell, while sodium ions (Na+) are concentrated outside, maintained by the sodium-potassium pump.",
            "concept_slugs": ["psyc-neuron-structure"],
        },
        {
            "question_text": "Which neurotransmitter is primarily involved in motor movement, attention, and reward pathways, and is depleted in Parkinson's disease?",
            "correct_text": "Dopamine",
            "distractors": [
                "Serotonin",
                "Gamma-aminobutyric acid (GABA)",
                "Glutamate",
            ],
            "explanation": "Dopamine governs voluntary movement, motivation, and reward; degeneration of dopamine-producing neurons in the substantia nigra causes the motor tremors of Parkinson's disease.",
            "concept_slugs": ["psyc-neurotransmitters"],
        },
    ],
    "Brain Architecture and Hemispheric Specialization": [
        {
            "question_text": "Damage to which cerebral brain area typically results in expressive aphasia, where a patient understands speech but struggles to produce fluent words?",
            "correct_text": "Broca's area in the left frontal lobe",
            "distractors": [
                "Wernicke's area in the left temporal lobe",
                "The somatosensory cortex in the parietal lobe",
                "The fusiform face area in the occipitotemporal region",
            ],
            "explanation": "Broca's area, located in the posterior inferior frontal gyrus of the dominant (usually left) hemisphere, controls the motor mechanics of speech production; damage causes non-fluent, expressive aphasia.",
            "concept_slugs": ["psyc-brain-structures"],
        },
        {
            "question_text": "In a classic split-brain study, when a picture of a fork is flashed exclusively to the patient's left visual field, how can the patient demonstrate recognition?",
            "correct_text": "By selecting a fork with their left hand beneath an opaque screen",
            "distractors": [
                "By immediately verbally stating the word 'fork'",
                "By writing the word 'fork' using their right hand",
                "By pointing to the fork with their right index finger",
            ],
            "explanation": "Images in the left visual field project to the right hemisphere, which controls the left hand. Because the corpus callosum is severed and speech is left-lateralized, the patient cannot name the object verbally but can identify it haptically with the left hand.",
            "concept_slugs": ["psyc-hemispheric-specialization"],
        },
    ],
    "Sensory Reception, Transduction, and Thresholds": [
        {
            "question_text": "What is the minimum physical intensity difference between two stimuli necessary for an observer to detect a difference 50% of the time called?",
            "correct_text": "Difference threshold (just noticeable difference)",
            "distractors": [
                "Absolute sensory threshold (minimum detection)",
                "Subliminal sensory priming detection boundary",
                "Sensory adaptation physiological baseline level",
            ],
            "explanation": "The difference threshold, or just noticeable difference (JND), is the smallest physical change between two stimuli that an individual can detect 50% of the time, described quantitatively by Weber's law.",
            "concept_slugs": ["psyc-sensory-thresholds"],
        },
        {
            "question_text": "According to signal detection theory, which psychological and environmental factor directly influences an observer's response bias (criterion)?",
            "correct_text": "Expectations, motivation, and consequences of errors",
            "distractors": [
                "The absolute density of retinal photoreceptor cells",
                "The wavelength of incoming electromagnetic radiation",
                "The anatomical size of the temporal auditory bulla",
            ],
            "explanation": "Signal detection theory posits that detecting a stimulus depends not just on sensory sensitivity, but on decision criteria influenced by expectations, motivation, alertness, and the payoff/cost of false alarms versus misses.",
            "concept_slugs": ["psyc-signal-detection"],
        },
    ],
    "Visual Anatomy, Color Theories, and Perceptual Organization": [
        {
            "question_text": "Which retinal photoreceptor cells are concentrated primarily in the fovea and are responsible for high visual acuity and color vision in bright light?",
            "correct_text": "Cones",
            "distractors": [
                "Rods",
                "Bipolar cells",
                "Ganglion cells",
            ],
            "explanation": "Cones are densely packed in the central fovea, mediate sharp spatial resolution, operate in photopic (bright) illumination, and contain photopigments responsive to red, green, or blue wavelengths.",
            "concept_slugs": ["psyc-visual-auditory-systems"],
        },
        {
            "question_text": "Which Gestalt principle explains why we perceive individual dots aligned in a smooth, continuous curve as belonging together rather than as separate points?",
            "correct_text": "Principle of continuity",
            "distractors": [
                "Principle of proximity",
                "Principle of closure",
                "Principle of figure-ground",
            ],
            "explanation": "The Gestalt principle of continuity states that observers perceive elements that follow a smooth vector or continuous line as a unified perceptual figure rather than as disjointed segments.",
            "concept_slugs": ["psyc-perceptual-organization"],
        },
    ],
    "Sleep Architecture and Biological Rhythms": [
        {
            "question_text": "Which brain structure acts as the master circadian pacemaker by regulating melatonin secretion from the pineal gland in response to light?",
            "correct_text": "Suprachiasmatic nucleus (SCN) of hypothalamus",
            "distractors": [
                "Ventral tegmental area of the midbrain region",
                "Substantia nigra of basal ganglia structures",
                "Anterior cingulate cortex of the frontal lobe",
            ],
            "explanation": "The suprachiasmatic nucleus (SCN) in the hypothalamus receives photic signals directly from retinal ganglion cells and synchronizes 24-hour biological rhythms by inhibiting melatonin release from the pineal gland during daylight.",
            "concept_slugs": ["psyc-circadian-rhythms"],
        },
        {
            "question_text": "EEG recordings showing sleep spindles and K-complexes are diagnostic of which stage of the non-REM sleep cycle?",
            "correct_text": "Stage N2 sleep",
            "distractors": [
                "Stage N1 sleep",
                "Stage N3 sleep",
                "REM state sleep",
            ],
            "explanation": "Stage N2 sleep is characterized electrophysiologically by sleep spindles (brief 12-14 Hz bursts) and K-complexes (high-amplitude biphasic waves), which represent neural mechanisms protecting sleep from sensory arousal.",
            "concept_slugs": ["psyc-sleep-stages"],
        },
    ],
    "Sleep Disorders, Theories of Dreaming, and Psychoactive Drugs": [
        {
            "question_text": "Which sleep disorder involves sudden, uncontrollable attacks of overwhelming daytime sleepiness and immediate intrusion into REM sleep?",
            "correct_text": "Narcolepsy",
            "distractors": [
                "Sleep apnea",
                "Somnambulism",
                "Sleep terror",
            ],
            "explanation": "Narcolepsy is characterized by severe daytime hypersomnolence, cataplexy (sudden loss of muscle tone), and rapid sleep-onset REM episodes, often linked to hypocretin/orexin neuron loss.",
            "concept_slugs": ["psyc-sleep-disorders-dreams"],
        },
        {
            "question_text": "Alcohol, barbiturates, and benzodiazepines are classified under which major category of psychoactive substances because they agonize GABA receptors?",
            "correct_text": "Depressants",
            "distractors": [
                "Stimulants",
                "Hallucinogens",
                "Opiates",
            ],
            "explanation": "Depressants reduce central nervous system arousal, motor activity, and anxiety by enhancing the inhibitory neurotransmitter GABA.",
            "concept_slugs": ["psyc-psychoactive-drugs"],
        },
    ],
    "Classical Conditioning: Principles and Extinction": [
        {
            "question_text": "In Pavlov's original experiments with dogs, the unconditioned stimulus (UCS) was which element?",
            "correct_text": "The food powder presented in the mouth",
            "distractors": [
                "The auditory tone presented by metronome",
                "The salivation triggered by tone stimulus",
                "The presence of the laboratory assistant",
            ],
            "explanation": "The unconditioned stimulus (UCS) is an environmental stimulus that naturally and reflexively triggers an innate physiological response (the UCR) without prior conditioning; in Pavlov's experiment, this was the food powder.",
            "concept_slugs": ["psyc-classical-conditioning"],
        },
        {
            "question_text": "John Garcia's experiments with taste aversion conditioning challenged classical behaviorist assumptions by demonstrating what biological principle?",
            "correct_text": "Organisms are biologically predisposed to associate novel tastes with illness over long delay intervals",
            "distractors": [
                "Any neutral conditioned stimulus can be paired equally easily with any unconditioned response",
                "Conditioned taste aversion requires continuous immediate reinforcement across dozens of trials",
                "Conditioned responses cannot be established without active conscious cognitive appraisal",
            ],
            "explanation": "Garcia demonstrated biological preparedness: rats readily formed associations between novel tastes and radiation-induced nausea even after hours-long delays, but could not associate visual or auditory cues with nausea.",
            "concept_slugs": ["psyc-biological-constraints"],
        },
    ],
    "Operant Conditioning: Reinforcement, Schedules, and Observational Learning": [
        {
            "question_text": "A student receives praise from an instructor after an unpredictable number of completed homework assignments (e.g., after 3, then 7, then 4 assignments). Which reinforcement schedule is being used?",
            "correct_text": "Variable-ratio schedule",
            "distractors": [
                "Fixed-ratio schedule",
                "Variable-interval schedule",
                "Fixed-interval schedule",
            ],
            "explanation": "A variable-ratio schedule delivers reinforcement after an unpredictable, varying number of responses; it generates high, steady response rates that are extremely resistant to extinction.",
            "concept_slugs": ["psyc-operant-conditioning"],
        },
        {
            "question_text": "In Albert Bandura's classic Bobo doll experiments, children who observed an adult model display aggressive behavior toward an inflatable doll subsequently exhibited what behavior?",
            "correct_text": "Imitated the novel aggressive actions and verbalizations of the model",
            "distractors": [
                "Showed decreased aggressive play due to cathartic vicarious relief",
                "Ignored the doll entirely and preferred neutral drawing activities",
                "Exhibited aggression only when an immediate tangible candy reward was offered",
            ],
            "explanation": "Bandura demonstrated observational learning: children exposed to aggressive models imitated specific physical and verbal aggressive behaviors, disproving the claim that observing aggression produces catharsis.",
            "concept_slugs": ["psyc-observational-learning"],
        },
    ],
    "Memory Systems: Encoding, Storage, and Retrieval": [
        {
            "question_text": "Which component of Alan Baddeley's working memory model coordinates cognitive activities, allocates attentional resources, and integrates information across slave systems?",
            "correct_text": "Central executive",
            "distractors": [
                "Phonological loop",
                "Visuospatial sketchpad",
                "Episodic buffer",
            ],
            "explanation": "The central executive directs cognitive focus, manages attentional switching, suppresses irrelevant information, and coordinates the phonological loop and visuospatial sketchpad.",
            "concept_slugs": ["psyc-memory-models"],
        },
        {
            "question_text": "An individual who can recall childhood events perfectly but is incapable of forming new conscious declarative memories after bilateral hippocampus surgery exhibits what condition?",
            "correct_text": "Anterograde amnesia",
            "distractors": [
                "Retrograde amnesia",
                "Proactive interference",
                "Retroactive interference",
            ],
            "explanation": "Anterograde amnesia is the inability to consolidate and transfer new declarative information from short-term to long-term memory following hippocampal trauma (as famously observed in patient H.M.).",
            "concept_slugs": ["psyc-memory-systems-forgetting"],
        },
    ],
    "Problem Solving, Cognitive Biases, and Language Acquisition": [
        {
            "question_text": "Searching for a misplaced item by methodically checking every single room, drawer, and shelf in an entire house exemplifies which problem-solving strategy?",
            "correct_text": "An algorithm",
            "distractors": [
                "A heuristic",
                "Functional fixedness",
                "Mental incubation",
            ],
            "explanation": "An algorithm is a step-by-step, methodical procedure or formula that guarantees a correct solution if followed correctly, though it may be slow and exhaustive compared to heuristics.",
            "concept_slugs": ["psyc-problem-solving-biases"],
        },
        {
            "question_text": "Noam Chomsky proposed that humans are born with an innate neural mechanism that facilitates language acquisition, termed what?",
            "correct_text": "Language acquisition device (LAD)",
            "distractors": [
                "Operant vocalization apparatus",
                "Critical articulatory buffer",
                "Universal syntactic transformer",
            ],
            "explanation": "Chomsky posited the Language Acquisition Device (LAD), an innate biological predisposition and universal grammar that enables infants to acquire complex natural language effortlessly without formal instruction.",
            "concept_slugs": ["psyc-language-development"],
        },
    ],
    "Theories of Motivation and Motivational Drives": [
        {
            "question_text": "According to Abraham Maslow's hierarchy of needs, which level of needs must be substantially satisfied before an individual becomes motivated by belongingness and love needs?",
            "correct_text": "Physiological and safety needs",
            "distractors": [
                "Self-actualization needs",
                "Esteem and competence needs",
                "Cognitive and aesthetic needs",
            ],
            "explanation": "Maslow proposed a pyramid structure where basic physiological needs (food, water) and safety needs must be substantially met before higher-order social belongingness and love motives emerge.",
            "concept_slugs": ["psyc-motivation-theories"],
        },
        {
            "question_text": "Bilateral lesioning of which hypothalamic nucleus in a laboratory rat causes continuous hyperphagia (overeating) and extreme obesity?",
            "correct_text": "Ventromedial hypothalamus (VMH)",
            "distractors": [
                "Lateral hypothalamus (LH)",
                "Suprachiasmatic nucleus (SCN)",
                "Preoptic anterior nucleus",
            ],
            "explanation": "The ventromedial hypothalamus (VMH) serves as a primary satiety center; destroying it abolishes satiety signals, leading to uncontrollable overeating and rapid obesity.",
            "concept_slugs": ["psyc-hunger-physiology"],
        },
    ],
    "Theories of Emotion, Stress, and Selye's GAS": [
        {
            "question_text": "Which classic theory of emotion argues that emotional feelings occur only AFTER we perceive our physiological arousal (e.g., 'we feel afraid because our heart is racing')?",
            "correct_text": "James-Lange theory",
            "distractors": [
                "Cannon-Bard theory",
                "Schachter-Singer theory",
                "Lazarus appraisal theory",
            ],
            "explanation": "The James-Lange theory asserts that physiological arousal precedes and triggers emotional experience: sensory stimuli generate bodily reactions, and the conscious emotion is our awareness of those changes.",
            "concept_slugs": ["psyc-emotion-theories"],
        },
        {
            "question_text": "In Hans Selye's General Adaptation Syndrome (GAS), during which second stage does the endocrine system sustain elevated cortisol secretion to cope with prolonged stressors?",
            "correct_text": "Resistance stage",
            "distractors": [
                "Alarm reaction stage",
                "Exhaustion stage",
                "Baseline recovery stage",
            ],
            "explanation": "In the resistance stage of Selye's GAS, the body adapts to the ongoing stressor; physiological arousal remains elevated and the adrenal cortex releases glucocorticoids (cortisol) to sustain defense.",
            "concept_slugs": ["psyc-stress-gas"],
        },
    ],
    "Cognitive and Motor Development Across Childhood": [
        {
            "question_text": "According to Jean Piaget, a child who realizes that pouring water from a wide bowl into a tall, thin cylinder does not alter the total amount of water has attained what cognitive ability?",
            "correct_text": "Conservation",
            "distractors": [
                "Object permanence",
                "Egocentrism",
                "Abstract logic",
            ],
            "explanation": "Conservation, mastered during Piaget's concrete operational stage (ages 7-11), is the understanding that quantitative physical properties (mass, volume) remain invariant despite perceptual changes in shape.",
            "concept_slugs": ["psyc-cognitive-development-stages"],
        },
        {
            "question_text": "A newborn infant who turns their head toward a gentle stroke on their cheek and opens their mouth to suck is exhibiting which primitive survival reflex?",
            "correct_text": "Rooting reflex",
            "distractors": [
                "Moro reflex",
                "Babinski reflex",
                "Palmar grasp reflex",
            ],
            "explanation": "The rooting reflex assists the neonate in finding a source of nourishment: touching the cheek causes the infant to orient their mouth toward the stimulus.",
            "concept_slugs": ["psyc-prenatal-infant-development"],
        },
    ],
    "Attachment, Parenting Styles, and Psychosocial Moral Development": [
        {
            "question_text": "In Mary Ainsworth's Strange Situation, an infant who explores comfortably when the mother is present, shows distress upon separation, and greets her enthusiastically upon reunion exhibits which attachment style?",
            "correct_text": "Secure attachment",
            "distractors": [
                "Insecure-avoidant attachment",
                "Insecure-resistant attachment",
                "Disorganized attachment",
            ],
            "explanation": "Securely attached infants utilize the caregiver as a safe base for environmental exploration, display appropriate distress when separated, and are readily comforted upon the parent's return.",
            "concept_slugs": ["psyc-attachment-parenting"],
        },
        {
            "question_text": "At which of Lawrence Kohlberg's levels of moral reasoning does an individual justify actions based on universal ethical principles, human rights, and social justice rather than written laws or punishment?",
            "correct_text": "Postconventional morality",
            "distractors": [
                "Preconventional morality",
                "Conventional morality",
                "Heteronomous morality",
            ],
            "explanation": "Postconventional moral reasoning evaluates moral dilemmas against abstract ethical principles of justice, individual dignity, and human rights, recognizing that existing civil laws may sometimes be unjust.",
            "concept_slugs": ["psyc-psychosocial-moral-development"],
        },
    ],
    "Psychodynamic and Humanistic Perspectives on Personality": [
        {
            "question_text": "According to Sigmund Freud, which structural component of personality operates entirely on the pleasure principle, seeking immediate gratification without regard to social reality?",
            "correct_text": "The id",
            "distractors": [
                "The ego",
                "The superego",
                "The persona",
            ],
            "explanation": "The id is the innate, primitive psychodynamic structure present at birth that contains instinctual sexual and aggressive drives (Eros and Thanatos) driven entirely by the pleasure principle.",
            "concept_slugs": ["psyc-freudian-psychodynamics"],
        },
        {
            "question_text": "Carl Rogers asserted that psychological health and personal growth are fostered when parents and therapists provide which condition without contingencies?",
            "correct_text": "Unconditional positive regard",
            "distractors": [
                "Rational cognitive disputation",
                "Systematic behavioral reinforcement",
                "Controlled psychoanalytic analysis",
            ],
            "explanation": "Unconditional positive regard is an attitude of total acceptance, empathy, and warmth extended to an individual regardless of their faults or behaviors, promoting congruence between actual and ideal selves.",
            "concept_slugs": ["psyc-humanistic-personality"],
        },
    ],
    "Trait Perspectives, Social-Cognitive Theory, and Personality Testing": [
        {
            "question_text": "Which dimension of the Five-Factor Model (Big Five) describes individuals who are organized, disciplined, dependable, and goal-directed?",
            "correct_text": "Conscientiousness",
            "distractors": [
                "Extraversion",
                "Agreeableness",
                "Openness to experience",
            ],
            "explanation": "Conscientiousness reflects self-regulation, impulse control, thoroughness, dependability, and persistence in pursuing long-term objectives.",
            "concept_slugs": ["psyc-big-five-traits"],
        },
        {
            "question_text": "Albert Bandura's concept that behavioral patterns, cognitive internal personal factors, and environmental contexts constantly influence and shape one another is called what?",
            "correct_text": "Reciprocal determinism",
            "distractors": [
                "Locus of control",
                "Self-serving bias",
                "Trait-state interaction",
            ],
            "explanation": "Reciprocal determinism describes the dynamic bidirectional interaction where personal cognitive factors, overt behavior, and environmental events mutually influence one another.",
            "concept_slugs": ["psyc-social-cognitive-assessment"],
        },
    ],
    "Psychological Disorders: Classification, Anxiety, OCD, and Trauma": [
        {
            "question_text": "In obsessive-compulsive disorder (OCD), repetitive behaviors or mental rituals (such as excessive handwashing or checking locks) primarily serve what psychological function?",
            "correct_text": "To temporarily reduce the intense distress caused by intrusive obsessive thoughts",
            "distractors": [
                "To induce pleasant euphoric sensations and reward dopamine release",
                "To consciously deceive observers and gain external secondary gain",
                "To establish psychotic detachment from stressful physical reality",
            ],
            "explanation": "Compulsions are repetitive behaviors performed according to rigid rules to diminish the severe anxiety or distress evoked by intrusive, uncontrollable obsessive thoughts.",
            "concept_slugs": ["psyc-anxiety-ocd-ptsd"],
        },
        {
            "question_text": "What is the primary manual published by the American Psychiatric Association used by clinicians in the United States to diagnose psychological disorders?",
            "correct_text": "Diagnostic and Statistical Manual of Mental Disorders (DSM-5-TR)",
            "distractors": [
                "International Classification of Diseases (ICD-11)",
                "Physicians' Desk Reference for Neuropsychology (PDR-7)",
                "Standardized Psychometric Classification Guide (SPCG-3)",
            ],
            "explanation": "The DSM-5 (and DSM-5-TR) is the standard classification manual in US clinical practice, establishing diagnostic criteria, symptom thresholds, and exclusionary conditions for mental disorders.",
            "concept_slugs": ["psyc-disorder-classification"],
        },
    ],
    "Depressive, Bipolar, Schizophrenic, and Personality Pathology": [
        {
            "question_text": "A patient exhibiting periods of profound depressive despair alternating with episodes of elevated euphoria, decreased need for sleep, and reckless grandiosity meets criteria for what disorder?",
            "correct_text": "Bipolar I disorder",
            "distractors": [
                "Major depressive disorder",
                "Persistent depressive disorder",
                "Generalized anxiety disorder",
            ],
            "explanation": "Bipolar I disorder is defined by the occurrence of at least one full manic episode (characterized by inflated self-esteem, grandiosity, reduced sleep, and impulsive spending), typically alternating with major depressive episodes.",
            "concept_slugs": ["psyc-mood-bipolar-disorders"],
        },
        {
            "question_text": "In schizophrenia, auditory hallucinations and persecutory delusions are classified as which type of symptoms?",
            "correct_text": "Positive symptoms",
            "distractors": [
                "Negative symptoms",
                "Catatonic motor signs",
                "Affective deficits",
            ],
            "explanation": "Positive symptoms in schizophrenia represent excess or distortion of normal functioning (hallucinations, delusions, disorganized speech), whereas negative symptoms represent deficits (avolition, flat affect).",
            "concept_slugs": ["psyc-schizophrenia-personality"],
        },
    ],
    "Psychological Therapies: Insight, Behavior, and Cognitive Approaches": [
        {
            "question_text": "Aaron Beck's cognitive therapy for major depression focuses primarily on identifying and modifying which psychological mechanism?",
            "correct_text": "Automatic negative thoughts and distorted cognitive schemas (the cognitive triad)",
            "distractors": [
                "Repressed childhood sexual conflicts stored within the dynamic unconscious",
                "Conditioned physiological responses using flooding and aversion protocols",
                "Incongruence between the client's actual and ideal self-concepts",
            ],
            "explanation": "Beck's cognitive therapy systematically targets cognitive distortions (such as catastrophizing, black-and-white thinking, and negative schemas about self, world, and future) through empirical cognitive restructuring.",
            "concept_slugs": ["psyc-cognitive-behavioral-therapy"],
        },
        {
            "question_text": "Which behavioral exposure therapy technique pairs gradual exposure to an anxiety-provoking hierarchy with progressive muscle relaxation?",
            "correct_text": "Systematic desensitization",
            "distractors": [
                "Aversive counterconditioning",
                "Free association therapy",
                "Rational emotive behavior",
            ],
            "explanation": "Developed by Joseph Wolpe, systematic desensitization utilizes counterconditioning: clients learn progressive relaxation and mentally or in vivo confront a graduated fear hierarchy, replacing anxiety with relaxation.",
            "concept_slugs": ["psyc-psychotherapy-modalities"],
        },
    ],
    "Biomedical Therapies, Psychopharmacology, and Treatment Outcomes": [
        {
            "question_text": "Selective serotonin reuptake inhibitors (SSRIs), such as fluoxetine and sertraline, exert their antidepressant effect primarily through which biochemical mechanism?",
            "correct_text": "Blocking the presynaptic reuptake transporter protein for serotonin",
            "distractors": [
                "Directly agonizing postsynaptic dopamine D2 receptors in the striatum",
                "Inhibiting the enzymatic breakdown of monoamine oxidase in the synapse",
                "Antagonizing central nervous system GABA receptors in the amygdala",
            ],
            "explanation": "SSRIs selectively bind to and inhibit the serotonin transporter (SERT) protein on the presynaptic terminal, prolonging the presence and availability of serotonin in the synaptic cleft.",
            "concept_slugs": ["psyc-biomedical-pharmacology"],
        },
        {
            "question_text": "In clinical treatment outcome research, what statistical technique combines the quantitative findings across dozens of independent clinical trials into a single summary effect size?",
            "correct_text": "Meta-analysis",
            "distractors": [
                "Factor analysis",
                "Analysis of variance",
                "Multivariate path model",
            ],
            "explanation": "Meta-analysis mathematically aggregates effect sizes from multiple empirical studies to determine the overall effectiveness and reliability of an intervention across heterogeneous patient samples.",
            "concept_slugs": ["psyc-treatment-efficacy-meta-analysis"],
        },
    ],
    "Social Thinking: Attribution, Cognitive Dissonance, and Obedience": [
        {
            "question_text": "When an observer witnesses a stranger trip and fall and immediately concludes the person is clumsy (ignoring an uneven sidewalk crack), they are demonstrating what cognitive bias?",
            "correct_text": "The fundamental attribution error",
            "distractors": [
                "The self-serving bias",
                "The halo effect bias",
                "Cognitive dissonance bias",
            ],
            "explanation": "The fundamental attribution error is the pervasive tendency to overestimate internal dispositional factors and underestimate situational external factors when analyzing other people's behaviors.",
            "concept_slugs": ["psyc-attribution-dissonance"],
        },
        {
            "question_text": "In Stanley Milgram's classic obedience experiments, which situational factor significantly reduced participants' willingness to administer the highest voltage shocks?",
            "correct_text": "Observing peer confederate teachers rebel and refuse to obey the experimenter",
            "distractors": [
                "Conducting the experiment at prestigious Yale University rather than a downtown office",
                "Having the experimenter wear an official gray laboratory coat and stand directly behind the teacher",
                "Informing participants that the learner was a fellow volunteer from the community",
            ],
            "explanation": "When two confederate teachers rebelled and refused to continue shocking the learner, participant obedience to the maximum 450-volt level dropped precipitously from 65% to only 10%.",
            "concept_slugs": ["psyc-conformity-obedience"],
        },
    ],
    "Group Influence, Prejudice, and the Bystander Effect": [
        {
            "question_text": "The tragic murder of Kitty Genovese in 1964 stimulated social psychologists John Darley and Bibb Latané to study which phenomenon?",
            "correct_text": "The bystander effect and diffusion of responsibility",
            "distractors": [
                "Social loafing in collaborative group tasks",
                "Deindividuation in anonymous crowds",
                "Group polarization during deliberations",
            ],
            "explanation": "Darley and Latané investigated the bystander effect: individuals are significantly less likely to intervene in an emergency when other bystanders are present due to diffusion of responsibility.",
            "concept_slugs": ["psyc-prejudice-altruism"],
        },
        {
            "question_text": "When like-minded group members discuss a contentious topic and their post-discussion viewpoints become substantially more extreme than their initial pre-discussion opinions, what has occurred?",
            "correct_text": "Group polarization",
            "distractors": [
                "Groupthink tendency",
                "Social facilitation",
                "Deindividuation effect",
            ],
            "explanation": "Group polarization occurs when group deliberation strengthens and intensifies the prevailing shared inclinations of its members, shifting decisions toward a more extreme pole.",
            "concept_slugs": ["psyc-group-dynamics"],
        },
    ],
    "Statistical Measures, Psychometric Standards, and Intelligence Assessment": [
        {
            "question_text": "In a positively skewed distribution of test scores with a few extremely high outlier scores, what is the relative order of the three measures of central tendency?",
            "correct_text": "Mode < Median < Mean",
            "distractors": [
                "Mean < Median < Mode",
                "Median < Mean < Mode",
                "Mean = Median = Mode",
            ],
            "explanation": "In a positively skewed distribution, extreme high scores pull the mean toward the right tail, resulting in Mode < Median < Mean.",
            "concept_slugs": ["psyc-descriptive-inferential-statistics"],
        },
        {
            "question_text": "A psychometric exam that yields consistent, stable scores across repeated administrations to the same cohort of students demonstrates what measurement property?",
            "correct_text": "High reliability",
            "distractors": [
                "High construct validity",
                "High criterion validity",
                "Low standard error mean",
            ],
            "explanation": "Reliability refers to the internal consistency and repeatability of a test's measurement results; a test that gives consistent scores over time has high test-retest reliability.",
            "concept_slugs": ["psyc-psychometric-reliability-validity"],
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
                "citation": "OpenStax Psychology 2e, CC BY 4.0",
            })
            q_index += 1
        balanced[title] = lesson_qs

    return balanced


FORMATIVE_QUESTIONS_BY_LESSON = build_balanced_formative_questions()
