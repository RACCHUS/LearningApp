import 'package:flutter/material.dart';
import '../../models/language/bilingual_bridge_item.dart';
import '../../services/language/bilingual_vocab_service.dart';

/// Interactive bilingual flashcard and translation bridge widget for ESL vocational learners (P8-4).
class BilingualBridgeWidget extends StatefulWidget {
  final BilingualVocabService vocabService;
  final String? initialCategory;
  final void Function(String text, bool isSpanish)? onSpeak;

  const BilingualBridgeWidget({
    super.key,
    required this.vocabService,
    this.initialCategory,
    this.onSpeak,
  });

  @override
  State<BilingualBridgeWidget> createState() => _BilingualBridgeWidgetState();
}

class _BilingualBridgeWidgetState extends State<BilingualBridgeWidget> {
  late List<BilingualBridgeItem> _items;
  int _currentIndex = 0;
  bool _primaryIsSpanish = false;

  @override
  void initState() {
    super.initState();
    _items = widget.initialCategory != null
        ? widget.vocabService.getItemsByCategory(widget.initialCategory!)
        : widget.vocabService.getAllItems();
  }

  void _speakCurrentTerm() {
    if (_items.isEmpty) return;
    final item = _items[_currentIndex];
    final text = _primaryIsSpanish ? item.spanishTerm : item.englishTerm;
    widget.onSpeak?.call(text, _primaryIsSpanish);
  }

  void _nextCard() {
    if (_currentIndex < _items.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: Text('No bilingual vocabulary items found.')),
        ),
      );
    }

    final item = _items[_currentIndex];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Controls: Category & Language Toggle
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Bilingual Bridge • ${item.category}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Language Switcher
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('EN 🇺🇸')),
                    ButtonSegment(value: true, label: Text('ES 🇪🇸')),
                  ],
                  selected: {_primaryIsSpanish},
                  onSelectionChanged: (val) {
                    setState(() => _primaryIsSpanish = val.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Card Body
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Emoji visual
                  Text(item.visualEmoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),

                  // Primary Term
                  Text(
                    _primaryIsSpanish ? item.spanishTerm : item.englishTerm,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Phonetic pronunciation guide
                  Text(
                    _primaryIsSpanish
                        ? item.spanishPhonetic
                        : item.englishPhonetic,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Translation Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.translate,
                          size: 16, color: theme.colorScheme.secondary),
                      const SizedBox(width: 6),
                      Text(
                        _primaryIsSpanish
                            ? 'English: ${item.englishTerm}'
                            : 'Español: ${item.spanishTerm}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Definition
                  Text(
                    _primaryIsSpanish
                        ? item.spanishDefinition
                        : item.englishDefinition,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),

                  // Regulatory Citation Chip
                  if (item.regulatoryCitation.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.gavel, size: 14),
                      label: Text(
                        'Standard: ${item.regulatoryCitation}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Navigation and Audio controls
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous',
                  onPressed: _currentIndex > 0 ? _prevCard : null,
                ),
                Text(
                  '${_currentIndex + 1} / ${_items.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next',
                  onPressed:
                      _currentIndex < _items.length - 1 ? _nextCard : null,
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  key: const Key('pronounce_bilingual_term_button'),
                  icon: const Icon(Icons.volume_up, size: 18),
                  label: const Text('Pronounce'),
                  onPressed: _speakCurrentTerm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

