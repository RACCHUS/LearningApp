import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/widgets/audio/audio_concept_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class ConceptScreen extends ConsumerStatefulWidget {
  final List<ConceptContent> concepts;
  final int initialIndex;
  final VoidCallback? onComplete;
  final bool isLastInLesson;
  final bool isEmbeddedInLesson; // New parameter for lesson mode

  const ConceptScreen({
    super.key,
    required this.concepts,
    this.initialIndex = 0,
    this.onComplete,
    this.isLastInLesson = false,
    this.isEmbeddedInLesson = false, // Default to false for standalone mode
  });

  @override
  ConsumerState<ConceptScreen> createState() => _ConceptScreenState();
}

class _ConceptScreenState extends ConsumerState<ConceptScreen> {
  late PageController _pageController;
  late int _currentIndex;
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

  void _nextConcept() {
    if (_currentIndex < widget.concepts.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // If embedded in lesson, directly call onComplete without showing overlay
      if (widget.isEmbeddedInLesson) {
        widget.onComplete?.call();
      } else {
        setState(() {
          _isComplete = true;
        });
        widget.onComplete?.call();
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      // Only show AppBar when not embedded in lesson mode
      appBar: widget.isEmbeddedInLesson ? null : AppBar(
        title: Text('Concepts (${_currentIndex + 1}/${widget.concepts.length})'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentIndex + 1) / widget.concepts.length,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: widget.concepts.length,
                  itemBuilder: (context, index) {
                    final concept = widget.concepts[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: AudioConceptWidget(
                                conceptText: concept.conceptText,
                                exampleText: concept.exampleText,
                                keyPoints: concept.keyPoints,
                                customTextBuilder: (text) {
                                  // Check if text contains LaTeX
                                  if (text.contains(r'\(') || text.contains(r'\[') || 
                                      text.contains(r'\frac') || text.contains(r'\sqrt')) {
                                    return Math.tex(
                                      text,
                                      textStyle: Theme.of(context).textTheme.titleLarge,
                                    );
                                  }
                                  return Text(
                                    text,
                                    style: Theme.of(context).textTheme.titleLarge,
                                  );
                                },
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Next button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _nextConcept,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _currentIndex < widget.concepts.length - 1 
                                  ? 'Next Concept' 
                                  : widget.isEmbeddedInLesson ? 'Continue Lesson' : 'Complete',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          
                          // Navigation controls for concept within lesson
                          if (widget.concepts.length > 1) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_currentIndex > 0)
                                  TextButton.icon(
                                    icon: const Icon(Icons.chevron_left),
                                    label: const Text('Previous'),
                                    onPressed: () {
                                      _pageController.previousPage(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                  )
                                else
                                  const SizedBox.shrink(),
                                
                                // Show concept progress for multiple concepts
                                Text(
                                  '${_currentIndex + 1} of ${widget.concepts.length}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                
                                if (_currentIndex < widget.concepts.length - 1)
                                  TextButton.icon(
                                    label: const Text('Next'),
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: () {
                                      _pageController.nextPage(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                  )
                                else
                                  const SizedBox.shrink(),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          
          // Completion overlay (only show when not embedded in lesson)
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
                          Icons.lightbulb,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Concepts Complete!',
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
                              child: const Text('Review Again'),
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
