import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/session_result.dart';
import 'package:learning_pwa/models/settings_model.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/screens/study/session_results_screen.dart';
import 'package:learning_pwa/widgets/audio/audio_mcq_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:shared_preferences/shared_preferences.dart';

class McqScreen extends ConsumerStatefulWidget {
  final List<Question> questions;
  final int initialIndex;
  final VoidCallback? onComplete;
  final bool isEmbeddedInLesson; // New parameter for lesson mode

  const McqScreen({
    super.key,
    required this.questions,
    this.initialIndex = 0,
    this.onComplete,
    this.isEmbeddedInLesson = false, // Default to false for standalone mode
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
  bool _focusMode = false;
  int _correctAnswers = 0;
  int? _selectedAnswerIndex; // Track selected answer for state persistence
  final Map<String, int> _wrongAnswers = {}; // questionId -> selectedIndex
  late List<Question> _activeQuestions;

  @override
  void initState() {
    super.initState();
    _activeQuestions = widget.questions;
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadBatchSize();
    
    // Check if this question was already answered
    _checkForExistingAnswer();
  }

  Future<void> _loadBatchSize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('settings');
    if (raw != null) {
      final settings = SettingsModel.fromRawJson(raw);
      if (settings.studyBatchSize > 0 && settings.studyBatchSize < widget.questions.length) {
        setState(() {
          _activeQuestions = widget.questions.sublist(0, settings.studyBatchSize);
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _checkForExistingAnswer() {
    if (widget.isEmbeddedInLesson) {
      final studyState = ref.read(studyProvider);
      final currentQuestion = _activeQuestions[_currentIndex];
      final savedAnswer = studyState.questionAnswers[currentQuestion.id];
      
      if (savedAnswer != null) {
        setState(() {
          _selectedAnswerIndex = savedAnswer;
          _showFeedback = true;
          _isCorrect = savedAnswer == currentQuestion.correctAnswer;
        });
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _showFeedback = false;
      _isCorrect = false;
      _selectedAnswerIndex = null;
    });
    // Check for existing answer on the new page
    _checkForExistingAnswer();
  }

  void _onAnswerSelected(int selectedIndex) {
    final currentQuestion = _activeQuestions[_currentIndex];
    
    setState(() {
      _selectedAnswerIndex = selectedIndex;
      _showFeedback = true;
      _isCorrect = selectedIndex == currentQuestion.correctAnswer;
      if (_isCorrect) {
        _correctAnswers++;
      } else {
        _wrongAnswers[currentQuestion.id] = selectedIndex;
      }
    });

    // Record answer in study provider for lesson mode
    if (widget.isEmbeddedInLesson) {
      ref.read(studyProvider.notifier).recordQuestionAnswer(
        currentQuestion.id, 
        selectedIndex
      );
    }

    // Track answer in study provider
    if (_isCorrect) {
      ref.read(studyProvider.notifier).markAnswerCorrect();
    } else {
      ref.read(studyProvider.notifier).markAnswerIncorrect();
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _activeQuestions.length - 1) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      // Only show AppBar when not embedded in lesson mode
      appBar: widget.isEmbeddedInLesson ? null : _focusMode ? null : AppBar(
        title: Text('MCQ (${_currentIndex + 1}/${_activeQuestions.length})'),
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
              // Minimal progress bar — in focus mode show with exit button, otherwise just the bar
              if (_focusMode && !widget.isEmbeddedInLesson) ...[
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (_currentIndex + 1) / _activeQuestions.length,
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
              ] else ...[
                // Progress indicator (default)
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / _activeQuestions.length,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ],
              
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activeQuestions.length,
                  itemBuilder: (context, index) {
                    final currentQuestion = _activeQuestions[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          AudioMCQWidget(
                            questionText: currentQuestion.questionText,
                            options: currentQuestion.options,
                            correctAnswer: currentQuestion.correctAnswer,
                            selectedAnswer: _selectedAnswerIndex,
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
                          
                          // Next button (only shows when feedback is shown and not in lesson mode)
                          if (_showFeedback && !widget.isEmbeddedInLesson) ...[
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
                                  _currentIndex < _activeQuestions.length - 1 
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
                          'Score: $_correctAnswers/${_activeQuestions.length}',
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
                                  _wrongAnswers.clear();
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
                              onPressed: () {
                                final missedQuestions = _activeQuestions
                                    .where((q) => _wrongAnswers.containsKey(q.id))
                                    .map((q) => MissedQuestion(
                                          question: q,
                                          selectedAnswer: _wrongAnswers[q.id]!,
                                        ))
                                    .toList();
                                final result = SessionResult(
                                  mode: SessionMode.mcq,
                                  correct: _correctAnswers,
                                  total: _activeQuestions.length,
                                  missedQuestions: missedQuestions,
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
        ],
      ),
    );
  }
}
