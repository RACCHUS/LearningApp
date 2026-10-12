import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/phonics_item.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/literacy/audio_phonics_widget.dart';
import 'package:learning_pwa/widgets/literacy/cvc_blending_widget.dart';
import 'package:learning_pwa/widgets/literacy/letter_tracing_canvas.dart';
import 'package:learning_pwa/widgets/literacy/personal_id_form_widget.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_track_picker_dialog.dart';
import 'package:learning_pwa/widgets/literacy/survival_words_widget.dart';

enum LiteracyHubSection {
  letters,
  blending,
  survival,
  personalId,
}

class FoundationalLiteracyScreen extends ConsumerStatefulWidget {
  const FoundationalLiteracyScreen({super.key});

  @override
  ConsumerState<FoundationalLiteracyScreen> createState() =>
      _FoundationalLiteracyScreenState();
}

class _FoundationalLiteracyScreenState
    extends ConsumerState<FoundationalLiteracyScreen> {
  LiteracyHubSection _activeSection = LiteracyHubSection.letters;
  int _activeItemIndex = 0;
  int _activeLetterSubTab = 0; // 0: Sound & Picture, 1: Finger Tracing

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentActivity();
    });
  }

  void _announceCurrentActivity() {
    final notifier = ref.read(preReaderProvider.notifier);
    switch (_activeSection) {
      case LiteracyHubSection.letters:
        final item = foundationalPhonicsCatalog[_activeItemIndex];
        if (_activeLetterSubTab == 0) {
          notifier.speak(
            'Letter ${item.letter}. Sound matching. Tap the picture that matches the sound.',
          );
        } else {
          notifier.speak(
            'Letter ${item.letter}. Finger tracing. Follow the glowing dot to write the letter.',
          );
        }
        break;
      case LiteracyHubSection.blending:
        notifier.speak(
          'Word Blending. Tap each sound card to hear the letters, then blend them together.',
        );
        break;
      case LiteracyHubSection.survival:
        notifier.speak(
          'Survival Safety Signs. Learn to recognize EXIT, RESTROOM, STOP, and emergency signs.',
        );
        break;
      case LiteracyHubSection.personalId:
        notifier.speak(
          'My Name and Info. Practice writing and orally spelling your own personal information.',
        );
        break;
    }
  }

  void _switchSection(LiteracyHubSection section) {
    setState(() {
      _activeSection = section;
    });
    _announceCurrentActivity();
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
            tooltip:
                profile.autoSpeakScreens ? 'Auto-speak ON' : 'Auto-speak OFF',
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
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(DesignTokens.space4),
            children: [
              // Top Category Navigation Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildHubNavChip(
                      label: '🔤 Letters (A-Z)',
                      section: LiteracyHubSection.letters,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    _buildHubNavChip(
                      label: '🧩 Word Blending',
                      section: LiteracyHubSection.blending,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    _buildHubNavChip(
                      label: '🛑 Survival Signs',
                      section: LiteracyHubSection.survival,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    _buildHubNavChip(
                      label: '📝 My Name & Info',
                      section: LiteracyHubSection.personalId,
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.space4),

              // Content according to active section
              if (_activeSection == LiteracyHubSection.letters) ...[
                // Letter Carousel selector (all 26 letters A-Z)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: foundationalPhonicsCatalog
                        .asMap()
                        .entries
                        .map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isSelected = index == _activeItemIndex;

                      return Padding(
                        padding:
                            const EdgeInsets.only(right: DesignTokens.space2),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(
                            item.letter,
                            style: TextStyle(
                              fontSize: 16,
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
                const SizedBox(height: DesignTokens.space3),

                // Sub-activity selector tabs (Sound & Picture vs Finger Tracing)
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
                  selected: {_activeLetterSubTab},
                  onSelectionChanged: (set) {
                    setState(() {
                      _activeLetterSubTab = set.first;
                    });
                    _announceCurrentActivity();
                  },
                ),
                const SizedBox(height: DesignTokens.space4),

                if (_activeLetterSubTab == 0)
                  AudioPhonicsWidget(
                    key: ValueKey('phonics-${activeItem.letter}'),
                    item: activeItem,
                    onCompleted: () {
                      if (_activeItemIndex <
                          foundationalPhonicsCatalog.length - 1) {
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
                  ),
              ] else if (_activeSection == LiteracyHubSection.blending) ...[
                const CvcBlendingWidget(),
              ] else if (_activeSection == LiteracyHubSection.survival) ...[
                const SurvivalWordsWidget(),
              ] else if (_activeSection == LiteracyHubSection.personalId) ...[
                const PersonalIdFormWidget(),
              ],

              const SizedBox(height: DesignTokens.space5),
              const Divider(),
              const SizedBox(height: DesignTokens.space3),

              // Direct Access Milestone Banner (Direct Access Rule: <=2 taps)
              InkWell(
                onTap: () => context.go('/milestones'),
                borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.space4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Text('🏛️', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: DesignTokens.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'High-Stakes US Life Goals',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: DesignTokens.space1),
                            Text(
                              'US Citizenship (2025 Test) • Driver\'s License • GED Bridge',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHubNavChip({
    required String label,
    required LiteracyHubSection section,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _activeSection == section;
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
}
