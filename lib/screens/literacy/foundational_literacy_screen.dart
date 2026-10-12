import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:learning_pwa/widgets/literacy/karaoke_story_reader_widget.dart';
import 'package:learning_pwa/widgets/literacy/oral_diagnostic_widget.dart';
import 'package:learning_pwa/widgets/literacy/caseworker_setup_dialog.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_picture_grid_widget.dart';

enum LiteracyHubSection {
  letters,
  blending,
  survival,
  personalId,
  stories,
  diagnostic,
  topics,
}

class FoundationalLiteracyScreen extends ConsumerStatefulWidget {
  final LiteracyHubSection? initialSection;

  const FoundationalLiteracyScreen({super.key, this.initialSection});

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
    if (widget.initialSection != null) {
      _activeSection = widget.initialSection!;
    }
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
      case LiteracyHubSection.stories:
        notifier.speak(
          'Connected Stories. Read along line by line with karaoke highlighting, or tap any word to hear it pronounced.',
        );
        break;
      case LiteracyHubSection.diagnostic:
        notifier.speak(
          'Placement Check. Answer three quick visual questions to find your personalized starting point.',
        );
        break;
      case LiteracyHubSection.topics:
        notifier.speak(
          'Life Topics. Tap any picture card to explore citizenship, driver rules, safety, and money skills.',
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
            key: const Key('literacy-caseworker-btn'),
            tooltip: 'Caseworker & Tutor Setup',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => CaseworkerSetupDialog.show(context),
          ),
          IconButton(
            tooltip: 'Switch between Adult and Youth tracks',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => PreReaderTrackPickerDialog.show(context),
          ),
          IconButton(
            tooltip: 'Hear page instructions',
            icon: const Icon(Icons.volume_up, size: 26),
            onPressed: _announceCurrentActivity,
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
                padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space1),
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
                    const SizedBox(width: DesignTokens.space2),
                    _buildHubNavChip(
                      label: '📖 Stories',
                      section: LiteracyHubSection.stories,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    _buildHubNavChip(
                      label: '🎯 Placement Check',
                      section: LiteracyHubSection.diagnostic,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    _buildHubNavChip(
                      label: '🌟 Life Topics',
                      section: LiteracyHubSection.topics,
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
              ] else if (_activeSection == LiteracyHubSection.stories) ...[
                const KaraokeStoryReaderWidget(),
              ] else if (_activeSection == LiteracyHubSection.diagnostic) ...[
                const OralDiagnosticWidget(),
              ] else if (_activeSection == LiteracyHubSection.topics) ...[
                const PreReaderPictureGridWidget(),
              ],
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
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      label: Text(
        label,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
      selectedColor: colorScheme.primary,
      onSelected: (_) => _switchSection(section),
    );
  }
}
