import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/cvc_word_item.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Interactive CVC Word Blending Widget
///
/// Teaches onset-rime and sound blending:
/// [Onset Sound] + [Vowel Sound] + [Ending Sound] = Blended Word!
class CvcBlendingWidget extends ConsumerStatefulWidget {
  final List<CvcWordItem>? wordBank;
  final VoidCallback? onWordMastered;

  const CvcBlendingWidget({
    super.key,
    this.wordBank,
    this.onWordMastered,
  });

  @override
  ConsumerState<CvcBlendingWidget> createState() => _CvcBlendingWidgetState();
}

class _CvcBlendingWidgetState extends ConsumerState<CvcBlendingWidget> {
  late ConfettiController _confettiController;
  int _currentIndex = 0;
  bool _isBlended = false;

  List<CvcWordItem> get _words => widget.wordBank ?? decodableCvcWordBank;
  CvcWordItem get _currentWord => _words[_currentIndex % _words.length];

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _speakSound(String letter, String sound) async {
    final notifier = ref.read(preReaderProvider.notifier);
    await notifier.speak('Letter $letter. Sound $sound.');
  }

  Future<void> _blendWord() async {
    final notifier = ref.read(preReaderProvider.notifier);
    final w = _currentWord;
    setState(() {
      _isBlended = true;
    });
    _confettiController.play();
    widget.onWordMastered?.call();

    // Guided step-by-step oral blending
    await notifier.speak(
      '${w.onsetSound} ... ${w.nucleusSound} ... ${w.codaSound} ... ${w.word}! ${w.sentence}',
    );
  }

  void _nextWord() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _words.length;
      _isBlended = false;
    });
    final w = _currentWord;
    ref.read(preReaderProvider.notifier).speak(
          'Next word: starts with ${w.onset}. Tap each letter to hear its sound.',
        );
  }

  void _prevWord() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
      _isBlended = false;
    });
    final w = _currentWord;
    ref.read(preReaderProvider.notifier).speak(
          'Word: ${w.word}. Tap each letter to hear its sound.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final w = _currentWord;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      key: const Key('cvc-prev-btn'),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Previous word',
                      onPressed: _prevWord,
                    ),
                    Text(
                      'Word ${_currentIndex + 1} of ${_words.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const Key('cvc-next-btn'),
                      icon: const Icon(Icons.arrow_forward),
                      tooltip: 'Next word',
                      onPressed: _nextWord,
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space4),

                // Sound segment cards: Onset, Vowel, Coda
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSoundCard(
                      context: context,
                      letter: w.onset,
                      sound: w.onsetSound,
                      label: 'Start',
                      color: colorScheme.primaryContainer,
                      onTap: () => _speakSound(w.onset, w.onsetSound),
                    ),
                    const SizedBox(width: DesignTokens.space3),
                    _buildSoundCard(
                      context: context,
                      letter: w.nucleus,
                      sound: w.nucleusSound,
                      label: 'Vowel',
                      color: colorScheme.tertiaryContainer,
                      onTap: () => _speakSound(w.nucleus, w.nucleusSound),
                    ),
                    const SizedBox(width: DesignTokens.space3),
                    _buildSoundCard(
                      context: context,
                      letter: w.coda,
                      sound: w.codaSound,
                      label: 'End',
                      color: colorScheme.secondaryContainer,
                      onTap: () => _speakSound(w.coda, w.codaSound),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space5),

                // Blending action button
                FilledButton.icon(
                  key: const Key('cvc-blend-action-btn'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space5,
                      vertical: DesignTokens.space3,
                    ),
                  ),
                  icon: const Icon(Icons.hearing, size: 24),
                  label: const Text(
                    'Blend Sounds Together',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _blendWord,
                ),
                const SizedBox(height: DesignTokens.space5),

                // Blended result presentation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(DesignTokens.space4),
                  decoration: BoxDecoration(
                    color: _isBlended
                        ? colorScheme.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                    border: Border.all(
                      color: _isBlended
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        w.emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(width: DesignTokens.space4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.word,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.0,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: DesignTokens.space1),
                          Text(
                            w.sentence,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Confetti burst for successful blending
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 20,
          gravity: 0.3,
        ),
      ],
    );
  }

  Widget _buildSoundCard({
    required BuildContext context,
    required String letter,
    required String sound,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      child: Container(
        width: 80,
        height: 100,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              letter,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.space1),
            Text(
              '"$sound"',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
