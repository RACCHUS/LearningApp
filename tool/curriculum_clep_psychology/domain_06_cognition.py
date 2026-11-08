"""Domain 6.0: Cognition (Quota: 9 questions, 8–9% blueprint)."""
from __future__ import annotations

DOMAIN_06 = {
    "code": "6.0",
    "title": "Cognition",
    "description": "Memory models (encoding, storage, retrieval), forgetting mechanisms, problem-solving heuristics and biases, language development, and intelligence.",
    "weight": 0.090,
    "sort_order": 6,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 6.0 (8–9%)",
    "objectives": [
        {
            "code": "6.1",
            "title": "Analyze memory architecture, encoding strategies, storage systems, and forgetting mechanisms",
            "description": "Contrast sensory, working, and long-term memory, evaluate explicit vs. implicit systems, distinguish proactive and retroactive interference, and explain Loftus's memory reconstruction.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 6.1",
            "concepts": [
                {
                    "slug": "psyc-memory-models",
                    "name": "Atkinson-Shiffrin Model and Working Memory",
                    "short_definition": "Three-stage memory processing model comprising sensory registers, short-term/working memory, and permanent long-term storage.",
                    "description": "Information passes through iconic/echoic sensory registers into working memory (Baddeley's phonological loop, visuospatial sketchpad, central executive) before LTM encoding.",
                    "citation": "OpenStax Psychology 2e, Section 8.1",
                },
                {
                    "slug": "psyc-memory-systems-forgetting",
                    "name": "Explicit vs. Implicit Memory and Interference",
                    "short_definition": "Subsystems of long-term memory (episodic, semantic, procedural) and forgetting mechanisms (proactive/retroactive interference and amnesia).",
                    "description": "Explicit memory requires hippocampus/cortex; implicit memory relies on cerebellum/basal ganglia. Forgetting is driven by interference and constructive distortion.",
                    "citation": "OpenStax Psychology 2e, Section 8.2 & 8.3",
                    "prerequisites": ["psyc-memory-models"],
                },
            ],
            "lessons": [
                {
                    "title": "Memory Systems: Encoding, Storage, and Retrieval",
                    "description": "Working memory components, levels of processing, explicit vs. implicit memory, serial position effect, and proactive vs. retroactive interference.",
                    "emoji": "🗄️",
                    "tags": ["memory", "working-memory", "interference", "amnesia", "ebbinghaus"],
                    "concept_slugs": [
                        "psyc-memory-models",
                        "psyc-memory-systems-forgetting",
                    ],
                    "citation": "OpenStax Psychology 2e, Chapter 8: Memory",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Atkinson-Shiffrin Three-Stage Memory Model\n\n"
                                    "1. **Sensory Memory:** Immediate, initial recording of sensory data.\n"
                                    "   - **Iconic Memory:** Visual sensory register lasting ~0.5 seconds (tested by George Sperling's partial-report technique).\n"
                                    "   - **Echoic Memory:** Auditory sensory register lasting 3–4 seconds.\n"
                                    "2. **Short-Term & Working Memory:** Active conscious workspace with a capacity of $7 \\pm 2$ chunks (Miller) or ~4 chunks (Cowan), lasting ~20–30 seconds without maintenance rehearsal. Alan Baddeley's model divides working memory into:\n"
                                    "   - **Central Executive:** Directs focal attention and coordinates slave systems.\n"
                                    "   - **Phonological Loop:** Holds and manipulates acoustic, verbal speech information.\n"
                                    "   - **Visuospatial Sketchpad:** Holds visual mental imagery and spatial coordinates.\n"
                                    "   - **Episodic Buffer:** Synthesizes information across domains into integrated chronological units.\n"
                                    "3. **Long-Term Memory (LTM):** Relatively permanent storage system with theoretically limitless capacity."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Long-Term Memory Subsystems\n\n"
                                    "| Memory System | Nature of Knowledge | Neural Substrates | Representative Example |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Explicit / Declarative (Episodic)** | Personally experienced autobiographical life events | Hippocampus, Prefrontal Cortex | Remembering your high school graduation ceremony |\n"
                                    "| **Explicit / Declarative (Semantic)** | General factual knowledge, concepts, vocabulary | Cerebral Cortex | Knowing that Paris is the capital of France |\n"
                                    "| **Implicit / Nondeclarative (Procedural)** | Motor skills, habits, and classical conditioning | Cerebellum, Basal Ganglia | Riding a bicycle; playing a rehearsed piano sonata |\n\n"
                                    "### Mechanisms of Forgetting and Interference\n\n"
                                    "- **Proactive Interference:** Prior (old) learning disrupts the recall of newly acquired information *(e.g., dialing your old landline phone number when attempting to recall your new cell number)*.\n"
                                    "- **Retroactive Interference:** Recent (new) learning disrupts the recall of previously learned information *(e.g., learning Spanish vocabulary causing you to forget French words learned last semester)*.\n"
                                    "- **Serial Position Effect:** Tendency to recall items at the beginning (**primacy effect**, transferred to LTM) and end (**recency effect**, retained in working memory) of a list better than items in the middle."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "The Interference Mnemonic: PORN",
                                "body": "Use the acronym **PORN**:\n- **P**roactive: **O**ld disrupts new.\n- **R**etroactive: **N**ew disrupts old.",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Historical Neurological Case Study: Patient H.M. (Henry Molaison)",
                                "text": (
                                    "In 1953, surgeon William Scoville performed a bilateral medial temporal lobectomy on 27-year-old Patient H.M. to treat severe epilepsy, "
                                    "removing both hippocampi. H.M. developed profound **anterograde amnesia**: he could never again form new explicit/declarative memories. "
                                    "However, psychologist Brenda Milner proved his **implicit procedural memory remained completely intact**: "
                                    "when trained on a mirror-tracing motor task, H.M. showed flawless day-to-day improvement despite having zero conscious recollection of ever performing the task before."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Elizabeth Loftus and Memory Reconstruction",
                                "body": "Memory is **constructive**, not a video recording. Elizabeth Loftus proved the **misinformation effect**: when eyewitnesses viewing a car crash were asked *'How fast were the cars going when they smashed into each other?'* versus *'hit each other?'*, those hearing 'smashed' falsely remembered seeing broken glass at the scene.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Anterograde Amnesia",
                            "definition": "The inability to encode, consolidate, or store new explicit memories following neurological trauma or surgery.",
                            "example": "Meeting your physician every morning and introducing yourself as if meeting a stranger for the first time.",
                        },
                        {
                            "term": "Proactive Interference",
                            "definition": "The disruptive effect of previously learned material on the retention and retrieval of newly acquired information.",
                            "example": "Accidentally writing your previous year's calendar date throughout January of the new year.",
                        },
                        {
                            "term": "Misinformation Effect",
                            "definition": "The incorporation of misleading post-event information into one's memory of an event, altering eyewitness recollections.",
                            "example": "Eyewitnesses falsely recalling a stop sign after being asked a question containing the premise 'after the yield sign'.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "A student moves into a new apartment and memorizes their new postal zip code. When attempting to mail a package to their previous residence, they can only remember the new zip code. What cognitive phenomenon explains this forgetting?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Retroactive interference",
                                    "Proactive interference",
                                    "Anterograde amnesia",
                                    "Sensory decay",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Retroactive interference occurs when newly acquired information (the new apartment's zip code) impairs and disrupts the retrieval of previously stored older information (the former residence's zip code).",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 8.3",
                            "concept_slugs": ["psyc-memory-systems-forgetting"],
                        },
                        {
                            "prompt": "Following surgical bilateral resection of his hippocampi to treat intractable epilepsy, Patient H.M. was able to learn and master mirror-drawing motor skills despite having zero conscious memory of practicing the task. What memory system remained intact?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Episodic memory",
                                    "Implicit procedural memory",
                                    "Semantic memory",
                                    "Echoic sensory memory",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Procedural memory is an implicit/nondeclarative memory system governed primarily by the cerebellum and basal ganglia. Because the hippocampus mediates explicit/declarative memory, Patient H.M. could acquire new motor skills (implicit) without any conscious recollection (explicit).",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 2e, Section 8.2",
                            "concept_slugs": ["psyc-memory-systems-forgetting"],
                        },
                        {
                            "prompt": "In an experiment conducted by Elizabeth Loftus, participants viewed a film of a traffic accident. Those asked 'How fast were the cars going when they smashed into each other?' gave significantly higher speed estimates and falsely reported broken glass. What psychological principle is demonstrated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "State-dependent memory retrieval",
                                    "Proactive linguistic interference",
                                    "The misinformation effect",
                                    "Sensory register iconic decay",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "The misinformation effect occurs when misleading post-event information presented in leading questions alters and reconstructs an individual's original memory trace of an observed event.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 8.3",
                            "concept_slugs": ["psyc-memory-systems-forgetting"],
                        },
                        {
                            "prompt": "When presented with a list of twenty vocabulary words, an individual immediately recalls words from the beginning and end of the list far more accurately than words situated in the middle. What memory phenomenon is illustrated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Encoding specificity principle",
                                    "Ebbinghaus forgetting asymptote",
                                    "Tip-of-the-tongue phenomenon",
                                    "The serial position effect",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "The serial position effect describes the tendency to recall the first items (primacy effect, transferred to LTM) and last items (recency effect, still in working memory) better than the middle items in a sequence.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 8.1",
                            "concept_slugs": ["psyc-memory-models"],
                        },
                        {
                            "prompt": "Which component of Alan Baddeley's working memory model is responsible for coordinating attentional focus, switching between cognitive tasks, and integrating inputs from sensory buffers?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "The central executive",
                                    "The phonological loop",
                                    "The visuospatial sketchpad",
                                    "The iconic sensory store",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "In Baddeley's multicomponent model of working memory, the central executive acts as the supervisory attentional controller, allocating cognitive resources and coordinating the phonological loop, visuospatial sketchpad, and episodic buffer.",
                            "difficulty": "intermediate",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 8.1",
                            "concept_slugs": ["psyc-memory-models"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the difference between proactive and retroactive interference?",
                    "back": "Proactive interference occurs when old memories block new ones; retroactive interference occurs when new learning disrupts old memories.",
                    "concept_slugs": ["psyc-memory-systems-forgetting"],
                },
                {
                    "front": "What brain structure is required for encoding explicit episodic memories?",
                    "back": "The hippocampus.",
                    "concept_slugs": ["psyc-memory-systems-forgetting"],
                },
            ],
        },
        {
            "code": "6.2",
            "title": "Evaluate problem-solving strategies, cognitive biases, language acquisition, and psycholinguistics",
            "description": "Distinguish heuristics from algorithms, identify availability and representativeness biases, evaluate functional fixedness, and explain Chomsky's universal grammar.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 6.2",
            "concepts": [
                {
                    "slug": "psyc-problem-solving-biases",
                    "name": "Heuristics, Algorithms, and Cognitive Biases",
                    "short_definition": "Decision-making rules-of-thumb (heuristics) vs. step-by-step procedures (algorithms) and systematic cognitive biases.",
                    "description": "Heuristics trade speed for accuracy; obstacles include functional fixedness, mental set, confirmation bias, and the availability/representativeness heuristics.",
                    "citation": "OpenStax Psychology 2e, Section 7.2 & 7.3",
                },
                {
                    "slug": "psyc-language-development",
                    "name": "Language Acquisition and Psycholinguistics",
                    "short_definition": "Structure of language (phonemes, morphemes, syntax) and developmental theories (Chomsky's universal grammar vs. Skinner's reinforcement).",
                    "description": "Language acquisition unfolds through babbling, one-word, and telegraphic speech stages, supported by innate neural language acquisition mechanisms.",
                    "citation": "OpenStax Psychology 2e, Section 7.4",
                    "prerequisites": ["psyc-problem-solving-biases"],
                },
            ],
            "lessons": [
                {
                    "title": "Problem Solving, Cognitive Biases, and Language Acquisition",
                    "description": "Algorithms vs. heuristics, confirmation bias, functional fixedness, phonemes vs. morphemes, and Chomsky's universal grammar.",
                    "emoji": "💡",
                    "tags": ["heuristics", "biases", "chomsky", "language", "problem-solving"],
                    "concept_slugs": [
                        "psyc-problem-solving-biases",
                        "psyc-language-development",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 7.2, 7.3, & 7.4",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Problem-Solving Strategies: Algorithms vs. Heuristics\n\n"
                                    "- **Algorithm:** A methodical, step-by-step logical rule or procedural formula that **guarantees** a correct solution if followed correctly *(e.g., searching every aisle in a grocery store systematically)*.\n"
                                    "- **Heuristic:** A fast, mental shortcut or 'rule-of-thumb' strategy that allows quick decision making but is prone to systematic cognitive errors *(e.g., checking only the baking aisle for vanilla extract)*.\n\n"
                                    "### Common Cognitive Biases and Heuristic Traps\n\n"
                                    "| Cognitive Phenomenon | Operational Definition | Real-World Manifestation |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Availability Heuristic** | Estimating the likelihood of an event based on how readily vivid examples come to mind | Fearing commercial airline crashes over car accidents due to dramatic media coverage |\n"
                                    "| **Representativeness Heuristic** | Judging the probability of an event by comparing it to an existing mental prototype | Assuming a quiet, bespectacled man reading poetry is an Ivy League classics professor rather than a truck driver |\n"
                                    "| **Confirmation Bias** | Actively seeking and favoring evidence that confirms existing beliefs while ignoring contradictory data | Only reading news columns written by ideologically aligned political pundits |\n"
                                    "| **Functional Fixedness** | The cognitive inability to see that familiar objects can be used for novel, non-traditional functions | Failing to realize that an unbent wire coat hanger can be used to unlock a jammed latch |\n"
                                    "| **Mental Set** | Tendency to approach a problem with a mindset that worked successfully on past problems | Persisting with an algebraic equation when simple arithmetic solves the puzzle |"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Structural Architecture of Human Language\n\n"
                                    "- **Phonemes:** The smallest distinctive sound units in a spoken language *(e.g., the English word 'chat' contains 3 phonemes: /ch/, /a/, /t/)*.\n"
                                    "- **Morphemes:** The smallest units of language that carry semantic meaning, including prefixes and suffixes *(e.g., 'unbreakable' contains 3 morphemes: 'un-', 'break', '-able')*.\n"
                                    "- **Grammar:** System of rules guiding communication:\n"
                                    "  * **Semantics:** Rules governing how we derive meaning from sounds and words.\n"
                                    "  * **Syntax:** Rules governing the grammatical arrangement of words into meaningful sentences.\n\n"
                                    "### Theories of Language Acquisition\n\n"
                                    "- **B. F. Skinner (Behavioral Model):** Argued language is acquired via environmental operant conditioning, imitation, and reinforcement.\n"
                                    "- **Noam Chomsky (Nativist Model):** Argued human brains are biologically hardwired with an innate **Language Acquisition Device (LAD)** and **Universal Grammar**, explaining why children acquire complex syntax effortlessly during a sensitive developmental window."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Phoneme vs. Morpheme Distinction",
                                "body": "**Phonemes** are speech *sounds* without intrinsic meaning (e.g., the sound /k/). **Morphemes** are the smallest units that carry *meaning* (e.g., words like 'cat', or prefixes like 're-', or suffixes like '-ed').",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Experimental Cognitive Case: Duncker's Candle Problem",
                                "text": (
                                    "Karl Duncker presented participants with a candle, a book of matches, and a box of thumbtacks, "
                                    "tasking them to mount the candle on a corkboard so wax wouldn't drip on the table. "
                                    "Most failed because of **functional fixedness**: they viewed the box solely as a container for tacks. "
                                    "The creative solution required emptying the box, tacking the box to the board, and standing the candle inside it."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Availability vs. Representativeness",
                                "body": "Use this heuristic distinction:\n- **Availability** is about **mental recall ease** (e.g., *'I can easily picture a shark attack on TV, so shark attacks must be frequent'*).\n- **Representativeness** is about **matching a prototype** (e.g., *'He wears a white lab coat, so he must be a doctor'*).",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Availability Heuristic",
                            "definition": "Estimating the frequency or likelihood of an event based on how easily relevant instances spring to mind from memory.",
                            "example": "Overestimating the statistical danger of commercial aviation after watching news footage of an airplane crash.",
                        },
                        {
                            "term": "Functional Fixedness",
                            "definition": "A cognitive block and type of mental set where an individual is unable to perceive an object being utilized for functions other than its customary purpose.",
                            "example": "Searching fruitlessly for a screwdriver when a butter knife or coin could easily tighten the loose screw.",
                        },
                        {
                            "term": "Morpheme",
                            "definition": "The smallest unit of language that carries meaning; may be a standalone word or a meaningful prefix/suffix.",
                            "example": "The word 'prepackaged' contains three morphemes: 'pre-', 'package', and '-ed'.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "An individual refuses to travel by passenger airplane because television news broadcasts recently covered a catastrophic plane crash. What cognitive heuristic is driving this inflated risk assessment?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Representativeness heuristic",
                                    "Availability heuristic",
                                    "Confirmation bias",
                                    "Anchoring heuristic",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "The availability heuristic operates when individuals evaluate the probability of events based on how readily vivid examples come to mind. Sensationalized media coverage makes plane crashes easily retrievable in memory, causing people to overestimate their frequency relative to automobile accidents.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 7.2",
                            "concept_slugs": ["psyc-problem-solving-biases"],
                        },
                        {
                            "prompt": "A handyman needs to secure a picture frame to a wall but has no hammer. Despite having a heavy steel wrench on the workbench, the handyman wastes thirty minutes searching for a hammer. What cognitive obstacle is demonstrated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Belief perseverance",
                                    "Framing effect",
                                    "Functional fixedness",
                                    "Overconfidence bias",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Functional fixedness is the cognitive inability to view familiar tools or objects as having utility beyond their traditional designed purpose (in this case, failing to recognize that a heavy steel wrench can pound a nail just like a hammer).",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 7.2",
                            "concept_slugs": ["psyc-problem-solving-biases"],
                        },
                        {
                            "prompt": "How many morphemes are contained in the English word 'unbreakable'?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "One morpheme",
                                    "Two morphemes",
                                    "Three morphemes",
                                    "Four morphemes",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "A morpheme is the smallest unit of language carrying meaning. The word 'unbreakable' consists of three distinct morphemes: the prefix 'un-' (meaning not), the root word 'break', and the suffix '-able' (meaning capable of).",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 2e, Section 7.4",
                            "concept_slugs": ["psyc-language-development"],
                        },
                        {
                            "prompt": "Linguist Noam Chomsky proposed that children acquire complex grammatical speech rapidly without explicit instruction because the human brain is biologically equipped with which innate mechanism?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Operant vicarious reinforcement buffer",
                                    "Phonemic sensory decay inhibitor",
                                    "Episodic working memory executive",
                                    "Innate Language Acquisition Device",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Noam Chomsky championed the nativist theory of language acquisition, asserting that humans possess an innate biological predisposition—termed the Language Acquisition Device (LAD) and Universal Grammar—that enables children to deduce grammatical rules spontaneously from exposure to speech.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 7.4",
                            "concept_slugs": ["psyc-language-development"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is an algorithm versus a heuristic in problem solving?",
                    "back": "An algorithm is a step-by-step rule that guarantees a solution; a heuristic is a fast mental shortcut that is prone to errors.",
                    "concept_slugs": ["psyc-problem-solving-biases"],
                },
                {
                    "front": "What is the difference between phonemes and morphemes?",
                    "back": "Phonemes are basic sound units; morphemes are the smallest units that carry semantic meaning.",
                    "concept_slugs": ["psyc-language-development"],
                },
            ],
        },
    ],
}

