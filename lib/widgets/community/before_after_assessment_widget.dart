import 'package:flutter/material.dart';
import 'package:learning_core/learning_core.dart';
import '../../models/community/family_abe_pilot.dart';
import '../../services/community/outcome_assessment_service.dart';

/// Interactive diagnostic pre-test and post-study assessment widget
/// computing normalized learning gain (Hake g) and capturing pilot feedback (ECO-09, Phase 3).
class BeforeAfterAssessmentWidget extends StatefulWidget {
  final OutcomeAssessmentService assessmentService;
  final String participantId;
  final String cohortId;
  final String topic;
  final double? initialPreScore;
  final void Function(AssessmentOutcomeRecord record)? onOutcomeSubmitted;

  const BeforeAfterAssessmentWidget({
    super.key,
    required this.assessmentService,
    required this.participantId,
    required this.cohortId,
    required this.topic,
    this.initialPreScore,
    this.onOutcomeSubmitted,
  });

  @override
  State<BeforeAfterAssessmentWidget> createState() =>
      _BeforeAfterAssessmentWidgetState();
}

class _BeforeAfterAssessmentWidgetState
    extends State<BeforeAfterAssessmentWidget> {
  late List<DiagnosticQuestion> _questions;
  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedAnswers = {};

  double? _preScore;
  double? _postScore;
  AssessmentOutcomeRecord? _outcomeResult;

  // Feedback fields
  int _clarityRating = 5;
  String _pacingFeedback = 'just_right';
  int _audioHelpfulnessRating = 5;
  int _confidenceRating = 5;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _questions = widget.assessmentService
        .getDiagnosticQuestionsForTopic(widget.topic);
    _preScore = widget.initialPreScore;
  }

  void _handleOptionSelected(int optionIndex) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = optionIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _calculateCurrentTestScore();
    }
  }

  void _calculateCurrentTestScore() {
    int correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctIndex) {
        correctCount++;
      }
    }
    final score = _questions.isNotEmpty ? correctCount / _questions.length : 0.0;

    setState(() {
      if (_preScore == null) {
        _preScore = score;
        _currentQuestionIndex = 0;
        _selectedAnswers.clear();
      } else {
        _postScore = score;
        _outcomeResult = widget.assessmentService.evaluateOutcome(
          participantId: widget.participantId,
          cohortId: widget.cohortId,
          topic: widget.topic,
          preScore: _preScore!,
          postScore: _postScore!,
          clarityRating: _clarityRating,
          pacingFeedback: _pacingFeedback,
          audioHelpfulnessRating: _audioHelpfulnessRating,
          confidenceRating: _confidenceRating,
        );
      }
    });
  }

  Future<void> _submitVerifiedOutcome() async {
    if (_outcomeResult == null) return;
    setState(() => _isSaving = true);

    try {
      final finalRecord = widget.assessmentService.evaluateOutcome(
        participantId: widget.participantId,
        cohortId: widget.cohortId,
        topic: widget.topic,
        preScore: _outcomeResult!.preScore,
        postScore: _outcomeResult!.postScore,
        clarityRating: _clarityRating,
        pacingFeedback: _pacingFeedback,
        audioHelpfulnessRating: _audioHelpfulnessRating,
        confidenceRating: _confidenceRating,
      );

      await widget.assessmentService.saveOutcomeRecord(finalRecord);
      widget.onOutcomeSubmitted?.call(finalRecord);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Learning gain and feedback saved to pilot evidence!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving outcome: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // View 1: When pre & post are both completed, show Hake gain comparison and feedback
    if (_outcomeResult != null) {
      return _buildGainSummaryView(context);
    }

    // View 2: Question answering view (Pre-test or Post-test)
    final isPreTest = _preScore == null;
    final q = _questions[_currentQuestionIndex];
    final selectedOption = _selectedAnswers[_currentQuestionIndex];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stage Indicator
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPreTest
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPreTest ? 'Step 1: Diagnostic Pre-Test' : 'Step 2: Post-Study Assessment',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPreTest
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Question Prompt
            Text(
              q.prompt,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Options
            ...q.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final text = entry.value;
              final isSelected = selectedOption == idx;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: InkWell(
                  key: Key('option_${_currentQuestionIndex}_$idx'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _handleOptionSelected(idx),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.12)
                          : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          child: Text(
                            String.fromCharCode(65 + idx),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Next / Finish Button
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('assessment_next_button'),
                onPressed: selectedOption != null ? _nextQuestion : null,
                child: Text(
                  _currentQuestionIndex < _questions.length - 1
                      ? 'Next Question'
                      : (isPreTest ? 'Complete Pre-Test' : 'Finish Assessment'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGainSummaryView(BuildContext context) {
    final theme = Theme.of(context);
    final outcome = _outcomeResult!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Measured Learning Outcome',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildGainBadge(context, outcome.gainCategory),
              ],
            ),
            const SizedBox(height: 16),

            // Pre / Post Score comparison
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Baseline Pre-Score',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        '${(outcome.preScore * 100).toInt()}%',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  Column(
                    children: [
                      Text('Post-Study Score',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        '${(outcome.postScore * 100).toInt()}%',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.trending_up, color: Colors.green),
                  Column(
                    children: [
                      Text('Hake Normalized Gain',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        'g = ${outcome.normalizedGain.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Multi-dimensional feedback section
            Text('Learner Pilot Feedback', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),

            // Clarity Rating
            Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text('Content Clarity:'),
                ),
                Expanded(
                  flex: 4,
                  child: Row(
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          star <= _clarityRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() => _clarityRating = star);
                        },
                      );
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Audio Helpfulness Rating
            Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text('Audio Assistance:'),
                ),
                Expanded(
                  flex: 4,
                  child: Row(
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          star <= _audioHelpfulnessRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() => _audioHelpfulnessRating = star);
                        },
                      );
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Pacing Feedback
            Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text('Instructional Pacing:'),
                ),
                Expanded(
                  flex: 4,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'too_slow',
                        label: Text('Slow', style: TextStyle(fontSize: 10)),
                      ),
                      ButtonSegment(
                        value: 'just_right',
                        label: Text('Right', style: TextStyle(fontSize: 10)),
                      ),
                      ButtonSegment(
                        value: 'too_fast',
                        label: Text('Fast', style: TextStyle(fontSize: 10)),
                      ),
                    ],
                    selected: {_pacingFeedback},
                    onSelectionChanged: (val) {
                      setState(() => _pacingFeedback = val.first);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Confidence Rating
            Row(
              children: [
                const Expanded(
                  flex: 3,
                  child: Text('Skill Confidence:'),
                ),
                Expanded(
                  flex: 4,
                  child: Row(
                    children: List.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          star <= _confidenceRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() => _confidenceRating = star);
                        },
                      );
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('save_outcome_button'),
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Save Verified Outcome to Evidence'),
                onPressed: _isSaving ? null : _submitVerifiedOutcome,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGainBadge(BuildContext context, LearningGainCategory category) {
    Color color;
    switch (category) {
      case LearningGainCategory.high:
        color = Colors.green;
        break;
      case LearningGainCategory.medium:
        color = Colors.blue;
        break;
      case LearningGainCategory.low:
        color = Colors.amber.shade800;
        break;
      case LearningGainCategory.loss:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

