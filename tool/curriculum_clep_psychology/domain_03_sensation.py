"""Domain 3.0: Sensation and Perception (Quota: 7 questions, 7–8% blueprint)."""
from __future__ import annotations

DOMAIN_03 = {
    "code": "3.0",
    "title": "Sensation and Perception",
    "description": "Sensory thresholds, signal detection, transduction, visual and auditory anatomy, color vision theories, and Gestalt perceptual organization.",
    "weight": 0.075,
    "sort_order": 3,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 3.0 (7–8%)",
    "objectives": [
        {
            "code": "3.1",
            "title": "Analyze sensory transduction, psychophysical thresholds, and signal detection theory",
            "description": "Define absolute and difference thresholds, apply Weber's law, explain sensory adaptation, and evaluate signal detection matrix outcomes.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 3.1",
            "concepts": [
                {
                    "slug": "psyc-sensory-thresholds",
                    "name": "Psychophysical Thresholds and Transduction",
                    "short_definition": "Conversion of environmental physical energy into neural electrical impulses, governed by absolute thresholds and Weber's law.",
                    "description": "Transduction converts physical wavelengths, sound waves, and chemical molecules into neural signals evaluated through absolute and difference thresholds.",
                    "citation": "OpenStax Psychology 2e, Section 5.1",
                },
                {
                    "slug": "psyc-signal-detection",
                    "name": "Signal Detection Theory and Sensory Adaptation",
                    "short_definition": "Framework quantifying the detection of faint sensory stimuli amid background noise as a function of sensitivity and decision bias.",
                    "description": "Decisions yield four outcomes: hits, misses, false alarms, and correct rejections, mediated by psychological readiness and sensory adaptation.",
                    "citation": "OpenStax Psychology 2e, Section 5.1",
                    "prerequisites": ["psyc-sensory-thresholds"],
                },
            ],
            "lessons": [
                {
                    "title": "Sensory Reception, Transduction, and Thresholds",
                    "description": "Principles of psychophysics: absolute thresholds, Weber's law, signal detection matrices, and sensory adaptation.",
                    "emoji": "👁️",
                    "tags": ["sensation", "thresholds", "transduction", "webers-law"],
                    "concept_slugs": [
                        "psyc-sensory-thresholds",
                        "psyc-signal-detection",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 5.1: Sensation versus Perception",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Sensation versus Perception and Transduction\n\n"
                                    "- **Sensation:** The physical reception of environmental energy by specialized sensory receptor cells.\n"
                                    "- **Perception:** The psychological organization and cognitive interpretation of sensory inputs to create meaningful experiences.\n"
                                    "- **Transduction:** The physical conversion of sensory stimuli (e.g., photons, acoustic pressure waves, dissolved chemicals) into electrochemical neural action potentials.\n\n"
                                    "### Psychophysical Thresholds\n\n"
                                    "- **Absolute Threshold:** The minimum intensity of a stimulus required for a person to detect it **50% of the time**.\n"
                                    "- **Difference Threshold (Just Noticeable Difference / JND):** The minimum difference between two stimuli required for detection 50% of the time.\n"
                                    "- **Weber's Law:** To be perceived as different, two stimuli must differ by a **constant minimum percentage (proportion)** rather than a constant fixed amount:\n"
                                    "  $$\\frac{\\Delta I}{I} = k$$\n"
                                    "  *(e.g., adding 1 ounce to a 10-ounce weight is noticeable, but adding 1 ounce to a 100-ounce weight is undetectable because the required proportion is not met.)*"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Signal Detection Theory Matrix\n\n"
                                    "Signal detection theory assumes there is no single absolute threshold; detection depends on both sensory sensitivity and psychological factors (motivation, fatigue, expectancy):\n\n"
                                    "| Subject Response | Stimulus Present | Stimulus Absent |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Said 'Yes' (Detected)** | **Hit** (Correct detection) | **False Alarm** (Type I error) |\n"
                                    "| **Said 'No' (Did Not Detect)** | **Miss** (Type II error) | **Correct Rejection** (Accurate dismissal) |\n\n"
                                    "### Sensory Adaptation\n\n"
                                    "**Sensory adaptation** occurs when prolonged exposure to an unchanging stimulus results in diminished neural firing and subjective sensitivity (e.g., no longer noticing the hum of an air conditioner or the scent of perfume after several minutes). Adaptation frees attentional capacity for novel environmental changes."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Sensory Adaptation vs. Habituation",
                                "body": "**Sensory adaptation** is a physiological reduction in sensory receptor responsiveness (e.g., retinal photoreceptors becoming less reactive). **Habituation** is a cognitive/central decrease in attention to a recognized, repeated stimulus (e.g., tuning out clock ticking).",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Applied Clinical Context: Radiologist Mammogram Screening",
                                "text": (
                                    "A radiologist scanning 200 mammograms per day operates under signal detection conditions. "
                                    "If set to a conservative criterion (afraid of false alarms), they risk missing faint malignant tumors (Misses). "
                                    "If set to a liberal criterion (determined never to miss a tumor), they produce more false alarms requiring follow-up biopsies. "
                                    "Signal detection theory models how training and stakes alter this decision threshold."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Weber's Law Constant Ratio",
                                "body": "Remember that Weber's Law operates on **proportions**, not absolute units. If an individual can just tell the difference between 50 grams and 52 grams (a 4% JND), they will require a difference of 4 grams (not 2 grams) to detect a difference starting from 100 grams.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Transduction",
                            "definition": "The biological process by which sensory receptors convert physical energy from the environment into neural electrochemical signals.",
                            "example": "Rods and cones converting electromagnetic light waves into action potentials transmitted along the optic nerve.",
                        },
                        {
                            "term": "Absolute Threshold",
                            "definition": "The minimal stimulus energy required to activate a sensory system and be detected at least 50 percent of the time.",
                            "example": "Detecting the flame of a candle 30 miles away on a clear, dark night.",
                        },
                        {
                            "term": "Weber's Law",
                            "definition": "The psychophysical principle that the just noticeable difference between two stimuli is a constant minimum proportion of the initial stimulus intensity.",
                            "example": "Noticing a 10% increase in brightness whether looking at a dim lamp or a bright chandelier.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "An audio engineer can just barely detect a volume difference when a 100-decibel tone is raised by 5 decibels. According to Weber's Law, how many decibels must a 200-decibel tone be raised for the engineer to notice a change?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "10 decibels",
                                    "5 decibels",
                                    "20 decibels",
                                    "2.5 decibels",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Weber's law states that the difference threshold is a constant proportion of the original stimulus. Since a 5 dB increase on a 100 dB sound represents a 5% difference ratio, a 200 dB sound requires a 5% increase (which equals 10 dB) to produce a just noticeable difference.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 5.1",
                            "concept_slugs": ["psyc-sensory-thresholds"],
                        },
                        {
                            "prompt": "An air traffic controller on night duty detects a faint radar blip on the screen when no aircraft is present. Under signal detection theory, what classification does this outcome represent?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Signal hit (accurate detection)",
                                    "False alarm (false positive)",
                                    "Signal miss (false negative)",
                                    "Correct rejection (true negative)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "In signal detection theory, a false alarm occurs when a participant reports detecting a target signal that was not actually present (a Type I error). A hit is detecting a signal present; a miss is failing to detect a signal present; a correct rejection is confirming absence.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 5.1",
                            "concept_slugs": ["psyc-signal-detection"],
                        },
                        {
                            "prompt": "After entering an Italian restaurant, an individual notices a pungent aroma of garlic, but after fifteen minutes, they are completely oblivious to the scent. What physiological phenomenon is illustrated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Top-down perceptual framing",
                                    "Selective cognitive inattention",
                                    "Sensory adaptation",
                                    "Subliminal olfactory priming",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Sensory adaptation is the diminished sensitivity to an unchanging, continuous stimulus that occurs as sensory receptor cells decrease their firing frequency. This allows the nervous system to focus on novel environmental changes.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 5.1",
                            "concept_slugs": ["psyc-signal-detection"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is transduction in sensation?",
                    "back": "The conversion of environmental physical energy into neural electrical impulses.",
                    "concept_slugs": ["psyc-sensory-thresholds"],
                },
                {
                    "front": "What does a false alarm represent in signal detection theory?",
                    "back": "Reporting that a signal was present when no signal actually occurred.",
                    "concept_slugs": ["psyc-signal-detection"],
                },
            ],
        },
        {
            "code": "3.2",
            "title": "Analyze visual and auditory anatomy, color vision theories, and Gestalt perceptual principles",
            "description": "Contrast rods and cones, compare trichromatic and opponent-process theories, describe auditory transduction, and apply Gestalt laws of perceptual grouping.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 3.2",
            "concepts": [
                {
                    "slug": "psyc-visual-auditory-systems",
                    "name": "Visual and Auditory Sensory Anatomy",
                    "short_definition": "Anatomical pathways of vision (retina, rods/cones, optic nerve) and audition (eardrum, ossicles, cochlear basilar membrane).",
                    "description": "Photoreception occurs in retinal rods (dim light) and cones (color/acuity in fovea); auditory transduction occurs in the cochlea via basilar membrane hair cell deflection.",
                    "citation": "OpenStax Psychology 2e, Section 5.2",
                },
                {
                    "slug": "psyc-perceptual-organization",
                    "name": "Perceptual Organization and Depth Cues",
                    "short_definition": "Gestalt principles of grouping (proximity, similarity, continuity, closure) and depth perception via monocular and binocular cues.",
                    "description": "Perception synthesizes bottom-up sensory data with top-down expectations through figure-ground segregation and retinal disparity.",
                    "citation": "OpenStax Psychology 2e, Section 5.3",
                    "prerequisites": ["psyc-visual-auditory-systems"],
                },
            ],
            "lessons": [
                {
                    "title": "Visual Anatomy, Color Theories, and Perceptual Organization",
                    "description": "Rods and cones, trichromatic vs. opponent-process theory, cochlear mechanics, and Gestalt grouping laws.",
                    "emoji": "🎨",
                    "tags": ["vision", "audition", "gestalt", "color-theory", "depth"],
                    "concept_slugs": [
                        "psyc-visual-auditory-systems",
                        "psyc-perceptual-organization",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 5.2 & 5.3",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Visual System: Photoreception and Processing\n\n"
                                    "Light enters through the **cornea**, passes through the **pupil** (regulated by the **iris**), is focused by the **lens** (via **accommodation**), and strikes the **retina**:\n\n"
                                    "| Feature | Rods | Cones |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Total Quantity** | ~120 million | ~6 million |\n"
                                    "| **Retinal Location** | Periphery of retina | Concentrated in central **fovea** |\n"
                                    "| **Light Sensitivity** | High sensitivity; optimal for dim/night vision | Low sensitivity; requires bright daylight |\n"
                                    "| **Color & Acuity** | Monochromatic (shades of gray); low acuity | Color vision; high spatial acuity and detail |\n\n"
                                    "### Theories of Color Vision\n\n"
                                    "1. **Young-Helmholtz Trichromatic Theory:** The retina possesses three distinct cone types maximally sensitive to different wavelengths: **Red (long)**, **Green (medium)**, and **Blue (short)**. Color perception results from additive ratios of stimulation.\n"
                                    "2. **Hering's Opponent-Process Theory:** Neural circuits beyond the retina (in ganglion cells, thalamus, and visual cortex) process color through three opposing channels:\n"
                                    "   - **Red vs. Green**\n"
                                    "   - **Blue vs. Yellow**\n"
                                    "   - **Black vs. White**\n"
                                    "   *Explains negative afterimages: fatiguing green receptors causes a white surface to appear red.*"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Gestalt Principles of Perceptual Organization\n\n"
                                    "The German Gestalt psychologists emphasized that *'the whole is greater than the sum of its parts'*. The mind automatically organizes sensations into coherent forms:\n"
                                    "- **Figure-Ground:** Isolating the primary object (figure) from its surrounding background.\n"
                                    "- **Proximity:** Grouping visual elements that are physically close together.\n"
                                    "- **Similarity:** Grouping elements that share color, shape, or orientation.\n"
                                    "- **Continuity:** Perceiving smooth, continuous paths rather than abrupt, jagged angles.\n"
                                    "- **Closure:** Automatically filling in missing visual gaps to perceive complete, whole objects.\n\n"
                                    "### Depth Perception Cues\n\n"
                                    "- **Binocular Cues:** Require both eyes. Includes **retinal disparity** (different angles seen by each eye, greater for nearby objects) and **convergence** (neuromuscular inward turning of eyes).\n"
                                    "- **Monocular Cues:** Require one eye only. Includes **linear perspective** (parallel lines converge with distance), **interposition** (closer objects block farther objects), **relative size**, **texture gradient**, and **motion parallax**."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Reconciling the Two Color Theories",
                                "body": "Both color theories are scientifically correct, but describe different stages: **Trichromatic theory** explains photoreceptor function at the *retina/cone* level. **Opponent-process theory** explains subsequent neural coding in *ganglion cells, thalamus, and visual cortex*.",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Experimental Case Study: The Visual Cliff Paradigm",
                                "text": (
                                    "Eleanor Gibson and Richard Walk placed 6- to 14-month-old human infants on a visual cliff apparatus: "
                                    "a heavy glass tabletop suspended over an apparent vertical drop. Even when coaxed by their mothers from the 'deep' side, "
                                    "most infants refused to crawl onto the glass, demonstrating that depth perception and innate avoidance of heights "
                                    "are present by the onset of mobile locomotion."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Blind Spot Mechanics",
                                "body": "The **blind spot** exists because there are zero photoreceptors (neither rods nor cones) at the specific point where the optic nerve axons exit the eyeball to travel toward the brain.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Opponent-Process Theory",
                            "definition": "The theory that color perception relies on retinal and thalamic ganglion cells that are stimulated by one color and inhibited by its opponent color.",
                            "example": "Staring at a green square for 60 seconds and then looking at a blank white wall produces a red afterimage.",
                        },
                        {
                            "term": "Fovea",
                            "definition": "The central focal point of the retina containing a dense concentration of cones and zero rods, providing maximum visual acuity.",
                            "example": "When reading fine print, your eyes orient the text directly onto the fovea.",
                        },
                        {
                            "term": "Retinal Disparity",
                            "definition": "A binocular depth cue arising from the horizontal separation between the eyes, resulting in slightly different images cast on each retina.",
                            "example": "Holding a finger in front of your face and alternately closing each eye reveals horizontal jumping of the image.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "An individual stares fixedly at an intense green square for one minute and then immediately shifts their gaze to a blank white card. What afterimage color will they perceive?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Red",
                                    "Blue",
                                    "Yellow",
                                    "Black",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "According to Hering's opponent-process theory, color vision is governed by opposing neural channels (red-green, blue-yellow, black-white). Staring at green fatigues the green-sensitive receptors, allowing the rebound firing of the opposing red receptors when viewing neutral white light.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 5.2",
                            "concept_slugs": ["psyc-visual-auditory-systems"],
                        },
                        {
                            "prompt": "Which photoreceptors are primarily concentrated in the central fovea of the retina and are responsible for high-acuity color vision in bright daylight?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Retinal bipolar cells",
                                    "Cone photoreceptors",
                                    "Rod photoreceptors",
                                    "Retinal ganglion cells",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Cones are specialized photoreceptors densely clustered in the central fovea that function best in bright illumination, providing fine spatial detail and trichromatic color vision. Rods dominate the periphery and govern dim light vision.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 5.2",
                            "concept_slugs": ["psyc-visual-auditory-systems"],
                        },
                        {
                            "prompt": "When observing railroad tracks that appear to converge in the distance, an artist relies on which monocular depth cue to create the perception of distance?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Retinal disparity",
                                    "Convergence",
                                    "Linear perspective",
                                    "Motion parallax",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Linear perspective is a monocular depth cue in which parallel lines appear to converge as distance from the observer increases. Retinal disparity and convergence are binocular cues requiring both eyes.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 5.3",
                            "concept_slugs": ["psyc-perceptual-organization"],
                        },
                        {
                            "prompt": "A reader effortlessly perceives a series of broken dashes '— — — —' as a single continuous line rather than disconnected individual fragments. Which Gestalt principle explains this tendency?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Law of figure-ground",
                                    "Law of proximity",
                                    "Law of closure",
                                    "Law of continuity",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "The Gestalt law of continuity states that observers tend to perceive elements as continuing along an established direction rather than as broken, abrupt fragments. Closure specifically refers to filling in enclosed gaps.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 5.3",
                            "concept_slugs": ["psyc-perceptual-organization"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What anatomical feature creates the visual blind spot?",
                    "back": "The exit point where the optic nerve leaves the retina, which lacks photoreceptors.",
                    "concept_slugs": ["psyc-visual-auditory-systems"],
                },
                {
                    "front": "What are the two binocular depth cues?",
                    "back": "Retinal disparity (different angles between retinas) and convergence (neuromuscular eye turning).",
                    "concept_slugs": ["psyc-perceptual-organization"],
                },
            ],
        },
    ],
}
