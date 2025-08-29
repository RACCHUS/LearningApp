import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/widgets/audio/audio_flashcard_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
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
    ref.read(studyProvider.notifier).markTermAsKnown(widget.terms[_currentIndex].id);
    _nextCard();
  }

  void _onDontKnow() {
    ref.read(studyProvider.notifier).markTermAsDifficult(widget.terms[_currentIndex].id);
    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex < widget.terms.length - 1) {
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
      appBar: widget.isEmbeddedInLesson ? null : AppBar(
        title: Text('Flashcards (${_currentIndex + 1}/${widget.terms.length})'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: widget.terms.length,
                  itemBuilder: (context, index) {
                    final term = widget.terms[index];
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: AudioFlashcardWidget(
                        frontText: term.term,
                        backText: term.definition,
                        example: term.example,
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
          if (_isComplete)
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
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _currentIndex = 0;
                                  _isComplete = false;
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
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
