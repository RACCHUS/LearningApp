"""Domain 10.0: Psychological Disorders and Health (Quota: 8 questions, 8–9% blueprint)."""
from __future__ import annotations

DOMAIN_10 = {
    "code": "10.0",
    "title": "Psychological Disorders and Health",
    "description": "DSM-5 classification, biopsychosocial etiology, anxiety disorders, OCD, PTSD, mood and bipolar disorders, schizophrenia spectrum, and personality disorders.",
    "weight": 0.085,
    "sort_order": 10,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 10.0 (8–9%)",
    "objectives": [
        {
            "code": "10.1",
            "title": "Analyze diagnostic classification criteria, the medical/biopsychosocial models, and anxiety/trauma disorders",
            "description": "Evaluate DSM-5 diagnostic frameworks, analyze the Rosenhan labeling study, and contrast generalized anxiety, panic, phobias, OCD, and PTSD.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 10.1",
            "concepts": [
                {
                    "slug": "psyc-disorder-classification",
                    "name": "Diagnostic Classification and Biopsychosocial Etiology",
                    "short_definition": "Defining psychological disorders via deviance, distress, and dysfunction, classified by the DSM-5-TR under the diathesis-stress framework.",
                    "description": "The medical model views disorders as illnesses; the diathesis-stress model integrates genetic predisposition with environmental stressors; Rosenhan demonstrated diagnostic labeling bias.",
                    "citation": "OpenStax Psychology 2e, Section 15.1 & 15.2",
                },
                {
                    "slug": "psyc-anxiety-ocd-ptsd",
                    "name": "Anxiety Disorders, OCD, and PTSD",
                    "short_definition": "Pathological anxiety syndromes (GAD, panic, phobias), obsessions/compulsions in OCD, and trauma intrusions in PTSD.",
                    "description": "Anxiety involves autonomic hyperarousal; OCD features cognitive obsessions relieved by behavioral compulsions; PTSD involves flashbacks and avoidance.",
                    "citation": "OpenStax Psychology 2e, Section 15.3, 15.4, & 15.5",
                    "prerequisites": ["psyc-disorder-classification"],
                },
            ],
            "lessons": [
                {
                    "title": "Psychological Disorders: Classification, Anxiety, OCD, and Trauma",
                    "description": "The 4 D's, DSM-5 criteria, Rosenhan's hospital study, GAD, panic disorder, agoraphobia, obsessions vs. compulsions, and PTSD.",
                    "emoji": "🧠",
                    "tags": ["disorders", "dsm5", "anxiety", "ocd", "ptsd", "rosenhan"],
                    "concept_slugs": [
                        "psyc-disorder-classification",
                        "psyc-anxiety-ocd-ptsd",
                    ],
                    "citation": "OpenStax Psychology 2e, Chapter 15",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Defining Abnormality and the DSM-5 Framework\n\n"
                                    "Mental health professionals define psychological disorders using the **4 D's**:\n"
                                    "- **Deviance:** Thoughts and behaviors that differ significantly from societal cultural norms.\n"
                                    "- **Distress:** Subjective emotional pain, suffering, or torment experienced by the individual.\n"
                                    "- **Dysfunction:** Interference with daily occupational, social, or academic functioning (the central diagnostic criterion).\n"
                                    "- **Danger:** Substantial risk of harm to oneself or others.\n\n"
                                    "The American Psychiatric Association's **DSM-5-TR** provides detailed, standardized categorical criteria without endorsing a single theoretical origin. "
                                    "The **Diathesis-Stress Model** posits that disorders result from a pre-existing biological or genetic vulnerability (**diathesis**) activated by severe environmental stress."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Anxiety, Obsessive-Compulsive, and Trauma Disorders\n\n"
                                    "| Disorder | Core Symptom Profile | Diagnostic Hallmark |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Generalized Anxiety Disorder (GAD)** | Chronic, diffuse, unfocused apprehension lasting $\\ge 6$ months | 'Free-floating' anxiety accompanied by muscle tension and fatigue |\n"
                                    "| **Panic Disorder** | Recurrent sudden surges of terrifying autonomic panic | Anticipatory terror; frequently accompanied by **agoraphobia** |\n"
                                    "| **Specific Phobia** | Persistent, irrational fear and avoidance of a specific object | Disproportionate dread; recognized by adult as irrational |\n"
                                    "| **Obsessive-Compulsive Disorder (OCD)** | Intrusive thoughts paired with repetitive ritualistic acts | **Obsessions** (anxiety-provoking thoughts) drive **Compulsions** (anxiety-reducing behaviors) |\n"
                                    "| **Post-Traumatic Stress Disorder (PTSD)** | Follows severe life-threatening trauma | Intrusive flashbacks, nightmares, hyperarousal, avoidance of trauma cues |"
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Obsessions vs. Compulsions in OCD",
                                "body": "**Obsessions are repetitive THOUGHTS** (e.g., persistent terrifying fear of microbial contamination). **Compulsions are repetitive BEHAVIORS or mental rituals** (e.g., washing hands raw for 20 minutes) performed to neutralize the anxiety caused by the obsession via negative reinforcement.",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Historical Psychiatric Experiment: David Rosenhan's Hospital Study",
                                "text": (
                                    "In 1973, David Rosenhan sent eight sane pseudopatients to various psychiatric hospitals claiming they heard a single auditory voice saying 'empty, hollow, thud.' "
                                    "All were admitted and diagnosed with schizophrenia. Once admitted, they acted completely normal. "
                                    "Hospital staff failed to detect them; normal behaviors (like writing notes in a diary) were documented as pathological 'patient engages in excessive note-taking behavior.' "
                                    "The study demonstrated the profound, persistent biasing power of **diagnostic labels**."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Panic Disorder vs. GAD",
                                "body": "**Generalized Anxiety Disorder (GAD)** is continuous, persistent, low-to-moderate 'free-floating' anxiety lasting months. **Panic Disorder** involves sudden, acute, intense attacks of terror lasting minutes that strike unexpectedly.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Obsessions",
                            "definition": "Persistent, intrusive, involuntary thoughts, urges, or mental images that cause marked anxiety or distress.",
                            "example": "An unrelenting fear that one will accidentally leave the stove gas on and burn down the house.",
                        },
                        {
                            "term": "Compulsions",
                            "definition": "Repetitive, ritualistic behaviors or mental acts that an individual feels driven to perform to reduce anxiety created by an obsession.",
                            "example": "Checking the front door lock exactly sixteen times in a rigid sequence before leaving.",
                        },
                        {
                            "term": "Diathesis-Stress Model",
                            "definition": "A psychological theory explaining that a disorder results from an interaction between an underlying genetic/biological vulnerability and environmental stress.",
                            "example": "A person possessing genetic risk for depression becoming clinically depressed only after enduring a severe divorce and job loss.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "An individual experiences persistent, intrusive thoughts that their hands are covered in lethal bacteria, creating severe anxiety. To relieve this distress, they wash their hands thirty times an hour. In psychiatric terminology, what is the handwashing behavior?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "A compulsion",
                                    "An obsession",
                                    "A delusion",
                                    "A hallucination",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "In obsessive-compulsive disorder, the intrusive thoughts regarding contamination are obsessions, whereas the repetitive behavioral rituals performed to reduce the anxiety generated by those thoughts (handwashing) are compulsions.",
                            "difficulty": "beginner",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 15.4",
                            "concept_slugs": ["psyc-anxiety-ocd-ptsd"],
                        },
                        {
                            "prompt": "In David Rosenhan's famous 1973 study 'On Being Sane in Insane Places,' what did the behavior of the hospital staff toward the pseudopatients reveal?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Psychiatric diagnostic criteria were objective and immune to bias",
                                    "Diagnostic labels strongly influenced how staff interpreted normal behaviors",
                                    "Pseudopatients developed actual psychotic symptoms due to institutionalization",
                                    "Antipsychotic medications produced immediate behavioral remission",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Rosenhan's study demonstrated that once individuals were labeled with schizophrenia, hospital staff interpreted completely normal, ordinary behaviors (such as pacing out of boredom or taking notes) as pathological manifestations of mental illness.",
                            "difficulty": "intermediate",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 2e, Section 15.1",
                            "concept_slugs": ["psyc-disorder-classification"],
                        },
                        {
                            "prompt": "An individual experiences sudden, unpredictable episodes of intense terror accompanied by heart palpitations, chest pain, dizziness, and a feeling of impending doom, leading them to fear leaving home. What diagnosis is indicated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Obsessive-compulsive disorder",
                                    "Bipolar II hypomania",
                                    "Panic disorder with agoraphobia",
                                    "Schizotypal personality disorder",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Panic disorder is defined by recurrent unexpected panic attacks featuring intense autonomic symptoms. When individuals fear having attacks in public spaces from which escape might be difficult, agoraphobia frequently develops.",
                            "difficulty": "intermediate",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 15.3",
                            "concept_slugs": ["psyc-anxiety-ocd-ptsd"],
                        },
                        {
                            "prompt": "Six months after surviving a severe industrial chemical explosion, a worker suffers recurrent nightmares, vivid flashbacks, emotional numbing, and severe hypervigilance. What diagnosis is warranted?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Dissociative fugue",
                                    "Generalized anxiety disorder",
                                    "Acute stress disorder",
                                    "Post-traumatic stress disorder",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Post-traumatic stress disorder (PTSD) is diagnosed when symptoms of intrusive memories, flashbacks, hyperarousal, avoidance of trauma cues, and negative alterations in mood persist for longer than one month following exposure to a traumatic event.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 15.5",
                            "concept_slugs": ["psyc-anxiety-ocd-ptsd"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the difference between an obsession and a compulsion?",
                    "back": "An obsession is an intrusive anxiety-provoking thought; a compulsion is a repetitive behavior performed to reduce that anxiety.",
                    "concept_slugs": ["psyc-anxiety-ocd-ptsd"],
                },
                {
                    "front": "What does the diathesis-stress model propose?",
                    "back": "A disorder emerges when an underlying biological vulnerability is triggered by environmental stress.",
                    "concept_slugs": ["psyc-disorder-classification"],
                },
            ],
        },
        {
            "code": "10.2",
            "title": "Analyze depressive, bipolar, schizophrenia spectrum, and personality disorders",
            "description": "Examine major depressive and bipolar episodes, contrast positive vs. negative symptoms of schizophrenia, and analyze Cluster B antisocial personality disorder.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 10.2",
            "concepts": [
                {
                    "slug": "psyc-mood-bipolar-disorders",
                    "name": "Depressive and Bipolar Disorders",
                    "short_definition": "Mood disturbances spanning Major Depressive Disorder (anhedonia, lethargy) and Bipolar Disorder (alternating depression and mania).",
                    "description": "Depression involves monoamine deficits and pessimistic cognitive triads; Bipolar I requires at least one full manic episode.",
                    "citation": "OpenStax Psychology 2e, Section 15.6 & 15.7",
                },
                {
                    "slug": "psyc-schizophrenia-personality",
                    "name": "Schizophrenia Spectrum and Personality Disorders",
                    "short_definition": "Psychotic positive/negative symptoms driven by dopamine dysregulation, and inflexible personality patterns like antisocial disorder.",
                    "description": "Schizophrenia features delusions, hallucinations, and flat affect; antisocial personality disorder features lack of remorse and pervasive rights violations.",
                    "citation": "OpenStax Psychology 2e, Section 15.8 & 15.9",
                    "prerequisites": ["psyc-mood-bipolar-disorders"],
                },
            ],
            "lessons": [
                {
                    "title": "Depressive, Bipolar, Schizophrenic, and Personality Pathology",
                    "description": "MDD, bipolar mania, positive vs. negative symptoms of schizophrenia, the dopamine hypothesis, and antisocial personality disorder.",
                    "emoji": "🎭",
                    "tags": ["depression", "bipolar", "mania", "schizophrenia", "dopamine", "personality-disorders"],
                    "concept_slugs": [
                        "psyc-mood-bipolar-disorders",
                        "psyc-schizophrenia-personality",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 15.6, 15.7, 15.8, & 15.9",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Mood and Bipolar Disorders\n\n"
                                    "- **Major Depressive Disorder (MDD):** A persistent state of despair and **anhedonia** (inability to experience pleasure) lasting at least **2 weeks**, accompanied by sleep disruptions, feelings of worthlessness, fatigue, and suicidal thoughts.\n"
                                    "- **Bipolar I Disorder:** Mood swings alternating between depressive episodes and full **manic episodes**—hyperactive, euphoric, grandiose states marked by racing thoughts, rapid flight of ideas, decreased need for sleep, and impulsive financial or sexual recklessness.\n"
                                    "- **Cognitive Etiology (Aaron Beck):** Depressive symptoms are reinforced by the **Cognitive Triad**: automatic negative views about **oneself**, the **world**, and the **future**."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Schizophrenia Spectrum: Positive vs. Negative Symptoms\n\n"
                                    "Schizophrenia is a severe psychotic disorder characterized by a disintegration of thought, emotion, and perception:\n\n"
                                    "| Category | Clinical Definition | Symptom Examples |\n"
                                    "| :--- | :--- | :--- |\n"
                                    "| **Positive Symptoms** | Presence of inappropriate or abnormal psychological experiences | **Hallucinations** (sensory perceptions without stimuli, most often auditory voices); **Delusions** (fixed false beliefs of persecution or grandeur); Disorganized speech ('word salad') |\n"
                                    "| **Negative Symptoms** | Absence or deficit of normal psychological functioning | **Flat affect** (monotone voice, blank facial expression); **Avolition** (total lack of initiative); **Alogia** (poverty of speech); Social withdrawal |\n\n"
                                    "**Biological Etiology:** Linked to the **dopamine hypothesis** (excessive dopamine D2 receptor signaling in subcortical brain pathways), enlarged fluid-filled cerebral ventricles, and prenatal neurodevelopmental insults."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Delusion vs. Hallucination",
                                "body": "- A **delusion is a false BELIEF** (e.g., believing the CIA is transmitting secret messages through the microwave).\n- A **hallucination is a false SENSORY PERCEPTION** (e.g., hearing voices arguing in an empty room).",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Clinical Forensic Case: Antisocial Personality Disorder",
                                "text": (
                                    "A 32-year-old con artist defrauds elderly investors out of their life savings. "
                                    "When interrogated, the individual displays no remorse, empathy, or guilt, boasting: 'If they were stupid enough to give me their money, they deserved to lose it.' "
                                    "This pattern of callous deceit, disregard for the rights of others, and absence of conscience characterizes **Antisocial Personality Disorder** (Cluster B)."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Schizophrenia is NOT Dissociative Identity Disorder",
                                "body": "Popular media frequently confuses **schizophrenia** (a psychotic disorder involving hallucinations and delusions) with **Dissociative Identity Disorder (DID)** (formerly 'multiple personality disorder,' involving two or more distinct split personalities). They are completely distinct diagnostic entities.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Hallucination",
                            "definition": "A false sensory perception occurring in the absence of any external physical stimulus, most frequently auditory in schizophrenia.",
                            "example": "Hearing voices commenting on one's actions when no one is speaking.",
                        },
                        {
                            "term": "Delusion",
                            "definition": "A firmly held false belief that persists despite overwhelming contradictory evidence, common in psychotic disorders.",
                            "example": "Believing that one is an extraterrestrial royalty tasked with controlling world weather patterns.",
                        },
                        {
                            "term": "Antisocial Personality Disorder",
                            "definition": "A personality disorder characterized by a pervasive pattern of disregard for and violation of the rights of others, lack of empathy, and deceitfulness.",
                            "example": "A chronic criminal who repeatedly exploits others without experiencing guilt or moral remorse.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "A patient diagnosed with schizophrenia firmly believes that television news anchors are broadcasting secret coded messages about their personal thoughts. What psychotic symptom is demonstrated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "A delusion of reference",
                                    "An auditory hallucination",
                                    "A catatonic motor stupor",
                                    "A dissociative fugue state",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "A delusion is a fixed false belief. Specifically, a delusion of reference involves the mistaken conviction that neutral external events, television broadcasts, or remarks have direct, special personal significance directed at the individual.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 15.8",
                            "concept_slugs": ["psyc-schizophrenia-personality"],
                        },
                        {
                            "prompt": "Which symptom of schizophrenia is classified by clinical psychiatrists as a negative symptom rather than a positive symptom?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Persecutory paranoia",
                                    "Flat emotional affect",
                                    "Auditory hallucinations",
                                    "Disorganized speech",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Negative symptoms represent the reduction or loss of normal functions. Flat affect (expressionless face and monotone voice), avolition, and alogia are negative symptoms. Hallucinations, delusions, and disorganized speech are positive symptoms (the presence of abnormal behaviors).",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 15.8",
                            "concept_slugs": ["psyc-schizophrenia-personality"],
                        },
                        {
                            "prompt": "Over the past two weeks, a patient has experienced grandiosity, slept only two hours a night without fatigue, spoken at blinding speed, and maxed out their credit cards on impulsive speculative real estate. What diagnosis is indicated?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Major depressive disorder",
                                    "Persistent dysthymic disorder",
                                    "Bipolar I manic episode",
                                    "Generalized anxiety disorder",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "A manic episode in Bipolar I Disorder is characterized by an abnormally elevated or irritable mood, grandiosity, decreased need for sleep, pressured speech, racing thoughts, and high-risk impulsive behavior.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 15.7",
                            "concept_slugs": ["psyc-mood-bipolar-disorders"],
                        },
                        {
                            "prompt": "An adult demonstrates a lifelong history of criminal deceit, aggressive impulsivity, chronic manipulation, and a total absence of guilt or empathy toward victims. What diagnostic category does this individual match?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Borderline personality disorder",
                                    "Narcissistic personality disorder",
                                    "Schizoid personality disorder",
                                    "Antisocial personality disorder",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Antisocial personality disorder (Cluster B) is characterized by a pervasive pattern of disregard for and violation of the rights of others, deceitfulness, impulsivity, irritability, and a lack of remorse or conscience.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 15.9",
                            "concept_slugs": ["psyc-schizophrenia-personality"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the difference between positive and negative symptoms of schizophrenia?",
                    "back": "Positive symptoms are additions to normal behavior (hallucinations, delusions); negative symptoms are deficits (flat affect, avolition).",
                    "concept_slugs": ["psyc-schizophrenia-personality"],
                },
                {
                    "front": "What neurotransmitter is hypothesized to be overactive in schizophrenia?",
                    "back": "Dopamine (the dopamine hypothesis).",
                    "concept_slugs": ["psyc-schizophrenia-personality"],
                },
            ],
        },
    ],
}
