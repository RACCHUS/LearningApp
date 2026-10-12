import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/survival_word_item.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Interactive Environmental Survival Words Explorer & Matching Game
class SurvivalWordsWidget extends ConsumerStatefulWidget {
  final List<SurvivalWordItem>? catalog;
  final VoidCallback? onCompleted;

  const SurvivalWordsWidget({
    super.key,
    this.catalog,
    this.onCompleted,
  });

  @override
  ConsumerState<SurvivalWordsWidget> createState() =>
      _SurvivalWordsWidgetState();
}

class _SurvivalWordsWidgetState extends ConsumerState<SurvivalWordsWidget> {
  late ConfettiController _confettiController;
  int _activeQuizIndex = 0;
  bool _quizMode = false;
  SurvivalWordItem? _selectedItem;

  List<SurvivalWordItem> get _items => widget.catalog ?? survivalWordsCatalog;
  SurvivalWordItem get _targetQuizItem =>
      _items[_activeQuizIndex % _items.length];

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

  void _onSignTapped(SurvivalWordItem item) {
    setState(() {
      _selectedItem = item;
    });
    ref.read(preReaderProvider.notifier).speak(item.audioPrompt);
  }

  void _startQuiz() {
    setState(() {
      _quizMode = true;
      _selectedItem = null;
    });
    _promptQuizItem();
  }

  void _exitQuiz() {
    setState(() {
      _quizMode = false;
      _selectedItem = null;
    });
    ref.read(preReaderProvider.notifier).speak(
          'Tap any sign to hear its name and meaning.',
        );
  }

  void _promptQuizItem() {
    final item = _targetQuizItem;
    ref.read(preReaderProvider.notifier).speak(
          'Find the sign for: ${item.word}. ${item.meaning}',
        );
  }

  void _onQuizChoiceTapped(SurvivalWordItem choice) {
    final isCorrect = choice.word == _targetQuizItem.word;
    if (isCorrect) {
      _confettiController.play();
      ref.read(preReaderProvider.notifier).speak(
            'Correct! That is ${choice.word}. ${choice.meaning}',
          );
      setState(() {
        _activeQuizIndex = (_activeQuizIndex + 1) % _items.length;
      });
      widget.onCompleted?.call();
    } else {
      ref.read(preReaderProvider.notifier).speak(
            'That is ${choice.word}. Look for ${_targetQuizItem.word}. Try again!',
          );
    }
  }

  List<SurvivalWordItem> _generateQuizOptions() {
    final target = _targetQuizItem;
    final others = _items.where((i) => i.word != target.word).toList()..shuffle();
    final options = [target, others[0], others[1]]..shuffle();
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                // Mode Toggle Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _quizMode ? 'Find the Sign' : 'Survival Safety Signs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('survival-mode-toggle-btn'),
                      icon: Icon(_quizMode ? Icons.grid_view : Icons.quiz),
                      label: Text(_quizMode ? 'Explore Signs' : 'Quiz Mode'),
                      onPressed: () {
                        if (_quizMode) {
                          _exitQuiz();
                        } else {
                          _startQuiz();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space4),

                if (_quizMode) ...[
                  // Quiz prompt header
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.space3),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.volume_up),
                          onPressed: _promptQuizItem,
                        ),
                        const SizedBox(width: DesignTokens.space2),
                        Flexible(
                          child: Text(
                            'Find: "${_targetQuizItem.word}"',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space4),

                  // Quiz choices
                  Wrap(
                    spacing: DesignTokens.space3,
                    runSpacing: DesignTokens.space3,
                    alignment: WrapAlignment.center,
                    children: _generateQuizOptions().map((opt) {
                      return _buildSignCard(
                        context: context,
                        item: opt,
                        isSelected: false,
                        onTap: () => _onQuizChoiceTapped(opt),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  // Explore grid
                  Wrap(
                    spacing: DesignTokens.space3,
                    runSpacing: DesignTokens.space3,
                    alignment: WrapAlignment.center,
                    children: _items.map((item) {
                      final isSelected = _selectedItem?.word == item.word;
                      return _buildSignCard(
                        context: context,
                        item: item,
                        isSelected: isSelected,
                        onTap: () => _onSignTapped(item),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: DesignTokens.space4),

                  if (_selectedItem != null) ...[
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.space4),
                      decoration: BoxDecoration(
                        color: _selectedItem!.backgroundColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                        border: Border.all(
                          color: _selectedItem!.backgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedItem!.symbol,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: DesignTokens.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedItem!.word,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: DesignTokens.space1),
                                Text(
                                  _selectedItem!.meaning,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),

        // Confetti celebration
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 20,
          gravity: 0.3,
        ),
      ],
    );
  }

  Widget _buildSignCard({
    required BuildContext context,
    required SurvivalWordItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      child: Container(
        width: 130,
        height: 100,
        decoration: BoxDecoration(
          color: item.backgroundColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          border: isSelected
              ? Border.all(color: Colors.white, width: 3)
              : Border.all(color: Colors.black12, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.symbol,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: DesignTokens.space1),
            Text(
              item.word,
              style: TextStyle(
                color: item.textColor,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
