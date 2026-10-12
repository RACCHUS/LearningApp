import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/phonics_item.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/literacy/audio_phonics_widget.dart';
import 'package:learning_pwa/widgets/literacy/letter_tracing_canvas.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_track_picker_dialog.dart';

class FoundationalLiteracyScreen extends ConsumerStatefulWidget {
  const FoundationalLiteracyScreen({super.key});

  @override
  ConsumerState<FoundationalLiteracyScreen> createState() =>
      _FoundationalLiteracyScreenState();
}

class _FoundationalLiteracyScreenState
    extends ConsumerState<FoundationalLiteracyScreen> {
  int _activeItemIndex = 0;
  int _activeActivityTab = 0; // 0: Sound & Words, 1: Finger Tracing

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentActivity();
    });
  }

  void _announceCurrentActivity() {
    final item = foundationalPhonicsCatalog[_activeItemIndex];
    final notifier = ref.read(preReaderProvider.notifier);
    if (_activeActivityTab == 0) {
      notifier.speak(
        'Letter ${item.letter}. Sound matching. Tap the picture that matches the sound.',
      );
    } else {
      notifier.speak(
        'Letter ${item.letter}. Finger tracing. Follow the glowing dot to write the letter.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = ref.watch(preReaderProvider);
    final activeItem = foundationalPhonicsCatalog[_activeItemIndex];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              profile.track == PreReaderTrack.youth ? '🎒' : '💼',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: DesignTokens.space2),
            Text(
              profile.track == PreReaderTrack.youth
                  ? 'Youth Phonics & ABCs'
                  : 'Foundational Literacy',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch between Adult and Youth tracks',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => PreReaderTrackPickerDialog.show(context),
          ),
          IconButton(
            tooltip: profile.autoSpeakScreens ? 'Auto-speak ON' : 'Auto-speak OFF',
            icon: Icon(
              profile.autoSpeakScreens ? Icons.volume_up : Icons.volume_off,
            ),
            onPressed: () {
              ref.read(preReaderProvider.notifier).toggleAutoSpeak();
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(DesignTokens.space4),
            children: [
              // Letter Carousel selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: foundationalPhonicsCatalog.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = index == _activeItemIndex;

                    return Padding(
                      padding: const EdgeInsets.only(right: DesignTokens.space3),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(
                          item.letter,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                        ),
                        selectedColor: colorScheme.primary,
                        onSelected: (_) {
                          setState(() {
                            _activeItemIndex = index;
                          });
                          _announceCurrentActivity();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: DesignTokens.space4),

              // Activity selector tabs
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    icon: Icon(Icons.hearing),
                    label: Text('Sound & Picture'),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    icon: Icon(Icons.edit),
                    label: Text('Finger Tracing'),
                  ),
                ],
                selected: {_activeActivityTab},
                onSelectionChanged: (set) {
                  setState(() {
                    _activeActivityTab = set.first;
                  });
                  _announceCurrentActivity();
                },
              ),
              const SizedBox(height: DesignTokens.space5),

              // Active Activity
              if (_activeActivityTab == 0)
                AudioPhonicsWidget(
                  key: ValueKey('phonics-${activeItem.letter}'),
                  item: activeItem,
                  onCompleted: () {
                    // Option to advance to next letter
                    if (_activeItemIndex < foundationalPhonicsCatalog.length - 1) {
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) {
                          setState(() {
                            _activeItemIndex++;
                          });
                          _announceCurrentActivity();
                        }
                      });
                    }
                  },
                )
              else
                LetterTracingCanvas(
                  key: ValueKey('tracing-${activeItem.letter}'),
                  letter: activeItem.letter,
                  onCompleted: () {
                    // Celebration feedback
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
