import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/session_result.dart';
import 'package:learning_pwa/models/settings_model.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/screens/study/session_results_screen.dart';
import 'package:learning_pwa/widgets/audio/audio_flashcard_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:learning_pwa/widgets/global_voice_indicator.dart';
import 'package:learning_pwa/widgets/study/break_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  final List<Term> terms;
  final int initialIndex;
  final VoidCallback? onComplete;
  final bool isEmbeddedInLesson; // New parameter for lesson mode

  const FlashcardScreen({
    super.key,
    required this.terms,
    this.initialIndex = 0,
    this.onComplete,
    this.isEmbeddedInLesson = false, // Default to false for standalone mode
  });

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  late int _currentIndex;
  late PageController _pageController;
  bool _isComplete = false;
  bool _focusMode = false;
  final Set<String> _difficultTermIds = {};
  late List<Term> _activeTerms;
  final DateTime _sessionStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _activeTerms = widget.terms; // default; may be sliced after settings load
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadBatchSize();
  }

  Future<void> _loadBatchSize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('settings');
    if (raw != null) {
      final settings = SettingsModel.fromRawJson(raw);
      if (settings.studyBatchSize > 0 && settings.studyBatchSize < widget.terms.length) {
        setState(() {
          _activeTerms = widget.terms.sublist(0, settings.studyBatchSize);
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onKnowIt() {
    ref.read(studyProvider.notifier).markTermAsKnown(_activeTerms[_currentIndex].id);
    _nextCard();
  }

  void _onDontKnow() {
    _difficultTermIds.add(_activeTerms[_currentIndex].id);
    ref.read(studyProvider.notifier).markTermAsDifficult(_activeTerms[_currentIndex].id);
    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex < _activeTerms.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Reached the end of the deck
      setState(() {
        _isComplete = true;
      });
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      // Only show AppBar when not embedded in lesson mode
      appBar: widget.isEmbeddedInLesson ? null : _focusMode ? null : AppBar(
        title: Text('Flashcards (${_currentIndex + 1}/${_activeTerms.length})'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_off_outlined),
            tooltip: 'Focus mode',
            onPressed: () => setState(() => _focusMode = true),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Minimal progress bar in focus mode
              if (_focusMode && !widget.isEmbeddedInLesson) ...[
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (_currentIndex + 1) / _activeTerms.length,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 20),
                          tooltip: 'Exit focus mode',
                          onPressed: () => setState(() => _focusMode = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _activeTerms.length,
                  itemBuilder: (context, index) {
                    final term = _activeTerms[index];
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: AudioFlashcardWidget(
                        frontText: term.term,
                        backText: term.definition,
                        example: term.example,
                        emoji: term.emoji,
                        autoPlayOverride: widget.isEmbeddedInLesson ? false : null, // Disable autoplay when embedded
                        frontStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        backStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        customTextBuilder: (text) {
                          // Check if text contains LaTeX
                          if (text.contains(r'\(') || text.contains(r'\[') || 
                              text.contains(r'\frac') || text.contains(r'\sqrt')) {
                            return Math.tex(
                              text,
                              textStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }
                          return Text(
                            text,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.thumb_down,
                      label: 'Need Practice',
                      color: theme.colorScheme.error,
                      onPressed: _onDontKnow,
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      icon: Icons.thumb_up,
                      label: 'I Know This',
                      color: theme.colorScheme.primary,
                      onPressed: _onKnowIt,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isComplete && !widget.isEmbeddedInLesson)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Flashcards Complete!',
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_activeTerms.length - _difficultTermIds.length}/${_activeTerms.length} known',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _currentIndex = 0;
                                  _isComplete = false;
                                  _difficultTermIds.clear();
                                });
                                _pageController.animateToPage(
                                  0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: const Text('Study Again'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final missedTerms = _activeTerms
                                    .where((t) => _difficultTermIds.contains(t.id))
                                    .map((t) => MissedTerm(term: t))
                                    .toList();
                                final result = SessionResult(
                                  mode: SessionMode.flashcards,
                                  correct: _activeTerms.length - _difficultTermIds.length,
                                  total: _activeTerms.length,
                                  missedTerms: missedTerms,
                                  duration:
                                      DateTime.now().difference(_sessionStart),
                                );
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => SessionResultsScreen(result: result),
                                  ),
                                );
                              },
                              child: const Text('See Results'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const BreakOverlay(),
        ],
      ),
      // Only show GlobalVoiceFAB when not embedded in lesson to avoid conflicts
      floatingActionButton: widget.isEmbeddedInLesson 
          ? null 
          : const GlobalVoiceFAB(heroTag: "flashcardVoiceFAB"),
    );
  }
}
