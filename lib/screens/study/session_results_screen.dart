import 'package:flutter/material.dart';
import 'package:learning_pwa/models/session_result.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/screens/study/flashcard_screen.dart';
import 'package:learning_pwa/screens/study/mcq_screen.dart';

/// Screen shown after completing a study session.
/// Displays score, accuracy, and lets users practice missed items.
class SessionResultsScreen extends StatelessWidget {
  final SessionResult result;

  const SessionResultsScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accuracy = result.accuracy;
    final percentage = (accuracy * 100).round();

    final accentColor = percentage >= 80
        ? Colors.green
        : percentage >= 50
            ? Colors.orange
            : colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Results'),
        leading: const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // Score circle
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: accuracy,
                          strokeWidth: 12,
                          backgroundColor:
                              colorScheme.surfaceContainerHighest,
                          color: accentColor,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$percentage%',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                          Text(
                            '${result.correct}/${result.total}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _getMessage(percentage),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _modeLabel(result.mode),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Stats row
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.check_circle,
                      label: 'Correct',
                      value: '${result.correct}',
                      color: Colors.green,
                      theme: theme,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.cancel,
                      label: 'Missed',
                      value: '${result.missed}',
                      color: colorScheme.error,
                      theme: theme,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.format_list_numbered,
                      label: 'Total',
                      value: '${result.total}',
                      color: colorScheme.primary,
                      theme: theme,
                    ),
                  ],
                ),

                // Practice mistakes button
                if (result.hasMissedItems) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () => _practiceMistakes(context),
                      icon: const Icon(Icons.replay),
                      label: const Text('Practice Mistakes'),
                    ),
                  ),
                ],

                // Missed items list
                if (result.missedTerms.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _SectionHeader(title: 'Terms to Review', theme: theme),
                  const SizedBox(height: 8),
                  ...result.missedTerms.map((mt) => _MissedTermTile(
                        term: mt.term,
                        theme: theme,
                        colorScheme: colorScheme,
                      )),
                ],
                if (result.missedQuestions.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _SectionHeader(title: 'Questions to Review', theme: theme),
                  const SizedBox(height: 8),
                  ...result.missedQuestions.map((mq) => _MissedQuestionTile(
                        question: mq.question,
                        selectedAnswer: mq.selectedAnswer,
                        theme: theme,
                        colorScheme: colorScheme,
                      )),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMessage(int percentage) {
    if (percentage == 100) return 'Perfect Score!';
    if (percentage >= 80) return 'Great Job!';
    if (percentage >= 60) return 'Good Effort!';
    if (percentage >= 40) return 'Keep Practicing!';
    return 'Room to Improve';
  }

  String _modeLabel(SessionMode mode) {
    return switch (mode) {
      SessionMode.flashcards => 'Flashcard Session',
      SessionMode.mcq => 'Quiz Session',
      SessionMode.lesson => 'Lesson Session',
      SessionMode.mixed => 'Mixed Session',
    };
  }

  void _practiceMistakes(BuildContext context) {
    if (result.missedTerms.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FlashcardScreen(
            terms: result.missedTerms.map((mt) => mt.term).toList(),
          ),
        ),
      );
    } else if (result.missedQuestions.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => McqScreen(
            questions:
                result.missedQuestions.map((mq) => mq.question).toList(),
          ),
        ),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ThemeData theme;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MissedTermTile extends StatelessWidget {
  final Term term;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _MissedTermTile({
    required this.term,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.style, color: colorScheme.error),
        title: Text(term.term, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          term.definition,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _MissedQuestionTile extends StatelessWidget {
  final Question question;
  final int selectedAnswer;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _MissedQuestionTile({
    required this.question,
    required this.selectedAnswer,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.close, size: 16, color: colorScheme.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Your answer: ${question.options[selectedAnswer]}',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.check, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Correct: ${question.options[question.correctAnswer]}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
