import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Modal dialog for pre-readers to choose their learning persona/track.
///
/// Fully audio-narrated so illiterate learners can understand the choices
/// without having to read any text.
class PreReaderTrackPickerDialog extends ConsumerStatefulWidget {
  const PreReaderTrackPickerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PreReaderTrackPickerDialog(),
    );
  }

  @override
  ConsumerState<PreReaderTrackPickerDialog> createState() =>
      _PreReaderTrackPickerDialogState();
}

class _PreReaderTrackPickerDialogState
    extends ConsumerState<PreReaderTrackPickerDialog> {
  PreReaderTrack _selectedTrack = PreReaderTrack.adult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(preReaderProvider.notifier).speak(
            'Welcome! Tap the briefcase if you are an adult, or tap the backpack for youth learning.',
          );
    });
  }

  void _onSelectTrack(PreReaderTrack track) {
    setState(() {
      _selectedTrack = track;
    });

    final notifier = ref.read(preReaderProvider.notifier);
    if (track == PreReaderTrack.adult) {
      notifier.speak(
        'Adult learning: Practical life skills, everyday writing, and money math.',
        customRate: 0.85,
      );
    } else {
      notifier.speak(
        'Youth learning: Fun phonics, games, and animal sounds!',
        customRate: 0.9,
      );
    }
  }

  Future<void> _confirmAndStart() async {
    // 1. Enable Pre-Reader mode with chosen track
    await ref.read(preReaderProvider.notifier).enable(_selectedTrack);

    // 2. Ensure a dedicated Foundational Literacy context exists
    try {
      final label = _selectedTrack == PreReaderTrack.adult
          ? 'Foundational Literacy (Adult)'
          : 'Foundational Literacy (Youth)';

      await ref.read(learningContextsProvider.notifier).add(
            label: label,
            rootType: ContextRootType.course,
            rootId: 'foundational-literacy',
            emoji: _selectedTrack == PreReaderTrack.adult ? '💼' : '🎒',
          );
    } catch (_) {
      // In guest / offline mode, proceed smoothly
    }

    if (mounted) {
      Navigator.of(context).pop();
      context.go('/literacy');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      backgroundColor: colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with audio prompt button
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.hearing,
                      color: colorScheme.onPrimaryContainer,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose Your Learning Path',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Tap to hear each choice',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Repeat audio instruction',
                    onPressed: () {
                      ref.read(preReaderProvider.notifier).speak(
                            'Tap the briefcase for adult learning, or the backpack for youth learning.',
                          );
                    },
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space5),

              // Option 1: Adult Track
              _TrackChoiceCard(
                key: const Key('pre-reader-adult-card'),
                emoji: '💼',
                title: 'Adult Learning',
                subtitle:
                    'Practical everyday skills, signs, and money math for work and life.',
                isSelected: _selectedTrack == PreReaderTrack.adult,
                onTap: () => _onSelectTrack(PreReaderTrack.adult),
              ),
              const SizedBox(height: DesignTokens.space3),

              // Option 2: Youth Track
              _TrackChoiceCard(
                key: const Key('pre-reader-youth-card'),
                emoji: '🎒',
                title: 'Youth & Early Learning',
                subtitle:
                    'Fun letter sounds, games, animals, and playful drawing.',
                isSelected: _selectedTrack == PreReaderTrack.youth,
                onTap: () => _onSelectTrack(PreReaderTrack.youth),
              ),
              const SizedBox(height: DesignTokens.space5),

              // Confirm Button
              FilledButton.icon(
                key: const Key('pre-reader-start-btn'),
                onPressed: _confirmAndStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Learning'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: DesignTokens.space3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackChoiceCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _TrackChoiceCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 38),
              ),
              const SizedBox(width: DesignTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
