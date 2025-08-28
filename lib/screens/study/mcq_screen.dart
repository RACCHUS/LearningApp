import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/widgets/audio/audio_mcq_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';

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

class _McqScreenState extends ConsumerState<McqScreen> {
  late int _currentIndex;
  late PageController _pageController;
  bool _showFeedback = false;
  bool _isCorrect = false;
  bool _isComplete = false;
  int _correctAnswers = 0;

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
      _showFeedback = false;
      _isCorrect = false;
    });
  }

  void _onAnswerSelected(int selectedIndex) {
    setState(() {
      _showFeedback = true;
      _isCorrect = selectedIndex == widget.questions[_currentIndex].correctAnswer;
      if (_isCorrect) {
        _correctAnswers++;
      }
    });

    // Track answer in study provider
    if (_isCorrect) {
      ref.read(studyProvider.notifier).markAnswerCorrect();
    } else {
      ref.read(studyProvider.notifier).markAnswerIncorrect();
    }
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() {
        _isComplete = true;
      });
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('MCQ (${_currentIndex + 1}/${widget.questions.length})'),
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
                value: (_currentIndex + 1) / widget.questions.length,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.questions.length,
                  itemBuilder: (context, index) {
                    final currentQuestion = widget.questions[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          AudioMCQWidget(
                            questionText: currentQuestion.questionText,
                            options: currentQuestion.options,
                            correctAnswer: currentQuestion.correctAnswer,
                            explanation: currentQuestion.explanation,
                            showResults: _showFeedback,
                            onAnswerSelected: _onAnswerSelected,
                            customTextBuilder: (text) {
                              // Check if text contains LaTeX
                              if (text.contains(r'\(') || text.contains(r'\[') || 
                                  text.contains(r'\frac') || text.contains(r'\sqrt')) {
                                return Math.tex(
                                  text,
                                  textStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }
                              return Text(
                                text,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                          
                          // Next button (only shows when feedback is shown)
                          if (_showFeedback) ...[
                            const SizedBox(height: 32),
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
                                  _currentIndex < widget.questions.length - 1 
                                    ? 'Next Question' 
                                    : 'Finish Quiz',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
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
                          Icons.quiz,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Quiz Complete!',
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Score: $_correctAnswers/${widget.questions.length}',
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
                                  _showFeedback = false;
                                  _correctAnswers = 0;
                                });
                                _pageController.animateToPage(
                                  0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: const Text('Try Again'),
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
