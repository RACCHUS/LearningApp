import 'package:flutter/material.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept_content.dart';

/// Represents a single study item in mixed mode.
class MixedStudyItem {
  final String type; // 'flashcard', 'mcq', 'concept'
  final dynamic data;
  MixedStudyItem({required this.type, required this.data});
}

class MixedModeScreen extends StatefulWidget {
  final List<Term> terms;
  final List<Question> questions;
  final List<ConceptContent> concepts;
  const MixedModeScreen({super.key, required this.terms, required this.questions, required this.concepts});

  @override
  State<MixedModeScreen> createState() => _MixedModeScreenState();
}

class _MixedModeScreenState extends State<MixedModeScreen> {
  bool _isComplete = false;
  bool _isFlipped = false; // For flashcard
  int? _selectedOption; // For MCQ
  bool _showFeedback = false;
  bool _isCorrect = false;
  late List<MixedStudyItem> _items;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _items = [
      ...widget.terms.map((t) => MixedStudyItem(type: 'flashcard', data: t)),
      ...widget.questions.map((q) => MixedStudyItem(type: 'mcq', data: q)),
      ...widget.concepts.map((c) => MixedStudyItem(type: 'concept', data: c)),
    ]..shuffle();
  }

  void _next() {
    if (_currentIndex < _items.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
        _selectedOption = null;
        _showFeedback = false;
        _isCorrect = false;
      });
    } else {
      setState(() {
        _isComplete = true;
      });
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
        _selectedOption = null;
        _showFeedback = false;
        _isCorrect = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_currentIndex];
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mixed Study Session'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / _items.length,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: _buildItemWidget(item),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _currentIndex > 0 ? _prev : null,
                    ),
                    Text('${_currentIndex + 1} / ${_items.length}'),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _currentIndex < _items.length - 1 ? _next : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isComplete)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Exit or Review'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemWidget(MixedStudyItem item) {
    switch (item.type) {
      case 'flashcard':
        final term = item.data as Term;
        final theme = Theme.of(context);
        final cardColor = theme.cardColor;
        final flippedColor = theme.colorScheme.secondaryContainer;
        final textColor = theme.textTheme.bodyLarge?.color;
        return GestureDetector(
          onTap: () => setState(() => _isFlipped = !_isFlipped),
          child: Card(
            color: _isFlipped ? flippedColor : cardColor,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(term.term, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isFlipped
                        ? Text(term.definition, key: const ValueKey('def'), style: TextStyle(fontSize: 20, color: textColor))
                        : Text('Tap to flip', key: const ValueKey('prompt'), style: TextStyle(fontSize: 18, color: theme.hintColor)),
                  ),
                ],
              ),
            ),
          ),
        );
      case 'mcq':
        final question = item.data as Question;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question.questionText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...List.generate(question.options.length, (i) => RadioListTile<int>(
                      value: i,
                      groupValue: _selectedOption,
                      onChanged: _showFeedback ? null : (val) => setState(() => _selectedOption = val),
                      title: Text('${String.fromCharCode(65 + i)}. ${question.options[i]}'),
                    )),
                const SizedBox(height: 12),
                if (!_showFeedback)
                  ElevatedButton(
                    onPressed: _selectedOption == null
                        ? null
                        : () {
                            setState(() {
                              _showFeedback = true;
                              _isCorrect = _selectedOption == question.correctAnswer;
                            });
                          },
                    child: const Text('Check Answer'),
                  ),
                if (_showFeedback)
                  Text(
                    _isCorrect ? 'Correct!' : 'Incorrect',
                    style: TextStyle(
                      color: _isCorrect ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
              ],
            ),
          ),
        );
      case 'concept':
        final concept = item.data as ConceptContent;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(concept.conceptText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                if (concept.exampleText != null) ...[
                  const SizedBox(height: 12),
                  Text(concept.exampleText!, style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
