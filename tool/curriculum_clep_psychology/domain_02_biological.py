"""Domain 2.0: Biological Bases of Behavior (Quota: 9 questions, 8–9% blueprint)."""
from __future__ import annotations

DOMAIN_02 = {
    "code": "2.0",
    "title": "Biological Bases of Behavior",
    "description": "Neural transmission, neurotransmitters, nervous system organization, endocrine regulation, brain structures, hemispheric lateralization, and neuroplasticity.",
    "weight": 0.090,
    "sort_order": 2,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 2.0 (8–9%)",
    "objectives": [
        {
            "code": "2.1",
            "title": "Analyze neural anatomy, electrochemical action potentials, and neurotransmitter functions",
            "description": "Describe neuron structures, resting and action potentials, synaptic transmission, and the behavioral roles of major neurotransmitters.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 2.1",
            "concepts": [
                {
                    "slug": "psyc-neuron-structure",
                    "name": "Neuron Structure and Action Potential Dynamics",
                    "short_definition": "Electrochemical signaling mechanism whereby neurons transmit information via all-or-none electrical impulses down the axon.",
                    "description": "Neurons maintain a resting potential of -70 mV and fire an all-or-none action potential when depolarization reaches the excitation threshold (-55 mV).",
                    "citation": "OpenStax Psychology 2e, Section 3.2",
                },
                {
                    "slug": "psyc-neurotransmitters",
                    "name": "Neurotransmitters and Neuromodulation",
                    "short_definition": "Chemical messengers released across the synaptic cleft that bind to postsynaptic receptors to produce excitatory or inhibitory potentials.",
                    "description": "Key neurotransmitters include acetylcholine, dopamine, serotonin, norepinephrine, GABA, and glutamate, modulated by pharmacological agonists and antagonists.",
                    "citation": "OpenStax Psychology 2e, Section 3.2",
                    "prerequisites": ["psyc-neuron-structure"],
                },
            ],
            "lessons": [
                {
                    "title": "The Neuron and Electrochemical Communication",
                    "description": "Anatomy of the neuron, resting potential, ionic action potential propagation, and neurotransmitter dynamics.",
                    "emoji": "⚡",
                    "tags": ["neuroscience", "neuron", "action-potential", "neurotransmitters"],
                    "concept_slugs": [
                        "psyc-neuron-structure",
                        "psyc-neurotransmitters",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 3.2: Cells of the Nervous System",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Electrochemical Architecture of the Neuron\n\n"
                                    "The **neuron** is the basic operational unit of the nervous system. Signals travel through distinct structural components:\n"
                                    "- **Dendrites:** Branching fibers that receive chemical messages from neighboring neurons.\n"
                                    "- **Soma (Cell Body):** Contains the nucleus and metabolic machinery; integrates incoming electrical inputs.\n"
                                    "- **Axon:** Single elongated fiber that conducts electrical impulses away from the cell body toward target cells.\n"
                                    "- **Myelin Sheath:** Fatty insulation formed by glial cells (Schwann cells in PNS, oligodendrocytes in CNS) that speeds transmission via **saltatory conduction** across the **Nodes of Ranvier**.\n"
                                    "- **Terminal Buttons:** Axon endings that release chemical neurotransmitters into the **synaptic cleft**.\n\n"
                                    "### The Action Potential Cycle\n\n"
                                    "1. **Resting Potential (-70 mV):** The neuron maintains a negative charge relative to the extracellular fluid, governed by the sodium-potassium pump (moving $3 \\text{ Na}^+$ out for every $2 \\text{ K}^+$ in).\n"
                                    "2. **Threshold of Excitation (-55 mV):** When excitatory postsynaptic potentials (EPSPs) depolarize the membrane to threshold, voltage-gated sodium channels burst open.\n"
                                    "3. **Depolarization (+30 to +40 mV):** Massive influx of positive sodium ions ($\\text{Na}^+$) rushes into the axon.\n"
                                    "4. **Repolarization & Hyperpolarization:** Sodium channels inactivate; voltage-gated potassium channels open, allowing $\\text{K}^+$ to exit, temporarily dipping below -70 mV (**refractory period**).\n"
                                    "5. **All-or-None Law:** A neuron either fires at full strength or not at all; stimulus intensity is encoded by firing *frequency*, never action potential size."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "The All-or-None Invariant",
                                "body": "A stronger stimulus (such as a scalding burn vs. a warm touch) does **not** create a larger action potential. It causes neurons to fire **more frequently** and recruits a greater **number** of sensory neurons.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Major Neurotransmitters and Behavioral Correlations\n\n"
                                    "| Neurotransmitter | Primary Physiological Role | Associated Clinical Disorders |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Acetylcholine (ACh)** | Muscle contraction, voluntary movement, memory encoding | Alzheimer's disease (severe loss of ACh neurons) |\n"
                                    "| **Dopamine** | Reward reinforcement, voluntary motor control, executive attention | Parkinson's disease (deficit in substantia nigra); Schizophrenia (excess receptor activity) |\n"
                                    "| **Serotonin (5-HT)** | Mood regulation, sleep architecture, appetite, impulsive aggression | Major depressive disorder, anxiety disorders (treated with SSRIs) |\n"
                                    "| **Norepinephrine** | Sympathetic alertness, fight-or-flight arousal, vigilance | Bipolar disorder, depressive episodes, panic disorder |\n"
                                    "| **GABA** | Primary **inhibitory** neurotransmitter in the central nervous system | Severe anxiety, seizures, insomnia (enhanced by benzodiazepines and alcohol) |\n"
                                    "| **Glutamate** | Primary **excitatory** neurotransmitter; synaptic plasticity and LTP | Excitotoxicity during strokes; migraine headaches, seizures |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Clinical Neurological Vignette: Myasthenia Gravis and Botulinum Toxin",
                                "text": (
                                    "Acetylcholine (ACh) operates at the neuromuscular junction. In **myasthenia gravis**, autoantibodies destroy ACh receptor sites, "
                                    "causing profound muscle fatigue. Conversely, **botulinum toxin** (Botox) blocks ACh release from presynaptic vesicles, causing flaccid paralysis. "
                                    "Black widow spider venom triggers massive ACh release, inducing violent muscular spasms."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Agonist vs. Antagonist",
                                "body": "An **agonist** mimics or increases the activity of a neurotransmitter (e.g., nicotine is an ACh agonist; morphine is an endorphin agonist). An **antagonist** blocks or inhibits neurotransmitter action (e.g., curare is an ACh antagonist that blocks muscle receptors).",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Action Potential",
                            "definition": "A brief electrochemical impulse that travels down an axon when a neuron's membrane potential depolarizes past the excitation threshold.",
                            "example": "Sodium ions rushing into the axon through voltage-gated ion channels when the potential reaches -55 mV.",
                        },
                        {
                            "term": "Myelin Sheath",
                            "definition": "A lipid-rich insulating layer wrapping axons that dramatically accelerates the conduction speed of nerve impulses.",
                            "example": "Multiple sclerosis damages the myelin sheath, causing disrupted motor and sensory signaling.",
                        },
                        {
                            "term": "Refractory Period",
                            "definition": "The brief recovery phase following an action potential during which a neuron cannot fire again or requires an exceptionally intense stimulus.",
                            "example": "During the absolute refractory period, sodium channel inactivation gates prevent any subsequent action potential.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "During an action potential, what specific ionic movement is directly responsible for the rapid depolarization of the neuronal membrane?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Rapid influx of positively charged sodium ions",
                                    "Rapid efflux of positively charged potassium ions",
                                    "Active pumping of negatively charged chloride ions",
                                    "Passive leakage of calcium ions out of the soma",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Depolarization is caused by the rapid opening of voltage-gated sodium channels once threshold (-55 mV) is reached, allowing positively charged sodium ions (Na+) to flood into the intracellular fluid along both concentration and electrical gradients.",
                            "difficulty": "intermediate",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 3.2",
                            "concept_slugs": ["psyc-neuron-structure"],
                        },
                        {
                            "prompt": "Degeneration of the myelin sheath surrounding axons in the central nervous system produces which debilitating autoimmune disorder?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Parkinson's disease",
                                    "Multiple sclerosis",
                                    "Huntington's chorea",
                                    "Alzheimer's dementia",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Multiple sclerosis is an autoimmune condition in which the body's immune system attacks and degrades the myelin sheath, slowing or halting neural impulse transmission along motor and sensory pathways.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 3.2",
                            "concept_slugs": ["psyc-neuron-structure"],
                        },
                        {
                            "prompt": "A patient with Parkinson's disease experiences severe tremors and rigidity due to the selective death of neurons that produce which neurotransmitter?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Acetylcholine",
                                    "Norepinephrine",
                                    "Dopamine",
                                    "Serotonin",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Parkinson's disease results from the degeneration of dopamine-producing neurons in the substantia nigra, impairing motor planning and basal ganglia communication. Dopamine precursors (such as L-DOPA) are administered to alleviate motor symptoms.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 3.2",
                            "concept_slugs": ["psyc-neurotransmitters"],
                        },
                        {
                            "prompt": "Which chemical acts as the primary inhibitory neurotransmitter throughout the human central nervous system, serving to decrease neuronal excitability?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Glutamate neurotransmitter",
                                    "Norepinephrine hormone",
                                    "Substance P peptide",
                                    "Gamma-aminobutyric acid (GABA)",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "GABA (gamma-aminobutyric acid) is the primary inhibitory neurotransmitter in the brain. By opening chloride ion channels and hyperpolarizing postsynaptic membranes, it reduces the probability that a neuron will fire an action potential.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 3.2",
                            "concept_slugs": ["psyc-neurotransmitters"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the resting membrane potential of a typical neuron?",
                    "back": "-70 millivolts (mV), maintained by the sodium-potassium pump.",
                    "concept_slugs": ["psyc-neuron-structure"],
                },
                {
                    "front": "Which neurotransmitter is critical for motor movement at the neuromuscular junction and memory consolidation?",
                    "back": "Acetylcholine (ACh).",
                    "concept_slugs": ["psyc-neurotransmitters"],
                },
            ],
        },
        {
            "code": "2.2",
            "title": "Analyze brain anatomy, cortical localization, autonomic divisions, and split-brain research",
            "description": "Distinguish hindbrain, midbrain, and forebrain structures, evaluate the sympathetic/parasympathetic divisions, and analyze split-brain lateralization findings.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 2.2",
            "concepts": [
                {
                    "slug": "psyc-brain-structures",
                    "name": "Cerebral Structures and Cortical Lobes",
                    "short_definition": "Functional specialization of subcortical centers and the four cerebral cortex lobes (frontal, parietal, occipital, temporal).",
                    "description": "Cortical organization localizes motor planning in frontal lobes, somatosensory processing in parietal, visual analysis in occipital, and auditory/language in temporal lobes.",
                    "citation": "OpenStax Psychology 2e, Section 3.4",
                },
                {
                    "slug": "psyc-hemispheric-specialization",
                    "name": "Hemispheric Lateralization and Autonomic Nervous System",
                    "short_definition": "Division of labor between cerebral hemispheres connected by the corpus callosum, alongside sympathetic/parasympathetic autonomic control.",
                    "description": "Split-brain experiments reveal left-hemisphere specialization for verbal speech and right-hemisphere specialization for visuospatial processing.",
                    "citation": "OpenStax Psychology 2e, Section 3.4",
                    "prerequisites": ["psyc-brain-structures"],
                },
            ],
            "lessons": [
                {
                    "title": "Brain Architecture and Hemispheric Specialization",
                    "description": "Limbic system, cortical lobes, autonomic nervous divisions, and split-brain research findings.",
                    "emoji": "🧩",
                    "tags": ["brain", "cortex", "split-brain", "autonomic", "limbic"],
                    "concept_slugs": [
                        "psyc-brain-structures",
                        "psyc-hemispheric-specialization",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 3.4: The Brain and Spinal Cord",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Subcortical Structures and the Limbic System\n\n"
                                    "The brain is organized into evolutionary hierarchical layers:\n"
                                    "- **Hindbrain:** Contains the **medulla** (controls automatic breathing, heartbeat, and blood pressure), the **pons** (coordinates movements and sleep regulation), and the **cerebellum** ('little brain,' governs balance, fine motor coordination, and procedural memory).\n"
                                    "- **Midbrain:** Contains the **reticular formation**, a nerve network regulating arousal, alertness, and sleep-wake transitions.\n"
                                    "- **Forebrain / Limbic System:** Coordinates emotional and motivational drives:\n"
                                    "  * **Thalamus:** Sensory switchboard routing all sensory inputs (except olfaction) to higher cortical centers.\n"
                                    "  * **Hypothalamus:** Regulates autonomic nervous system, hunger, thirst, body temperature, sexual drives, and directs the pituitary master gland.\n"
                                    "  * **Amygdala:** Processes emotional salience, particularly fear conditioning and aggressive responses.\n"
                                    "  * **Hippocampus:** Crucial for consolidating new explicit/declarative memories into long-term storage."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Four Cortical Lobes and Autonomic Nervous Control\n\n"
                                    "| Cortical Lobe | Key Functional Centers | Clinical Deficit Upon Damage |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Frontal** | Prefrontal cortex (executive judgment, impulse control); Primary motor cortex; **Broca's area** (left hemisphere speech production) | Broca's aphasia (non-fluent, halting speech); emotional disinhibition (Phineas Gage) |\n"
                                    "| **Parietal** | Primary somatosensory cortex (processes touch, pain, temperature); spatial orientation | Hemispatial neglect, loss of tactile discrimination |\n"
                                    "| **Occipital** | Primary visual cortex (feature detection, retinotopic processing) | Cortical blindness, visual agnosia |\n"
                                    "| **Temporal** | Primary auditory cortex; **Wernicke's area** (left hemisphere language comprehension); facial recognition | Wernicke's aphasia (fluent but meaningless speech); prosopagnosia (face blindness) |\n\n"
                                    "### Autonomic Nervous System Divisions\n\n"
                                    "- **Sympathetic Division:** Accelerates heart rate, dilates pupils, inhibits digestion, and mobilizes glycogen for **fight-or-flight** action.\n"
                                    "- **Parasympathetic Division:** Constricts pupils, slows heart rate, stimulates digestive peristalsis for **rest-and-digest** recovery."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Broca's vs. Wernicke's Aphasia",
                                "body": "**Broca's aphasia** impairs speech *production* (the patient knows what they want to say but speaks with great effort in broken words). **Wernicke's aphasia** impairs language *comprehension* (the patient speaks fluently with normal rhythm, but the words form meaningless 'word salad').",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Experimental Case Study: Roger Sperry's Split-Brain Patients",
                                "text": (
                                    "To alleviate intractable grand mal epilepsy, surgeons severed the **corpus callosum**—the thick bundle of axon fibers connecting the left and right hemispheres. "
                                    "In laboratory tachistoscopic tests, when an image of a spoon was flashed to the patient's **left visual field** (projecting to the right hemisphere), "
                                    "the patient verbally claimed to see nothing (because the left hemisphere controls speech). "
                                    "However, when asked to reach beneath a screen with their **left hand** (controlled by the right hemisphere), they effortlessly selected the spoon."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Left Visual Field vs. Left Eye",
                                "body": "Do not confuse the *left visual field* with the *left eye*. Visual fields project contralateral information from both eyes: the left half of each retina projects to the right hemisphere, and the right half of each retina projects to the left hemisphere.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Hippocampus",
                            "definition": "A limbic system structure vital for processing and consolidating new explicit memories for long-term storage.",
                            "example": "Patient H.M. lost the ability to form new episodic memories after bilateral surgical removal of his hippocampi.",
                        },
                        {
                            "term": "Corpus Callosum",
                            "definition": "The large band of neural fibers connecting the two cerebral hemispheres, enabling interhemispheric communication.",
                            "example": "Severing the corpus callosum prevents information presented to the right hemisphere from reaching the left hemisphere's language centers.",
                        },
                        {
                            "term": "Prefrontal Cortex",
                            "definition": "The forward part of the frontal lobes responsible for executive functions including working memory, decision making, social planning, and impulse restraint.",
                            "example": "Phineas Gage suffered dramatic personality shifts and emotional volatility after an iron rod pierced his prefrontal cortex.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "A construction foreman survives an accident in which a tamping iron penetrates his skull, destroying extensive portions of his prefrontal cortex. What psychological change is most expected?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Profound disruption of emotional regulation and planning",
                                    "Total permanent loss of tactile sensation across both arms",
                                    "Complete inability to comprehend spoken or written speech",
                                    "Loss of basic autonomic respiration and heart rate control",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Damage to the prefrontal cortex (as famously documented in the historical case of Phineas Gage) impairs executive functions, emotional inhibition, foresight, and moral judgment without eliminating primary motor or vital autonomic functions.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 3.4",
                            "concept_slugs": ["psyc-brain-structures"],
                        },
                        {
                            "prompt": "Which brain structure acts as the central sensory relay station, directing incoming information from all senses except olfaction to the appropriate cortical lobes?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Hypothalamus",
                                    "Thalamus",
                                    "Hippocampus",
                                    "Cerebellum",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "The thalamus serves as the sensory routing hub of the brain, receiving sensory signals from the visual, auditory, gustatory, and somatosensory systems and relaying them to specialized cortical areas. Olfactory signals bypass the thalamus directly to the olfactory bulb.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 3.4",
                            "concept_slugs": ["psyc-brain-structures"],
                        },
                        {
                            "prompt": "A patient suffers a left-hemisphere stroke and can comprehend conversation perfectly but speaks with agonizing slowness, omitting grammatical conjunctions. Where is the damage localized?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Wernicke's area in the left temporal lobe",
                                    "Primary somatosensory cortex in the parietal lobe",
                                    "Broca's area in the left frontal lobe",
                                    "Primary visual cortex in the occipital lobe",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Broca's area, located in the frontal lobe of the dominant (usually left) hemisphere, controls speech production and muscle movements involved in articulation. Damage produces expressive aphasia characterized by non-fluent, halting speech.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 3.4",
                            "concept_slugs": ["psyc-brain-structures"],
                        },
                        {
                            "prompt": "In a classic split-brain experiment, an image of an apple is flashed exclusively to the patient's left visual field. Which behavioral response can the patient perform?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Verbally name the apple immediately upon viewing",
                                    "Write the word 'apple' using their right hand",
                                    "Identify the apple by touch using their right hand",
                                    "Retrieve an apple by touch with their left hand",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Stimuli in the left visual field project to the right cerebral hemisphere, which controls the left hand. Because the severed corpus callosum prevents transmission to the verbal left hemisphere, the patient cannot name the object verbally, but can easily retrieve it with the left hand.",
                            "difficulty": "advanced",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 2e, Section 3.4",
                            "concept_slugs": ["psyc-hemispheric-specialization"],
                        },
                        {
                            "prompt": "Following a sudden frightening encounter with a snarling dog, an individual's pupils dilate, respiration quickens, and digestion ceases. Which autonomic division is dominant?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Sympathetic nervous system",
                                    "Parasympathetic nervous system",
                                    "Somatic nervous system",
                                    "Central sensory nervous system",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "The sympathetic division of the autonomic nervous system mobilizes physiological resources during emergency or stress situations (the 'fight-or-flight' response), elevating heart rate, dilating bronchioles, dilating pupils, and inhibiting gastrointestinal motility.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 3.4",
                            "concept_slugs": ["psyc-hemispheric-specialization"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "Which brain structure is primary for consolidating new long-term declarative memories?",
                    "back": "The hippocampus.",
                    "concept_slugs": ["psyc-brain-structures"],
                },
                {
                    "front": "What is the primary function of Broca's area vs. Wernicke's area?",
                    "back": "Broca's area (frontal lobe) directs speech production; Wernicke's area (temporal lobe) governs language comprehension.",
                    "concept_slugs": ["psyc-brain-structures"],
                },
            ],
        },
    ],
}
