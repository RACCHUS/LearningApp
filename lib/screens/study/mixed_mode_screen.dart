import 'package:flutter/material.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/widgets/audio/audio_flashcard_widget.dart';
import 'package:learning_pwa/widgets/audio/audio_mcq_widget.dart';
import 'package:learning_pwa/widgets/audio/audio_concept_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Represents a single study item in mixed mode.
class MixedStudyItem {
  final String type; // 'flashcard', 'mcq', 'concept'
  final dynamic data;
  MixedStudyItem({required this.type, required this.data});
}

class MixedModeScreen extends StatefulWidget {
  final List<Term>? terms;
  final List<Question>? questions;
  final List<ConceptContent>? concepts;
  final List<MixedStudyItem>? preSortedItems; // New option for pre-sorted items
  
  const MixedModeScreen({
    super.key, 
    this.terms, 
    this.questions, 
    this.concepts,
    this.preSortedItems,
  }) : assert(
    (terms != null && questions != null && concepts != null && preSortedItems == null) ||
    (terms == null && questions == null && concepts == null && preSortedItems != null),
    'Either provide terms/questions/concepts OR preSortedItems, not both'
  );

  @override
  State<MixedModeScreen> createState() => _MixedModeScreenState();
}

class _MixedModeScreenState extends State<MixedModeScreen> {
  bool _isComplete = false;
  late List<MixedStudyItem> _items;
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    if (widget.preSortedItems != null) {
      // Use pre-sorted items (already ordered)
      _items = widget.preSortedItems!;
    } else {
      // Create items from individual lists and sort by order field
      _items = [
        ...widget.terms!.map((t) => MixedStudyItem(type: 'flashcard', data: t)),
        ...widget.questions!.map((q) => MixedStudyItem(type: 'mcq', data: q)),
        ...widget.concepts!.map((c) => MixedStudyItem(type: 'concept', data: c)),
      ];
      
      // Sort by order field (default behavior)
      _items.sort((a, b) => a.data.order.compareTo(b.data.order));
      
      // Alternative: Group by type (uncomment to use old behavior)
      // _items..shuffle();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentIndex < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() {
        _isComplete = true;
      });
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildItemWidget(MixedStudyItem item) {
    switch (item.type) {
      case 'flashcard':
        final term = item.data as Term;
        return AudioFlashcardWidget(
          frontText: term.term,
          backText: term.definition,
          example: term.example,
          customTextBuilder: (text) {
            if (text.contains(r'\(') || text.contains(r'\[') || 
                text.contains(r'\frac') || text.contains(r'\sqrt')) {
              return Math.tex(text, textStyle: const TextStyle(fontSize: 20));
            }
            return Text(text, style: const TextStyle(fontSize: 20), textAlign: TextAlign.center);
          },
        );
      
      case 'mcq':
        final question = item.data as Question;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AudioMCQWidget(
              questionText: question.questionText,
              options: question.options,
              correctAnswer: question.correctAnswer,
              explanation: question.explanation,
              customTextBuilder: (text) {
                if (text.contains(r'\(') || text.contains(r'\[') || 
                    text.contains(r'\frac') || text.contains(r'\sqrt')) {
                  return Math.tex(text, textStyle: const TextStyle(fontSize: 18));
                }
                return Text(text, style: const TextStyle(fontSize: 18));
              },
            ),
          ),
        );
      
      case 'concept':
        final concept = item.data as ConceptContent;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AudioConceptWidget(
              conceptText: concept.conceptText,
              exampleText: concept.exampleText,
              keyPoints: concept.keyPoints,
              customTextBuilder: (text) {
                if (text.contains(r'\(') || text.contains(r'\[') || 
                    text.contains(r'\frac') || text.contains(r'\sqrt')) {
                  return Math.tex(text, textStyle: const TextStyle(fontSize: 18));
                }
                return Text(text, style: const TextStyle(fontSize: 18));
              },
            ),
          ),
        );
      
      default:
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Unsupported content type'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mixed Study Session')),
        body: const Center(
          child: Text('No study content available.'),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Mixed Study (${_currentIndex + 1}/${_items.length})'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _items.length,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildItemWidget(_items[index]),
                          
                          const SizedBox(height: 32),
                          
                          // Navigation buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _currentIndex > 0 ? _prev : null,
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Previous'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _currentIndex < _items.length - 1 ? _next : () {
                                  setState(() {
                                    _isComplete = true;
                                  });
                                },
                                icon: Icon(_currentIndex < _items.length - 1 ? Icons.arrow_forward : Icons.check),
                                label: Text(_currentIndex < _items.length - 1 ? 'Next' : 'Complete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          
          // Completion overlay
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
                          Icons.celebration,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Study Session Complete!',
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
