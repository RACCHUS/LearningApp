import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/uscis_civics_item.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Interactive simulator for the USCIS Naturalization & Civics Test.
///
/// Complies with the 2025 Revised Civics Test standard (128-question pool,
/// 20 questions asked, 12 to pass, stopping rule at 12 correct or 9 incorrect),
/// the legacy 2008 standard (100 questions, 10 asked, 6 to pass),
/// and the 65/20 special exemption set, plus the Form N-400 oral interview.
class UscisCivicsSimulatorWidget extends ConsumerStatefulWidget {
  const UscisCivicsSimulatorWidget({super.key});

  @override
  ConsumerState<UscisCivicsSimulatorWidget> createState() =>
      _UscisCivicsSimulatorWidgetState();
}

class _UscisCivicsSimulatorWidgetState
    extends ConsumerState<UscisCivicsSimulatorWidget> {
  UscisTestMode _mode = UscisTestMode.test2025;

  // Civics test state
  int _currentIndex = 0;
  int _correctCount = 0;
  int _incorrectCount = 0;
  int? _selectedOptionIndex;
  bool _isAnswerSubmitted = false;
  bool _isTestConcluded = false;
  String _concludedMessage = '';

  // N-400 interview state
  int _n400Index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentQuestion();
    });
  }

  List<UscisCivicsItem> get _filteredCivicsList {
    switch (_mode) {
      case UscisTestMode.test2025:
        return officialUscisCivicsCatalog
            .where((item) => item.is2025Test)
            .toList();
      case UscisTestMode.test2008:
        return officialUscisCivicsCatalog
            .where((item) => item.is2008Test)
            .toList();
      case UscisTestMode.exemption65_20:
        return officialUscisCivicsCatalog
            .where((item) => item.is65_20Exemption)
            .toList();
      case UscisTestMode.n400Interview:
        return const [];
    }
  }

  int get _maxQuestionsToAsk {
    switch (_mode) {
      case UscisTestMode.test2025:
        return 20;
      case UscisTestMode.test2008:
      case UscisTestMode.exemption65_20:
        return 10;
      case UscisTestMode.n400Interview:
        return officialN400InterviewCatalog.length;
    }
  }

  int get _passingScore {
    switch (_mode) {
      case UscisTestMode.test2025:
        return 12;
      case UscisTestMode.test2008:
      case UscisTestMode.exemption65_20:
        return 6;
      case UscisTestMode.n400Interview:
        return 0;
    }
  }

  int get _failingLimit {
    switch (_mode) {
      case UscisTestMode.test2025:
        return 9; // 9 wrong means learner cannot reach 12 out of 20
      case UscisTestMode.test2008:
      case UscisTestMode.exemption65_20:
        return 5; // 5 wrong means learner cannot reach 6 out of 10
      case UscisTestMode.n400Interview:
        return 99;
    }
  }

  void _switchMode(UscisTestMode newMode) {
    setState(() {
      _mode = newMode;
      _resetTestState();
    });
    _announceCurrentQuestion();
  }

  void _resetTestState() {
    _currentIndex = 0;
    _correctCount = 0;
    _incorrectCount = 0;
    _selectedOptionIndex = null;
    _isAnswerSubmitted = false;
    _isTestConcluded = false;
    _concludedMessage = '';
    _n400Index = 0;
  }

  void _announceCurrentQuestion() {
    final audio = ref.read(preReaderAudioServiceProvider);
    if (_mode == UscisTestMode.n400Interview) {
      if (_n400Index < officialN400InterviewCatalog.length) {
        final q = officialN400InterviewCatalog[_n400Index];
        audio.speak(
            'Form N 400 Interview. ${q.section}. Officer asks: ${q.officerQuestion}');
      }
    } else {
      final list = _filteredCivicsList;
      if (list.isNotEmpty && _currentIndex < list.length && !_isTestConcluded) {
        final item = list[_currentIndex];
        audio.speak(
            'Question ${_currentIndex + 1}. ${item.spokenQuestion}');
      }
    }
  }

  void _speakOption(String text) {
    ref.read(preReaderAudioServiceProvider).speak(text);
  }

  void _submitCivicsAnswer(int optionIndex) {
    if (_isAnswerSubmitted || _isTestConcluded) return;

    final list = _filteredCivicsList;
    if (_currentIndex >= list.length) return;
    final item = list[_currentIndex];
    final isCorrect = optionIndex == item.correctOptionIndex;

    setState(() {
      _selectedOptionIndex = optionIndex;
      _isAnswerSubmitted = true;
      if (isCorrect) {
        _correctCount++;
      } else {
        _incorrectCount++;
      }
    });

    final audio = ref.read(preReaderAudioServiceProvider);
    if (isCorrect) {
      audio.speak('Correct! ${item.explanation}');
    } else {
      audio.speak(
          'Incorrect. The correct answer is: ${item.options[item.correctOptionIndex]}. ${item.explanation}');
    }

    // Check 2025 / 2008 stopping rule immediately
    if (_correctCount >= _passingScore) {
      setState(() {
        _isTestConcluded = true;
        _concludedMessage =
            'Congratulations! You answered $_correctCount questions correctly and passed the naturalization civics test!';
      });
      audio.speak(_concludedMessage);
    } else if (_incorrectCount >= _failingLimit) {
      setState(() {
        _isTestConcluded = true;
        _concludedMessage =
            'Test stopped. You reached $_incorrectCount incorrect answers. Let\'s practice again to get ready!';
      });
      audio.speak(_concludedMessage);
    }
  }

  void _nextCivicsQuestion() {
    final list = _filteredCivicsList;
    if (_currentIndex + 1 < list.length &&
        _currentIndex + 1 < _maxQuestionsToAsk) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _isAnswerSubmitted = false;
      });
      _announceCurrentQuestion();
    } else {
      // Reached end of questions
      setState(() {
        _isTestConcluded = true;
        if (_correctCount >= _passingScore) {
          _concludedMessage =
              'Exam complete! You passed with $_correctCount correct out of ${_currentIndex + 1} asked!';
        } else {
          _concludedMessage =
              'Exam finished. Score: $_correctCount correct. Need $_passingScore to pass. Keep practicing!';
        }
      });
      ref.read(preReaderAudioServiceProvider).speak(_concludedMessage);
    }
  }

  void _nextN400Question() {
    if (_n400Index + 1 < officialN400InterviewCatalog.length) {
      setState(() {
        _n400Index++;
      });
      _announceCurrentQuestion();
    } else {
      final audio = ref.read(preReaderAudioServiceProvider);
      audio.speak(
          'Great practice! You have completed all simulated Form N-400 interview questions.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completed Form N-400 interview drill!'),
        ),
      );
    }
  }

  void _showDojReferralDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Text('⚖️', style: TextStyle(fontSize: 24)),
            SizedBox(width: DesignTokens.space2),
            Expanded(
              child: Text('Immigration Legal Help'),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Only authorized individuals can give legal advice on your immigration case:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: DesignTokens.space2),
              Text(
                '• DOJ-Accredited Representatives working for non-profit organizations recognized by the Executive Office for Immigration Review (EOIR).\n'
                '• Licensed Immigration Attorneys in good standing.\n\n'
                '⚠️ Beware of "Notarios": In the United States, a notary public is NOT authorized to provide immigration legal advice.\n\n'
                'To find a recognized legal aid organization near you, visit:\n'
                'justice.gov/eoir/recognized-organizations',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(preReaderAudioServiceProvider).speak(
                  'Only DOJ-accredited representatives or licensed immigration attorneys may provide legal advice. Never use a notario.');
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.volume_up, size: 18),
                SizedBox(width: 4),
                Text('Read Aloud'),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode Selector Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildModeChip(
                label: '🇺🇸 2025 Test (128 Pool)',
                mode: UscisTestMode.test2025,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildModeChip(
                label: '📜 2008 Test (100 Pool)',
                mode: UscisTestMode.test2008,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildModeChip(
                label: '🌟 65/20 Exemption',
                mode: UscisTestMode.exemption65_20,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildModeChip(
                label: '🗣️ Oral N-400 Interview',
                mode: UscisTestMode.n400Interview,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        if (_mode == UscisTestMode.n400Interview)
          _buildN400Content(theme, colorScheme)
        else
          _buildCivicsContent(theme, colorScheme),

        const SizedBox(height: DesignTokens.space4),

        // Legal Advice Disclaimer Banner with DOJ Referral
        Container(
          padding: const EdgeInsets.all(DesignTokens.space3),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: DesignTokens.space2),
                  Expanded(
                    child: Text(
                      'Legal Advice Notice',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.gavel, size: 16),
                    label: const Text('DOJ Help', style: TextStyle(fontSize: 12)),
                    onPressed: _showDojReferralDialog,
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space1),
              Text(
                uscisLegalDisclaimer,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeChip({
    required String label,
    required UscisTestMode mode,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _mode == mode;
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
      selectedColor: colorScheme.primary,
      onSelected: (_) => _switchMode(mode),
    );
  }

  Widget _buildCivicsContent(ThemeData theme, ColorScheme colorScheme) {
    if (_isTestConcluded) {
      final isPassed = _correctCount >= _passingScore;
      return Card(
        color: isPassed
            ? colorScheme.primaryContainer
            : colorScheme.errorContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space5),
          child: Column(
            children: [
              Text(
                isPassed ? '🎉' : '📚',
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: DesignTokens.space2),
              Text(
                isPassed ? 'Test Passed!' : 'Practice Incomplete',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPassed
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
              Text(
                _concludedMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isPassed
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: DesignTokens.space4),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                onPressed: () {
                  setState(() {
                    _resetTestState();
                  });
                  _announceCurrentQuestion();
                },
              ),
            ],
          ),
        ),
      );
    }

    final list = _filteredCivicsList;
    if (list.isEmpty) {
      return const Center(child: Text('No questions available in this mode.'));
    }

    final item = list[_currentIndex];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header & Stopping Rule Counter
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space2,
                    vertical: DesignTokens.space1,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                  child: Text(
                    'Q ${_currentIndex + 1} of $_maxQuestionsToAsk',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.space2),
                if (item.is65_20Exemption)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space2,
                      vertical: DesignTokens.space1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSm),
                    ),
                    child: const Text(
                      '⭐ 65/20',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  '✅ $_correctCount/$_passingScore to Pass   ❌ $_incorrectCount/$_failingLimit',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space2),

            // Category badge
            Text(
              item.category,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DesignTokens.space2),

            // Question Text & Big Speaker Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton.filled(
                  icon: const Icon(Icons.volume_up, size: 28),
                  onPressed: _announceCurrentQuestion,
                  tooltip: 'Read question aloud',
                ),
                const SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: Text(
                    item.question,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space4),

            // Multiple Choice Options (with tap-to-listen speaker icon)
            ...item.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final optText = entry.value;
              final isSelected = _selectedOptionIndex == idx;
              final isCorrect = idx == item.correctOptionIndex;

              Color? cardColor;
              BorderSide borderSide =
                  BorderSide(color: colorScheme.outlineVariant);

              if (_isAnswerSubmitted) {
                if (isCorrect) {
                  cardColor = Colors.green.withValues(alpha: 0.15);
                  borderSide = const BorderSide(color: Colors.green, width: 2);
                } else if (isSelected) {
                  cardColor = colorScheme.errorContainer.withValues(alpha: 0.3);
                  borderSide =
                      BorderSide(color: colorScheme.error, width: 2);
                }
              } else if (isSelected) {
                cardColor = colorScheme.primaryContainer.withValues(alpha: 0.4);
                borderSide =
                    BorderSide(color: colorScheme.primary, width: 1.5);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: DesignTokens.space2),
                child: InkWell(
                  onTap: _isAnswerSubmitted
                      ? null
                      : () => _submitCivicsAnswer(idx),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space3,
                      vertical: DesignTokens.space3,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMd),
                      border: Border.fromBorderSide(borderSide),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.volume_up_outlined, size: 20),
                          tooltip: 'Hear this choice',
                          onPressed: () => _speakOption(optText),
                        ),
                        Expanded(
                          child: Text(
                            optText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_isAnswerSubmitted && isCorrect)
                          const Icon(Icons.check_circle, color: Colors.green)
                        else if (_isAnswerSubmitted && isSelected)
                          Icon(Icons.cancel, color: colorScheme.error),
                      ],
                    ),
                  ),
                ),
              );
            }),

            if (_isAnswerSubmitted) ...[
              const SizedBox(height: DesignTokens.space3),
              Container(
                padding: const EdgeInsets.all(DesignTokens.space3),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 20),
                    const SizedBox(width: DesignTokens.space2),
                    Expanded(
                      child: Text(
                        item.explanation,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.space3),
              FilledButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Question'),
                onPressed: _nextCivicsQuestion,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildN400Content(ThemeData theme, ColorScheme colorScheme) {
    final q = officialN400InterviewCatalog[_n400Index];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space2,
                    vertical: DesignTokens.space1,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                  child: Text(
                    'Part ${_n400Index + 1} of ${officialN400InterviewCatalog.length} • ${q.section}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.secondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Repeat officer question',
                  onPressed: _announceCurrentQuestion,
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space3),

            // Officer Question
            Container(
              padding: const EdgeInsets.all(DesignTokens.space4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('👮', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: DesignTokens.space2),
                      Text(
                        'USCIS Officer Asks:',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space2),
                  Text(
                    '"${q.officerQuestion}"',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space3),

            // Guidance
            Text(
              'What the officer is looking for:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.space1),
            Text(
              q.guidanceAudio,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DesignTokens.space4),

            // Sample Answer Card
            Container(
              padding: const EdgeInsets.all(DesignTokens.space3),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sample Spoken Answer:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space1),
                  Text(
                    q.sampleAnswer,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space2),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.record_voice_over, size: 18),
                    label: const Text('Hear Sample Answer'),
                    onPressed: () {
                      ref
                          .read(preReaderAudioServiceProvider)
                          .speak('Sample answer: ${q.sampleAnswer}');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space4),

            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('I Practiced This Answer'),
              onPressed: _nextN400Question,
            ),
          ],
        ),
      ),
    );
  }
}
