import 'package:flutter/material.dart';
import 'package:learning_core/learning_core.dart';
import '../../services/performance/performance_assessment_service.dart';

/// Interactive procedural checklist and rubric scoring widget (OPP-4, OPP-3).
class ProceduralRubricWidget extends StatefulWidget {
  final ProceduralRubricCore rubric;
  final String learnerId;
  final PerformanceAssessmentService? assessmentService;
  final void Function(PerformanceEvaluationResult result)? onAssessmentCompleted;

  const ProceduralRubricWidget({
    super.key,
    required this.rubric,
    required this.learnerId,
    this.assessmentService,
    this.onAssessmentCompleted,
  });

  @override
  State<ProceduralRubricWidget> createState() => _ProceduralRubricWidgetState();
}

class _ProceduralRubricWidgetState extends State<ProceduralRubricWidget> {
  late final PerformanceAssessmentService _service;
  final Map<String, int> _scores = {};
  final Map<String, String> _notes = {};
  PerformanceSignoffRole _selectedRole = PerformanceSignoffRole.selfAssessment;
  final TextEditingController _signatureController = TextEditingController();
  final TextEditingController _evaluatorNotesController = TextEditingController();
  PerformanceEvaluationResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _service = widget.assessmentService ?? PerformanceAssessmentService();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _evaluatorNotesController.dispose();
    super.dispose();
  }

  void _setScore(String criterionId, int score) {
    setState(() {
      _scores[criterionId] = score;
    });
  }

  List<RubricStepEvaluation> _buildStepEvaluations() {
    return widget.rubric.criteria.map((c) {
      final score = _scores[c.id] ?? 0;
      final isCrit = c.isCritical;
      final critFailed = isCrit && score == 0;
      return RubricStepEvaluation(
        criterionId: c.id,
        score: score,
        isCompleted: _scores.containsKey(c.id),
        notes: _notes[c.id],
        criticalFailed: critFailed,
      );
    }).toList();
  }

  void _submitAssessment() {
    final stepEvals = _buildStepEvaluations();
    final result = _service.recordAttempt(
      rubric: widget.rubric,
      learnerId: widget.learnerId,
      role: _selectedRole,
      stepEvaluations: stepEvals,
      elapsedSeconds: 240,
      evaluatorNotes: _evaluatorNotesController.text.trim().isNotEmpty
          ? _evaluatorNotesController.text.trim()
          : null,
      evaluatorSignature: _signatureController.text.trim().isNotEmpty
          ? _signatureController.text.trim()
          : null,
    );

    setState(() {
      _lastResult = result;
    });

    widget.onAssessmentCompleted?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentEvals = _buildStepEvaluations();
    final liveEvaluation = ProceduralEvaluatorCore.evaluate(
      rubric: widget.rubric,
      stepEvaluations: currentEvals,
    );

    return SingleChildScrollView(
      key: Key('procedural_rubric_${widget.rubric.id}'),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.rubric.targetDomain.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Pass Threshold: ${(widget.rubric.passingScorePercentage * 100).toInt()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.rubric.title,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (widget.rubric.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(widget.rubric.description, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Live Scoring & Critical Fail Alert
          if (liveEvaluation.criticalFailEncountered)
            Container(
              key: const Key('critical_failure_alert'),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent, width: 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AUTOMATIC CRITICAL FAILURE TRIGGERED',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A critical clinical/safety step was failed or omitted. '
                          'Per delivery rule § 7.1, the candidate cannot pass this assessment regardless of points scored.',
                          style: TextStyle(color: Colors.red.shade100, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Steps list
          Text(
            'Operational Steps & Evaluation Criteria',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...widget.rubric.criteria.map((c) => _buildCriterionCard(context, c)),

          const SizedBox(height: 16),

          // Sign-Off & Role Selection Section
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assessment Sign-Off (OPP-4)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<PerformanceSignoffRole>(
                    segments: const [
                      ButtonSegment(
                        value: PerformanceSignoffRole.selfAssessment,
                        label: Text('Self-Check'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment(
                        value: PerformanceSignoffRole.peerReview,
                        label: Text('Peer'),
                        icon: Icon(Icons.group),
                      ),
                      ButtonSegment(
                        value: PerformanceSignoffRole.evaluatorSignoff,
                        label: Text('Evaluator'),
                        icon: Icon(Icons.verified_user),
                      ),
                    ],
                    selected: {_selectedRole},
                    onSelectionChanged: (set) {
                      setState(() {
                        _selectedRole = set.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('evaluator_signature_field'),
                    controller: _signatureController,
                    decoration: const InputDecoration(
                      labelText: 'Observer / Evaluator Signature',
                      hintText: 'e.g. Jane Doe, RN or Certified Preceptor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Score: ${liveEvaluation.totalEarnedScore.toStringAsFixed(1)} / ${liveEvaluation.maxPossibleScore.toStringAsFixed(1)} (${(liveEvaluation.scorePercentage * 100).toInt()}%)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: liveEvaluation.passed ? Colors.green : Colors.red,
                              ),
                            ),
                            Text(
                              liveEvaluation.passed ? 'STATUS: PASS' : 'STATUS: NOT PASSING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: liveEvaluation.passed ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        key: const Key('submit_assessment_button'),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Complete Assessment'),
                        onPressed: _submitAssessment,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_lastResult != null) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('assessment_completed_banner'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _lastResult!.passed ? Colors.green.shade900 : Colors.red.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _lastResult!.passed
                    ? 'Assessment Successfully Passed and Recorded in Learning Ledger.'
                    : 'Assessment Recorded as Incomplete / Not Passing.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriterionCard(BuildContext context, RubricCriterionCore criterion) {
    final theme = Theme.of(context);
    final currentScore = _scores[criterion.id] ?? 0;

    return Card(
      key: Key('rubric_step_${criterion.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: criterion.isCritical
            ? BorderSide(color: Colors.red.shade400, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  child: Text(
                    '${criterion.stepOrder}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        criterion.title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (criterion.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(criterion.description, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (criterion.isCritical)
                  Container(
                    key: Key('critical_badge_${criterion.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade700),
                    ),
                    child: Text(
                      'CRITICAL STEP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
              ],
            ),

            if (criterion.criticalFailureNotice != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.red.shade800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        criterion.criticalFailureNotice!,
                        style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Score Choices (0 to maxScore)
            Wrap(
              spacing: 8,
              children: List.generate(criterion.maxScore + 1, (scoreVal) {
                final isSelected = currentScore == scoreVal;
                final descriptor = criterion.descriptors[scoreVal];

                return ChoiceChip(
                  key: Key('criterion_${criterion.id}_score_$scoreVal'),
                  label: Text(
                    descriptor != null ? '$scoreVal - $descriptor' : '$scoreVal pts',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: scoreVal == criterion.maxScore
                      ? Colors.green.shade200
                      : scoreVal == 0 && criterion.isCritical
                          ? Colors.red.shade200
                          : theme.colorScheme.primaryContainer,
                  onSelected: (val) {
                    if (val) _setScore(criterion.id, scoreVal);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
