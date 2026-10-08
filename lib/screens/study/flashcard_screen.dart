import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/session_result.dart';
import 'package:learning_pwa/models/settings_model.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/screens/study/session_results_screen.dart';
import 'package:learning_pwa/widgets/audio/audio_flashcard_widget.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:learning_pwa/widgets/global_voice_indicator.dart';
import 'package:learning_pwa/widgets/study/break_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  final List<Term> terms;
  final int initialIndex;
  final VoidCallback? onComplete;
  final bool isEmbeddedInLesson;

  const FlashcardScreen({
    super.key,
    required this.terms,
    this.initialIndex = 0,
    this.onComplete,
    this.isEmbeddedInLesson = false,
  });

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  late int _currentIndex;
  late PageController _pageController;
  bool _isComplete = false;
  bool _isBatchComplete = false;
  bool _focusMode = false;
  bool _isRevealed = false;
  bool _recallBeforeReveal = true;
  int _batchSize = 15;
  int _batchStartIndex = 0;
  final Set<String> _difficultTermIds = {};
  final Set<String> _currentBatchDifficultIds = {};
  final Set<String> _studiedTermIds = {};
  late List<Term> _activeTerms;
  final DateTime _sessionStart = DateTime.now();

  int get _currentBatchNumber =>
      _batchSize > 0 ? (_batchStartIndex ~/ _batchSize) + 1 : 1;

  int get _totalBatches =>
      _batchSize > 0 ? (widget.terms.length / _batchSize).ceil() : 1;

  int get _currentBatchEndIndex => _batchSize > 0
      ? math.min(_batchStartIndex + _batchSize, widget.terms.length)
      : widget.terms.length;

  bool get _hasNextBatch =>
      _batchSize > 0 && _currentBatchEndIndex < widget.terms.length;

  @override
  void initState() {
    super.initState();
    _activeTerms = widget.terms;
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('settings');
    final settings = raw == null
        ? SettingsModel.defaultSettings()
        : SettingsModel.fromRawJson(raw);
    if (!mounted) return;

    final safeInitialIndex = widget.terms.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.terms.length - 1);
    var batchStart = 0;
    var localIndex = safeInitialIndex;
    var activeTerms = widget.terms;

    if (settings.studyBatchSize > 0 &&
        settings.studyBatchSize < widget.terms.length) {
      batchStart =
          (safeInitialIndex ~/ settings.studyBatchSize) * settings.studyBatchSize;
      final end =
          math.min(batchStart + settings.studyBatchSize, widget.terms.length);
      activeTerms = widget.terms.sublist(batchStart, end);
      localIndex = safeInitialIndex - batchStart;
    }

    setState(() {
      _recallBeforeReveal = settings.recallBeforeReveal;
      _batchSize = settings.studyBatchSize;
      _batchStartIndex = batchStart;
      _activeTerms = activeTerms;
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

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isRevealed = false;
    });
  }

  void _revealCurrentCard() {
    setState(() {
      _isRevealed = true;
    });
  }

  void _hideCurrentCard() {
    setState(() {
      _isRevealed = false;
    });
  }

  void _onKnowIt() {
    final termId = _activeTerms[_currentIndex].id;
    _studiedTermIds.add(termId);
    _difficultTermIds.remove(termId);
    _currentBatchDifficultIds.remove(termId);
    ref.read(studyProvider.notifier).markTermAsKnown(termId);
    _nextCard();
  }

  void _onDontKnow() {
    final termId = _activeTerms[_currentIndex].id;
    _studiedTermIds.add(termId);
    _difficultTermIds.add(termId);
    _currentBatchDifficultIds.add(termId);
    ref.read(studyProvider.notifier).markTermAsDifficult(termId);
    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex < _activeTerms.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Reached the end of this batch
      if (_hasNextBatch) {
        setState(() {
          _isBatchComplete = true;
        });
      } else {
        setState(() {
          _isComplete = true;
        });
        if (widget.onComplete != null) {
          widget.onComplete!();
        }
      }
    }
  }

  void _continueToNextBatch() {
    final nextStart = _currentBatchEndIndex;
    if (nextStart < widget.terms.length) {
      final nextEnd = math.min(nextStart + _batchSize, widget.terms.length);
      setState(() {
        _batchStartIndex = nextStart;
        _activeTerms = widget.terms.sublist(nextStart, nextEnd);
        _currentIndex = 0;
        _isRevealed = false;
        _isBatchComplete = false;
        _currentBatchDifficultIds.clear();
      });
      _pageController.jumpToPage(0);
    }
  }

  void _reviewDifficultInBatch() {
    if (_currentBatchDifficultIds.isEmpty) return;
    final difficultTerms = widget.terms
        .where((t) => _currentBatchDifficultIds.contains(t.id))
        .toList();
    setState(() {
      _activeTerms = difficultTerms;
      _currentIndex = 0;
      _isRevealed = false;
      _isBatchComplete = false;
    });
    _pageController.jumpToPage(0);
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
    final totalCards = widget.terms.length;
    final overallCardNumber = _batchStartIndex + _currentIndex + 1;

    return Scaffold(
      appBar: widget.isEmbeddedInLesson
          ? null
          : _focusMode
              ? null
              : AppBar(
                  title: Text(
                    _batchSize > 0 && totalCards > _batchSize
                        ? 'Flashcards ($overallCardNumber/$totalCards • Batch $_currentBatchNumber/$_totalBatches)'
                        : 'Flashcards (${_currentIndex + 1}/${_activeTerms.length})',
                  ),
                  centerTitle: true,
                  elevation: 0,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  foregroundColor: theme.colorScheme.onSurface,
                  actions: [
                    IconButton(
                      icon: Icon(_recallBeforeReveal
                          ? Icons.psychology
                          : Icons.psychology_outlined),
                      tooltip: _recallBeforeReveal
                          ? 'Recall Practice: Active'
                          : 'Recall Practice: Instant',
                      onPressed: () {
                        setState(() {
                          _recallBeforeReveal = !_recallBeforeReveal;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _recallBeforeReveal
                                  ? 'Active Recall mode enabled'
                                  : 'Instant Reveal mode enabled',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
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
              // Minimal progress bar in focus mode
              if (_focusMode && !widget.isEmbeddedInLesson) ...[
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: overallCardNumber / totalCards,
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
              ],

              // Active recall / self-assessment state indicator banner
              if (_recallBeforeReveal && _activeTerms.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isRevealed
                          ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.4)
                          : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isRevealed
                            ? theme.colorScheme.secondary.withValues(alpha: 0.3)
                            : theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isRevealed
                              ? Icons.rate_review_outlined
                              : Icons.psychology_outlined,
                          size: 16,
                          color: _isRevealed
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isRevealed
                              ? 'Self-Assessment: Did you recall it accurately?'
                              : 'Active Recall: Try to retrieve the answer first',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _isRevealed
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activeTerms.length,
                  itemBuilder: (context, index) {
                    final term = _activeTerms[index];
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: AudioFlashcardWidget(
                        frontText: term.term,
                        backText: term.definition,
                        example: term.example,
                        emoji: term.emoji,
                        isRevealed: index == _currentIndex ? _isRevealed : false,
                        onFlipChanged: (val) {
                          if (index == _currentIndex) {
                            setState(() => _isRevealed = val);
                          }
                        },
                        showFlipButton: !_recallBeforeReveal,
                        autoPlayOverride: widget.isEmbeddedInLesson ? false : null,
                        frontStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        backStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        customTextBuilder: (text) {
                          if (text.contains(r'\(') ||
                              text.contains(r'\[') ||
                              text.contains(r'\frac') ||
                              text.contains(r'\sqrt')) {
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

              // Bottom action bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: _recallBeforeReveal && !_isRevealed
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _revealCurrentCard,
                              icon: const Icon(Icons.visibility),
                              label: const Text('Reveal Definition'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap button or card to check answer',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
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
                          if (_recallBeforeReveal) ...[
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: _hideCurrentCard,
                              icon: const Icon(Icons.flip_to_front, size: 16),
                              label: const Text('Hide definition'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ],
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
                          '${_studiedTermIds.length} of $totalCards cards studied.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _currentBatchEndIndex / totalCards,
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
                        if (_currentBatchDifficultIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _reviewDifficultInBatch,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                'Review ${_currentBatchDifficultIds.length} Difficult Cards in Batch',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            final missedTerms = widget.terms
                                .where((t) => _difficultTermIds.contains(t.id))
                                .map((t) => MissedTerm(term: t))
                                .toList();
                            final result = SessionResult(
                              mode: SessionMode.flashcards,
                              correct:
                                  _studiedTermIds.length - _difficultTermIds.length,
                              total: _studiedTermIds.length,
                              missedTerms: missedTerms,
                              duration: DateTime.now().difference(_sessionStart),
                            );
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => SessionResultsScreen(result: result),
                              ),
                            );
                          },
                          child: const Text('Finish Session Early'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Deck Complete Overlay
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
                        const SizedBox(height: 8),
                        Text(
                          '${totalCards - _difficultTermIds.length}/$totalCards known',
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
                                  final end = (_batchSize > 0 && _batchSize < widget.terms.length)
                                      ? _batchSize
                                      : widget.terms.length;
                                  _activeTerms = widget.terms.sublist(0, end);
                                  _currentIndex = 0;
                                  _isComplete = false;
                                  _isBatchComplete = false;
                                  _isRevealed = false;
                                  _difficultTermIds.clear();
                                  _currentBatchDifficultIds.clear();
                                  _studiedTermIds.clear();
                                });
                                _pageController.jumpToPage(0);
                              },
                              child: const Text('Study Again'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final missedTerms = widget.terms
                                    .where((t) => _difficultTermIds.contains(t.id))
                                    .map((t) => MissedTerm(term: t))
                                    .toList();
                                final result = SessionResult(
                                  mode: SessionMode.flashcards,
                                  correct: totalCards - _difficultTermIds.length,
                                  total: totalCards,
                                  missedTerms: missedTerms,
                                  duration: DateTime.now().difference(_sessionStart),
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
      floatingActionButton: widget.isEmbeddedInLesson || _focusMode
          ? null
          : const GlobalVoiceFAB(heroTag: "flashcardVoiceFAB"),
    );
  }
}
