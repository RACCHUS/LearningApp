import 'learning_strategy.dart';

/// Official blueprint domain entry with published range and internal normalized weight.
class OfficialDomainBlueprint {
  final String domainId;
  final int domainNumber;
  final String title;
  final String publishedWeightRangeLabel;
  final double rawMidpointWeight;
  final double normalizedModelWeight;
  final String familyId;

  const OfficialDomainBlueprint({
    required this.domainId,
    required this.domainNumber,
    required this.title,
    required this.publishedWeightRangeLabel,
    required this.rawMidpointWeight,
    required this.normalizedModelWeight,
    required this.familyId,
  });
}

/// Vocabulary card surfaced in 15-minute and 30-minute Overview projections.
class OverviewVocabularyCard {
  final String term;
  final String plainMeaning;
  final String whyItMatters;
  final String familyId;

  const OverviewVocabularyCard({
    required this.term,
    required this.plainMeaning,
    required this.whyItMatters,
    required this.familyId,
  });
}

/// Optional transient comprehension self-check surfaced in 30-minute Overview.
///
/// Responses are never persisted to `learning_events`, `user_concept_state`,
/// or FSRS scheduling tables.
class OverviewComprehensionCheck {
  final String id;
  final String familyId;
  final String prompt;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;

  const OverviewComprehensionCheck({
    required this.id,
    required this.familyId,
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
  });
}

/// One of the 5–7 reviewed learner-facing topic families in an [OverviewOutline].
///
/// The same authored family supports 5-minute, 15-minute, and 30-minute
/// progressive disclosure without changing the underlying outline structure.
class OverviewFamily {
  final String id;
  final int order;
  final String title;
  final List<String> officialDomainIds;
  final String publishedShareSummary;
  final String fiveMinuteTakeaway;
  final String fifteenMinuteExplanation;
  final List<String> keyDistinctions;
  final String commonMisconception;
  final String thirtyMinuteRealWorldApplication;
  final String thirtyMinuteConnectionNotes;
  final List<OverviewVocabularyCard> vocabularyCards;
  final List<OverviewComprehensionCheck> comprehensionChecks;
  final List<String> linkedLessonSlugs;

  const OverviewFamily({
    required this.id,
    required this.order,
    required this.title,
    required this.officialDomainIds,
    required this.publishedShareSummary,
    required this.fiveMinuteTakeaway,
    required this.fifteenMinuteExplanation,
    required this.keyDistinctions,
    required this.commonMisconception,
    required this.thirtyMinuteRealWorldApplication,
    required this.thirtyMinuteConnectionNotes,
    required this.vocabularyCards,
    this.comprehensionChecks = const [],
    this.linkedLessonSlugs = const [],
  });
}

/// Explicit provenance and source verification metadata (`TEL-00`, `TEL-02A`).
class OverviewProvenance {
  final String sourceOrganization;
  final String blueprintSummary;
  final String openTextbookAttribution;
  final String openTextbookLicense;
  final String openTextbookUrl;
  final SourceVerificationLevel verificationLevel;
  final String verificationDisclosure;

  const OverviewProvenance({
    required this.sourceOrganization,
    required this.blueprintSummary,
    required this.openTextbookAttribution,
    required this.openTextbookLicense,
    required this.openTextbookUrl,
    required this.verificationLevel,
    required this.verificationDisclosure,
  });
}

/// Complete single-outline subject overview model (`TEL-02A`).
class OverviewOutline {
  final String id;
  final String targetId;
  final String targetSlug;
  final String title;
  final String subtitle;
  final String plainLanguagePremise;
  final List<String> centralQuestions;
  final List<OfficialDomainBlueprint> officialDomains;
  final List<OverviewFamily> families;
  final List<String> omittedOrDeferredNotes;
  final OverviewProvenance provenance;

  const OverviewOutline({
    required this.id,
    required this.targetId,
    required this.targetSlug,
    required this.title,
    required this.subtitle,
    required this.plainLanguagePremise,
    required this.centralQuestions,
    required this.officialDomains,
    required this.families,
    required this.omittedOrDeferredNotes,
    required this.provenance,
  });
}

/// Official 13 CLEP Introductory Psychology blueprint domains with published
/// College Board topic weight ranges and normalized internal model weights
/// (midpoint sum = 1.015, normalized to 1.0000; see TEL v0.5 §3.1).
const List<OfficialDomainBlueprint> clepPsychologyOfficialDomains = [
  OfficialDomainBlueprint(
    domainId: '1.0',
    domainNumber: 1,
    title: 'History, Approaches, and Methods',
    publishedWeightRangeLabel: '11–12%',
    rawMidpointWeight: 0.115,
    normalizedModelWeight: 0.1133,
    familyId: 'family-1-foundations-methods',
  ),
  OfficialDomainBlueprint(
    domainId: '2.0',
    domainNumber: 2,
    title: 'Biological Bases of Behavior',
    publishedWeightRangeLabel: '8–9%',
    rawMidpointWeight: 0.085,
    normalizedModelWeight: 0.0837,
    familyId: 'family-2-brain-senses-awareness',
  ),
  OfficialDomainBlueprint(
    domainId: '3.0',
    domainNumber: 3,
    title: 'Sensation and Perception',
    publishedWeightRangeLabel: '7–8%',
    rawMidpointWeight: 0.075,
    normalizedModelWeight: 0.0739,
    familyId: 'family-2-brain-senses-awareness',
  ),
  OfficialDomainBlueprint(
    domainId: '4.0',
    domainNumber: 4,
    title: 'States of Consciousness',
    publishedWeightRangeLabel: '5–6%',
    rawMidpointWeight: 0.055,
    normalizedModelWeight: 0.0542,
    familyId: 'family-2-brain-senses-awareness',
  ),
  OfficialDomainBlueprint(
    domainId: '5.0',
    domainNumber: 5,
    title: 'Learning',
    publishedWeightRangeLabel: '8–9%',
    rawMidpointWeight: 0.085,
    normalizedModelWeight: 0.0837,
    familyId: 'family-3-learning-thinking',
  ),
  OfficialDomainBlueprint(
    domainId: '6.0',
    domainNumber: 6,
    title: 'Cognition',
    publishedWeightRangeLabel: '8–9%',
    rawMidpointWeight: 0.085,
    normalizedModelWeight: 0.0837,
    familyId: 'family-3-learning-thinking',
  ),
  OfficialDomainBlueprint(
    domainId: '7.0',
    domainNumber: 7,
    title: 'Motivation and Emotion',
    publishedWeightRangeLabel: '7–8%',
    rawMidpointWeight: 0.075,
    normalizedModelWeight: 0.0739,
    familyId: 'family-4-drives-feelings',
  ),
  OfficialDomainBlueprint(
    domainId: '8.0',
    domainNumber: 8,
    title: 'Developmental Psychology across the Lifespan',
    publishedWeightRangeLabel: '8–9%',
    rawMidpointWeight: 0.085,
    normalizedModelWeight: 0.0837,
    familyId: 'family-5-growth-personality',
  ),
  OfficialDomainBlueprint(
    domainId: '9.0',
    domainNumber: 9,
    title: 'Personality',
    publishedWeightRangeLabel: '7–8%',
    rawMidpointWeight: 0.075,
    normalizedModelWeight: 0.0739,
    familyId: 'family-5-growth-personality',
  ),
  OfficialDomainBlueprint(
    domainId: '10.0',
    domainNumber: 10,
    title: 'Psychological Disorders and Psychopathology',
    publishedWeightRangeLabel: '8–9%',
    rawMidpointWeight: 0.085,
    normalizedModelWeight: 0.0837,
    familyId: 'family-6-mental-health-treatment',
  ),
  OfficialDomainBlueprint(
    domainId: '11.0',
    domainNumber: 11,
    title: 'Treatment of Psychological Disorders',
    publishedWeightRangeLabel: '6–7%',
    rawMidpointWeight: 0.065,
    normalizedModelWeight: 0.0640,
    familyId: 'family-6-mental-health-treatment',
  ),
  OfficialDomainBlueprint(
    domainId: '12.0',
    domainNumber: 12,
    title: 'Social Psychology',
    publishedWeightRangeLabel: '7–8%',
    rawMidpointWeight: 0.075,
    normalizedModelWeight: 0.0739,
    familyId: 'family-7-people-together',
  ),
  OfficialDomainBlueprint(
    domainId: '13.0',
    domainNumber: 13,
    title: 'Statistics, Tests, and Measurements',
    publishedWeightRangeLabel: '5–6%',
    rawMidpointWeight: 0.055,
    normalizedModelWeight: 0.0542,
    familyId: 'family-1-foundations-methods',
  ),
];

/// Reviewed CLEP Introductory Psychology 7-family Overview outline (`TEL-02A`).
const OverviewOutline clepPsychologyOverviewOutline = OverviewOutline(
  id: 'overview-clep-introductory-psychology-v1',
  targetId: 'a0000000-0000-0000-0000-000000000001',
  targetSlug: 'clep-introductory-psychology',
  title: 'CLEP Introductory Psychology',
  subtitle: 'Get oriented in minutes across all 13 official exam topic areas',
  plainLanguagePremise:
      'Psychology is the empirical study of how biological systems, mental processes, development, and social contexts interact to shape behavior and experience—and how researchers test those claims without being fooled by intuition.',
  centralQuestions: [
    'How do psychologists test claims about behavior using experiments, correlations, and measurement?',
    'How do neural signaling, sensory transduction, perception, and sleep/waking states turn physical energy into conscious experience?',
    'How do organisms adapt through conditioning, memory encoding/retrieval, problem solving, and biological/emotional drives?',
    'How do people develop across the lifespan, form stable personality patterns, respond to psychological disorders, and influence one another in groups?',
  ],
  officialDomains: clepPsychologyOfficialDomains,
  families: [
    OverviewFamily(
      id: 'family-1-foundations-methods',
      order: 1,
      title: 'Foundations and method',
      officialDomainIds: ['1.0', '13.0'],
      publishedShareSummary: '~16–18% combined published range (Domains 1 & 13)',
      fiveMinuteTakeaway:
          'Psychologists use distinct theoretical lenses (behavioral, cognitive, biological, psychodynamic, humanistic, sociocultural) and rigorous research designs to separate causal evidence from mere correlation.',
      fifteenMinuteExplanation:
          'Only true experiments—where researchers manipulate an independent variable, measure a dependent variable, and use random assignment—can establish cause and effect. Correlational studies measure how two variables co-vary (-1.00 to +1.00) when manipulation is unethical or impossible. Good psychological measurement requires both reliability (consistency) and validity (measuring what is intended), alongside ethical safeguards (informed consent, debriefing, IRB review).',
      keyDistinctions: [
        'Independent Variable (manipulated cause) vs. Dependent Variable (measured outcome)',
        'Random Sampling (generalizing to a population) vs. Random Assignment (equalizing experimental groups for causality)',
        'Reliability (repeatability) vs. Validity (accuracy of construct measurement)',
      ],
      commonMisconception:
          'A strong correlation (e.g., r = -0.85 or +0.85) does not prove one variable causes the other, and the sign (+ or -) indicates direction rather than strength.',
      thirtyMinuteRealWorldApplication:
          'When evaluating a headline claiming that screen time causes anxiety, check whether participants were randomly assigned to screen-time conditions or merely surveyed at one point in time (where reverse causality or a third variable like sleep loss could explain the link).',
      thirtyMinuteConnectionNotes:
          'Every subsequent topic area—from drug trials in biological psychology to therapy outcome studies in clinical psychology—relies on double-blind experimental controls and statistical significance.',
      vocabularyCards: [
        OverviewVocabularyCard(
          term: 'Operational definition',
          plainMeaning:
              'A concrete, measurable specification of how a research variable is manipulated or recorded.',
          whyItMatters:
              'Allows other scientists to replicate a study and prevents vague constructs like "stress" or "aggression" from being scored subjectively.',
          familyId: 'family-1-foundations-methods',
        ),
        OverviewVocabularyCard(
          term: 'Confounding variable',
          plainMeaning:
              'An unmeasured third factor that varies alongside the independent variable and clouds causal conclusions.',
          whyItMatters:
              'Random assignment is the primary tool used in experiments to distribute potential confounds evenly across groups.',
          familyId: 'family-1-foundations-methods',
        ),
      ],
      comprehensionChecks: [
        OverviewComprehensionCheck(
          id: 'ov-check-1',
          familyId: 'family-1-foundations-methods',
          prompt:
              'Which correlation coefficient indicates the strongest predictive relationship between two variables?',
          options: ['+0.68', '-0.84', '+0.12', '-0.45'],
          correctOptionIndex: 1,
          explanation:
              'Correlation strength depends on absolute magnitude (distance from 0 toward 1.00). |-0.84| is larger than |+0.68|.',
        ),
      ],
      linkedLessonSlugs: [
        'history-and-approaches',
        'research-methods',
        'statistics-and- ethics',
      ],
    ),
    OverviewFamily(
      id: 'family-2-brain-senses-awareness',
      order: 2,
      title: 'Brain, senses and awareness',
      officialDomainIds: ['2.0', '3.0', '4.0'],
      publishedShareSummary: '~20–23% combined published range (Domains 2, 3 & 4)',
      fiveMinuteTakeaway:
          'Electrochemical signaling in neurons, specialized brain structures, sensory receptors, and perceptual organization work together to construct our waking and sleeping awareness.',
      fifteenMinuteExplanation:
          'Neurons fire all-or-none action potentials down their axons and release neurotransmitters across synapses (agonists amplify; antagonists block). The central nervous system coordinates reflexes and higher processing across brainstem, limbic (amygdala, hippocampus, hypothalamus), and cerebral cortex lobes (frontal, parietal, occipital, temporal). Sensation transduces physical stimuli into neural signals (governed by absolute and difference thresholds), whereas perception applies top-down expectations and Gestalt principles. Consciousness shifts predictably across circadian rhythms, NREM stages, and REM sleep.',
      keyDistinctions: [
        'Sympathetic (arousing fight-or-flight) vs. Parasympathetic (calming rest-and-digest) nervous systems',
        'Bottom-Up Processing (sensory receptor data) vs. Top-Down Processing (prior knowledge & expectations)',
        'Agonist (mimics/enhances neurotransmitter) vs. Antagonist (blocks receptor or release)',
      ],
      commonMisconception:
          'A stronger stimulus does not make a single neuron fire a larger action potential; instead, it increases firing frequency and recruits more neurons (all-or-none law).',
      thirtyMinuteRealWorldApplication:
          'Understanding why patients with hippocampal damage can learn new motor skills (procedural memory via cerebellum/basal ganglia) while failing to form new conscious episodic memories.',
      thirtyMinuteConnectionNotes:
          'Neurotransmitter pathways here (dopamine, serotonin, GABA, norepinephrine) directly underpin pharmacological treatments in Domain 11 and substance tolerance/withdrawal in Domain 4.',
      vocabularyCards: [
        OverviewVocabularyCard(
          term: 'Transduction',
          plainMeaning:
              'Conversion of physical energy (light waves, sound pressure, chemical molecules) into neural impulses.',
          whyItMatters:
              'Marks the boundary where physical sensation enters the nervous system (e.g., rods/cones in the retina, hair cells in the cochlea).',
          familyId: 'family-2-brain-senses-awareness',
        ),
        OverviewVocabularyCard(
          term: 'Selective attention',
          plainMeaning:
              'Focusing conscious awareness on a narrow slice of stimuli while filtering out competing inputs.',
          whyItMatters:
              'Explains both the cocktail party effect and inattentional blindness when multitasking.',
          familyId: 'family-2-brain-senses-awareness',
        ),
      ],
      comprehensionChecks: [
        OverviewComprehensionCheck(
          id: 'ov-check-2',
          familyId: 'family-2-brain-senses-awareness',
          prompt:
              'Damage to Wernicke’s area in the left temporal lobe most directly impairs which ability?',
          options: [
            'Comprehending spoken and written language meaning',
            'Coordinating fine voluntary finger movements',
            'Regulating basic hunger and body temperature drives',
            'Transducing light waves into neural signals in the retina',
          ],
          correctOptionIndex: 0,
          explanation:
              'Wernicke’s area supports language comprehension; Broca’s area in the left frontal lobe directs speech production.',
        ),
      ],
      linkedLessonSlugs: [
        'neurons-and-neurotransmitters',
        'brain-structure-and-function',
        'sensation-and-perception',
        'states-of-consciousness',
      ],
    ),
    OverviewFamily(
      id: 'family-3-learning-thinking',
      order: 3,
      title: 'Learning and thinking',
      officialDomainIds: ['5.0', '6.0'],
      publishedShareSummary: '~16–18% combined published range (Domains 5 & 6)',
      fiveMinuteTakeaway:
          'Experience changes behavior through associative conditioning and observation, while cognitive systems encode, store, retrieve, and transform information using concepts and heuristics.',
      fifteenMinuteExplanation:
          'Classical conditioning (Pavlov, Watson, Rescorla) pairs a neutral stimulus with an unconditioned stimulus until it becomes a conditioned stimulus eliciting a conditioned response. Operant conditioning (Thorndike, Skinner) shapes voluntary behavior through reinforcement (which increases behavior) and punishment (which decreases behavior) on fixed or variable schedules. Observational learning (Bandura) occurs via modeling without direct reinforcement. In cognition, information moves through sensory, working, and long-term memory, where retrieval cues help overcome proactive/retroactive interference, and heuristics speed decisions at the cost of predictable biases.',
      keyDistinctions: [
        'Negative Reinforcement (removing an aversive stimulus to INCREASE behavior) vs. Punishment (decreasing behavior)',
        'Variable-Ratio Schedule (highest, most extinction-resistant response rate) vs. Fixed-Interval Schedule (scalloped response pattern)',
        'Availability Heuristic (judging likelihood by ease of recall) vs. Representativeness Heuristic (judging by prototype similarity)',
      ],
      commonMisconception:
          'Negative reinforcement is NOT punishment; taking aspirin to relieve a headache negatively reinforces aspirin-taking because removing pain increases the future likelihood of taking aspirin.',
      thirtyMinuteRealWorldApplication:
          'Designing study habits around spaced retrieval practice, deep semantic encoding, and context cues rather than passive rereading.',
      thirtyMinuteConnectionNotes:
          'Conditioning and cognitive appraisal principles directly inform behavioral and cognitive-behavioral therapies (CBT) in Domain 11.',
      vocabularyCards: [
        OverviewVocabularyCard(
          term: 'Negative reinforcement',
          plainMeaning:
              'Strengthening a behavior by removing or avoiding an unpleasant stimulus after the behavior occurs.',
          whyItMatters:
              'One of the most frequently tested distinctions in CLEP Psychology; explains escape and avoidance learning.',
          familyId: 'family-3-learning-thinking',
        ),
        OverviewVocabularyCard(
          term: 'Proactive vs. retroactive interference',
          plainMeaning:
              'Proactive: old memories block new ones; Retroactive: new learning disrupts recall of older memories.',
          whyItMatters:
              'Explains why studying similar material back-to-back can impair recall of earlier or later lists.',
          familyId: 'family-3-learning-thinking',
        ),
      ],
      comprehensionChecks: [
        OverviewComprehensionCheck(
          id: 'ov-check-3',
          familyId: 'family-3-learning-thinking',
          prompt:
              'Fastening your seatbelt to stop a car’s annoying warning chime makes you more likely to buckle up in the future. This is an example of:',
          options: [
            'Positive punishment',
            'Negative punishment',
            'Negative reinforcement',
            'Classical extinction',
          ],
          correctOptionIndex: 2,
          explanation:
              'Buckling up removes an aversive stimulus (the chime) and increases future seatbelt use—the definition of negative reinforcement.',
        ),
      ],
      linkedLessonSlugs: [
        'classical-conditioning',
        'operant-and-observational-learning',
        'memory',
        'thinking-language-and-intelligence',
      ],
    ),
    OverviewFamily(
      id: 'family-4-drives-feelings',
      order: 4,
      title: 'Drives and feelings',
      officialDomainIds: ['7.0'],
      publishedShareSummary: '~7–8% published range (Domain 7)',
      fiveMinuteTakeaway:
          'Biological homeostasis, optimal arousal, cognitive incentives, and physiological/cognitive appraisals interact to energize behavior and produce emotional experience.',
      fifteenMinuteExplanation:
          'No single theory explains all motivation: drive-reduction theory focuses on homeostatic balance (hunger, thirst), arousal theory (Yerkes-Dodson law) shows performance peaks at moderate arousal, incentive theory highlights external pulls, and self-determination theory contrasts intrinsic vs. extrinsic motivation. Emotion theories debate the sequence of physiological arousal and conscious cognitive labeling: James-Lange (arousal precedes emotion), Cannon-Bard (simultaneous), and Schachter-Singer two-factor theory (arousal + cognitive label).',
      keyDistinctions: [
        'Intrinsic Motivation (internal satisfaction) vs. Overjustification Effect (extrinsic rewards crowding out intrinsic interest)',
        'James-Lange ("I feel afraid because I tremble") vs. Schachter-Singer Two-Factor (arousal + situational cognitive appraisal)',
      ],
      commonMisconception:
          'Adding external rewards to an already enjoyable activity does not always boost long-term motivation; it can trigger the overjustification effect and reduce intrinsic drive once rewards stop.',
      thirtyMinuteRealWorldApplication:
          'Recognizing how Hans Selye’s General Adaptation Syndrome (alarm, resistance, exhaustion) links chronic HPA-axis cortisol elevation to immune suppression.',
      thirtyMinuteConnectionNotes:
          'Hypothalamic regulation and autonomic arousal connect Biological Bases (Domain 2) with anxiety and stress disorders (Domain 10).',
      vocabularyCards: [
        OverviewVocabularyCard(
          term: 'Yerkes-Dodson law',
          plainMeaning:
              'Performance increases with physiological or mental arousal only up to an optimal point, after which excessive arousal impairs performance.',
          whyItMatters:
              'Simple or well-practiced tasks tolerate higher arousal, whereas complex or novel tasks peak at lower arousal.',
          familyId: 'family-4-drives-feelings',
        ),
      ],
      comprehensionChecks: [],
      linkedLessonSlugs: [
        'motivation',
        'emotion-and-stress',
      ],
    ),
    OverviewFamily(
      id: 'family-5-growth-personality',
      order: 5,
      title: 'Growth and personality',
      officialDomainIds: ['8.0', '9.0'],
      publishedShareSummary: '~15–17% combined published range (Domains 8 & 9)',
      fiveMinuteTakeaway:
          'Human cognitive, social, and moral capacities unfold across the lifespan, while enduring personality patterns are explained through psychodynamic, trait, humanistic, and social-cognitive frameworks.',
      fifteenMinuteExplanation:
          'Developmental psychology tracks physical maturation, Piaget’s cognitive stages (sensorimotor object permanence, preoperational conservation limits, concrete operational logic, formal operational abstraction), Vygotsky’s scaffolding, Ainsworth’s attachment styles, Baumrind’s parenting styles, Erikson’s eight psychosocial crises, and Kohlberg’s moral reasoning levels. Personality psychology compares Freud’s unconscious dynamics and defense mechanisms with the Big Five traits (OCEAN), Rogers/Maslow humanistic self-actualization, and Bandura’s reciprocal determinism and locus of control.',
      keyDistinctions: [
        'Assimilation (fitting new info into existing schemas) vs. Accommodation (revising schemas to fit new info)',
        'Authoritative Parenting (warm + structured limits) vs. Authoritarian Parenting (rigid obedience + low warmth)',
        'Cross-Sectional Study (different ages at one time; fast but cohort effects) vs. Longitudinal Study (same cohort over years)',
      ],
      commonMisconception:
          'Cross-sectional differences between 20-year-olds and 70-year-olds do not automatically reflect aging; they often reflect generational cohort differences.',
      thirtyMinuteRealWorldApplication:
          'Distinguishing self-efficacy (task-specific confidence) from self-esteem (global self-worth) when coaching learners through challenging skills.',
      thirtyMinuteConnectionNotes:
          'Trait measurement (MMPI, Big Five inventories) relies on psychometric standardization, reliability, and validity from Domain 13.',
      vocabularyCards: [
        OverviewVocabularyCard(
          term: 'Reciprocal determinism',
          plainMeaning:
              'Bandura’s principle that behavior, internal personal/cognitive factors, and environmental context continuously influence one another.',
          whyItMatters:
              'Bridges behavioral environmentalism and internal trait/cognitive models of personality.',
          familyId: 'family-5-growth-personality',
        ),
        OverviewVocabularyCard(
          term: 'Object permanence & conservation',
          plainMeaning:
              'Object permanence (sensorimotor): knowing unseen objects still exist; Conservation (concrete operational): knowing quantity stays constant despite shape changes.',
          whyItMatters:
              'Anchors Piaget’s stage transitions in developmental exam questions.',
          familyId: 'family-5-growth-personality',
        ),
      ],
      comprehensionChecks: [
        OverviewComprehensionCheck(
          id: 'ov-check-5',
          familyId: 'family-5-growth-personality',
          prompt:
              'A child who realizes that pouring water from a short, wide glass into a tall, thin glass does not change the amount of water has mastered:',
          options: [
            'Object permanence',
            'Conservation',
            'Stranger anxiety',
            'Postconventional morality',
          ],
          correctOptionIndex: 1,
          explanation:
              'Conservation of volume is a hallmark of Piaget’s concrete operational stage.',
        ),
      ],
      linkedLessonSlugs: [
        'lifespan-development-early',
        'lifespan-development-adolescence-adulthood',
        'personality-theories',
      ],
    ),
    OverviewFamily(
      id: 'family-6-mental-health-treatment',
      order: 6,
      title: 'Mental health and treatment',
      officialDomainIds: ['10.0', '11.0'],
      publishedShareSummary: '~14–16% combined published range (Domains 10 & 11)',
      fiveMinuteTakeaway:
          'Psychological disorders are classified by maladaptive distress and dysfunction (DSM-5-TR) and understood through the diathesis-stress / biopsychosocial model, guiding evidence-based psychotherapies and biomedical treatments.',
      fifteenMinuteExplanation:
          'Major diagnostic categories include anxiety disorders, OCD, PTSD, depressive and bipolar disorders, schizophrenia spectrum disorders (positive symptoms like hallucinations/delusions vs. negative symptoms like flat affect), dissociative, somatic, and personality disorders. Treatment modalities match mechanisms to symptoms: behavioral exposure/systematic desensitization for phobias and OCD, cognitive restructuring and CBT for mood/anxiety disorders, humanistic client-centered active listening, and biomedical interventions (SSRIs, mood stabilizers like lithium, antipsychotics, ECT).',
      keyDistinctions: [
        'Positive Symptoms of Schizophrenia (added abnormal behaviors like hallucinations) vs. Negative Symptoms (absence of normal function like avolition/flat affect)',
        'Systematic Desensitization (graduated exposure + relaxation) vs. Aversive Conditioning',
        'Obsessions (intrusive anxiety-provoking thoughts) vs. Compulsions (repetitive behaviors performed to neutralize anxiety)',
      ],
      commonMisconception:
          'Schizophrenia does NOT mean "split personality" (which is Dissociative Identity Disorder); it refers to a split from reality involving disorganized thought, perception, and affect.',
      thirtyMinuteRealWorldApplication:
          'Using the diathesis-stress model to explain why genetic vulnerability alone rarely determines disorder onset without environmental stressors.',
      thirtyMinuteConnectionNotes:
          'Combines neurotransmitter pharmacology (Domain 2), conditioning/extinction (Domain 5), and cognitive appraisal (Domain 6).',
      vocabularyCards: [
        OverviewVocabularyCard(
          term: 'Diathesis-stress model',
          plainMeaning:
              'Framework proposing that psychological disorders arise when an underlying biological or psychological predisposition (diathesis) interacts with stressful life events.',
          whyItMatters:
              'Explains why identical twins can be discordant for disorders despite shared genetics.',
          familyId: 'family-6-mental-health-treatment',
        ),
      ],
      comprehensionChecks: [],
      linkedLessonSlugs: [
        'psychological-disorders-part-1',
        'psychological-disorders-part-2',
        'treatment-of-psychological-disorders',
      ],
    ),
    OverviewFamily(
      id: 'family-7-people-together',
      order: 7,
      title: 'People together',
      officialDomainIds: ['12.0'],
      publishedShareSummary: '~7–8% published range (Domain 12)',
      fiveMinuteTakeaway:
          'Social situations, group norms, attribution biases, cognitive dissonance, and authority pressures powerfully shape individual attitudes and actions.',
      fifteenMinuteExplanation:
          'Social cognition examines how we explain behavior—often falling prey to the fundamental attribution error (overblaming others’ dispositions while excusing our own behavior via situational factors) and resolving Festinger’s cognitive dissonance when actions conflict with attitudes. Classic social influence research demonstrates normative and informational conformity (Asch), obedience to authority (Milgram), group polarization, groupthink, social loafing, social facilitation, and bystander diffusion of responsibility (Darley & Latané).',
      keyDistinctions: [
        'Fundamental Attribution Error (overestimating disposition in others) vs. Self-Serving Bias (crediting dispositions for success, situations for failure)',
        'Normative Social Influence (conforming to be liked/accepted) vs. Informational Social Influence (conforming to be accurate in ambiguous situations)',
        'Prejudice (unjustified attitude) vs. Discrimination (unjustified behavior)',
      ],
      commonMisconception:
          'In Festinger’s cognitive dissonance studies, participants paid a small reward ($1) to praise a boring task changed their private attitude MORE than those paid $20, because $1 provided insufficient external justification.',
      thirtyMinuteRealWorldApplication:
          'Preventing bystander apathy in emergencies by assigning responsibility to a specific individual rather than appealing to an anonymous crowd.',
      thirtyMinuteConnectionNotes:
          'Completes the biopsychosocial arc by showing how immediate social context overrides individual personality traits more often than intuition predicts.',
      vocabularyCards: [
        OverviewVocabularyCard(
          term: 'Fundamental attribution error',
          plainMeaning:
              'The tendency for observers, when analyzing another person’s behavior, to underestimate situational influences and overestimate personal disposition.',
          whyItMatters:
              'Core concept across attribution, prejudice, and interpersonal conflict questions.',
          familyId: 'family-7-people-together',
        ),
        OverviewVocabularyCard(
          term: 'Cognitive dissonance',
          plainMeaning:
              'Psychological discomfort caused by holding conflicting attitudes or acting in a way that contradicts one’s beliefs.',
          whyItMatters:
              'Drives attitude change when external justification for counter-attitudinal behavior is low.',
          familyId: 'family-7-people-together',
        ),
      ],
      comprehensionChecks: [
        OverviewComprehensionCheck(
          id: 'ov-check-7',
          familyId: 'family-7-people-together',
          prompt:
              'When a driver cuts you off in traffic, you immediately assume they are a reckless, selfish person rather than considering they might be rushing to an emergency. This illustrates:',
          options: [
            'Social facilitation',
            'The fundamental attribution error',
            'Informational social influence',
            'Deindividuation',
          ],
          correctOptionIndex: 1,
          explanation:
              'Overestimating internal personality traits while ignoring situational pressures in others’ behavior is the fundamental attribution error.',
        ),
      ],
      linkedLessonSlugs: [
        'social-thinking-and-influence',
        'social-relations-and-group-behavior',
      ],
    ),
  ],
  omittedOrDeferredNotes: [
    'This overview is a read-only orientation map and does not assess mastery or record study progress.',
    'Detailed experimental paradigms, full neurotransmitter receptor tables, DSM-5-TR diagnostic duration criteria, and statistical formula derivations are covered in the full curriculum lessons and practice items.',
    'Viewing this overview or completing optional self-check questions does not mark any domain as completed or ready for the exam.',
  ],
  provenance: OverviewProvenance(
    sourceOrganization: 'College Board CLEP & OpenStax',
    blueprintSummary:
        'Based on College Board’s published CLEP Introductory Psychology exam topic outline (13 topic areas; published percentage ranges sum to 95–108%).',
    openTextbookAttribution:
        'Adapted from OpenStax Psychology 2e by Rose M. Spielman, William J. Jenkins, and Marilyn D. Lovett (Rice University). Access for free at https://openstax.org/books/psychology-2e/pages/1-introduction',
    openTextbookLicense: 'Creative Commons Attribution 4.0 International (CC BY 4.0)',
    openTextbookUrl: 'https://openstax.org/books/psychology-2e/pages/1-introduction',
    verificationLevel: SourceVerificationLevel.unverifiedPlaceholder,
    verificationDisclosure:
        'Topic structure and published weight ranges are reviewed against the public CLEP Introductory Psychology outline. Raw source archive SHA-256 digests in the curriculum manifest are currently marked hash_unavailable / unverified_placeholder pending byte-level archive capture.',
  ),
);
