import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/session_result.dart';
import 'package:learning_pwa/models/settings_model.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/screens/study/session_results_screen.dart';
import 'package:learning_pwa/widgets/audio/audio_mcq_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:learning_pwa/widgets/study/break_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

class McqScreen extends ConsumerStatefulWidget {
  final List<Question> questions;
  final int initialIndex;
  final VoidCallback? onComplete;
  final bool isEmbeddedInLesson;

  const McqScreen({
    super.key,
    required this.questions,
    this.initialIndex = 0,
    this.onComplete,
    this.isEmbeddedInLesson = false,
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
  bool _isBatchComplete = false;
  bool _focusMode = false;
  int? _selectedAnswerIndex;
  final Set<String> _correctQuestionIds = {};
  final Set<String> _answeredQuestionIds = {};
  final Map<String, int> _wrongAnswers = {}; // questionId -> selectedIndex
  final Map<String, int> _currentBatchWrongAnswers = {};
  int _batchSize = 15;
  int _batchStartIndex = 0;
  late List<Question> _activeQuestions;
  final DateTime _sessionStart = DateTime.now();

  int get _currentBatchNumber =>
      _batchSize > 0 ? (_batchStartIndex ~/ _batchSize) + 1 : 1;

  int get _totalBatches =>
      _batchSize > 0 ? (widget.questions.length / _batchSize).ceil() : 1;

  int get _correctAnswers => _correctQuestionIds.length;

  int get _currentBatchEndIndex => _batchSize > 0
      ? math.min(_batchStartIndex + _batchSize, widget.questions.length)
      : widget.questions.length;

  bool get _hasNextBatch =>
      _batchSize > 0 && _currentBatchEndIndex < widget.questions.length;

  @override
  void initState() {
    super.initState();
    _activeQuestions = widget.questions;
    _currentIndex = widget.questions.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.questions.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);
    _loadBatchSize();
    _checkForExistingAnswer();
  }

  Future<void> _loadBatchSize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('settings');
    final settings = raw == null
        ? SettingsModel.defaultSettings()
        : SettingsModel.fromRawJson(raw);
    if (!mounted) return;

    final safeInitialIndex = widget.questions.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.questions.length - 1).toInt();
    var batchStart = 0;
    var localIndex = safeInitialIndex;
    var activeQuestions = widget.questions;

    if (settings.studyBatchSize > 0 &&
        settings.studyBatchSize < widget.questions.length) {
      batchStart = (safeInitialIndex ~/ settings.studyBatchSize) *
          settings.studyBatchSize;
      final end =
          math.min(batchStart + settings.studyBatchSize, widget.questions.length);
      activeQuestions = widget.questions.sublist(batchStart, end);
      localIndex = safeInitialIndex - batchStart;
    }

    setState(() {
      _batchSize = settings.studyBatchSize;
      _batchStartIndex = batchStart;
      _activeQuestions = activeQuestions;
      _currentIndex = localIndex;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(localIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _checkForExistingAnswer() {
    if (widget.isEmbeddedInLesson && _activeQuestions.isNotEmpty && _currentIndex < _activeQuestions.length) {
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
    _checkForExistingAnswer();
  }

  void _onAnswerSelected(int selectedIndex) {
    if (_showFeedback) return;

    final currentQuestion = _activeQuestions[_currentIndex];
    
    setState(() {
      _selectedAnswerIndex = selectedIndex;
      _showFeedback = true;
      _isCorrect = selectedIndex == currentQuestion.correctAnswer;
      _answeredQuestionIds.add(currentQuestion.id);

      if (_isCorrect) {
        _correctQuestionIds.add(currentQuestion.id);
        _wrongAnswers.remove(currentQuestion.id);
        _currentBatchWrongAnswers.remove(currentQuestion.id);
      } else {
        _correctQuestionIds.remove(currentQuestion.id);
        _wrongAnswers[currentQuestion.id] = selectedIndex;
        _currentBatchWrongAnswers[currentQuestion.id] = selectedIndex;
      }
    });

    if (widget.isEmbeddedInLesson) {
      ref.read(studyProvider.notifier).recordQuestionAnswer(
        currentQuestion.id, 
        selectedIndex,
      );
    }

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
      if (widget.isEmbeddedInLesson) {
        widget.onComplete?.call();
      } else if (_hasNextBatch) {
        setState(() {
          _isBatchComplete = true;
        });
      } else {
        setState(() {
          _isComplete = true;
        });
        widget.onComplete?.call();
      }
    }
  }

  void _continueToNextBatch() {
    final nextStart = _currentBatchEndIndex;
    if (nextStart < widget.questions.length) {
      final nextEnd = math.min(nextStart + _batchSize, widget.questions.length);
      setState(() {
        _batchStartIndex = nextStart;
        _activeQuestions = widget.questions.sublist(nextStart, nextEnd);
        _currentIndex = 0;
        _showFeedback = false;
        _isCorrect = false;
        _selectedAnswerIndex = null;
        _isBatchComplete = false;
        _currentBatchWrongAnswers.clear();
      });
      _pageController.jumpToPage(0);
    }
  }

  void _reviewIncorrectInBatch() {
    if (_currentBatchWrongAnswers.isEmpty) return;
    final incorrectQuestions = widget.questions
        .where((q) => _currentBatchWrongAnswers.containsKey(q.id))
        .toList();
    setState(() {
      _activeQuestions = incorrectQuestions;
      _currentIndex = 0;
      _showFeedback = false;
      _isCorrect = false;
      _selectedAnswerIndex = null;
      _isBatchComplete = false;
    });
    _pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalQuestions = widget.questions.length;
    final overallQuestionNumber = _batchStartIndex + _currentIndex + 1;

    return Scaffold(
      appBar: widget.isEmbeddedInLesson
          ? null
          : _focusMode
              ? null
              : AppBar(
                  title: Text(
                    _batchSize > 0 && totalQuestions > _batchSize
                        ? 'MCQ ($overallQuestionNumber/$totalQuestions • Batch $_currentBatchNumber/$_totalBatches)'
                        : 'MCQ (${_currentIndex + 1}/${_activeQuestions.length})',
                  ),
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
              if (_focusMode && !widget.isEmbeddedInLesson) ...[
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: overallQuestionNumber / totalQuestions,
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
                LinearProgressIndicator(
                  value: _batchSize > 0 && totalQuestions > _batchSize
                      ? overallQuestionNumber / totalQuestions
                      : (_currentIndex + 1) / (_activeQuestions.isEmpty ? 1 : _activeQuestions.length),
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
                              if (text.contains(r'\(') ||
                                  text.contains(r'\[') ||
                                  text.contains(r'\frac') ||
                                  text.contains(r'\sqrt')) {
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
                                      : _hasNextBatch
                                          ? 'Finish Batch'
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

          // Batch Checkpoint Overlay
          if (_isBatchComplete && !widget.isEmbeddedInLesson)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(28),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 56,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Batch $_currentBatchNumber of $_totalBatches Complete!',
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_answeredQuestionIds.length} of $totalQuestions questions answered.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _currentBatchEndIndex / totalQuestions,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _continueToNextBatch,
                            icon: const Icon(Icons.arrow_forward),
                            label: Text('Continue to Batch ${_currentBatchNumber + 1}'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_currentBatchWrongAnswers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _reviewIncorrectInBatch,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                'Review ${_currentBatchWrongAnswers.length} Missed Questions in Batch',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            final missedQuestions = widget.questions
                                .where((q) => _wrongAnswers.containsKey(q.id))
                                .map((q) => MissedQuestion(
                                      question: q,
                                      selectedAnswer: _wrongAnswers[q.id]!,
                                    ))
                                .toList();
                            final result = SessionResult(
                              mode: SessionMode.mcq,
                              correct: _correctAnswers,
                              total: _answeredQuestionIds.length,
                              missedQuestions: missedQuestions,
                              duration: DateTime.now().difference(_sessionStart),
                            );
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => SessionResultsScreen(result: result),
                              ),
                            );
                          },
                          child: const Text('Finish Quiz Early'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Final Quiz Completion overlay
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
                          'Score: $_correctAnswers/$totalQuestions',
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
                                  _batchStartIndex = 0;
                                  final end = (_batchSize > 0 && _batchSize < widget.questions.length)
                                      ? _batchSize
                                      : widget.questions.length;
                                  _activeQuestions = widget.questions.sublist(0, end);
                                  _currentIndex = 0;
                                  _isComplete = false;
                                  _isBatchComplete = false;
                                  _showFeedback = false;
                                  _correctQuestionIds.clear();
                                  _answeredQuestionIds.clear();
                                  _wrongAnswers.clear();
                                  _currentBatchWrongAnswers.clear();
                                });
                                _pageController.jumpToPage(0);
                              },
                              child: const Text('Try Again'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final missedQuestions = widget.questions
                                    .where((q) => _wrongAnswers.containsKey(q.id))
                                    .map((q) => MissedQuestion(
                                          question: q,
                                          selectedAnswer: _wrongAnswers[q.id]!,
                                        ))
                                    .toList();
                                final result = SessionResult(
                                  mode: SessionMode.mcq,
                                  correct: _correctAnswers,
                                  total: totalQuestions,
                                  missedQuestions: missedQuestions,
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
          if (!widget.isEmbeddedInLesson) const BreakOverlay(),
        ],
      ),
    );
  }
}
