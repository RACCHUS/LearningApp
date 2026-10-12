import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/dmv_exam_item.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Category of DMV activity within the module.
enum DmvActivitySection {
  /// MUTCD road sign shape and color grammar.
  signGrammar,

  /// Interactive intersection and right-of-way rules.
  rightOfWay,

  /// Florida Class E knowledge exam practice (80% passing threshold).
  classEExam,
}

/// Interactive simulator for the Florida FLHSMV Driver's License exam,
/// MUTCD sign grammar, and intersection right-of-way rules.
class DmvExamSimulatorWidget extends ConsumerStatefulWidget {
  const DmvExamSimulatorWidget({super.key});

  @override
  ConsumerState<DmvExamSimulatorWidget> createState() =>
      _DmvExamSimulatorWidgetState();
}

class _DmvExamSimulatorWidgetState
    extends ConsumerState<DmvExamSimulatorWidget> {
  DmvActivitySection _section = DmvActivitySection.signGrammar;

  // Sign grammar state
  int _activeSignIndex = 0;

  // Exam state
  int _examQuestionIndex = 0;
  int _examCorrectCount = 0;
  int? _selectedExamOption;
  bool _isExamAnswerSubmitted = false;
  bool _isExamConcluded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentActivity();
    });
  }

  void _switchSection(DmvActivitySection newSection) {
    setState(() {
      _section = newSection;
      if (newSection == DmvActivitySection.classEExam) {
        _resetExam();
      }
    });
    _announceCurrentActivity();
  }

  void _resetExam() {
    _examQuestionIndex = 0;
    _examCorrectCount = 0;
    _selectedExamOption = null;
    _isExamAnswerSubmitted = false;
    _isExamConcluded = false;
  }

  void _announceCurrentActivity() {
    final audio = ref.read(preReaderAudioServiceProvider);
    switch (_section) {
      case DmvActivitySection.signGrammar:
        final sign = mutcdSignGrammarCatalog[_activeSignIndex];
        audio.speak(
            'Road Sign Grammar. ${sign.shape}. Color: ${sign.color}. Meaning: ${sign.meaning}. ${sign.audioDescription}');
      case DmvActivitySection.rightOfWay:
        audio.speak(
            'Right of Way Scenarios. Learn who goes first at intersections and Florida emergency vehicle laws.');
      case DmvActivitySection.classEExam:
        if (!_isExamConcluded &&
            _examQuestionIndex < floridaDmvQuestionsCatalog.length) {
          final q = floridaDmvQuestionsCatalog[_examQuestionIndex];
          audio.speak(
              'Florida Class E Exam. Question ${_examQuestionIndex + 1}. ${q.spokenQuestion}');
        }
    }
  }

  void _selectSign(int index) {
    setState(() {
      _activeSignIndex = index;
    });
    final sign = mutcdSignGrammarCatalog[index];
    ref.read(preReaderAudioServiceProvider).speak(
        '${sign.shape}. ${sign.meaning}. ${sign.audioDescription}');
  }

  void _submitExamAnswer(int optionIndex) {
    if (_isExamAnswerSubmitted || _isExamConcluded) return;

    final q = floridaDmvQuestionsCatalog[_examQuestionIndex];
    final isCorrect = optionIndex == q.correctOptionIndex;

    setState(() {
      _selectedExamOption = optionIndex;
      _isExamAnswerSubmitted = true;
      if (isCorrect) {
        _examCorrectCount++;
      }
    });

    final audio = ref.read(preReaderAudioServiceProvider);
    if (isCorrect) {
      audio.speak('Correct! ${q.spokenExplanation}');
    } else {
      audio.speak(
          'Incorrect. The correct answer is: ${q.options[q.correctOptionIndex]}. ${q.spokenExplanation}');
    }
  }

  void _nextExamQuestion() {
    if (_examQuestionIndex + 1 < floridaDmvQuestionsCatalog.length) {
      setState(() {
        _examQuestionIndex++;
        _selectedExamOption = null;
        _isExamAnswerSubmitted = false;
      });
      _announceCurrentActivity();
    } else {
      setState(() {
        _isExamConcluded = true;
      });
      final total = floridaDmvQuestionsCatalog.length;
      final percent = (_examCorrectCount / total * 100).round();
      final passed = percent >= 80; // Florida standard: 80% to pass
      final audio = ref.read(preReaderAudioServiceProvider);
      if (passed) {
        audio.speak(
            'Congratulations! You scored $percent percent with $_examCorrectCount correct out of $total. You passed the Florida driver practice exam!');
      } else {
        audio.speak(
            'Exam completed. You scored $percent percent with $_examCorrectCount correct out of $total. Florida requires 80 percent to pass. Let\'s practice again!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Selector Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSectionChip(
                label: '🛑 Sign Shapes & Colors',
                section: DmvActivitySection.signGrammar,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildSectionChip(
                label: '🔄 Right-of-Way Rules',
                section: DmvActivitySection.rightOfWay,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildSectionChip(
                label: '🚗 Florida Class E Exam',
                section: DmvActivitySection.classEExam,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Accommodation Banner
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space3,
            vertical: DesignTokens.space2,
          ),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.headphones, color: Colors.blue, size: 20),
              const SizedBox(width: DesignTokens.space2),
              Expanded(
                child: Text(
                  'Florida FLHSMV testing centers provide audio-assisted testing with headphones upon request.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Section Content
        switch (_section) {
          DmvActivitySection.signGrammar =>
            _buildSignGrammarContent(theme, colorScheme),
          DmvActivitySection.rightOfWay =>
            _buildRightOfWayContent(theme, colorScheme),
          DmvActivitySection.classEExam =>
            _buildClassEExamContent(theme, colorScheme),
        },
      ],
    );
  }

  Widget _buildSectionChip({
    required String label,
    required DmvActivitySection section,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _section == section;
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
      onSelected: (_) => _switchSection(section),
    );
  }

  Widget _buildSignGrammarContent(ThemeData theme, ColorScheme colorScheme) {
    final activeSign = mutcdSignGrammarCatalog[_activeSignIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Horizontal list of sign shapes
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: mutcdSignGrammarCatalog.asMap().entries.map((entry) {
              final idx = entry.key;
              final sign = entry.value;
              final isSelected = idx == _activeSignIndex;

              return Padding(
                padding: const EdgeInsets.only(right: DesignTokens.space2),
                child: FilterChip(
                  selected: isSelected,
                  avatar: Text(sign.visualIcon, style: const TextStyle(fontSize: 18)),
                  label: Text(
                    sign.meaning,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                  selectedColor: colorScheme.primary,
                  onSelected: (_) => _selectSign(idx),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Active Sign Detail Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Column(
              children: [
                Text(
                  activeSign.visualIcon,
                  style: const TextStyle(fontSize: 54),
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  activeSign.meaning,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: DesignTokens.space1),
                Text(
                  '${activeSign.shape} • ${activeSign.color}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  child: Text(
                    activeSign.audioDescription,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),
                FilledButton.icon(
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Listen to Sign Rule'),
                  onPressed: _announceCurrentActivity,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightOfWayContent(ThemeData theme, ColorScheme colorScheme) {
    final rightOfWayItems = [
      (
        title: '4-Way Stop Right of Way',
        icon: '🛑',
        summary:
            'The first vehicle to reach the intersection goes first. If two vehicles arrive at the same time, yield to the car on your RIGHT.',
        audio:
            'Four-way stop: first vehicle to arrive goes first. If arriving at the exact same time, the driver on the right goes first.',
      ),
      (
        title: 'Florida Move Over Law',
        icon: '🚓',
        summary:
            'When approaching stopped emergency, sanitation, utility, or tow vehicles with flashing lights on a multi-lane road, vacate the lane closest to them. On a two-lane road, slow down to 20 mph below the speed limit.',
        audio:
            'Florida Move Over Law: Move over one lane for emergency vehicles. On two-lane roads, slow down to 20 miles per hour below the speed limit.',
      ),
      (
        title: 'Roundabout Traffic Circle',
        icon: '🔄',
        summary:
            'Vehicles already circulating inside the roundabout always have the right of way. Yield before entering.',
        audio:
            'Roundabouts: Always yield to traffic already circulating inside the circle and pedestrians.',
      ),
      (
        title: 'Flashing Red vs. Yellow Lights',
        icon: '🚦',
        summary:
            'Flashing RED = Complete stop like a stop sign. Flashing YELLOW = Slow down and proceed with caution.',
        audio:
            'Flashing red means complete stop. Flashing yellow means proceed with caution.',
      ),
    ];

    return Column(
      children: rightOfWayItems.map((item) {
        return Card(
          margin: const EdgeInsets.only(bottom: DesignTokens.space3),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.space1),
                      Text(
                        item.summary,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Listen to scenario rule',
                  onPressed: () {
                    ref.read(preReaderAudioServiceProvider).speak(item.audio);
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildClassEExamContent(ThemeData theme, ColorScheme colorScheme) {
    final total = floridaDmvQuestionsCatalog.length;

    if (_isExamConcluded) {
      final percent = (_examCorrectCount / total * 100).round();
      final isPassed = percent >= 80;

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
              Text(isPassed ? '🚗🏆' : '⚠️',
                  style: const TextStyle(fontSize: 48)),
              const SizedBox(height: DesignTokens.space2),
              Text(
                isPassed
                    ? 'Exam Passed! ($percent%)'
                    : 'Practice Needed ($percent%)',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPassed
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
              Text(
                'You answered $_examCorrectCount out of $total questions correctly. '
                'Florida requires 80% to pass Class E knowledge testing.',
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
                label: const Text('Retake Practice Exam'),
                onPressed: () {
                  setState(() {
                    _resetExam();
                  });
                  _announceCurrentActivity();
                },
              ),
            ],
          ),
        ),
      );
    }

    final q = floridaDmvQuestionsCatalog[_examQuestionIndex];

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
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                  child: Text(
                    'Q ${_examQuestionIndex + 1} of $total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.space2),
                Text(
                  q.visualEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
                const Spacer(),
                Text(
                  'Score: $_examCorrectCount / ${_examQuestionIndex + (_isExamAnswerSubmitted ? 1 : 0)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space3),

            // Spoken Question
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton.filled(
                  icon: const Icon(Icons.volume_up, size: 28),
                  onPressed: _announceCurrentActivity,
                  tooltip: 'Read question aloud',
                ),
                const SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: Text(
                    q.question,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space4),

            // Options
            ...q.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final text = entry.value;
              final isSelected = _selectedExamOption == idx;
              final isCorrect = idx == q.correctOptionIndex;

              Color? cardColor;
              BorderSide borderSide =
                  BorderSide(color: colorScheme.outlineVariant);

              if (_isExamAnswerSubmitted) {
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
                  onTap: _isExamAnswerSubmitted
                      ? null
                      : () => _submitExamAnswer(idx),
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
                          tooltip: 'Listen to choice',
                          onPressed: () {
                            ref
                                .read(preReaderAudioServiceProvider)
                                .speak(text);
                          },
                        ),
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
                        if (_isExamAnswerSubmitted && isCorrect)
                          const Icon(Icons.check_circle, color: Colors.green)
                        else if (_isExamAnswerSubmitted && isSelected)
                          Icon(Icons.cancel, color: colorScheme.error),
                      ],
                    ),
                  ),
                ),
              );
            }),

            if (_isExamAnswerSubmitted) ...[
              const SizedBox(height: DesignTokens.space3),
              Container(
                padding: const EdgeInsets.all(DesignTokens.space3),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: DesignTokens.space2),
                    Expanded(
                      child: Text(
                        q.explanation,
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
                onPressed: _nextExamQuestion,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
