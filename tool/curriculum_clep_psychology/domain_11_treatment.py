"""Domain 11.0: Treatment of Psychological Disorders (Quota: 6 questions, 6–7% blueprint)."""
from __future__ import annotations

DOMAIN_11 = {
    "code": "11.0",
    "title": "Treatment of Psychological Disorders",
    "description": "Psychotherapy modalities (psychodynamic, humanistic, behavioral, cognitive-behavioral), psychopharmacological agents, ECT, and treatment efficacy.",
    "weight": 0.065,
    "sort_order": 11,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 11.0 (6–7%)",
    "objectives": [
        {
            "code": "11.1",
            "title": "Analyze psychological therapies across psychodynamic, humanistic, behavioral, and cognitive orientations",
            "description": "Examine psychoanalytic transference, Rogers's client-centered active listening, Wolpe's systematic desensitization, and Beck/Ellis cognitive restructuring.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 11.1",
            "concepts": [
                {
                    "slug": "psyc-psychotherapy-modalities",
                    "name": "Psychodynamic, Humanistic, and Behavioral Therapies",
                    "short_definition": "Major therapeutic traditions emphasizing unconscious insight (Freud), personal growth (Rogers), and learned counterconditioning (Wolpe).",
                    "description": "Techniques include free association, resistance, transference, unconditional positive regard, systematic desensitization, and token economies.",
                    "citation": "OpenStax Psychology 2e, Section 16.2",
                },
                {
                    "slug": "psyc-cognitive-behavioral-therapy",
                    "name": "Cognitive Restructuring and REBT",
                    "short_definition": "Therapies targeting maladaptive, irrational thinking patterns through cognitive reappraisal and behavioral activation.",
                    "description": "Beck's cognitive therapy disputes automatic catastrophic assumptions; Ellis's REBT challenges irrational beliefs via the ABC model.",
                    "citation": "OpenStax Psychology 2e, Section 16.2",
                    "prerequisites": ["psyc-psychotherapy-modalities"],
                },
            ],
            "lessons": [
                {
                    "title": "Psychological Therapies: Insight, Behavior, and Cognitive Approaches",
                    "description": "Psychoanalysis, client-centered therapy, systematic desensitization, token economies, Ellis's REBT, and Beck's CBT.",
                    "emoji": "🛋️",
                    "tags": ["therapy", "cbt", "psychoanalysis", "desensitization", "beck", "rogers"],
                    "concept_slugs": [
                        "psyc-psychotherapy-modalities",
                        "psyc-cognitive-behavioral-therapy",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 16.2: Types of Treatment",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Major Psychotherapy Orientations\n\n"
                                    "| Therapeutic Approach | Founding Theorists | Primary Mechanism of Change | Hallmark Techniques |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Psychoanalysis** | Sigmund Freud | Bringing repressed unconscious conflicts into conscious awareness | **Free association**, dream analysis, resolving **resistance** and **transference** |\n"
                                    "| **Client-Centered (Humanistic)** | Carl Rogers | Fostering self-actualization by resolving actual/ideal self incongruence | Nondirective **active listening**, empathy, **unconditional positive regard**, genuineness |\n"
                                    "| **Behavior Therapy** | Joseph Wolpe, B. F. Skinner | Replacing maladaptive learned responses with adaptive behaviors via conditioning | **Systematic desensitization**, exposure therapy, flooding, aversive conditioning, **token economy** |\n"
                                    "| **Cognitive Therapy (CBT)** | Aaron Beck, Albert Ellis | Identifying and disputing irrational, catastrophic cognitive distortions | **Cognitive restructuring**, Ellis's **ABC model** (Activating event, Belief, Consequence) |"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Joseph Wolpe's Systematic Desensitization\n\n"
                                    "Based on **classical counterconditioning** and reciprocal inhibition (one cannot be simultaneously relaxed and terrified):\n"
                                    "1. The client is trained in deep **progressive muscle relaxation**.\n"
                                    "2. The client constructs an **anxiety hierarchy** (ranking fear-evoking scenes from least to most terrifying, e.g., looking at a picture of a spider $\\rightarrow$ holding a tarantula).\n"
                                    "3. The client progressively pairs deep relaxation with each scene in the hierarchy until the phobic response is extinguished."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Psychoanalytic Transference",
                                "body": "**Transference** occurs when a patient unconsciously redirects emotions, expectations, and conflicts originally experienced with key childhood figures (such as a parent) onto the therapist. Analyzing transference provides a window into unresolved childhood relational dynamics.",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Clinical Case: Systematic Desensitization for Aviophobia",
                                "text": (
                                    "A businesswoman with a severe phobia of commercial flight undergoes systematic desensitization. "
                                    "While maintaining deep diaphragmatic relaxation, she visualizes booking a flight, driving to the airport, "
                                    "boarding the plane, and experiencing takeoff. After eight sessions, she boards a real flight without panic."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Flooding vs. Systematic Desensitization",
                                "body": "**Systematic desensitization** is gradual, pairing progressive relaxation with an anxiety hierarchy. **Flooding** is immediate, continuous exposure to the maximum feared stimulus (e.g., placing the spider directly in the patient's hands) until the sympathetic nervous response exhausts itself.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Systematic Desensitization",
                            "definition": "A behavior therapy technique that pairs progressive relaxation with gradual exposure to an anxiety hierarchy to extinguish phobias.",
                            "example": "Overcoming a fear of heights by relaxing while looking out a first-floor, then fifth-floor, then twentieth-floor window.",
                        },
                        {
                            "term": "Transference",
                            "definition": "In psychoanalysis, the patient's unconscious transfer of intense feelings or desires linked with parents or key figures onto the analyst.",
                            "example": "A client becoming irrationally furious at their therapist for rescheduling, mirroring feelings toward an unreliable father.",
                        },
                        {
                            "term": "Cognitive Restructuring",
                            "definition": "A cognitive therapy technique that teaches clients to identify, challenge, and replace irrational, distorted automatic thoughts.",
                            "example": "Replacing the catastrophic belief 'If I fail this exam, my life is ruined' with 'A low score is disappointing, but I can study and retake the course.'",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "A therapist helps a client conquer a severe dog phobia by first training the client in deep relaxation, and then gradually exposing them to pictures of dogs, viewing a dog through a window, and finally petting a therapy dog. What therapeutic technique is being used?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Systematic desensitization",
                                    "Psychoanalytic free association",
                                    "Flooding exposure therapy",
                                    "Aversive counterconditioning",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Systematic desensitization, developed by Joseph Wolpe, is a classical counterconditioning therapy that pairs progressive relaxation with a graduated hierarchy of anxiety-provoking stimuli to systematically extinguish a phobic reaction.",
                            "difficulty": "beginner",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 16.2",
                            "concept_slugs": ["psyc-psychotherapy-modalities"],
                        },
                        {
                            "prompt": "During long-term psychoanalysis, a patient begins treating their therapist with intense, bitter anger, accusing the therapist of being cold, distant, and unsupportive—mirroring the patient's unresolved childhood relationship with their father. What clinical phenomenon is occurring?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Resistance",
                                    "Transference",
                                    "Sublimation",
                                    "Incongruence",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "Transference occurs in psychoanalysis when a patient unconsciously projects and redirects emotional feelings, conflicts, and expectations originally experienced with important childhood figures (such as parents) onto the therapist.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 16.2",
                            "concept_slugs": ["psyc-psychotherapy-modalities"],
                        },
                        {
                            "prompt": "Which therapeutic modality focuses specifically on identifying automatic cognitive distortions—such as catastrophizing and all-or-nothing thinking—and replacing them with objective, realistic appraisals?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Client-centered humanistic therapy",
                                    "Psychodynamic dream analysis",
                                    "Aaron Beck's cognitive therapy",
                                    "Operant token economy therapy",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "Aaron Beck's cognitive therapy focuses on identifying maladaptive cognitive schemas and automatic negative thoughts (such as arbitrary inference and catastrophizing) and actively restructuring them through collaborative empirical questioning.",
                            "difficulty": "beginner",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 16.2",
                            "concept_slugs": ["psyc-cognitive-behavioral-therapy"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "What is the core principle behind Joseph Wolpe's systematic desensitization?",
                    "back": "Counterconditioning: an individual cannot be simultaneously relaxed and terrified (reciprocal inhibition).",
                    "concept_slugs": ["psyc-psychotherapy-modalities"],
                },
                {
                    "front": "What does Albert Ellis's ABC model stand for in Rational Emotive Behavior Therapy (REBT)?",
                    "back": "A = Activating event, B = Belief, C = emotional Consequence.",
                    "concept_slugs": ["psyc-cognitive-behavioral-therapy"],
                },
            ],
        },
        {
            "code": "11.2",
            "title": "Analyze biomedical therapies, psychopharmacology, brain stimulation, and treatment efficacy",
            "description": "Categorize antipsychotics, antidepressants, and mood stabilizers, evaluate electroconvulsive therapy, and review meta-analytic psychotherapy efficacy.",
            "sort_order": 2,
            "importance": "core",
            "citation": "College Board Objective 11.2",
            "concepts": [
                {
                    "slug": "psyc-biomedical-pharmacology",
                    "name": "Psychopharmacology and Biomedical Therapies",
                    "short_definition": "Pharmacological mechanisms of antipsychotics, SSRI antidepressants, mood-stabilizing lithium, and ECT brain stimulation.",
                    "description": "Antipsychotics block dopamine receptors; SSRIs block serotonin reuptake; lithium stabilizes bipolar cycling; ECT delivers controlled seizures for severe depression.",
                    "citation": "OpenStax Psychology 2e, Section 16.3",
                },
                {
                    "slug": "psyc-treatment-efficacy-meta-analysis",
                    "name": "Evaluating Treatment Outcomes and Therapeutic Alliance",
                    "short_definition": "Empirical evaluation of psychotherapy efficacy through meta-analysis and the foundational role of the therapeutic alliance.",
                    "description": "Meta-analyses demonstrate that psychotherapy is substantially more effective than no treatment, mediated by empathy, hope, and the therapeutic alliance.",
                    "citation": "OpenStax Psychology 2e, Section 16.4",
                    "prerequisites": ["psyc-biomedical-pharmacology"],
                },
            ],
            "lessons": [
                {
                    "title": "Biomedical Therapies, Psychopharmacology, and Treatment Outcomes",
                    "description": "Antipsychotics, SSRIs, lithium, electroconvulsive therapy (ECT), tardive dyskinesia, and meta-analytic evidence for psychotherapy.",
                    "emoji": "💊",
                    "tags": ["pharmacology", "ssri", "antipsychotics", "lithium", "ect", "meta-analysis"],
                    "concept_slugs": [
                        "psyc-biomedical-pharmacology",
                        "psyc-treatment-efficacy-meta-analysis",
                    ],
                    "citation": "OpenStax Psychology 2e, Section 16.3 & 16.4",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Major Psychopharmacological Drug Classes\n\n"
                                    "| Drug Category | Primary Biological Mechanism | Target Clinical Disorders | Common Side Effects & Risks |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Antipsychotics (Typical)** *(e.g., Thorazine, Haldol)* | Block **dopamine D2 receptors** in limbic pathways | Schizophrenia (positive symptoms: hallucinations, delusions) | **Tardive dyskinesia** (involuntary facial grimacing and tongue protrusion) |\n"
                                    "| **Antipsychotics (Atypical)** *(e.g., Clozaril, Risperdal)* | Target both **dopamine** and **serotonin** receptors | Schizophrenia (positive and negative symptoms) | Metabolic syndrome, substantial weight gain |\n"
                                    "| **Antidepressants (SSRIs)** *(e.g., Prozac, Zoloft, Paxil)* | Selectively block the **reuptake of serotonin**, elevating synaptic concentration | Major Depressive Disorder, GAD, OCD, Panic Disorder | Sexual dysfunction, nausea, delayed onset (2–4 weeks) |\n"
                                    "| **Mood Stabilizers** *(e.g., Lithium carbonate)* | Regulates glutamate and intracellular neuroprotective cascades | **Bipolar I Disorder** (prevents and treats manic episodes) | Requires regular blood monitoring due to narrow therapeutic window |\n"
                                    "| **Antianxiety Drugs** *(e.g., Xanax, Valium, Ativan)* | Enhance inhibitory neurotransmitter **GABA** activity | Panic disorder, acute anxiety | Sedation, physical dependence, tolerance, severe withdrawal |"
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Brain Stimulation Modalities and Outcome Research\n\n"
                                    "- **Electroconvulsive Therapy (ECT):** A biomedical therapy for severe, treatment-resistant depression in which a brief electrical current is sent through the brain of an anesthetized patient to trigger a controlled seizure. Highly effective for acute suicidal depression; primary side effect is temporary anterograde/retrograde memory loss.\n"
                                    "- **Repetitive Transcranial Magnetic Stimulation (rTMS):** Delivers repeated magnetic pulses to the left prefrontal cortex to stimulate inactive neural circuits without producing seizures or memory loss.\n\n"
                                    "### Evaluating Therapy Outcomes: Meta-Analysis\n\n"
                                    "In 1952, Hans Eysenck claimed two-thirds of untreated neurotic patients improve on their own through **spontaneous remission**. "
                                    "Subsequent large-scale **meta-analyses** (statistical syntheses of hundreds of randomized controlled trials) conducted by Mary Lee Smith and Gene Glass decisively disproved Eysenck, "
                                    "revealing that **the average treated therapy client is better off than 80% of untreated control individuals**. "
                                    "The single strongest predictor of positive outcome across all therapy types is the **therapeutic alliance**—the empathic, collaborative bond between therapist and client."
                                )
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "How SSRIs Function at the Synapse",
                                "body": "Normally, presynaptic neurons reabsorb excess serotonin from the synaptic cleft through reuptake pumps. **Selective Serotonin Reuptake Inhibitors (SSRIs)** bind to these reuptake transporter proteins, preventing serotonin reabsorption and leaving more serotonin available in the synaptic cleft to stimulate postsynaptic receptors.",
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "example",
                            "content": {
                                "title": "Clinical Case: Managing Severe Bipolar I Mania",
                                "text": (
                                    "A 30-year-old musician in a severe manic episode has not slept in four days, is experiencing racing thoughts, and has spent $40,000 on soundboards. "
                                    "Prescribing an SSRI antidepressant would be dangerous, potentially exacerbating the mania into psychosis. "
                                    "The first-line psychiatric pharmacological treatment is **Lithium carbonate**, which stabilizes mood oscillations."
                                ),
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Tardive Dyskinesia Risk",
                                "body": "**Tardive dyskinesia** is a severe, often irreversible neurological syndrome featuring involuntary movements of the tongue, lips, and extremities resulting from **long-term use of first-generation typical antipsychotic medications** that block dopamine receptors.",
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Selective Serotonin Reuptake Inhibitor (SSRI)",
                            "definition": "A class of psychotropic antidepressant medications that increase extracellular levels of serotonin by limiting its reabsorption into the presynaptic cell.",
                            "example": "Fluoxetine (Prozac) prescribed to treat major depressive episodes and obsessive-compulsive disorder.",
                        },
                        {
                            "term": "Tardive Dyskinesia",
                            "definition": "A neurological condition marked by involuntary, repetitive movements of the mouth, face, and limbs, caused by long-term treatment with typical antipsychotics.",
                            "example": "A chronic schizophrenia patient displaying repetitive lip smacking and involuntary facial grimacing.",
                        },
                        {
                            "term": "Therapeutic Alliance",
                            "definition": "The collaborative, trusting relationship and bond established between a client and their therapist, recognized as a primary factor in treatment success.",
                            "example": "A patient feeling deeply understood, respected, and supported by their clinical psychologist.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "Selective serotonin reuptake inhibitors (SSRIs), such as fluoxetine and sertraline, relieve depressive symptoms primarily through which neurochemical mechanism?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Accelerating the enzymatic destruction of monoamines",
                                    "Stimulating rapid postsynaptic destruction of dopamine D2 receptors",
                                    "Blocking the reabsorption of serotonin into presynaptic terminal buttons",
                                    "Directly converting GABA neurotransmitters into norepinephrine",
                                ]
                            },
                            "scoring_spec": {"correct_index": 2},
                            "explanation": "SSRIs function by inhibiting the presynaptic reuptake transporter proteins for serotonin, thereby preventing serotonin from being cleared from the synaptic cleft and increasing its availability to bind to postsynaptic receptors.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 16.3",
                            "concept_slugs": ["psyc-biomedical-pharmacology"],
                        },
                        {
                            "prompt": "Long-term maintenance treatment with first-generation typical antipsychotic medications carries a substantial risk of producing which irreversible motor syndrome?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Catatonic stupor",
                                    "Retrograde amnesia",
                                    "Serotonin syndrome",
                                    "Tardive dyskinesia",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "Tardive dyskinesia is a serious, often permanent movement disorder caused by long-term blockade of dopamine receptors by first-generation typical antipsychotics (e.g., haloperidol), manifesting as involuntary twitches of the tongue, jaw, and facial muscles.",
                            "difficulty": "intermediate",
                            "cognitive_level": "recall",
                            "citation": "OpenStax Psychology 2e, Section 16.3",
                            "concept_slugs": ["psyc-biomedical-pharmacology"],
                        },
                        {
                            "prompt": "Large-scale meta-analyses evaluating psychotherapy outcomes (such as research by Smith and Glass) have established which conclusion regarding the efficacy of psychological treatments?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "Treated psychotherapy clients show significantly greater clinical improvement than approximately eighty percent of untreated control individuals.",
                                    "Psychotherapy produces lasting positive behavioral change only when combined with daily maintenance dosages of psychiatric medication.",
                                    "Spontaneous remission occurs at identical rates whether patients receive evidence-based cognitive therapy or no formal clinical treatment.",
                                    "The specific theoretical modality practiced by the clinician accounts for virtually all variance in patient recovery and symptom reduction.",
                                ]
                            },
                            "scoring_spec": {"correct_index": 0},
                            "explanation": "Meta-analytic reviews synthesizing hundreds of controlled outcome studies demonstrate that psychotherapy is effective: the average treated client is better off than approximately 80% of untreated individuals on waitlists, refuting Eysenck's spontaneous remission claims.",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 16.4",
                            "concept_slugs": ["psyc-treatment-efficacy-meta-analysis"],
                        },
                    ],
                }
            ],
            "flashcards": [
                {
                    "front": "How do SSRIs work at the neuronal synapse?",
                    "back": "They block the reuptake of serotonin by the presynaptic neuron, increasing serotonin availability.",
                    "concept_slugs": ["psyc-biomedical-pharmacology"],
                },
                {
                    "front": "What does meta-analysis show regarding the overall efficacy of psychotherapy?",
                    "back": "The average therapy client is better off than 80% of untreated individuals.",
                    "concept_slugs": ["psyc-treatment-efficacy-meta-analysis"],
                },
            ],
        },
    ],
}
