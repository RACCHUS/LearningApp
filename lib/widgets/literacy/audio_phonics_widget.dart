import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/phonics_item.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

class AudioPhonicsWidget extends ConsumerStatefulWidget {
  final PhonicsItem item;
  final VoidCallback? onCompleted;

  const AudioPhonicsWidget({
    super.key,
    required this.item,
    this.onCompleted,
  });

  @override
  ConsumerState<AudioPhonicsWidget> createState() => _AudioPhonicsWidgetState();
}

class _AudioPhonicsWidgetState extends ConsumerState<AudioPhonicsWidget> {
  late ConfettiController _confettiController;
  String? _selectedLabel;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));

    // Auto-announce on open if auto-speak is enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePrompt();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _announcePrompt() {
    final notifier = ref.read(preReaderProvider.notifier);
    notifier.speak(
      'Listen to the sound: ${widget.item.phonemeSound}. Which picture starts with ${widget.item.phonemeSound}?',
    );
  }

  void _onCardTapped(PhonicsAnchor anchor) async {
    final notifier = ref.read(preReaderProvider.notifier);

    setState(() {
      _selectedLabel = anchor.label;
    });

    if (anchor.isCorrect) {
      setState(() {
        _isSuccess = true;
      });
      _confettiController.play();
      await notifier.speak(
        'Yes! ${widget.item.letter} makes the sound ${widget.item.phonemeSound}! As in ${anchor.label}!',
      );
      widget.onCompleted?.call();
    } else {
      await notifier.speak(
        'That is ${anchor.label}. Listen again for the sound ${widget.item.phonemeSound}.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = ref.watch(preReaderProvider);
    final anchors = widget.item.anchorsFor(profile.track);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            side: BorderSide(
              color: _isSuccess ? Colors.green : colorScheme.outline,
              width: _isSuccess ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Letter header and sound replay button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radiusLg),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.item.letter,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: DesignTokens.space4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sound: ${widget.item.phonemeSound}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.item.explanation,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton.filledTonal(
                      key: const Key('phonics-listen-sound-btn'),
                      icon: const Icon(Icons.volume_up, size: 28),
                      tooltip: 'Listen to sound',
                      onPressed: () {
                        ref.read(preReaderProvider.notifier).speak(
                              'The letter ${widget.item.letter} makes the sound ${widget.item.phonemeSound}.',
                            );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space5),
                const Divider(),
                const SizedBox(height: DesignTokens.space4),

                Text(
                  'Tap the picture that starts with ${widget.item.phonemeSound}:',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: DesignTokens.space4),

                // Picture anchor choices
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 450;
                    return Wrap(
                      spacing: DesignTokens.space3,
                      runSpacing: DesignTokens.space3,
                      alignment: WrapAlignment.center,
                      children: anchors.map((anchor) {
                        final isSelected = _selectedLabel == anchor.label;
                        final isCorrectCard = isSelected && anchor.isCorrect;

                        return SizedBox(
                          width: isNarrow ? (constraints.maxWidth - 20) / 2 : 120,
                          child: Material(
                            color: isCorrectCard
                                ? Colors.green.withValues(alpha: 0.15)
                                : colorScheme.surfaceContainerHigh,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusLg),
                              side: BorderSide(
                                color: isCorrectCard
                                    ? Colors.green
                                    : (isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(DesignTokens.radiusLg),
                              onTap: () => _onCardTapped(anchor),
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(DesignTokens.space4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      anchor.emoji,
                                      style: const TextStyle(fontSize: 44),
                                    ),
                                    const SizedBox(height: DesignTokens.space2),
                                    Text(
                                      anchor.label,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isCorrectCard
                                            ? Colors.green
                                            : colorScheme.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [Colors.green, Colors.blue, Colors.orange, Colors.purple],
        ),
      ],
    );
  }
}
