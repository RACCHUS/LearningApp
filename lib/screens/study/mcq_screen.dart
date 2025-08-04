import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/providers/study_provider.dart';

class McqScreen extends ConsumerStatefulWidget {
  final List<Question> questions;
  final int initialIndex;
  final VoidCallback? onComplete;

  const McqScreen({
    super.key,
    required this.questions,
    this.initialIndex = 0,
    this.onComplete,
  });

  @override
  ConsumerState<McqScreen> createState() => _McqScreenState();
}

class _McqScreenState extends ConsumerState<McqScreen> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;
  late AnimationController _animationController;
  int? _selectedOption;
  bool _showFeedback = false;
  bool _isCorrect = false;
  bool _isLastQuestion = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _updateLastQuestionState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _updateLastQuestionState() {
    _isLastQuestion = _currentIndex == widget.questions.length - 1;
  }

  void _onOptionSelected(int? value) {
    if (_showFeedback) return;
    
    setState(() {
      _selectedOption = value;
    });
  }

  void _checkAnswer() {
    if (_selectedOption == null) return;
    
    final currentQuestion = widget.questions[_currentIndex];
    final isCorrect = _selectedOption == currentQuestion.correctAnswer;
    
    // Update study progress
    if (isCorrect) {
      ref.read(studyProvider.notifier).markAnswerCorrect();
    } else {
      ref.read(studyProvider.notifier).markAnswerIncorrect();
    }
    
    setState(() {
      _isCorrect = isCorrect;
      _showFeedback = true;
    });
    
    _animationController.forward();
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // End of quiz
      setState(() {
        _isComplete = true;
      });
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
      // Do not pop automatically; show persistent button instead
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _selectedOption = null;
      _showFeedback = false;
      _animationController.reset();
      _updateLastQuestionState();
    });
  }

  Widget _buildOption(int index, String text, Question question) {
    final bool isSelected = _selectedOption == index;
    bool showCorrect = _showFeedback && index == question.correctAnswer;
    bool showIncorrect = _showFeedback && isSelected && !_isCorrect;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () => _onOptionSelected(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: showCorrect
                ? Colors.green.shade100
                : showIncorrect
                    ? Colors.red.shade100
                    : isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: showCorrect
                  ? Colors.green
                  : showIncorrect
                      ? Colors.red
                      : isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    color: showCorrect || showIncorrect
                        ? Colors.black87
                        : Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: showCorrect || showIncorrect
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (showCorrect) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
              ] else if (showIncorrect) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.cancel,
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    if (!_showFeedback) return const SizedBox.shrink();
    
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isCorrect ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isCorrect ? Colors.green.shade200 : Colors.red.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isCorrect ? Icons.check_circle : Icons.info,
                color: _isCorrect ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isCorrect 
                      ? 'Correct! Well done! 🎉' 
                      : 'Not quite. The correct answer is: ${widget.questions[_currentIndex].options[widget.questions[_currentIndex].correctAnswer]}',
                  style: TextStyle(
                    color: _isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _nextQuestion,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isLastQuestion ? 'Finish' : 'Next Question',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / widget.questions.length;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} of ${widget.questions.length}'),
        centerTitle: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.questions.length,
            itemBuilder: (context, index) {
              final currentQuestion = widget.questions[index];
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Question
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          currentQuestion.questionText,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Options
                    ...currentQuestion.options.asMap().entries.map(
                      (entry) => _buildOption(entry.key, entry.value, currentQuestion),
                    ),
                    // Feedback and next button
                    _buildFeedback(),
                    // Submit button (only shows when an option is selected and feedback isn't shown)
                    if (!_showFeedback) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selectedOption == null ? null : _checkAnswer,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Check Answer',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
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
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
}
