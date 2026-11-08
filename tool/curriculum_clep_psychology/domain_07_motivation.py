"""Domain 7.0: Motivation and Emotion (Quota: 5 questions, 5–6% blueprint)."""
from __future__ import annotations

DOMAIN_07 = {
    "code": "7.0",
    "title": "Motivation and Emotion",
    "description": "Biological and social motives, drive-reduction, optimal arousal, hunger physiology, emotion theories, and Selye's General Adaptation Syndrome.",
    "weight": 0.055,
    "sort_order": 7,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 7.0 (5–6%)",
    "objectives": [
        {
            "code": "7.1",
            "title": "Analyze motivational theories, homeostasis, hunger mechanisms, and incentive systems",
            "description": "Evaluate drive-reduction and Yerkes-Dodson arousal models, analyze hypothalamic hunger regulation, and contrast intrinsic and extrinsic motivation.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 7.1",
            "concepts": [
                {
                    "slug": "psyc-motivation-theories",
                    "name": "Theories of Motivation and Arousal",
                    "short_definition": "Frameworks explaining behavioral drive, including Hull's drive-reduction, homeostasis, and the Yerkes-Dodson arousal law.",
                    "description": "Drive-reduction restores biological homeostasis; optimal arousal dictates that intermediate arousal maximizes complex cognitive task performance.",
                    "citation": "OpenStax Psychology 2e, Section 10.1",
                },
                {
                    "slug": "psyc-hunger-physiology",
                    "name": "Hypothalamic Hunger Regulation and Incentives",
                    "short_definition": "Biological appetite mechanisms mediated by lateral (hunger) and ventromedial (satiety) hypothalamic centers and intrinsic incentives.",
                    "description": "The lateral hypothalamus stimulates hunger while the ventromedial nucleus signals satiety, interacting with ghrelin, leptin, and the overjustification effect.",
                    "citation": "OpenStax Psychology 2e, Section 10.2",
                    "prerequisites": ["psyc-motivation-theories"],
                },
            ],
            "lessons": [
                {
                    "title": "Theories of Motivation and Motivational Drives",
                    "description": "Drive-reduction, Yerkes-Dodson law, Maslow's hierarchy, hypothalamic hunger centers, and the overjustification effect.",
                    "emoji": "🎯",
                    "tags": ["motivation", "drives", "yerkes-dodson", "hypothalamus", "maslow"],
                    "concept_slugs": [
                        "psyc-motivation-theories",
                        "psyc-hunger-physiology",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 10.1 & 10.2",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Core Theories of Human Motivation\n\n"
                                    "- **Drive-Reduction Theory (Clark Hull):** A physiological need (such as food or water) creates an aroused internal psychological tension state (a **drive**) that motivates the organism to satisfy the need and restore **homeostasis** (internal biological equilibrium).\n"
                                    "- **Optimal Arousal Theory & Yerkes-Dodson Law:** Organisms seek an optimal level of arousal rather than zero arousal. The **Yerkes-Dodson Law** dictates that performance on difficult or complex tasks is best under **moderate-to-low arousal**, whereas simple or well-practiced tasks benefit from **higher arousal**.\n"
                                    "- **Maslow's Hierarchy of Needs:** Needs are organized hierarchically: Physiological $\\rightarrow$ Safety $\\rightarrow$ Belongingness & Love $\\rightarrow$ Esteem $\\rightarrow$ **Self-Actualization** (realizing one's fullest unique human potential).\n\n"
                                    "### Biological Mechanisms of Hunger\n\n"
                                    "| Hypothalamic Center | Physiological Function | Effect of Experimental Lesion / Destruction |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Lateral Hypothalamus (LH)** | The **'hunger center'**; triggers feeding behavior when stimulated | Produces **aphagia** (complete refusal to eat, leading to starvation) |\n"
                                    "| **Ventromedial Hypothalamus (VMH)** | The **'satiety center'**; signals fullness and ceases eating | Produces **hyperphagia** (insatiable eating, leading to extreme obesity) |"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Memory Mnemonic: Lateral vs. Ventromedial",
                                "body": "- **L**ateral hypothalamus brings on the **L**arge appetite (destruction = **L**ate for meals / starvation).\n- **V**entromedial hypothalamus makes you **V**ery **M**oderate (destruction = **V**ery **M**uch overweight).",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "example",
                            "content": {
                                "title": "Educational Psychology Case: The Overjustification Effect",
                                "text": (
                                    "Mark Lepper and colleagues observed preschool children who intrinsically loved drawing with felt-tip markers. "
                                    "When researchers introduced an extrinsic reward (a fancy certificate and ribbon) for drawing, "
                                    "the children later drew significantly less during free play once the rewards ceased. "
                                    "Extrinsic rewards had undermined their **intrinsic motivation**, reframing play as work."
                                ),
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Drive-Reduction Cannot Explain All Behaviors",
                                "body": "Drive-reduction theory explains biological survival needs (drinking water when dehydrated), but completely fails to explain behaviors that deliberately increase physiological tension, such as riding roller coasters, exploring dangerous caves, or skydiving (which are explained by **optimal arousal theory**).",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Yerkes-Dodson Law",
                            "definition": "The empirical principle that performance increases with physiological or mental arousal, but only up to an optimal point, after which performance declines.",
                            "example": "A surgeon remaining calm and composed during an intricate 8-hour neurosurgical procedure.",
                        },
                        {
                            "term": "Overjustification Effect",
                            "definition": "The phenomenon in which being rewarded for doing something intrinsically enjoyable diminishes a person's intrinsic motivation to perform that activity.",
                            "example": "A passionate amateur baker losing interest in baking after being hired as an industrial pastry chef.",
                        },
                        {
                            "term": "Ventromedial Hypothalamus",
                            "definition": "The nucleus within the hypothalamus that acts as the primary satiety center, signaling an organism to terminate feeding.",
                            "example": "A rat with a surgically destroyed ventromedial hypothalamus continuously eating until it quadruples its normal body weight.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "An experimental neurobiologist surgically destroys the ventromedial hypothalamus of a laboratory rat. What behavioral outcome will immediately manifest?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Total cessation of feeding leading to severe starvation",
                                    "Excessive overeating resulting in extreme obesity",
                                    "Disruption of circadian REM sleep cycles",
                                    "Inability to regulate core body temperature",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "The ventromedial hypothalamus (VMH) serves as the satiety center of the brain. When it is lesioned or destroyed, the rat no longer perceives signals that it is full, leading to hyperphagia (insatiable overeating) and dramatic obesity.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 10.2",
                            "concept_slugs": ["psyc-hunger-physiology"],
                        },
                        {
                            "prompt": "According to the Yerkes-Dodson Law, which physiological arousal level is optimal when an individual is executing a highly complex, intellectually demanding mathematical examination?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Maximum sympathetic arousal bordering on panic",
                                    "Total autonomic sedation and near sleep",
                                    "A moderate-to-low level of physiological arousal",
                                    "Fluctuating surges of intense adrenaline output",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "The Yerkes-Dodson Law posits an inverted-U relationship between arousal and performance. For complex, novel, or intellectually demanding cognitive tasks, lower-to-moderate levels of arousal yield peak performance by preventing cognitive tunnel vision and anxiety.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 10.1",
                            "concept_slugs": ["psyc-motivation-theories"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What occurs when the lateral hypothalamus is destroyed in an animal?",
                    "back": "The animal starves (aphagia) because the hunger-stimulating center is destroyed.",
                    "concept_slugs": ["psyc-hunger-physiology"],
                },
                {
                    "front": "What does the overjustification effect demonstrate?",
                    "back": "Extrinsic rewards can reduce an individual's intrinsic motivation for an activity.",
                    "concept_slugs": ["psyc-hunger-physiology"],
                },
            ],
        },
        {
            "code": "7.2",
            "title": "Analyze theories of emotion, cognitive appraisal, and Selye's General Adaptation Syndrome",
            "description": "Contrast James-Lange, Cannon-Bard, and Schachter-Singer two-factor models, describe the high/low road emotional circuits, and evaluate Selye's GAS stages.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 7.2",
            "concepts": [
                {
                    "slug": "psyc-emotion-theories",
                    "name": "Theories of Emotion and Cognitive Appraisal",
                    "short_definition": "Classical emotion models (James-Lange, Cannon-Bard, Schachter-Singer two-factor, Zajonc/LeDoux, Lazarus) detailing the sequence of arousal and cognition.",
                    "description": "James-Lange posits arousal precedes emotion; Cannon-Bard posits simultaneous occurrence; Schachter-Singer requires cognitive labeling of physiological arousal.",
                    "citation": "OpenStax Psychology 2e, Section 10.4",
                },
                {
                    "slug": "psyc-stress-gas",
                    "name": "Stress Response and General Adaptation Syndrome",
                    "short_definition": "Hans Selye's three-stage biological response to chronic physical or psychological stressors: alarm, resistance, and exhaustion.",
                    "description": "Prolonged resistance drains energy reserves through chronic cortisol elevation, culminating in exhaustion, immunosuppression, and cardiovascular strain.",
                    "citation": "OpenStax Psychology 2e, Chapter 14",
                    "prerequisites": ["psyc-emotion-theories"],
                },
            ],
            "lessons": [
                {
                    "title": "Theories of Emotion, Stress, and Selye's GAS",
                    "description": "James-Lange vs. Cannon-Bard vs. Schachter-Singer two-factor theory, Zajonc-LeDoux low road, and Selye's General Adaptation Syndrome.",
                    "emoji": "🎭",
                    "tags": ["emotion", "james-lange", "cannon-bard", "schachter-singer", "stress", "selye"],
                    "concept_slugs": [
                        "psyc-emotion-theories",
                        "psyc-stress-gas",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 10.4 & Chapter 14",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Comparing the Major Theories of Emotion\n\n"
                                    "| Theory of Emotion | Sequence of Events | Defining Theoretical Principle |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **James-Lange Theory** | Stimulus $\\rightarrow$ **Physiological Arousal** $\\rightarrow$ **Subjective Emotion** | Emotion is our conscious awareness of our bodily physiological responses (*'We feel afraid because our heart races'*). |\n"
                                    "| **Cannon-Bard Theory** | Stimulus $\\rightarrow$ **Simultaneous & Independent** Arousal and Emotion | Subcortical thalamic centers send signals to the autonomic system and cerebral cortex at the exact same time. |\n"
                                    "| **Schachter-Singer Two-Factor** | Stimulus $\\rightarrow$ **Arousal** $+$ **Cognitive Label** $\\rightarrow$ **Emotion** | Emotion requires both generalized physiological arousal and an explanatory cognitive interpretation. |\n"
                                    "| **Zajonc & LeDoux (Low Road)** | Stimulus $\\rightarrow$ **Thalamus** $\\rightarrow$ **Amygdala** (Bypasses Cortex) | Instantaneous emotional reactions (fear, disgust) occur prior to conscious cognitive appraisal. |\n"
                                    "| **Lazarus Cognitive-Mediational** | Stimulus $\\rightarrow$ **Cognitive Appraisal** $\\rightarrow$ Emotion & Arousal | An appraisal of personal significance must occur before emotion and bodily arousal take place. |"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Hans Selye's General Adaptation Syndrome (GAS)\n\n"
                                    "Hans Selye discovered that the human body reacts to severe, prolonged stress through a universal three-stage physiological response:\n"
                                    "1. **Alarm Reaction:** Sudden sympathetic nervous activation. Heart rate accelerates, pupils dilate, and adrenaline/norepinephrine surge to mobilize energy for fight-or-flight.\n"
                                    "2. **Resistance:** Sympathetic arousal remains elevated as the **adrenal cortex** releases **cortisol** (glucocorticoids). The body remains on high alert, successfully adapting to the ongoing stressor while consuming internal reserves.\n"
                                    "3. **Exhaustion:** Prolonged exposure depletes the body's physical and hormonal resources. The immune system collapses, leading to clinical vulnerability, organ damage, depression, and cardiovascular illness."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "The Schachter-Singer Suproxin Experiment",
                                "body": "Stanley Schachter and Jerome Singer injected participants with adrenaline (under the guise of a vitamin called 'Suproxin'). Those who were **not told** about the drug's physiological side effects adopted the emotion of a confederate in the room—becoming euphoric with a playful confederate or furious with an angry confederate. This proved that **cognitive context labels generalized arousal**.",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Clinical Stress Case: Undergraduate Medical School Finals",
                                "text": (
                                    "During exam week, medical students maintain sustained high vigilance powered by elevated cortisol (**Stage 2: Resistance**). "
                                    "The morning after exams conclude, dozens fall severely ill with respiratory infections, migraines, and severe fatigue. "
                                    "Their bodies have entered **Stage 3: Exhaustion**, characterized by acute immunosuppression."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: James-Lange vs. Cannon-Bard",
                                "body": "**James-Lange** requires a sequential bodily reaction *first* (arousal $\\rightarrow$ emotion). **Cannon-Bard** asserts physiological changes are too slow to cause fast emotions, meaning bodily arousal and feeling happen *simultaneously*.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Two-Factor Theory",
                            "definition": "The Schachter-Singer theory that to experience emotion, one must be physically aroused and cognitively label the arousal.",
                            "example": "Interpreting an elevated heart rate as excitement when receiving an award versus fear when walking down a dark alley.",
                        },
                        {
                            "term": "General Adaptation Syndrome (GAS)",
                            "definition": "Selye's concept of the body's adaptive response to chronic stress across three progressive phases: alarm, resistance, and exhaustion.",
                            "example": "A soldier in combat experiencing acute alarm, enduring weeks of sustained resistance, and ultimately collapsing from physical exhaustion.",
                        },
                        {
                            "term": "Facial Feedback Hypothesis",
                            "definition": "The tendency of facial muscle states to trigger corresponding feelings such as fear, anger, or happiness.",
                            "example": "Holding a pen between one's teeth to force a smiling expression, which subsequently increases ratings of cartoon humor.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "An individual walks past an alley and encounters a snarling bear. Their heart races, and they immediately conclude: 'My heart is pounding, therefore I must be terrified.' Which theory of emotion does this thought process represent?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Cannon-Bard theory",
                                    "Schachter-Singer two-factor theory",
                                    "Lazarus cognitive-mediational theory",
                                    "James-Lange theory",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "The James-Lange theory of emotion asserts that physiological arousal occurs first and that our conscious subjective emotion is the direct perception of that bodily response ('we are afraid because we tremble').",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 10.4",
                            "concept_slugs": ["psyc-emotion-theories"],
                        },
                        {
                            "prompt": "A corporate executive experiences intense workplace stress for six consecutive months without relief. In Hans Selye's General Adaptation Syndrome, what characterizes the second stage (Resistance)?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Sustained elevated arousal and continuous cortisol secretion",
                                    "Immediate sudden sympathetic shock and lowered blood pressure",
                                    "Total bodily collapse and severe immune system breakdown",
                                    "Temporary rebound parasympathetic sleep and muscular atonia",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "In Selye's GAS, the second stage (Resistance) is characterized by sustained physiological arousal, continuous endocrine output of cortisol from the adrenal cortex, and active biological coping to endure the persistent stressor.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Chapter 14",
                            "concept_slugs": ["psyc-stress-gas"],
                        },
                        {
                            "prompt": "Which theoretical model of emotion argues that physiological arousal and conscious emotional experience are triggered simultaneously and independently by subcortical thalamic brain centers?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "James-Lange theory",
                                    "Cannon-Bard theory",
                                    "Schachter-Singer two-factor theory",
                                    "Zajonc low-road theory",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "The Cannon-Bard theory argues that bodily physiological responses and conscious feelings occur simultaneously and independently because the thalamus routes incoming sensory information to the sympathetic autonomic system and cerebral cortex at the exact same moment.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 10.4",
                            "concept_slugs": ["psyc-emotion-theories"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What are the three stages of Hans Selye's General Adaptation Syndrome?",
                    "back": "1. Alarm reaction, 2. Resistance, 3. Exhaustion.",
                    "concept_slugs": ["psyc-stress-gas"],
                },
                {
                    "front": "What distinguishes the Schachter-Singer two-factor theory from the James-Lange theory?",
                    "back": "Two-factor theory requires both physical arousal AND a cognitive label/interpretation of that arousal.",
                    "concept_slugs": ["psyc-emotion-theories"],
                },
            ],
        },
    ],
}

