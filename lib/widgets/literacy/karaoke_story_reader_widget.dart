import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/decodable_story_item.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Karaoke-style early reading widget with synchronized word highlighting
/// and tap-any-word audio pronunciation.
///
/// Adheres to Section 6 of the Literacy Accessibility Plan:
/// - Openly licensed stories (CC-BY 4.0 / Public Domain)
/// - Synchronized word-by-word visual highlight as lines are read aloud
/// - Immediate tactile feedback: tapping any word pronounces it immediately
/// - High-contrast text layout with accessible line-by-line pacing
class KaraokeStoryReaderWidget extends ConsumerStatefulWidget {
  final List<DecodableStoryItem> stories;

  const KaraokeStoryReaderWidget({
    super.key,
    this.stories = officialDecodableStories,
  });

  @override
  ConsumerState<KaraokeStoryReaderWidget> createState() =>
      _KaraokeStoryReaderWidgetState();
}

class _KaraokeStoryReaderWidgetState
    extends ConsumerState<KaraokeStoryReaderWidget> {
  int _selectedStoryIndex = 0;
  int _currentLineIndex = 0;
  int? _highlightedWordIndex;
  bool _isPlaying = false;
  Timer? _highlightTimer;

  DecodableStoryItem get _currentStory =>
      widget.stories[_selectedStoryIndex];

  StoryLine get _currentLine =>
      _currentStory.lines[_currentLineIndex];

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _selectStory(int index) {
    _highlightTimer?.cancel();
    setState(() {
      _selectedStoryIndex = index;
      _currentLineIndex = 0;
      _highlightedWordIndex = null;
      _isPlaying = false;
    });
  }

  void _goToLine(int index) {
    if (index < 0 || index >= _currentStory.lines.length) return;
    _highlightTimer?.cancel();
    setState(() {
      _currentLineIndex = index;
      _highlightedWordIndex = null;
      _isPlaying = false;
    });
  }

  /// Speaks an individual tapped word aloud immediately
  void _speakIndividualWord(String word) {
    // Strip trailing punctuation for clean phonics pronunciation
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '');
    final audio = ref.read(preReaderAudioServiceProvider);
    audio.speak(cleanWord);
  }

  /// Plays the current line with karaoke-style synchronized word progression
  void _playCurrentLine() {
    _highlightTimer?.cancel();
    final words = _currentLine.words;
    if (words.isEmpty) return;

    setState(() {
      _isPlaying = true;
      _highlightedWordIndex = 0;
    });

    final audio = ref.read(preReaderAudioServiceProvider);
    audio.speak(_currentLine.spokenText);

    // Synchronize highlighting across word tokens (~350ms per word)
    const wordDuration = Duration(milliseconds: 360);
    int currentStep = 0;

    _highlightTimer = Timer.periodic(wordDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentStep++;
      if (currentStep < words.length) {
        setState(() {
          _highlightedWordIndex = currentStep;
        });
      } else {
        timer.cancel();
        setState(() {
          _highlightedWordIndex = null;
          _isPlaying = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Story Selection Header Carousel
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < widget.stories.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: DesignTokens.space2),
                    child: ChoiceChip(
                      key: Key('story-tab-${widget.stories[i].id}'),
                      avatar: Text(widget.stories[i].coverEmoji),
                      label: Text(
                        widget.stories[i].title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      selected: _selectedStoryIndex == i,
                      onSelected: (_) => _selectStory(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space4),

          // Story Card Container
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            ),
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Level Bar
                  Row(
                    children: [
                      Text(
                        _currentStory.coverEmoji,
                        style: const TextStyle(fontSize: 36),
                      ),
                      const SizedBox(width: DesignTokens.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentStory.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Level ${_currentStory.level} Reader • ${_currentStory.description}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Line Counter Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.space3,
                          vertical: DesignTokens.space1,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius:
                              BorderRadius.circular(DesignTokens.radiusMd),
                        ),
                        child: Text(
                          'Line ${_currentLineIndex + 1} of ${_currentStory.lines.length}',
                          style: TextStyle(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: DesignTokens.space5),

                  // Interactive Karaoke Line Display Area
                  Container(
                    constraints: const BoxConstraints(minHeight: 140),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(DesignTokens.space4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                          : Colors.amber.shade50.withValues(alpha: 0.5),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusLg),
                      border: Border.all(
                        color: Colors.amber.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: DesignTokens.space2,
                      runSpacing: DesignTokens.space2,
                      children: [
                        for (int w = 0; w < _currentLine.words.length; w++) ...[
                          _buildKaraokeWordChip(
                            word: _currentLine.words[w],
                            index: w,
                            isHighlighted: _highlightedWordIndex == w,
                            theme: theme,
                            colorScheme: colorScheme,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space4),

                  // Audio & Karaoke Playback Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Previous Line Button
                      IconButton.filledTonal(
                        key: const Key('story-prev-line-button'),
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Previous line',
                        onPressed: _currentLineIndex > 0
                            ? () => _goToLine(_currentLineIndex - 1)
                            : null,
                      ),
                      const SizedBox(width: DesignTokens.space3),

                      // Play / Read Aloud Button
                      FilledButton.icon(
                        key: const Key('story-play-line-button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.space5,
                            vertical: DesignTokens.space3,
                          ),
                        ),
                        icon: Icon(
                          _isPlaying ? Icons.volume_up : Icons.play_arrow,
                        ),
                        label: Text(
                          _isPlaying ? 'Reading Line...' : 'Read Line Aloud',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _playCurrentLine,
                      ),
                      const SizedBox(width: DesignTokens.space3),

                      // Next Line Button
                      IconButton.filledTonal(
                        key: const Key('story-next-line-button'),
                        icon: const Icon(Icons.arrow_forward),
                        tooltip: 'Next line',
                        onPressed: _currentLineIndex <
                                _currentStory.lines.length - 1
                            ? () => _goToLine(_currentLineIndex + 1)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space3),

                  // Tap-Any-Word Guidance Hint
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.space2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('👆 ', style: TextStyle(fontSize: 16)),
                        Flexible(
                          child: Text(
                            'Tap any single word above to hear how it sounds.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.space3),

          // Open Licensing & StoryWeaver Attribution
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space3,
              vertical: DesignTokens.space2,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, size: 16),
                const SizedBox(width: DesignTokens.space2),
                Expanded(
                  child: Text(
                    'Licensing: ${_currentStory.attribution}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKaraokeWordChip({
    required String word,
    required int index,
    required bool isHighlighted,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('karaoke-word-$index'),
        onTap: () => _speakIndividualWord(word),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space2,
            vertical: DesignTokens.space1,
          ),
          decoration: BoxDecoration(
            color: isHighlighted
                ? Colors.amber.shade400
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
            border: isHighlighted
                ? Border.all(color: Colors.amber.shade900, width: 2)
                : null,
          ),
          child: Text(
            word,
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  isHighlighted ? FontWeight.bold : FontWeight.w500,
              color: isHighlighted
                  ? Colors.black87
                  : (theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}
