import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/content_types.dart';

class ConceptScreen extends ConsumerStatefulWidget {
  final List<ConceptContent> concepts;
  final int initialIndex;
  final VoidCallback? onComplete;
  final bool isLastInLesson;

  const ConceptScreen({
    super.key,
    required this.concepts,
    this.initialIndex = 0,
    this.onComplete,
    this.isLastInLesson = false,
  });

  @override
  ConsumerState<ConceptScreen> createState() => _ConceptScreenState();
}

class _ConceptScreenState extends ConsumerState<ConceptScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showExample = false;

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
      widget.onComplete?.call();
    }
  }

  void _toggleExample() {
    setState(() {
      _showExample = !_showExample;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Concept ${_currentIndex + 1} of ${widget.concepts.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: _toggleExample,
            tooltip: _showExample ? 'Hide Example' : 'Show Example',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.concepts.length,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: theme.colorScheme.primary,
            minHeight: 4,
          ),
          
          // Main content area
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.concepts.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _showExample = false;
                });
              },
              itemBuilder: (context, index) {
                final concept = widget.concepts[index];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Concept title
                      Text(
                        'Concept',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Concept content
                      Text(
                        concept.conceptText,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Example section (initially hidden)
                      if (_showExample && concept.exampleText != null) ...[
                        Text(
                          'Example',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            concept.exampleText!,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Key points
                      if (concept.keyPoints != null && concept.keyPoints!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Key Points',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...concept.keyPoints!.map((point) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4.0, right: 8.0),
                                child: Icon(Icons.circle, size: 8),
                              ),
                              Expanded(child: Text(point)),
                            ],
                          ),
                        )),
                      ],
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Bottom action buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous button (only show if not first concept)
                if (_currentIndex > 0)
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  )
                else
                  const SizedBox(width: 100),
                
                // Next/Complete button
                ElevatedButton(
                  onPressed: _nextConcept,
                  child: Text(
                    _currentIndex < widget.concepts.length - 1 
                        ? 'Next Concept' 
                        : widget.isLastInLesson ? 'Complete Lesson' : 'Continue',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
