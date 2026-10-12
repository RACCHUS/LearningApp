import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ged_bridge_item.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Interactive Adult Basic Education (ABE) reading bridge for learners
/// preparing for GED® readiness.
///
/// TRUTHFUL FRAMING & TRADEMARK ATTRIBUTION:
/// Built in strict compliance with trademark rules and adult education standards.
/// Provides synchronized line-by-line audio reading across ABE Levels 1–3
/// (Grade equivalency 0 to 5.9).
class GedBridgeWidget extends ConsumerStatefulWidget {
  const GedBridgeWidget({super.key});

  @override
  ConsumerState<GedBridgeWidget> createState() => _GedBridgeWidgetState();
}

class _GedBridgeWidgetState extends ConsumerState<GedBridgeWidget> {
  AbeLevel _activeLevel = AbeLevel.level1BeginningLiteracy;
  int _activePassageIndex = 0;
  int? _highlightedSentenceIndex;

  // Comprehension question state
  int _questionIndex = 0;
  int? _selectedOptionIndex;
  bool _isAnswerSubmitted = false;
  int _correctCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePassage();
    });
  }

  List<GedBridgePassage> get _levelPassages {
    return officialGedBridgeCatalog
        .where((p) => p.level == _activeLevel)
        .toList();
  }

  GedBridgePassage get _currentPassage {
    final list = _levelPassages;
    if (_activePassageIndex < list.length) {
      return list[_activePassageIndex];
    }
    return list.isNotEmpty ? list.first : officialGedBridgeCatalog.first;
  }

  void _switchLevel(AbeLevel newLevel) {
    setState(() {
      _activeLevel = newLevel;
      _activePassageIndex = 0;
      _highlightedSentenceIndex = null;
      _questionIndex = 0;
      _selectedOptionIndex = null;
      _isAnswerSubmitted = false;
      _correctCount = 0;
    });
    _announcePassage();
  }

  void _announcePassage() {
    final p = _currentPassage;
    ref.read(preReaderAudioServiceProvider).speak(
        'Reading passage: ${p.title}. ${p.gradeEquivalency}. Tap any sentence to hear it read.');
  }

  void _readFullPassage() {
    final p = _currentPassage;
    ref
        .read(preReaderAudioServiceProvider)
        .speak('${p.title}. ${p.fullText}');
  }

  void _readSentence(int index, String sentence) {
    setState(() {
      _highlightedSentenceIndex = index;
    });
    ref.read(preReaderAudioServiceProvider).speak(sentence);
  }

  void _submitComprehension(int optionIndex) {
    if (_isAnswerSubmitted) return;

    final p = _currentPassage;
    if (_questionIndex >= p.comprehensionQuestions.length) return;
    final q = p.comprehensionQuestions[_questionIndex];
    final isCorrect = optionIndex == q.correctOptionIndex;

    setState(() {
      _selectedOptionIndex = optionIndex;
      _isAnswerSubmitted = true;
      if (isCorrect) {
        _correctCount++;
      }
    });

    final audio = ref.read(preReaderAudioServiceProvider);
    if (isCorrect) {
      audio.speak('Correct! ${q.explanation}');
    } else {
      audio.speak(
          'Incorrect. The answer is: ${q.options[q.correctOptionIndex]}. ${q.explanation}');
    }
  }

  void _nextQuestion() {
    final p = _currentPassage;
    if (_questionIndex + 1 < p.comprehensionQuestions.length) {
      setState(() {
        _questionIndex++;
        _selectedOptionIndex = null;
        _isAnswerSubmitted = false;
      });
      final nextQ = p.comprehensionQuestions[_questionIndex];
      ref
          .read(preReaderAudioServiceProvider)
          .speak('Question: ${nextQ.spokenQuestion}');
    } else {
      final total = p.comprehensionQuestions.length;
      ref.read(preReaderAudioServiceProvider).speak(
          'Comprehension check complete! You scored $_correctCount out of $total.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Completed passage check: $_correctCount / $total correct!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final passage = _currentPassage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Level Selector Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildLevelChip(
                label: '🌱 Level 1 (Grades 0–1.9)',
                level: AbeLevel.level1BeginningLiteracy,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildLevelChip(
                label: '🌿 Level 2 (Grades 2.0–3.9)',
                level: AbeLevel.level2BasicEducation,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildLevelChip(
                label: '🌳 Level 3 (Grades 4.0–5.9)',
                level: AbeLevel.level3LowIntermediate,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Truthful Framing Card
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space3,
            vertical: DesignTokens.space2,
          ),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.menu_book, color: Colors.amber, size: 20),
              const SizedBox(width: DesignTokens.space2),
              Expanded(
                child: Text(
                  'ABE Reading Bridge: Systematic reading progression from basic letters to functional paragraphs.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Reading Passage Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.space2,
                        vertical: DesignTokens.space1,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusSm),
                      ),
                      child: Text(
                        passage.gradeEquivalency,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    Text(
                      '• ${passage.category}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.volume_up, size: 18),
                      label: const Text('Read Full Story'),
                      onPressed: _readFullPassage,
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  passage.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),

                // Synchronized Sentence Cards
                ...passage.sentences.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final sentence = entry.value;
                  final isHighlighted = _highlightedSentenceIndex == idx;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: DesignTokens.space2),
                    child: InkWell(
                      onTap: () => _readSentence(idx, sentence),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.all(DesignTokens.space3),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                              : colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMd),
                          border: Border.all(
                            color: isHighlighted
                                ? colorScheme.primary
                                : colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: isHighlighted ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isHighlighted
                                  ? Icons.volume_up
                                  : Icons.play_circle_outline,
                              color: isHighlighted
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: DesignTokens.space2),
                            Expanded(
                              child: Text(
                                sentence,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 16,
                                  fontWeight: isHighlighted
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
              ],
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.space4),

        // Comprehension Check Card
        if (passage.comprehensionQuestions.isNotEmpty) ...[
          _buildComprehensionCard(theme, colorScheme, passage),
          const SizedBox(height: DesignTokens.space4),
        ],

        // Trademark Attribution Card
        Container(
          padding: const EdgeInsets.all(DesignTokens.space3),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: DesignTokens.space2),
                  Text(
                    'Trademark Notice',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space1),
              Text(
                gedTrademarkAttribution,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelChip({
    required String label,
    required AbeLevel level,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _activeLevel == level;
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
      onSelected: (_) => _switchLevel(level),
    );
  }

  Widget _buildComprehensionCard(
      ThemeData theme, ColorScheme colorScheme, GedBridgePassage passage) {
    final q = passage.comprehensionQuestions[_questionIndex];

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
                const Text('🧠', style: TextStyle(fontSize: 22)),
                const SizedBox(width: DesignTokens.space2),
                Text(
                  'Comprehension Check (${_questionIndex + 1} of ${passage.comprehensionQuestions.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
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
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Read question aloud',
                  onPressed: () {
                    ref
                        .read(preReaderAudioServiceProvider)
                        .speak(q.spokenQuestion);
                  },
                ),
                const SizedBox(width: DesignTokens.space2),
                Expanded(
                  child: Text(
                    q.question,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space3),

            // Options
            ...q.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final opt = entry.value;
              final isSelected = _selectedOptionIndex == idx;
              final isCorrect = idx == q.correctOptionIndex;

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
                      : () => _submitComprehension(idx),
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
                          tooltip: 'Listen to option',
                          onPressed: () {
                            ref
                                .read(preReaderAudioServiceProvider)
                                .speak(opt);
                          },
                        ),
                        Expanded(
                          child: Text(
                            opt,
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
                onPressed: _nextQuestion,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
