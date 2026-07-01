import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/assessment_provider.dart';
import '../../screens/assessment/assessment_result_screen.dart';

/// Screen for taking an assessment
class AssessmentScreen extends ConsumerStatefulWidget {
  final String assessmentId;

  const AssessmentScreen({super.key, required this.assessmentId});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    // Start assessment when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assessmentSessionProvider.notifier).startAssessment(widget.assessmentId);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(assessmentSessionProvider);

    // Start timer when assessment starts
    if (session.isActive && _timer == null) {
      _startTimer();
    }

    // Show result if completed
    if (session.isCompleted) {
      return AssessmentResultView(result: session.result!);
    }

    // Show loading
    if (!session.isActive) {
      if (session.error != null) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${session.error}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        );
      }
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final assessment = session.assessment!;
    final question = session.currentQuestion!;
    final timeLimit = assessment.timeLimitMinutes * 60;
    final isOvertime = _elapsedSeconds > timeLimit;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(assessment.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitDialog,
          ),
          actions: [
            // Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isOvertime
                    ? Colors.red.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    isOvertime ? Icons.warning : Icons.timer,
                    size: 16,
                    color: isOvertime ? Colors.red : null,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_elapsedSeconds),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOvertime ? Colors.red : null,
                    ),
                  ),
                  if (!isOvertime) ...[
                    Text(
                      ' / ${_formatTime(timeLimit)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: session.progress,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
            ),

            // Overtime warning
            if (isOvertime)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.orange.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Time\'s up! You can continue, but this will be noted.',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ],
                ),
              ),

            // Question
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question number
                    Text(
                      'Question ${session.currentQuestionIndex + 1} of ${session.totalQuestions}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),

                    // Question text
                    Text(
                      question.questionText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Options
                    ...List.generate(question.options.length, (index) {
                      final isSelected = session.currentAnswer == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OptionCard(
                          text: question.options[index],
                          isSelected: isSelected,
                          onTap: () => ref
                              .read(assessmentSessionProvider.notifier)
                              .answerQuestion(index),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Navigation
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Previous button
                    if (session.canGoBack)
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(assessmentSessionProvider.notifier)
                            .previousQuestion(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                      )
                    else
                      const SizedBox(width: 100),

                    const Spacer(),

                    // Question dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        session.totalQuestions,
                        (index) => GestureDetector(
                          onTap: () => ref
                              .read(assessmentSessionProvider.notifier)
                              .goToQuestion(index),
                          child: Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == session.currentQuestionIndex
                                  ? Theme.of(context).colorScheme.primary
                                  : session.answers.containsKey(
                                          session.questions[index].id)
                                      ? Colors.green
                                      : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Next/Submit button
                    if (session.isLastQuestion)
                      FilledButton.icon(
                        onPressed: session.allAnswered
                            ? () => _submitAssessment()
                            : null,
                        icon: const Icon(Icons.check),
                        label: const Text('Submit'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: session.hasAnsweredCurrent
                            ? () => ref
                                .read(assessmentSessionProvider.notifier)
                                .nextQuestion()
                            : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _showExitDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Assessment?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(assessmentSessionProvider.notifier).abandon();
      context.pop();
    }
  }

  Future<void> _submitAssessment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Assessment?'),
        content: const Text(
          'Are you sure you want to submit your answers? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _timer?.cancel();
      await ref.read(assessmentSessionProvider.notifier).submitAssessment();
    }
  }
}

class _OptionCard extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isSelected ? theme.colorScheme.primary : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
