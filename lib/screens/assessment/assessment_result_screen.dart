import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/assessment.dart';
import '../../providers/assessment_provider.dart';

/// Displays the assessment results after submission: score, level change,
/// question-by-question breakdown, and retry/done actions.
class AssessmentResultView extends ConsumerWidget {
  final AssessmentResult result;

  const AssessmentResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passed = result.passed;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Result icon
              Icon(
                passed ? Icons.check_circle : Icons.cancel,
                size: 80,
                color: passed ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 16),

              // Score
              Text(
                '${result.attempt.score}%',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                passed ? 'Passed!' : 'Keep practicing!',
                style: TextStyle(
                  fontSize: 20,
                  color: passed ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.attempt.correctCount}/${result.attempt.totalQuestions} correct',
                style: TextStyle(color: Colors.grey[600]),
              ),

              // Overtime warning
              if (result.attempt.wasOvertime) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_off,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        'Completed overtime',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Level change
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text('Previous'),
                          Text(
                            '${result.previousLevel}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 32,
                          color: result.leveledUp ? Colors.green : Colors.grey,
                        ),
                      ),
                      Column(
                        children: [
                          const Text('New'),
                          Text(
                            '${result.newLevel}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: result.leveledUp ? Colors.green : null,
                            ),
                          ),
                        ],
                      ),
                      if (result.levelChange != 0) ...[
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: result.leveledUp
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${result.levelChange > 0 ? '+' : ''}${result.levelChange}',
                            style: TextStyle(
                              color: result.leveledUp
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Question breakdown
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Question Breakdown',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              ...result.questionResults.asMap().entries.map((entry) {
                final index = entry.key;
                final qr = entry.value;
                return _QuestionResultCard(
                  index: index + 1,
                  result: qr,
                );
              }),

              const SizedBox(height: 32),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(assessmentSessionProvider.notifier).reset();
                        context.pop();
                      },
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        ref.read(assessmentSessionProvider.notifier).reset();
                        ref
                            .read(assessmentSessionProvider.notifier)
                            .startAssessment(result.assessment.id);
                      },
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionResultCard extends StatelessWidget {
  final int index;
  final QuestionResult result;

  const _QuestionResultCard({
    required this.index,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(
        result.isCorrect ? Icons.check_circle : Icons.cancel,
        color: result.isCorrect ? Colors.green : Colors.red,
      ),
      title: Text(
        'Question $index',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        result.isCorrect ? 'Correct' : 'Incorrect',
        style: TextStyle(
          color: result.isCorrect ? Colors.green : Colors.red,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.question.questionText,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              ...result.question.options.asMap().entries.map((entry) {
                final i = entry.key;
                final option = entry.value;
                final isCorrect = i == result.question.correctAnswer;
                final isUserAnswer = i == result.userAnswer;

                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.withValues(alpha: 0.1)
                        : isUserAnswer
                            ? Colors.red.withValues(alpha: 0.1)
                            : null,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect
                          ? Colors.green
                          : isUserAnswer
                              ? Colors.red
                              : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isCorrect)
                        const Icon(Icons.check, size: 16, color: Colors.green)
                      else if (isUserAnswer)
                        const Icon(Icons.close, size: 16, color: Colors.red)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(option)),
                    ],
                  ),
                );
              }),
              if (result.question.explanation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.question.explanation!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
