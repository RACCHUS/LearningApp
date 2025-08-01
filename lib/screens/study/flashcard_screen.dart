import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/providers/study_provider.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  final List<Term> terms;
  final int initialIndex;
  final VoidCallback? onComplete;

  const FlashcardScreen({
    super.key,
    required this.terms,
    this.initialIndex = 0,
    this.onComplete,
  });

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;
  late AnimationController _flipController;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isFlipped = false;
    });
  }

  void _onFlip() {
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
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
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
    }
  }

  Widget _buildFlashcard(String text, {required bool isFront}) {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isFront ? 'Term' : 'Definition',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: isFront
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
            if (isFront) ...[
              const Spacer(),
              Text(
                'Tap to reveal definition',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Flashcards (${_currentIndex + 1}/${widget.terms.length})'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.terms.length,
              itemBuilder: (context, index) {
                final term = widget.terms[index];
                return GestureDetector(
                  onTap: _onFlip,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: _isFlipped
                        ? _buildFlashcard(term.definition, isFront: false)
                        : _buildFlashcard(term.term, isFront: true),
                  ),
                );
              },
            ),
          ),
          if (_isFlipped) ...[
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
          const SizedBox(height: 16),
        ],
      ),
    );
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
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }
}
