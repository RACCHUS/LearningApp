"""Domain 5.0: Learning (Quota: 8 questions, 8–9% blueprint)."""
from __future__ import annotations

DOMAIN_05 = {
    "code": "5.0",
    "title": "Learning",
    "description": "Classical conditioning paradigms, operant conditioning principles and schedules of reinforcement, cognitive maps, and observational learning.",
    "weight": 0.085,
    "sort_order": 5,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 5.0 (8–9%)",
    "objectives": [
        {
            "code": "5.1",
            "title": "Analyze classical conditioning mechanisms, acquisition, extinction, and biological preparedness",
            "description": "Identify unconditioned/conditioned stimuli and responses, explain stimulus generalization and discrimination, and evaluate Garcia's taste aversion.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 5.1",
            "concepts": [
                {
                    "slug": "psyc-classical-conditioning",
                    "name": "Pavlovian Classical Conditioning",
                    "short_definition": "Form of associative learning where an organism pairs a neutral stimulus with an unconditioned stimulus to elicit a conditioned response.",
                    "description": "Demonstrated by Ivan Pavlov (salivation in dogs) and Watson's Little Albert; governed by acquisition, extinction, spontaneous recovery, and generalization.",
                    "citation": "OpenStax Psychology 2e, Section 6.2",
                },
                {
                    "slug": "psyc-biological-constraints",
                    "name": "Biological Preparedness and Taste Aversion",
                    "short_definition": "Evolutionary predisposition to learn specific associations (e.g., taste and nausea) rapidly across prolonged delays.",
                    "description": "John Garcia demonstrated that rats associate novel flavors with sickness even after hours of delay, violating traditional temporal contiguity assumptions.",
                    "citation": "OpenStax Psychology 2e, Section 6.2",
                    "prerequisites": ["psyc-classical-conditioning"],
                },
            ],
            "lessons": [
                {
                    "title": "Classical Conditioning: Principles and Extinction",
                    "description": "UCS, UCR, CS, CR paradigms, acquisition curves, extinction, spontaneous recovery, and conditioned taste aversions.",
                    "emoji": "🔔",
                    "tags": ["classical", "pavlov", "conditioning", "watson", "extinction"],
                    "concept_slugs": [
                        "psyc-classical-conditioning",
                        "psyc-biological-constraints",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 6.2: Classical Conditioning",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Pavlovian Classical Conditioning Paradigm\n\n"
                                    "**Classical conditioning** is an associative learning process where an organism learns to link two or more stimuli to anticipate events:\n"
                                    "- **Unconditioned Stimulus (UCS):** A stimulus that naturally and automatically triggers an unlearned response (e.g., meat powder placed on a dog's tongue).\n"
                                    "- **Unconditioned Response (UCR):** The unlearned, naturally occurring response to the UCS (e.g., salivation elicited by food).\n"
                                    "- **Neutral Stimulus (NS):** A stimulus that elicits no response before conditioning (e.g., ringing a bell or metronome).\n"
                                    "- **Conditioned Stimulus (CS):** An originally neutral stimulus that, after repeated pairing with a UCS, triggers a conditioned response (e.g., the bell alone).\n"
                                    "- **Conditioned Response (CR):** The learned response to the previously neutral CS (e.g., salivating to the sound of the bell)."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Stages of Classical Conditioning\n\n"
                                    "| Conditioning Phase | Operational Definition | Behavioral Manifestation |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Acquisition** | Initial learning phase where NS is repeatedly paired with UCS | CR progressively strengthens as CS-UCS association solidifies |\n"
                                    "| **Extinction** | Diminishing of CR when CS is repeatedly presented **without** UCS | Salivation to the bell drops to zero over repeated trials |\n"
                                    "| **Spontaneous Recovery** | Reappearance of an extinguished CR after an intervening rest interval | After 24 hours of rest, presenting the bell alone triggers salivation again |\n"
                                    "| **Generalization** | Tendency for stimuli similar to the CS to evoke similar responses | Little Albert fearing white rabbits and fur coats after conditioning with a white rat |\n"
                                    "| **Discrimination** | Learned capacity to distinguish between a CS and irrelevant stimuli | A dog salivating only to a 1000 Hz tone, not an 800 Hz tone |"
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "UCR vs. CR Distinction",
                                "body": "The **unconditioned response (UCR)** and the **conditioned response (CR)** typically describe the *same physical behavior* (e.g., salivating or blinking). What differs is the **triggering stimulus**: the UCR is elicited by the UCS; the CR is elicited by the CS.",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Experimental Case Study: John Garcia's Conditioned Taste Aversion",
                                "text": (
                                    "Behaviorists historically claimed any stimulus could be conditioned to any response with equal ease. "
                                    "John Garcia disproved this by exposing rats to novel flavored water followed hours later by radiation-induced nausea. "
                                    "The rats developed immediate, powerful **taste aversions** after a **single trial**, even with a delay of several hours. "
                                    "Crucially, rats failed to develop aversions to sights or sounds paired with nausea, proving that organisms are **biologically prepared** to associate taste with gastrointestinal illness."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Spontaneous Recovery Does Not Mean Re-learning",
                                "body": "**Spontaneous recovery** proves that extinction suppresses rather than permanently erases a conditioned association. When an extinguished response reappears following a delay, it occurs without any new pairings with the unconditioned stimulus.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Conditioned Stimulus (CS)",
                            "definition": "An originally neutral stimulus that, after association with an unconditioned stimulus, comes to trigger a conditioned response.",
                            "example": "A doctor's white coat triggering a child's crying after being paired with painful vaccine injections.",
                        },
                        {
                            "term": "Spontaneous Recovery",
                            "definition": "The sudden reappearance of an extinguished conditioned response after a period of rest or delay.",
                            "example": "A dog salivating to a buzzer 48 hours after the buzzer had been completely extinguished.",
                        },
                        {
                            "term": "Garcia Effect",
                            "definition": "An evolutionary biological predisposition in mammals to readily associate novel tastes with subsequent nausea even across prolonged delays.",
                            "example": "Avoiding oysters for years after experiencing food poisoning from an oyster dinner.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "In Pavlov's classic laboratory experiments with canines, what represented the unconditioned stimulus (UCS)?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "The meat powder placed on the canine's tongue",
                                    "The sound of the ringing auditory metronome",
                                    "The salivation elicited by the auditory tone",
                                    "The sight of the research experimenter entering",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "In Pavlov's experiments, the meat powder is the unconditioned stimulus (UCS) because it naturally, automatically, and reliably triggers salivation without any prior learning or conditioning.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 6.2",
                            "concept_slugs": ["psyc-classical-conditioning"],
                        },
                        {
                            "prompt": "A young child is conditioned to fear a laboratory white rat. The following week, the child displays intense fear when presented with a white rabbit and a white fur coat. What learning phenomenon is demonstrated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Spontaneous recovery",
                                    "Stimulus generalization",
                                    "Stimulus discrimination",
                                    "Higher-order conditioning",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Stimulus generalization is the tendency for stimuli that resemble the original conditioned stimulus (e.g., other furry white objects resembling the white rat) to evoke similar conditioned responses, as demonstrated in Watson and Rayner's Little Albert experiment.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 6.2",
                            "concept_slugs": ["psyc-classical-conditioning"],
                        },
                        {
                            "prompt": "An extinguished conditioned response spontaneously reappears when the conditioned stimulus is presented after a twenty-four-hour delay. What does this observation demonstrate about extinction?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Extinction permanently erases the neural connection",
                                    "The organism requires immediate reconditioning trials",
                                    "Extinction suppresses rather than completely destroys the association",
                                    "Operant punishment has overridden the classical reflex",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Spontaneous recovery reveals that extinction is an active inhibitory process that suppresses the conditioned response rather than permanently destroying the underlying associative memory trace.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 2e, Section 6.2",
                            "concept_slugs": ["psyc-classical-conditioning"],
                        },
                        {
                            "prompt": "Why did John Garcia's research on conditioned taste aversion challenge the traditional assumptions of behaviorist learning theory?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Conditioning occurred only after hundreds of repetitive exposures",
                                    "Conditioning required an explicit human verbal cognitive contract",
                                    "Conditioning failed to occur if a secondary reinforcer was withheld",
                                    "Conditioning occurred after a single trial despite hours of delay",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Traditional behaviorism asserted that conditioning required immediate temporal contiguity (seconds) and many repetitive pairings. Garcia proved that rats formed taste aversions after a single exposure even with hours separating ingestion and sickness, demonstrating evolutionary biological preparedness.",
                            "difficulty": "advanced",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 2e, Section 6.2",
                            "concept_slugs": ["psyc-biological-constraints"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the difference between stimulus generalization and stimulus discrimination?",
                    "back": "Generalization is responding similarly to resembling stimuli; discrimination is learning to respond exclusively to the specific CS.",
                    "concept_slugs": ["psyc-classical-conditioning"],
                },
                {
                    "front": "What did the Garcia Effect reveal about learning?",
                    "back": "Organisms possess biological constraints that make them predisposed to associate taste with illness more readily than visual/auditory cues.",
                    "concept_slugs": ["psyc-biological-constraints"],
                },
            ],
        },
        {
            "code": "5.2",
            "title": "Analyze operant conditioning paradigms, reinforcement schedules, and observational learning",
            "description": "Contrast positive/negative reinforcement and punishment, analyze ratio and interval reinforcement schedules, and evaluate Bandura's observational modeling.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 5.2",
            "concepts": [
                {
                    "slug": "psyc-operant-conditioning",
                    "name": "Operant Conditioning Principles and Schedules",
                    "short_definition": "Voluntary behavioral modification where actions are strengthened by reinforcement or weakened by punishment.",
                    "description": "B. F. Skinner defined positive/negative reinforcers and punishers along fixed/variable ratio and interval partial reinforcement schedules.",
                    "citation": "OpenStax Psychology 2e, Section 6.3",
                },
                {
                    "slug": "psyc-observational-learning",
                    "name": "Social Learning and Cognitive Modeling",
                    "short_definition": "Learning by observing others' behaviors and consequences, highlighted by Bandura's Bobo doll study and mirror neurons.",
                    "description": "Observational learning requires attention, retention, motor reproduction, and motivation, augmented by latent learning and cognitive maps.",
                    "citation": "OpenStax Psychology 2e, Section 6.4",
                    "prerequisites": ["psyc-operant-conditioning"],
                },
            ],
            "lessons": [
                {
                    "title": "Operant Conditioning: Reinforcement, Schedules, and Observational Learning",
                    "description": "Reinforcement vs. punishment matrix, Skinner box mechanics, schedules of partial reinforcement, and Bandura's Bobo doll experiments.",
                    "emoji": "📦",
                    "tags": ["operant", "skinner", "reinforcement", "schedules", "bandura"],
                    "concept_slugs": [
                        "psyc-operant-conditioning",
                        "psyc-observational-learning",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 6.3 & 6.4",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Operant Conditioning Matrix\n\n"
                                    "Whereas classical conditioning pairs two stimuli to elicit involuntary reflexes, **operant conditioning** modifies voluntary behavior via consequences:\n\n"
                                    "| Contingency | Stimulus Presentation / Removal | Effect on Future Behavior | Practical Clinical Example |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Positive Reinforcement** | **Add** a pleasant stimulus | **Increases** behavior | Giving a child a gold star for completing homework |\n"
                                    "| **Negative Reinforcement** | **Remove** an aversive stimulus | **Increases** behavior | Fastening your seatbelt to terminate an annoying warning chime |\n"
                                    "| **Positive Punishment** | **Add** an unpleasant stimulus | **Decreases** behavior | Receiving a speeding fine from a traffic officer |\n"
                                    "| **Negative Punishment** | **Remove** a pleasant stimulus | **Decreases** behavior | Revoking a teenager's cell phone privileges for breaking curfew |"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "The Universal Student Pitfall: Negative Reinforcement is NOT Punishment",
                                "body": "**Reinforcement always INCREASES behavior.** Negative reinforcement increases behavior by taking away something bad (e.g., taking an aspirin removes a headache, so you take aspirin again). **Punishment always DECREASES behavior.**",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Schedules of Partial (Intermittent) Reinforcement\n\n"
                                    "- **Fixed-Ratio (FR):** Reinforces after a set number of responses (e.g., factory worker paid for every 20 garments assembled). High response rate with brief post-reinforcement pause.\n"
                                    "- **Variable-Ratio (VR):** Reinforces after an unpredictable number of responses (e.g., slot machines, scratch-off lottery tickets). Yields the **highest response rate** and greatest resistance to extinction.\n"
                                    "- **Fixed-Interval (FI):** Reinforces the first response after a set time interval (e.g., weekly salary direct-deposited every Friday). Produces a characteristic **scalloped response pattern** (activity surges just prior to deadline).\n"
                                    "- **Variable-Interval (VI):** Reinforces the first response after unpredictable time periods (e.g., checking email or waiting for a fish to bite). Produces slow, steady response rates.\n\n"
                                    "### Bandura's Observational Learning Theory\n\n"
                                    "Albert Bandura demonstrated that organisms learn through **modeling** without direct reinforcement. "
                                    "In his famous **Bobo Doll experiments**, children who watched an adult violently strike an inflated doll were significantly more likely to imitate the specific hostile acts and verbal insults when later frustrated, driven by **vicarious reinforcement**."
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Real-World Application: Shaping via Successive Approximations",
                                "text": (
                                    "A service dog trainer wants a retriever to learn how to turn on a light switch. "
                                    "The trainer cannot wait for the dog to spontaneously perform the full action. "
                                    "Using **shaping**, the trainer first reinforces looking at the wall, then walking to the switch, "
                                    "then touching the plate with its nose, and finally flipping the lever upward."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Latent Learning and Cognitive Maps",
                                "body": "Edward Tolman demonstrated that rats wandering through a maze formed internal mental representations (**cognitive maps**) without any reward. When food was finally introduced, they navigated the maze just as quickly as rewarded rats, proving **latent learning** occurs without immediate reinforcement.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Negative Reinforcement",
                            "definition": "The strengthening of a response by the removal, escape from, or avoidance of an unpleasant or aversive stimulus.",
                            "example": "Turning off a loud alarm clock by pressing the snooze button reinforces pressing the button.",
                        },
                        {
                            "term": "Variable-Ratio Schedule",
                            "definition": "A reinforcement schedule that reinforces a response after an unpredictable number of responses.",
                            "example": "A gambler continuing to pull the arm of a slot machine because a payout could occur on any pull.",
                        },
                        {
                            "term": "Shaping",
                            "definition": "An operant conditioning procedure in which reinforcers guide behavior toward closer and closer approximations of the desired goal.",
                            "example": "Teaching a pigeon to bowl a ball by progressively rewarding orienting, approaching, and rolling.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "An individual takes an aspirin to eliminate a throbbing tension headache. The pain dissipates, making the individual more likely to take aspirin the next time a headache arises. What conditioning principle explains this increased behavior?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Negative reinforcement",
                                    "Positive reinforcement",
                                    "Positive punishment",
                                    "Classical counterconditioning",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Negative reinforcement occurs when a behavior is strengthened and increases in frequency because it successfully removes, terminates, or avoids an aversive stimulus (in this case, the painful headache).",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 6.3",
                            "concept_slugs": ["psyc-operant-conditioning"],
                        },
                        {
                            "prompt": "Which partial reinforcement schedule produces the highest rate of behavioral responding and exhibits the greatest resistance to extinction?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Fixed-interval schedule",
                                    "Variable-ratio schedule",
                                    "Fixed-ratio schedule",
                                    "Variable-interval schedule",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "A variable-ratio schedule delivers reinforcement after an unpredictable number of responses (like a slot machine or lottery ticket). Because the next response could always yield reward, it generates the highest, steadiest response rates and is remarkably resistant to extinction.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 6.3",
                            "concept_slugs": ["psyc-operant-conditioning"],
                        },
                        {
                            "prompt": "A college student studies intensively only during the night before each scheduled weekly exam, followed by a total cessation of studying until the eve of the next test. What reinforcement schedule generates this scalloped response pattern?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Variable-ratio schedule",
                                    "Fixed-ratio schedule",
                                    "Fixed-interval schedule",
                                    "Continuous reinforcement schedule",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "A fixed-interval schedule reinforces the first response only after a specified time interval has elapsed. It characteristically produces a 'scalloped' response curve where activity slows dramatically following reinforcement and surges right before the scheduled deadline.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 6.3",
                            "concept_slugs": ["psyc-operant-conditioning"],
                        },
                        {
                            "prompt": "In Albert Bandura's classic Bobo Doll experiments, what factor determined whether children spontaneously imitated aggressive behaviors displayed by adult models?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "The gender of the child observing the scenario",
                                    "Direct primary reinforcers delivered immediately to the child",
                                    "The genetic temperament score of the experimental subject",
                                    "Observing vicarious consequences delivered to the model",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Bandura's experiments demonstrated that observational learning is heavily mediated by vicarious reinforcement and vicarious punishment: children who observed the aggressive adult model being rewarded or experiencing no consequences readily imitated the hostility, whereas observing punishment suppressed imitation.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 6.4",
                            "concept_slugs": ["psyc-observational-learning"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the operational definition of negative reinforcement?",
                    "back": "Increasing the frequency of a behavior by removing an aversive stimulus.",
                    "concept_slugs": ["psyc-operant-conditioning"],
                },
                {
                    "front": "What schedule of reinforcement governs slot machine gambling?",
                    "back": "Variable-ratio schedule.",
                    "concept_slugs": ["psyc-operant-conditioning"],
                },
            ],
        },
    ],
}

