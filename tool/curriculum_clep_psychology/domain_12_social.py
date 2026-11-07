"""Domain 12.0: Social Psychology (Quota: 9 questions, 9–10% blueprint)."""
from __future__ import annotations

DOMAIN_12 = {
    "code": "12.0",
    "title": "Social Psychology",
    "description": "Attribution theory, cognitive dissonance, conformity and compliance, obedience experiments, group dynamics, prejudice, and bystander intervention.",
    "weight": 0.095,
    "sort_order": 12,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 12.0 (9–10%)",
    "objectives": [
        {
            "code": "12.1",
            "title": "Analyze attribution theory, cognitive dissonance, and social influence experiments",
            "description": "Evaluate the fundamental attribution error, explain Festinger's cognitive dissonance, and analyze Asch's conformity and Milgram's obedience experiments.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 12.1",
            "concepts": [
                {
                    "slug": "psyc-attribution-dissonance",
                    "name": "Attribution Theory and Cognitive Dissonance",
                    "short_definition": "How individuals explain causes of behavior (dispositional vs. situational, FAE) and resolve internal conflict between actions and beliefs.",
                    "description": "The fundamental attribution error underestimates situational pressures in others; cognitive dissonance drives attitude alignment with behavior.",
                    "citation": "OpenStax Psychology 2e, Section 12.1 & 12.2",
                },
                {
                    "slug": "psyc-conformity-obedience",
                    "name": "Conformity, Compliance, and Milgram Obedience",
                    "short_definition": "Social pressure paradigms including Asch line conformity, normative/informational influence, and Milgram's destructive obedience.",
                    "description": "Asch demonstrated visual judgment conformity; Milgram demonstrated that 65% of participants obey legitimate authority commands to deliver lethal shocks.",
                    "citation": "OpenStax Psychology 2e, Section 12.3",
                    "prerequisites": ["psyc-attribution-dissonance"],
                },
            ],
            "lessons": [
                {
                    "title": "Social Thinking: Attribution, Cognitive Dissonance, and Obedience",
                    "description": "The Fundamental Attribution Error, Festinger's cognitive dissonance, Asch's line studies, and Milgram's 450-volt shock experiments.",
                    "emoji": "👥",
                    "tags": ["social", "attribution", "dissonance", "conformity", "milgram", "asch"],
                    "concept_slugs": [
                        "psyc-attribution-dissonance",
                        "psyc-conformity-obedience",
                    ],
                    "citation": "OpenStax Psychology 2e, Chapter 12: Social Psychology",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Social Attribution and Common Attributional Biases\n\n"
                                    "When observing human conduct, individuals attribute causes to either **dispositional (internal personal traits)** or **situational (external environmental factors)**:\n"
                                    "- **Fundamental Attribution Error (FAE):** The pervasive tendency for observers to underestimate situational influences and overestimate internal dispositional traits when explaining *others'* behavior *(e.g., assuming a cashier who does not smile is an inherently hostile person rather than exhausted)*.\n"
                                    "- **Self-Serving Bias:** The tendency to attribute our own successes to internal disposition ('I aced the exam because I am brilliant') and our failures to external situations ('I failed because the teacher wrote unfair questions').\n\n"
                                    "### Leon Festinger's Cognitive Dissonance Theory\n\n"
                                    "When our actions conflict with our established attitudes, we experience an uncomfortable psychological tension (**cognitive dissonance**). "
                                    "Because we cannot un-do past actions, we resolve dissonance by **aligning our attitudes with our behaviors**.\n"
                                    "*(In Festinger's classic 1959 peg-turning study, participants paid only $1 to lie to the next subject reported genuine enjoyment of the dull task, needing to justify their behavior, whereas those paid $20 felt no dissonance because the money was sufficient external justification.)*"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Classic Social Influence Experiments\n\n"
                                    "| Landmark Study | Lead Investigator | Experimental Paradigm | Definitive Research Finding |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Conformity Studies (1955)** | **Solomon Asch** | Participants matched line lengths in a group of confederates giving unanimously wrong answers | ~37% of trials produced conformity; driven by **normative influence** (avoiding rejection) |\n"
                                    "| **Obedience to Authority (1963)** | **Stanley Milgram** | Teachers commanded by an authority figure to administer escalating electrical shocks to a screaming learner | **65% of ordinary participants** obeyed orders to deliver the maximum 450-volt lethal shock |\n"
                                    "| **Stanford Prison Experiment (1971)** | **Philip Zimbardo** | College students randomly assigned to mock guards or prisoners in a simulated basement prison | Deindividuation and institutional roles rapidly overrode personal morality within 6 days |"
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Normative vs. Informational Social Influence",
                                "body": "- **Normative Social Influence:** Conforming to gain social approval or avoid group rejection and embarrassment (e.g., wearing uncomfortable formal clothing to a banquet).\n- **Informational Social Influence:** Conforming because we accept others' opinions as genuine evidence about reality (e.g., following a crowd toward an emergency exit during an alarm).",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Milgram's Experimental Variations: Factors Altering Obedience",
                                "text": (
                                    "Milgram systematically manipulated variables affecting compliance:\n"
                                    "- **Proximity to Victim:** Obedience dropped to 40% when the learner was in the same room, and to 30% when the teacher had to physically press the learner's hand onto a shock plate.\n"
                                    "- **Proximity to Authority:** Obedience dropped to 21% when the experimenter issued commands via telephone.\n"
                                    "- **Defiant Peer Role Models:** When two confederate teachers rebelled and refused to proceed, participant obedience plummeted to **only 10%**."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: FAE Appears Primarily in Individualistic Cultures",
                                "body": "The **Fundamental Attribution Error** is significantly more pronounced in Western **individualistic cultures** (which emphasize personal autonomy) and is markedly lower in East Asian **collectivist cultures** (which naturally emphasize situational and social context).",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Fundamental Attribution Error",
                            "definition": "The tendency for observers to underestimate situational factors and overestimate dispositional personality factors when explaining others' behavior.",
                            "example": "Assuming a driver who cuts you off is an aggressive jerk, rather than considering they might be rushing to an emergency room.",
                        },
                        {
                            "term": "Cognitive Dissonance",
                            "definition": "The mental discomfort experienced by an individual who holds contradictory beliefs, values, or actions, driving attitude change.",
                            "example": "A dedicated cigarette smoker convincing themselves that medical smoking studies are exaggerated to reduce internal guilt.",
                        },
                        {
                            "term": "Normative Social Influence",
                            "definition": "Influence resulting from a person's desire to gain approval or avoid social disapproval and rejection.",
                            "example": "Applauding enthusiastically at the end of a dull symphony simply because everyone else in the auditorium stood and cheered.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "When a classmate arrives forty minutes late to a morning seminar, an observer concludes: 'She is chronically lazy, irresponsible, and undisciplined.' The observer fails to consider that the classmate's vehicle broke down. What attributional error is demonstrated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Self-serving attribution bias",
                                    "The fundamental attribution error",
                                    "The false consensus effect",
                                    "The representativeness heuristic",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "The fundamental attribution error occurs when observers attribute another person's actions to internal, enduring personality traits (laziness) while completely overlooking environmental situational constraints (traffic, mechanical breakdown).",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 12.1",
                            "concept_slugs": ["psyc-attribution-dissonance"],
                        },
                        {
                            "prompt": "In Solomon Asch's landmark 1955 visual line-judgment conformity experiments, what percentage of trials resulted in naive participants conforming to the group's unanimously incorrect visual answer?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Approximately 5% of trials",
                                    "Approximately 15% of trials",
                                    "Approximately 37% of trials",
                                    "Approximately 95% of trials",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "In Asch's conformity experiments, naive participants conformed to the confederates' unanimously erroneous visual judgments on approximately 37% of all critical trials, demonstrating the power of normative social influence.",
                            "difficulty": "intermediate",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 12.3",
                            "concept_slugs": ["psyc-conformity-obedience"],
                        },
                        {
                            "prompt": "In Stanley Milgram's original 1963 obedience study at Yale University, what proportion of ordinary adult male participants complied with the experimenter's commands to deliver the maximum 450-volt shock to the learner?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Less than 2% of participants",
                                    "Approximately 25% of participants",
                                    "Approximately 45% of participants",
                                    "Approximately 65% of participants",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "In Milgram's baseline obedience study, 65% (26 out of 40) of participants administered the final 450-volt electrical shock, despite the learner screaming in agony and subsequently going silent.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 12.3",
                            "concept_slugs": ["psyc-conformity-obedience"],
                        },
                        {
                            "prompt": "Under what condition did participant obedience in Stanley Milgram's shock experiments plummet most dramatically to only 10%?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "When two confederate teachers rebelled and refused to obey",
                                    "When the study was relocated to an off-campus storefront",
                                    "When the learner complained of a chronic mild heart condition",
                                    "When female experimental subjects were tested in place of males",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Milgram discovered that the presence of defiant peer role models who openly refused to obey orders shattered the perceived legitimacy and authority pressure, causing participant obedience to drop from 65% down to just 10%.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 12.3",
                            "concept_slugs": ["psyc-conformity-obedience"],
                        },
                        {
                            "prompt": "According to Leon Festinger's cognitive dissonance theory, why did participants in his 1959 experiment who were paid only one dollar to lie about a boring peg-turning task report genuinely liking the task more than those paid twenty dollars?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "The one-dollar subjects received greater operant reinforcement",
                                    "They lacked sufficient external justification, forcing attitude change",
                                    "They possessed higher intrinsic levels of procedural compliance",
                                    "The experimenter utilized double-blind counterconditioning protocols",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Participants paid $20 had sufficient external justification for lying ('I lied because I got paid twenty dollars'). Participants paid only $1 experienced severe cognitive dissonance ('I lied for a trivial dollar'), forcing them to resolve the dissonance by internally convincing themselves the task was actually interesting.",
                            "difficulty": "advanced",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 2e, Section 12.2",
                            "concept_slugs": ["psyc-attribution-dissonance"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What percentage of participants obeyed orders up to the maximum 450 volts in Milgram's baseline experiment?",
                    "back": "65% of participants.",
                    "concept_slugs": ["psyc-conformity-obedience"],
                },
                {
                    "front": "What is the difference between normative and informational social influence?",
                    "back": "Normative influence is conforming to be liked/accepted; informational influence is conforming to be correct based on others' knowledge.",
                    "concept_slugs": ["psyc-conformity-obedience"],
                },
            ],
        },
        {
            "code": "12.2",
            "title": "Analyze group dynamics, deindividuation, prejudice, and bystander intervention",
            "description": "Examine social facilitation, social loafing, group polarization, groupthink, in-group bias, and the Darley-Latané bystander effect.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 12.2",
            "concepts": [
                {
                    "slug": "psyc-group-dynamics",
                    "name": "Group Polarization, Groupthink, and Social Loafing",
                    "short_definition": "Collective social phenomena altering individual performance (social facilitation/loafing) and group decisions (polarization/groupthink).",
                    "description": "Social loafing reduces individual effort in unmonitored groups; groupthink prioritizes consensus over critical appraisal, risking catastrophic errors.",
                    "citation": "OpenStax Psychology 2e, Section 12.4",
                },
                {
                    "slug": "psyc-prejudice-altruism",
                    "name": "Prejudice, Ingroup Bias, and the Bystander Effect",
                    "short_definition": "Social relations spanning stereotypes, ingroup/outgroup bias, scapegoating, and bystander apathy via diffusion of responsibility.",
                    "description": "Darley and Latané proved that emergency intervention decreases as bystander group size increases due to pluralistic ignorance and diffused responsibility.",
                    "citation": "OpenStax Psychology 2e, Section 12.5 & 12.6",
                    "prerequisites": ["psyc-group-dynamics"],
                },
            ],
            "lessons": [
                {
                    "title": "Group Influence, Prejudice, and the Bystander Effect",
                    "description": "Social facilitation, social loafing, groupthink, Janis's foreign policy analysis, ingroup bias, and Darley-Latané bystander intervention.",
                    "emoji": "🤝",
                    "tags": ["groups", "groupthink", "loafing", "polarization", "bystander", "altruism"],
                    "concept_slugs": [
                        "psyc-group-dynamics",
                        "psyc-prejudice-altruism",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 12.4, 12.5, & 12.6",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Group Dynamics and Individual Performance\n\n"
                                    "- **Social Facilitation (Norman Triplett):** The presence of others enhances physiological arousal. This improves performance on **simple, well-learned tasks** (e.g., cyclists riding faster in groups), but impairs performance on **complex, unfamiliar tasks** (social impairment).\n"
                                    "- **Social Loafing:** The tendency for people in a collective group to exert less effort when pooling efforts toward a common goal than when individually accountable *(e.g., pulling less hard during a tug-of-war)*.\n"
                                    "- **Deindividuation:** The loss of self-awareness and personal restraint occurring in group situations that foster anonymity and high emotional arousal *(e.g., cyber mob bullying, nighttime riot vandalism)*.\n"
                                    "- **Group Polarization:** The enhancement and strengthening of a group's prevailing inclinations and attitudes following discussion among like-minded individuals.\n"
                                    "- **Groupthink (Irving Janis):** The mode of thinking that occurs when the desire for harmony and consensus in a cohesive decision-making group suppresses realistic dissenting viewpoints *(e.g., the Bay of Pigs invasion failure, NASA Challenger launch disaster)*."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Social Relations: Prejudice and Altruism\n\n"
                                    "| Social Concept | Operational Definition | Real-World Manifestation |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Stereotype** | Generalized cognitive belief about a group of people | Assuming all athletes are poor academic students |\n"
                                    "| **Prejudice** | Unjustified negative attitude toward a specific group | Feeling hostility or suspicion toward outgroup members |\n"
                                    "| **Discrimination** | Unjustified negative behavior or action toward a group | Refusing to lease an apartment based on ethnic background |\n"
                                    "| **Ingroup Bias** | Tendency to favor one's own identified group ('us') | Rating one's own university classmates as more trustworthy |\n"
                                    "| **Outgroup Homogeneity** | Viewing members of outside groups as identical ('they are all alike') | Believing rival political partisans all share identical monolithic thoughts |"
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Darley and Latané's Bystander Effect",
                                "body": "Spurred by the murder of Kitty Genovese, John Darley and Bibb Latané demonstrated that an individual is significantly **less likely to help in an emergency as the number of passive bystanders increases**. This bystander apathy is driven by:\n1. **Diffusion of Responsibility:** Believing someone else will step forward or call emergency services.\n2. **Pluralistic Ignorance:** Looking to other passive observers and concluding that because no one is reacting, the situation must not be a genuine crisis.",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Laboratory Case Study: The Staged Seizure Experiment",
                                "text": (
                                    "Darley and Latané placed college students in individual intercom cubicles. "
                                    "During discussion, an audio recording of a fellow student staged an acute epileptic seizure, gasping for medical help. "
                                    "When participants believed they were the **only person** on the intercom, **85% left their room to seek help immediately**. "
                                    "When they believed four other students were listening, **only 31% responded**, demonstrating dramatic diffusion of responsibility."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Social Facilitation vs. Social Loafing",
                                "body": "**Social facilitation** occurs when individual efforts are *evaluated* (arousal increases; simple tasks get better). **Social loafing** occurs when individual efforts are *pooled and anonymous* (arousal decreases; effort drops).",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Groupthink",
                            "definition": "The tendency of group members to conform, resulting in a narrow, uncritical view of an issue to maintain group cohesiveness.",
                            "example": "A presidential cabinet failing to question flawed military invasion plans because dissenting opinions are discouraged.",
                        },
                        {
                            "term": "Bystander Effect",
                            "definition": "The tendency for any given observer to be less likely to provide aid in an emergency if other bystanders are present.",
                            "example": "Dozens of commuters watching a person collapse on a subway platform, each assuming another commuter has called 911.",
                        },
                        {
                            "term": "Deindividuation",
                            "definition": "The loss of self-awareness and self-restraint occurring in group situations that foster both physical anonymity and high emotional arousal.",
                            "example": "An otherwise peaceful sports fan joining in overturning cars and smashing windows while masked within a championship victory riot.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "In a crowded urban train terminal, a pedestrian collapses unconscious to the ground. Despite dozens of commuters witnessing the event, several minutes pass before anyone assists or dials emergency dispatch. What social psychological phenomenon is operating?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "The bystander effect and diffusion of responsibility",
                                    "Group polarization toward institutional reliance",
                                    "Social facilitation under high autonomic arousal",
                                    "Hostile cognitive dissonance reduction",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "The bystander effect describes the phenomenon where individuals are less likely to offer help in an emergency when other bystanders are present. It is driven by diffusion of responsibility (each person assumes another witness will act) and pluralistic ignorance.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 12.6",
                            "concept_slugs": ["psyc-prejudice-altruism"],
                        },
                        {
                            "prompt": "An executive committee composed of like-minded directors discusses a controversial new product launch. Rather than critically challenging questionable financial assumptions, members suppress their private doubts to maintain unanimous harmony. What decision-making flaw is evident?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Social facilitation",
                                    "Groupthink",
                                    "Deindividuation",
                                    "Social loafing",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Groupthink (identified by Irving Janis) occurs in cohesive, isolated groups where the desire for consensus and harmony overrides the critical, objective appraisal of alternative courses of action.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 12.4",
                            "concept_slugs": ["psyc-group-dynamics"],
                        },
                        {
                            "prompt": "When four students are assigned a group project with a single shared grade, two members contribute significantly less research effort than they would have if graded individually. What phenomenon accounts for this reduced output?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Group polarization",
                                    "Deindividuation",
                                    "Social loafing",
                                    "Normative obedience",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Social loafing is the tendency for individuals to exert less physical or mental effort when their contributions are pooled into a group project where individual accountability and evaluation are diminished.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 12.4",
                            "concept_slugs": ["psyc-group-dynamics"],
                        },
                        {
                            "prompt": "Following a lively ninety-minute discussion among gun control advocates, the participants' attitudes toward enacting strict firearms legislation become substantially more extreme and unified than before the meeting. What group process occurred?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Deindividuation",
                                    "Social facilitation",
                                    "Cognitive dissonance",
                                    "Group polarization",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Group polarization describes the tendency for discussions among like-minded individuals to strengthen and amplify the group's preexisting attitudes and shared opinions, making their collective stance significantly more extreme.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 12.4",
                            "concept_slugs": ["psyc-group-dynamics"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the bystander effect and what drives it?",
                    "back": "People are less likely to help when others are present, driven by diffusion of responsibility.",
                    "concept_slugs": ["psyc-prejudice-altruism"],
                },
                {
                    "front": "What is groupthink in collective decision making?",
                    "back": "When the desire for group consensus overrides realistic, critical appraisal of alternatives.",
                    "concept_slugs": ["psyc-group-dynamics"],
                },
            ],
        },
    ],
}

