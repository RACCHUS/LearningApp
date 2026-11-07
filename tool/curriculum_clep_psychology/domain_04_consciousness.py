"""Domain 4.0: States of Consciousness (Quota: 5 questions, 5–6% blueprint)."""
from __future__ import annotations

DOMAIN_04 = {
    "code": "4.0",
    "title": "States of Consciousness",
    "description": "Circadian rhythms, sleep architecture and NREM/REM stages, sleep disorders, dream theories, hypnosis, and psychoactive drug classifications.",
    "weight": 0.055,
    "sort_order": 4,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 4.0 (5–6%)",
    "objectives": [
        {
            "code": "4.1",
            "title": "Analyze biological rhythms, sleep stages, and physiological architecture",
            "description": "Examine circadian regulation by the suprachiasmatic nucleus, distinguish NREM-1, NREM-2, NREM-3, and REM sleep, and describe sleep functions.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 4.1",
            "concepts": [
                {
                    "slug": "psyc-circadian-rhythms",
                    "name": "Circadian Rhythms and Sleep Architecture",
                    "short_definition": "Endogenous 24-hour biological cycles governed by the suprachiasmatic nucleus regulating sleep-wake cycles and melatonin secretion.",
                    "description": "The suprachiasmatic nucleus (SCN) in the hypothalamus directs the pineal gland to release melatonin during darkness and suppress it in light.",
                    "citation": "OpenStax Psychology 2e, Section 4.2",
                },
                {
                    "slug": "psyc-sleep-stages",
                    "name": "NREM and REM Sleep Cycles",
                    "short_definition": "Sequential 90-minute sleep cycles alternating between non-REM stages (characterized by sleep spindles and delta waves) and REM paradoxical sleep.",
                    "description": "Sleep transitions through NREM-1 (theta), NREM-2 (spindles/K-complexes), NREM-3 (slow-wave delta), and REM (rapid eye movement, motor atonia, dreaming).",
                    "citation": "OpenStax Psychology 2e, Section 4.2",
                    "prerequisites": ["psyc-circadian-rhythms"],
                },
            ],
            "lessons": [
                {
                    "title": "Sleep Architecture and Biological Rhythms",
                    "description": "Circadian regulation, suprachiasmatic nucleus mechanics, EEG waveforms across NREM-1, NREM-2, NREM-3, and REM sleep.",
                    "emoji": "🌙",
                    "tags": ["sleep", "circadian", "rem", "delta", "brainwaves"],
                    "concept_slugs": [
                        "psyc-circadian-rhythms",
                        "psyc-sleep-stages",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 4.2: Sleep and Why We Sleep",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Biological Clocks and Circadian Regulation\n\n"
                                    "Human physiological arousal, hormone release, and body temperature fluctuate along a **circadian rhythm**—an internal biological clock that repeats approximately every 24 hours. "
                                    "Light-sensitive retinal ganglion cells project to the **suprachiasmatic nucleus (SCN)** in the hypothalamus. "
                                    "In daylight, the SCN suppresses melatonin secretion; in darkness, the SCN signals the **pineal gland** to secrete **melatonin**, inducing drowsiness.\n\n"
                                    "### The Architecture of the 90-Minute Sleep Cycle\n\n"
                                    "Sleep progresses through repeating 90-minute ultradian cycles across four distinct stages:\n\n"
                                    "| Sleep Stage | Dominant EEG Waveform | Defining Physiological Characteristics |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Waking (Alert)** | Beta waves (high frequency, low amplitude) | Active mental concentration, desynchronized firing |\n"
                                    "| **Waking (Relaxed)** | Alpha waves (8–12 Hz) | Calm, resting state with closed eyes |\n"
                                    "| **NREM-1** | Theta waves (4–7 Hz) | Light transitional sleep; hypnagogic sensations (falling, jerks) |\n"
                                    "| **NREM-2** | Theta with **Sleep Spindles** & **K-complexes** | Baseline adult sleep (~50% of night); memory consolidation |\n"
                                    "| **NREM-3** | **Delta waves** (slow, large waves $<4$ Hz) | Deep slow-wave sleep; pituitary human growth hormone release |\n"
                                    "| **REM Sleep** | Beta-like fast, desynchronized waves | **Paradoxical sleep:** active brain/eyes, but complete **motor atonia** |"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Why REM is Termed 'Paradoxical Sleep'",
                                "body": "REM sleep is called **paradoxical** because the internal body is physiologically highly aroused (heart rate accelerates, breathing becomes irregular, brain metabolism resembles waking beta activity), yet the external somatic musculature is completely paralyzed by brainstem inhibition (motor atonia).",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "example",
                            "content": {
                                "title": "Sleep Lab Case Study: Polysomnographic Shift Across the Night",
                                "text": (
                                    "An overnight sleep study monitors a 20-year-old college student. "
                                    "During the first four hours of sleep, the patient spends extensive durations in deep NREM-3 slow-wave sleep (delta waves). "
                                    "During the second half of the night, NREM-3 stages virtually disappear, while REM periods lengthen progressively, "
                                    "culminating in an extended 30-minute REM dream episode just before waking."
                                ),
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Sleep Spindles vs. Delta Waves",
                                "body": "Do not confuse **NREM-2** with **NREM-3**. **Sleep spindles** (brief 12–14 Hz bursts) definitively mark NREM-2. **Delta waves** (large, high-amplitude slow waves) definitively mark NREM-3 deep sleep.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Suprachiasmatic Nucleus (SCN)",
                            "definition": "A pair of cell clusters in the hypothalamus that controls the circadian rhythm by regulating pineal melatonin production.",
                            "example": "Light entering the retinas stimulates the SCN to inhibit melatonin synthesis in the morning.",
                        },
                        {
                            "term": "Sleep Spindles",
                            "definition": "Rapid bursts of oscillatory brain electrical activity generated in the thalamus during NREM-2 sleep, aiding memory consolidation.",
                            "example": "An EEG recording displaying brief 12–14 Hz spikes against a theta wave background.",
                        },
                        {
                            "term": "REM Sleep",
                            "definition": "A recurring sleep stage characterized by rapid conjugate eye movements, vivid dreaming, and postural muscle atonia.",
                            "example": "A sleeper experiencing vivid dream narratives while their skeletal muscles remain completely limp.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Which biological structure located in the hypothalamus functions as the body's primary circadian pacemaker by regulating the pineal gland's secretion of melatonin?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Substantia nigra",
                                    "Suprachiasmatic nucleus",
                                    "Hippocampal formation",
                                    "Nucleus accumbens",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "The suprachiasmatic nucleus (SCN) in the hypothalamus serves as the primary master circadian clock. In response to retinal light input, the SCN directs the pineal gland to suppress melatonin production in the morning and stimulate melatonin synthesis at night.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 4.2",
                            "concept_slugs": ["psyc-circadian-rhythms"],
                        },
                        {
                            "prompt": "Why is rapid eye movement (REM) sleep frequently referred to by neuroscientists as 'paradoxical sleep'?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "The brain exhibits slow delta waves while muscles twitch rapidly",
                                    "Sleepers experience no dreams despite intense ocular movement",
                                    "The brain is highly active internally while skeletal muscles are paralyzed",
                                    "Growth hormone secretion peaks while heart rate plummets to near zero",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "REM sleep is called paradoxical because the central nervous system is highly aroused with waking-like beta/theta brainwave activity and rapid eye movements, yet the brainstem actively blocks somatic motor commands, leaving the sleeper in a state of postural muscle paralysis (atonia).",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 4.2",
                            "concept_slugs": ["psyc-sleep-stages"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "Which gland releases melatonin in response to signals from the suprachiasmatic nucleus?",
                    "back": "The pineal gland.",
                    "concept_slugs": ["psyc-circadian-rhythms"],
                },
                {
                    "front": "What type of EEG wave dominates deep, slow-wave NREM-3 sleep?",
                    "back": "Delta waves (large, slow brain waves).",
                    "concept_slugs": ["psyc-sleep-stages"],
                },
            ],
        },
        {
            "code": "4.2",
            "title": "Evaluate sleep disorders, theories of dreaming, hypnosis, and psychoactive drugs",
            "description": "Distinguish insomnia, narcolepsy, and sleep apnea, evaluate activation-synthesis vs. psychodynamic dream models, and categorize depressants, stimulants, and hallucinogens.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 4.2",
            "concepts": [
                {
                    "slug": "psyc-sleep-disorders-dreams",
                    "name": "Sleep Pathology and Dream Theories",
                    "short_definition": "Clinical sleep disorders (narcolepsy, sleep apnea, insomnia) and theoretical explanations of dream function (Freud vs. activation-synthesis).",
                    "description": "Pathology includes narcoleptic cataplexy and obstructive sleep apnea; dream models contrast Freud's latent wish fulfillment with Hobson's neurobiological synthesis.",
                    "citation": "OpenStax Psychology 2e, Section 4.3 & 4.4",
                },
                {
                    "slug": "psyc-psychoactive-drugs",
                    "name": "Psychoactive Drugs and Altered Consciousness",
                    "short_definition": "Pharmacological classes of consciousness-altering substances (depressants, stimulants, hallucinogens, opioids) and dependence mechanisms.",
                    "description": "Depressants enhance GABA inhibition; stimulants elevate monoamines; tolerance and withdrawal characterize physical dependence alongside psychological craving.",
                    "citation": "OpenStax Psychology 2e, Section 4.5",
                    "prerequisites": ["psyc-sleep-disorders-dreams"],
                },
            ],
            "lessons": [
                {
                    "title": "Sleep Disorders, Theories of Dreaming, and Psychoactive Drugs",
                    "description": "Insomnia, narcolepsy, sleep apnea, Hobson's activation-synthesis, hypnosis dissociation, and psychoactive substance categories.",
                    "emoji": "💊",
                    "tags": ["disorders", "narcolepsy", "apnea", "activation-synthesis", "drugs"],
                    "concept_slugs": [
                        "psyc-sleep-disorders-dreams",
                        "psyc-psychoactive-drugs",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 4.3, 4.4, & 4.5",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Major Clinical Sleep Disorders\n\n"
                                    "- **Insomnia:** Chronic inability to fall asleep or maintain sleep, causing daytime cognitive impairment.\n"
                                    "- **Narcolepsy:** Sudden, uncontrollable sleep attacks where the patient collapses directly into **REM sleep**, often triggered by strong emotional excitement. Associated with a deficit in **hypocretin/orexin** neurons in the hypothalamus.\n"
                                    "- **Sleep Apnea:** Repeated episodes during sleep where the airway collapses, stopping respiration for 10–60 seconds hundreds of times per night. Treated with continuous positive airway pressure (**CPAP**).\n"
                                    "- **Night Terrors:** High autonomic arousal and screaming occurring during **NREM-3 deep sleep** (not REM nightmares); patients rarely recall the episode.\n\n"
                                    "### Theoretical Models of Dreaming\n\n"
                                    "| Model | Primary Mechanism | View on Dream Content |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Freud's Psychoanalytic Theory** | Unconscious psychic wish fulfillment | **Manifest content** (apparent storyline) masks **Latent content** (hidden sexual/aggressive drives) |\n"
                                    "| **Activation-Synthesis Theory (Hobson)** | Random neural brainstem firing synthesized by cortex | Dreams are cognitive attempts to make sense of spontaneous pontine activity |\n"
                                    "| **Information-Processing Theory** | Memory consolidation and synaptic pruning | Dreams reprocess and organize daytime experiences into long-term storage |"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Psychoactive Drug Classifications\n\n"
                                    "- **Depressants (Alcohol, Barbiturates, Benzodiazepines):** Reduce neural activity and slow body functions by enhancing the inhibitory neurotransmitter **GABA**.\n"
                                    "- **Stimulants (Caffeine, Nicotine, Cocaine, Amphetamines):** Excite neural activity, elevate heart rate, and suppress appetite by blocking the reuptake of **dopamine** and **norepinephrine**.\n"
                                    "- **Opioids / Narcotics (Morphine, Heroin, Codeine, Fentanyl):** Depress neural functioning, relieve pain, and produce euphoria by binding to endogenous **endorphin** receptor sites.\n"
                                    "- **Hallucinogens (LSD, Psilocybin, MDMA):** Distort visual and auditory perceptions and evoke sensory images without sensory input, primarily acting as **serotonin** receptor agonists.\n\n"
                                    "### Dependence and Tolerance\n\n"
                                    "- **Tolerance:** Requiring larger and larger drug dosages to achieve the initial physiological effect.\n"
                                    "- **Physical Dependence & Withdrawal:** Physiological adaptation characterized by physical illness, cramping, or tremors upon cessation."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Night Terrors vs. Nightmares",
                                "body": "**Night terrors** occur during **NREM-3 deep sleep**, involve screaming and frantic motor agitation, and are rarely remembered. **Nightmares** are vivid terrifying dreams that occur during **REM sleep**, usually in early morning hours, and are readily recalled upon waking.",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Clinical Vignette: Cataplexy in Narcoleptic Patients",
                                "text": (
                                    "A 28-year-old teacher laughs uproariously at a student's joke and instantly collapses to the floor, "
                                    "unable to speak or move while remaining fully conscious for 45 seconds. "
                                    "This symptom—**cataplexy**—is a pathognomonic sign of narcolepsy, where REM-induced muscle atonia is inappropriately triggered during waking consciousness."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Alcohol Classification",
                                "body": "Even though small amounts of alcohol can cause behavioral disinhibition and an initial sense of euphoria, alcohol is biologically classified as a **depressant** because it systematically suppresses central nervous system functioning by acting as a GABA agonist.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Sleep Apnea",
                            "definition": "A serious sleep disorder in which breathing repeatedly stops and starts throughout the night due to upper airway collapse.",
                            "example": "A patient with loud snoring who wakes hundreds of times per night gasping for air, suffering chronic daytime fatigue.",
                        },
                        {
                            "term": "Activation-Synthesis Theory",
                            "definition": "The neurobiological theory that dreams are created by the cerebral cortex attempting to synthesize and interpret random neural impulses originating in the brainstem.",
                            "example": "Hobson and McCarley proposing that dreams represent cortical sense-making of spontaneous pontine bursts.",
                        },
                        {
                            "term": "Tolerance",
                            "definition": "The diminishing effect with regular use of the same dose of a drug, requiring the user to take larger amounts to experience the drug's effect.",
                            "example": "A chronic heroin user requiring ten times their starting dose to achieve pain relief.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "According to J. Allan Hobson's activation-synthesis hypothesis, what represents the primary biological origin of dreams?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Random pontine neural activity synthesized by the cerebral cortex",
                                    "Repressed sexual impulses emerging from the unconscious id",
                                    "Systematic sorting and filing of daily declarative memory traces",
                                    "Periodic physiological maintenance of damaged retinal photoreceptors",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Hobson and McCarley's activation-synthesis model proposes that dreaming results from the cerebral cortex's attempt to synthesize and impose a coherent narrative onto spontaneous, random bursts of neural activity originating in the lower brainstem (pons) during REM sleep.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 4.3",
                            "concept_slugs": ["psyc-sleep-disorders-dreams"],
                        },
                        {
                            "prompt": "A sleep clinic patient periodically stops breathing dozens of times each hour, resulting in repeated micro-awakenings and severe daytime somnolence. What diagnosis is indicated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Narcoleptic cataplexy",
                                    "Somnambulism",
                                    "Sleep apnea",
                                    "NREM-3 night terrors",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Sleep apnea is characterized by temporary cessations of breathing during sleep lasting 10 seconds or longer, caused by airway blockage. The resulting blood oxygen drops prompt repeated brief awakenings, disrupting restorative sleep.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 4.4",
                            "concept_slugs": ["psyc-sleep-disorders-dreams"],
                        },
                        {
                            "prompt": "Alcohol, barbiturates, and benzodiazepines are grouped together into which pharmacological drug category based on their shared ability to depress central nervous system activity?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Stimulants",
                                    "Hallucinogens",
                                    "Opiates",
                                    "Depressants",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Alcohol, barbiturates, and benzodiazepines are depressants. They reduce neural activity and slow autonomic functions, primarily by acting as GABA receptor agonists, which enhances inhibitory neurotransmission across the central nervous system.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 4.5",
                            "concept_slugs": ["psyc-psychoactive-drugs"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the difference between manifest and latent dream content in Freud's theory?",
                    "back": "Manifest content is the remembered storyline; latent content is the underlying, hidden psychological meaning.",
                    "concept_slugs": ["psyc-sleep-disorders-dreams"],
                },
                {
                    "front": "What neurotransmitter system is primarily enhanced by depressant drugs like alcohol and benzodiazepines?",
                    "back": "GABA (the primary inhibitory neurotransmitter).",
                    "concept_slugs": ["psyc-psychoactive-drugs"],
                },
            ],
        },
    ],
}
