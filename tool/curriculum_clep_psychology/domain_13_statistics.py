"""Domain 13.0: Statistics, Tests, and Measurement (Quota: 3 questions, 3–4% blueprint)."""
from __future__ import annotations

DOMAIN_13 = {
    "code": "13.0",
    "title": "Statistics, Tests, and Measurement",
    "description": "Descriptive statistics (central tendency, variability, normal curve), inferential statistics and statistical significance, correlation coefficients, psychometric reliability and validity, and theories and measurement of intelligence.",
    "weight": 0.030,
    "sort_order": 13,
    "importance": "core",
    "citation": "College Board CLEP Introductory Psychology Domain 13.0 (3–4%)",
    "objectives": [
        {
            "code": "13.1",
            "title": "Apply descriptive and inferential statistics, psychometric standards, and intelligence theories",
            "description": "Analyze measures of central tendency, variance, normal curve distributions, statistical significance, reliability, validity, and major theoretical models of human intelligence.",
            "sort_order": 1,
            "importance": "core",
            "citation": "College Board Objective 13.1",
            "concepts": [
                {
                    "slug": "psyc-descriptive-inferential-statistics",
                    "name": "Descriptive and Inferential Statistics",
                    "short_definition": "Quantitative tools for summarizing data distributions (central tendency, standard deviation, normal curve) and determining whether observed sample differences reflect true population effects (p < 0.05).",
                    "description": "Descriptive statistics characterize datasets using central tendency and dispersion. Inferential statistics use probability theory to test null hypotheses and establish statistical significance.",
                    "citation": "OpenStax Psychology 2e, Section 2.3",
                },
                {
                    "slug": "psyc-psychometric-reliability-validity",
                    "name": "Psychometric Reliability and Validity",
                    "short_definition": "Fundamental measurement criteria evaluating consistency (test-retest, split-half, alternate form, inter-rater reliability) and accuracy (content, criterion/predictive, construct validity).",
                    "description": "Reliability reflects score stability and reproducibility across administrations. Validity reflects whether an assessment genuinely measures the underlying construct it was designed to measure.",
                    "citation": "OpenStax Psychology 2e, Section 7.5",
                    "prerequisites": ["psyc-descriptive-inferential-statistics"],
                },
                {
                    "slug": "psyc-intelligence-theories-measurement",
                    "name": "Theories and Measurement of Intelligence",
                    "short_definition": "Theoretical models (Spearman's g, Gardner's multiple intelligences, Sternberg's triarchic theory) and psychometric tests (Stanford-Binet mental age, Wechsler deviation IQ).",
                    "description": "Intelligence assessment evolved from early ratio IQ (MA/CA * 100) to modern standardized deviation IQ distributions (mean 100, SD 15), alongside theoretical debates regarding general versus multifaceted cognitive abilities.",
                    "citation": "OpenStax Psychology 2e, Section 7.4 & 7.5",
                    "prerequisites": ["psyc-psychometric-reliability-validity"],
                },
            ],
            "lessons": [
                {
                    "title": "Statistical Measures, Psychometric Standards, and Intelligence Assessment",
                    "description": "Mastering central tendency, variance, the normal distribution, correlation vs. causation, reliability, validity, and intelligence measurement.",
                    "emoji": "📊",
                    "tags": ["statistics", "measurement", "reliability", "validity", "intelligence", "psychometrics"],
                    "concept_slugs": [
                        "psyc-descriptive-inferential-statistics",
                        "psyc-psychometric-reliability-validity",
                        "psyc-intelligence-theories-measurement",
                    ],
                    "citation": "OpenStax Psychology 2e, Chapter 2 (Research Methods) and Chapter 7 (Thinking and Intelligence)",
                    "blocks": [
                        {
                            "sort_order": 1,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### Descriptive Statistics: Central Tendency and Variability\n\n"
                                    "Psychological research relies on **descriptive statistics** to synthesize and organize raw quantitative observations into meaningful summaries. "
                                    "The three fundamental measures of **central tendency** are:\n\n"
                                    "- **Mean**: The arithmetic average of all scores (sum divided by $N$). The mean is highly sensitive to extreme outliers and skewed data.\n"
                                    "- **Median**: The exact physical midpoint score separating the top 50% from the bottom 50% when values are ranked. The median is the most robust measure in skewed distributions (such as annual income or reaction times).\n"
                                    "- **Mode**: The most frequently occurring score in the dataset. A distribution can be unimodal, bimodal, or multimodal.\n\n"
                                    "When a distribution is skewed, the mean is pulled farthest toward the extended tail. In a **positively skewed distribution** (skewed right, with a long tail of high scores), "
                                    "`Mode < Median < Mean`. In a **negatively skewed distribution** (skewed left, with a long tail of low scores), `Mean < Median < Mode`.\n\n"
                                    "Measures of **variability** describe how clustered or dispersed scores are around the center. The **range** is the distance between highest and lowest scores. "
                                    "The **standard deviation (SD, $\\sigma$)** calculates the average distance of each data point from the mean. A small standard deviation indicates homogeneous, clustered performance; "
                                    "a large standard deviation indicates heterogeneous, widely dispersed scores."
                                )
                            },
                        },
                        {
                            "sort_order": 2,
                            "block_type": "callout",
                            "content": {
                                "type": "warning",
                                "title": "Cognitive Pitfall: Reliability vs. Validity",
                                "body": "A psychometric test can be completely **reliable** (yielding identical results on every administration) while having **zero validity** (failing to measure what it claims to measure). For example, a scale that consistently adds 15 pounds is reliable, but invalid. However, a test **cannot be valid unless it is first reliable**.",
                            },
                        },
                        {
                            "sort_order": 3,
                            "block_type": "markdown",
                            "content": {
                                "text": (
                                    "### The Normal Curve and Psychometric Properties\n\n"
                                    "Many human biological and psychological characteristics conform to a symmetrical, bell-shaped **normal distribution**. "
                                    "In a standard normal curve, the mean, median, and mode are identical, and score dispersion follows the empirical **68-95-99.7 rule**:\n\n"
                                    "- **68.26%** of all observations fall within $\\pm 1$ standard deviation of the mean.\n"
                                    "- **95.44%** fall within $\\pm 2$ standard deviations of the mean.\n"
                                    "- **99.74%** fall within $\\pm 3$ standard deviations of the mean.\n\n"
                                    "Scientific test construction demands rigorous validation across both reliability (consistency) and validity (truthfulness/accuracy):\n\n"
                                    "| Psychometric Property | Specific Evaluation Type | Operational Definition | Clinical / Experimental Example |\n"
                                    "| :--- | :--- | :--- | :--- |\n"
                                    "| **Reliability** | **Test-Retest** | Consistency of scores when the same assessment is taken at two separate time points | Administering a trait extraversion inventory two weeks apart ($r \\ge +0.85$) |\n"
                                    "| **Reliability** | **Split-Half** | Internal consistency between odd-numbered and even-numbered items within the test | Correlating score performance across halves of a 100-item math diagnostic exam |\n"
                                    "| **Reliability** | **Inter-Rater** | Level of statistical agreement between independent clinical observers/judges | Two clinical psychologists independently scoring diagnostic interviews for autism |\n"
                                    "| **Validity** | **Content Validity** | Extent to which the items thoroughly sample the entire conceptual domain | A psychology final exam that comprehensively evaluates all 13 textbook chapters |\n"
                                    "| **Validity** | **Predictive (Criterion)** | Capacity of test scores to accurately forecast future relevant performance | High MCAT entrance exam scores predicting success in medical school coursework |\n"
                                    "| **Validity** | **Construct Validity** | Degree to which the test truly measures the theoretical, unobservable psychological attribute | Demonstrating a depression questionnaire correlates with elevated cortisol and clinical despair |"
                                )
                            },
                        },
                        {
                            "sort_order": 4,
                            "block_type": "callout",
                            "content": {
                                "type": "key_concept",
                                "title": "Theories of Intelligence and Deviation IQ",
                                "body": "Early intelligence testing pioneered by Alfred Binet used **mental age** ($MA$). William Stern formulated the ratio IQ: $IQ = (MA / CA) \\times 100$. Modern tests like David Wechsler's **WAIS** and **WISC** abandoned ratio IQ in favor of **deviation IQ**, standardizing performance against representative age cohorts with a fixed mean of 100 and standard deviation of 15. In theory, **Charles Spearman** posited a general cognitive factor ($g$); **Howard Gardner** proposed eight independent multiple intelligences; and **Robert Sternberg** formulated the triarchic theory (analytical, creative, and practical intelligence).",
                            },
                        },
                        {
                            "sort_order": 5,
                            "block_type": "example",
                            "content": {
                                "title": "Applied Case Scenario: Standardized Examination Score Interpretation",
                                "text": (
                                    "A school psychologist evaluates 1,000 high school students on a newly standardized cognitive reasoning inventory. "
                                    "The exam is normally distributed with a mean ($\\mu$) of 100 and a standard deviation ($\\sigma$) of 15.\n\n"
                                    "- **Student A** scores 115 (+1 SD above the mean). By applying the 68-95-99.7 rule, 50% score below the mean and 34.1% fall between the mean and +1 SD, meaning Student A scored higher than approximately 84% of test takers.\n"
                                    "- **Student B** scores 130 (+2 SD above the mean). Scoring higher than approximately 97.5% of test takers, placing Student B in the top 2.5% of the population.\n"
                                    "- When the 1,000 students retake an alternate form 30 days later, the Pearson correlation coefficient between test administrations is $r = +0.94$, demonstrating exceptional test-retest reliability."
                                ),
                            },
                        },
                    ],
                    "terms": [
                        {
                            "term": "Standard Deviation",
                            "definition": "A computed measure of how much scores vary around the mean score in a distribution, establishing data dispersion.",
                            "example": "On the WAIS intelligence test, a standard deviation of 15 indicates that scores between 85 and 115 represent normal average cognitive performance.",
                        },
                        {
                            "term": "Statistical Significance",
                            "definition": "A statistical criterion indicating that the observed experimental effect or difference is unlikely to have arisen by random chance alone, conventionally set at p < 0.05.",
                            "example": "A novel psychotherapy demonstrating symptom reduction with p = 0.01, indicating only a 1% probability of observing such results under the null hypothesis.",
                        },
                        {
                            "term": "Construct Validity",
                            "definition": "The extent to which an operational test or measurement tool accurately captures the underlying theoretical, unobservable psychological attribute it was designed to evaluate.",
                            "example": "Demonstrating that an anxiety questionnaire correlates with physiological galvanic skin conductance and validated psychiatric clinical ratings.",
                        },
                        {
                            "term": "Deviation IQ",
                            "definition": "An intelligence score derived statistically by positioning an individual's performance on a normal distribution of age peers, centered at a mean of 100 with a standard deviation of 15.",
                            "example": "An adult achieving a WAIS score of 130 performs two standard deviations above the population mean, placing them in the 98th percentile.",
                        },
                    ],
                    "assessment_items": [
                        {
                            "prompt": "On a standardized intelligence test with a normal distribution, a mean of 100, and a standard deviation of 15, approximately what percentage of test takers will obtain a score between 85 and 115?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "34 percent",
                                    "68 percent",
                                    "95 percent",
                                    "99.7 percent",
                                ]
                            },
                            "scoring_spec": {"correct_index": 1},
                            "explanation": "According to the empirical 68-95-99.7 rule for a normal bell curve, approximately 68% of all scores fall within one standard deviation of the mean (between -1 SD and +1 SD, or 85 to 115). Approximately 95% fall within two standard deviations (70 to 130), and 99.7% fall within three standard deviations (55 to 145).",
                            "difficulty": "intermediate",
                            "cognitive_level": "comprehension",
                            "citation": "OpenStax Psychology 2e, Section 7.5",
                            "concept_slugs": [
                                "psyc-descriptive-inferential-statistics",
                                "psyc-intelligence-theories-measurement",
                            ],
                        },
                        {
                            "prompt": "A clinical researcher develops a new screening tool for generalized anxiety disorder. Administering the assessment to the same cohort on two consecutive weeks yields nearly identical scores (r = +0.92), but the test fails to distinguish individuals with diagnosed anxiety from individuals without anxiety symptoms. Which psychometric statement accurately characterizes this assessment?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "The assessment possesses high predictive validity but low test-retest reliability.",
                                    "The assessment possesses high face validity but low split-half reliability.",
                                    "The assessment possesses low construct validity and low inter-rater reliability.",
                                    "The assessment possesses high test-retest reliability but low construct validity.",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "The correlation of r = +0.92 across consecutive administrations demonstrates high test-retest reliability (consistent measurement over time). However, because the tool fails to discriminate individuals with the target clinical condition from healthy controls, it fails to measure the theoretical psychological construct it claims to assess, reflecting low construct validity.",
                            "difficulty": "advanced",
                            "cognitive_level": "analysis",
                            "citation": "OpenStax Psychology 2e, Section 7.5",
                            "concept_slugs": ["psyc-psychometric-reliability-validity"],
                        },
                        {
                            "prompt": "In an experimental drug trial evaluating a novel antidepressant, the researchers obtain a p-value of 0.02 on depressive symptom reduction. What does this inferential statistical finding indicate?",
                            "interaction_type": "single_choice",
                            "response_spec": {
                                "options": [
                                    "The experimental drug completely eliminated symptoms in exactly ninety-eight percent of the clinical trial participants.",
                                    "The observed improvement demonstrates an overwhelmingly large clinical treatment effect across all tested demographics.",
                                    "The probability that the experimental compound has no biochemical efficacy in the broader population is exactly two percent.",
                                    "The likelihood of observing a difference of this magnitude by chance alone under the null hypothesis is less than five percent.",
                                ]
                            },
                            "scoring_spec": {"correct_index": 3},
                            "explanation": "A p-value of 0.02 is below the conventional alpha threshold of 0.05, indicating statistical significance. This means there is only a 2% probability that the observed difference between the experimental and control groups occurred by chance alone assuming the null hypothesis (no true drug effect) is true. It does not measure effect size, percent of cured patients, or clinical magnitude.",
                            "difficulty": "advanced",
                            "cognitive_level": "application",
                            "citation": "OpenStax Psychology 2e, Section 2.3",
                            "concept_slugs": ["psyc-descriptive-inferential-statistics"],
                        },
                    ],
                },
            ],
        },
    ],
}
