import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/services/assessment/assessment_grading_service.dart';
import 'package:learning_pwa/utils/voice_input_handler.dart';
import 'package:learning_pwa/widgets/assessment/assessment_answer_views.dart';
import 'package:learning_pwa/widgets/assessment/stimulus_viewer.dart';
import 'package:learning_pwa/widgets/mcq_options.dart';
import 'package:learning_pwa/widgets/lesson/blocks/markdown_math.dart';
import '../whiteboard/question_scratchpad.dart';

class AssessmentItemRenderer extends StatefulWidget {
  final AssessmentItem item;
  final VoidCallback? onCompleted;
  final VoidCallback? onRetry;
  final Function(bool isCorrect, double score)? onAnswerSubmitted;
  final bool isExamMode;
  final dynamic initialResponse;
  final ValueChanged<dynamic>? onResponseChanged;
  final bool shuffleOptions;
  final int? presentationSeed;
  final List<int>? avoidOrder;
  final ValueChanged<List<int>>? onPresentationOrderChanged;

  /// Grades items whose answer keys are hidden from the client.
  final AssessmentGradingService? gradingService;

  const AssessmentItemRenderer({
    super.key,
    required this.item,
    this.onCompleted,
    this.onRetry,
    this.onAnswerSubmitted,
    this.isExamMode = false,
    this.initialResponse,
    this.onResponseChanged,
    this.shuffleOptions = true,
    this.presentationSeed,
    this.avoidOrder,
    this.onPresentationOrderChanged,
    this.gradingService,
  });

  @override
  State<AssessmentItemRenderer> createState() => _AssessmentItemRendererState();
}

/// Public access to the renderer's answer-key rules, for tests and other
/// readers that must agree with it.
abstract final class AssessmentItemRendererKeys {
  static int? resolve(AssessmentItem item) =>
      _AssessmentItemRendererState.resolveSingleChoiceKey(item);
  static const unscorableMessage =
      _AssessmentItemRendererState.unscorableMessage;
}

/// Strict number parsing, matching the server grader: a plain decimal or
/// correctly grouped thousands ("1,200"); "0,6" or words are not numbers.
double? parseNumericAnswer(String raw) {
  final s = raw.trim().replaceAll('\u2212', '-');
  if (RegExp(r'^[+-]?(\d+(\.\d+)?|\.\d+)$').hasMatch(s)) {
    return double.tryParse(s);
  }
  if (RegExp(r'^[+-]?\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(s)) {
    return double.tryParse(s.replaceAll(',', ''));
  }
  return null;
}

class _AssessmentItemRendererState extends State<AssessmentItemRenderer> {
  static int _globalAttemptNonce = 0x5bf03635;

  // Option presentation mapping: index in presentation -> original option index
  List<int> _presentationOrder = [];
  List<int> get presentationOrder => List.unmodifiable(_presentationOrder);

  late int _localAttemptNonce;
  int get attemptNonce => widget.presentationSeed ?? _localAttemptNonce;

  // State for single choice
  int? _selectedSingleChoice;
  int? get selectedSingleChoice => _selectedSingleChoice;

  // State for multi-select (SATA)
  final Set<int> _selectedMultiIndices = {};

  // State for ordered response
  late List<String> _orderedItems;

  // State for matching
  final Map<String, String> _userMatches = {};
  String? _selectedMatchKey;

  // State for numeric entry
  final TextEditingController _numericController = TextEditingController();

  // Submission & evaluation state
  bool _submitted = false;
  bool _isCorrect = false;
  double _score = 0.0;
  String _feedbackMessage = '';

  // Server-revealed scoring for items whose keys are hidden from the client.
  AssessmentItem? _revealedItem;
  bool _grading = false;
  String? _gradingError;

  AssessmentItem get _item =>
      _revealedItem?.id == widget.item.id ? _revealedItem! : widget.item;

  @override
  void dispose() {
    _numericController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _localAttemptNonce = _nextLocalNonce(previousOrder: widget.avoidOrder);
    _initInteractionState(previousOrder: widget.avoidOrder);
  }

  int _nextLocalNonce({List<int>? previousOrder}) {
    final optionsRaw = widget.item.responseSpec['options'] as List?;
    final options = optionsRaw?.map((e) => e.toString()).toList();
    _globalAttemptNonce = McqOptions.nextPresentationNonce(
      currentNonce: _globalAttemptNonce ^ DateTime.now().microsecondsSinceEpoch,
      options: options,
      itemHash: widget.item.id.hashCode,
      previousOrder: previousOrder,
    );
    return _globalAttemptNonce;
  }

  static bool _nullableOrdersEqual(List<int>? a, List<int>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return McqOptions.listsEqual(a, b);
  }

  @override
  void didUpdateWidget(covariant AssessmentItemRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.initialResponse != widget.initialResponse ||
        oldWidget.presentationSeed != widget.presentationSeed ||
        !_nullableOrdersEqual(oldWidget.avoidOrder, widget.avoidOrder)) {
      final inStatePreviousOrder =
          (oldWidget.item.id == widget.item.id &&
              oldWidget.presentationSeed != widget.presentationSeed &&
              _presentationOrder.isNotEmpty)
          ? List<int>.from(_presentationOrder)
          : null;
      final effectivePreviousOrder = widget.avoidOrder ?? inStatePreviousOrder;
      if (widget.presentationSeed == null) {
        _localAttemptNonce = _nextLocalNonce(
          previousOrder: effectivePreviousOrder,
        );
      }
      _resetState();
      _initInteractionState(previousOrder: effectivePreviousOrder);
    }
  }

  /// Retries the current item with a fresh per-attempt nonce and option permutation.
  void retry() {
    if (widget.onRetry != null) {
      widget.onRetry!();
      return;
    }
    final previousOrder = _presentationOrder.isNotEmpty
        ? List<int>.from(_presentationOrder)
        : null;
    setState(() {
      _localAttemptNonce = _nextLocalNonce(previousOrder: previousOrder);
      _resetState();
      _initInteractionState(previousOrder: previousOrder);
    });
  }

  /// Selects a single-choice option via spoken input (e.g. "Option A", "B", "first")
  /// mapped through the current [presentationOrder].
  int? selectOptionByVoice(String voiceInput) {
    if (_submitted ||
        widget.item.interactionType != AssessmentInteractionType.singleChoice) {
      return null;
    }
    final optionsRaw = widget.item.responseSpec['options'] as List? ?? [];
    final mapped = VoiceInputHandler.mapSpokenChoiceToIndex(
      voiceInput,
      optionCount: optionsRaw.length,
      presentationOrder: _presentationOrder,
    );
    if (mapped != null) {
      setState(() => _selectedSingleChoice = mapped);
      if (widget.isExamMode) {
        widget.onResponseChanged?.call(mapped);
      }
    }
    return mapped;
  }

  void _resetState() {
    _presentationOrder.clear();
    _selectedSingleChoice = null;
    _selectedMultiIndices.clear();
    _userMatches.clear();
    _selectedMatchKey = null;
    _submitted = false;
    _isCorrect = false;
    _score = 0.0;
    _feedbackMessage = '';
    _grading = false;
    _gradingError = null;
  }

  void _initInteractionState({List<int>? previousOrder}) {
    final spec = widget.item.responseSpec;
    if (widget.item.interactionType == AssessmentInteractionType.numericEntry) {
      _numericController.text = widget.initialResponse?.toString() ?? '';
    }
    if (widget.item.interactionType == AssessmentInteractionType.singleChoice ||
        widget.item.interactionType == AssessmentInteractionType.multiSelect) {
      final optionsRaw = spec['options'] as List? ?? [];
      final count = optionsRaw.length;
      _presentationOrder = List.generate(count, (i) => i);

      if (widget.shuffleOptions && count > 1) {
        // Single-XOR Combination Contract: combine raw presentation nonce with item.id.hashCode once
        final rawNonce = widget.presentationSeed ?? _localAttemptNonce;
        final seed = rawNonce ^ widget.item.id.hashCode;
        final optionStrings = optionsRaw.map((e) => e.toString()).toList();
        _presentationOrder = McqOptions.computePresentationOrder(
          optionStrings,
          presentationSeed: seed,
          shuffle: true,
          avoidOrder: previousOrder ?? widget.avoidOrder,
        );
      }
      widget.onPresentationOrderChanged?.call(
        List.unmodifiable(_presentationOrder),
      );
    }

    if (widget.item.interactionType ==
        AssessmentInteractionType.orderedResponse) {
      if (widget.initialResponse is List) {
        _orderedItems = (widget.initialResponse as List)
            .map((e) => e.toString())
            .toList();
      } else {
        final itemsRaw = spec['items'] as List? ?? [];
        _orderedItems = itemsRaw.map((e) => e.toString()).toList();
      }
    } else if (widget.item.interactionType ==
        AssessmentInteractionType.singleChoice) {
      if (widget.initialResponse is int) {
        _selectedSingleChoice = widget.initialResponse as int;
      }
    } else if (widget.item.interactionType ==
        AssessmentInteractionType.multiSelect) {
      if (widget.initialResponse is Iterable) {
        _selectedMultiIndices.addAll(
          (widget.initialResponse as Iterable).map((e) => (e as num).toInt()),
        );
      }
    } else if (widget.item.interactionType ==
        AssessmentInteractionType.matching) {
      if (widget.initialResponse is Map) {
        _userMatches.addAll(
          (widget.initialResponse as Map).map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ),
        );
      }
    }
  }

  void _submitAnswer() {
    if (_submitted || _grading) return;
    if (_item.hasLocalScoringSpec) {
      _gradeWith(_item);
    } else {
      _gradeOnServer();
    }
  }

  dynamic _currentResponse() {
    switch (widget.item.interactionType) {
      case AssessmentInteractionType.singleChoice:
        return _selectedSingleChoice;
      case AssessmentInteractionType.multiSelect:
        return (_selectedMultiIndices.toList()..sort());
      case AssessmentInteractionType.orderedResponse:
        return List<String>.from(_orderedItems);
      case AssessmentInteractionType.matching:
        return Map<String, String>.from(_userMatches);
      case AssessmentInteractionType.numericEntry:
        return _numericController.text.trim();
      default:
        return null;
    }
  }

  Future<void> _gradeOnServer() async {
    final item = widget.item;
    setState(() {
      _grading = true;
      _gradingError = null;
    });
    try {
      final service = widget.gradingService ?? AssessmentGradingService();
      final revealed = await service.revealForResponse(
        item,
        _currentResponse(),
      );
      if (!mounted || widget.item.id != item.id) return;
      setState(() {
        _revealedItem = revealed;
        _grading = false;
      });
      _gradeWith(revealed);
    } on AssessmentGradingException catch (error) {
      if (!mounted) return;
      setState(() {
        _grading = false;
        _gradingError = error.message;
      });
    }
  }

  /// Shown instead of a score when an item's answer key cannot be trusted.
  static const unscorableMessage =
      "This question can't be checked: its answer key is missing or "
      'invalid. It was not scored.';

  /// The single-choice key, or `null` when it is missing, not an integer or
  /// outside the options. Never defaults to the first option (master plan
  /// v2.6 §14.8: no "auto-correct to answer A").
  static int? resolveSingleChoiceKey(AssessmentItem item) {
    final raw =
        item.scoringSpec['correct_index'] ?? item.scoringSpec['correct_answer'];
    final options = item.responseSpec['options'];
    if (raw is! int || options is! List) return null;
    return raw >= 0 && raw < options.length ? raw : null;
  }

  /// Leaves the item unscored: no correct/incorrect, no score and no
  /// [AssessmentItemRenderer.onAnswerSubmitted] call.
  void _markUnscorable() {
    setState(() => _gradingError = unscorableMessage);
  }

  void _gradeWith(AssessmentItem item) {
    final scoring = item.scoringSpec;

    bool correct = false;
    double score = 0.0;
    String feedback = '';

    switch (item.interactionType) {
      case AssessmentInteractionType.singleChoice:
        final correctIdx = resolveSingleChoiceKey(item);
        if (correctIdx == null) return _markUnscorable();
        correct = _selectedSingleChoice == correctIdx;
        score = correct ? 1.0 : 0.0;
        feedback = correct
            ? 'Practice evidence: Correct retrieval'
            : 'Needs reinforcement on this concept';
        break;

      case AssessmentInteractionType.multiSelect:
        final List<dynamic> correctIndicesRaw =
            scoring['correct_indices'] as List? ?? [];
        final optionCount = (item.responseSpec['options'] as List?)?.length;
        if (optionCount == null ||
            correctIndicesRaw.isEmpty ||
            correctIndicesRaw.any(
              (e) => e is! int || e < 0 || e >= optionCount,
            )) {
          return _markUnscorable();
        }
        final correctSet = correctIndicesRaw.cast<int>().toSet();
        final method = scoring['scoring_method'] as String? ?? 'all_or_nothing';

        if (method == 'all_or_nothing') {
          correct =
              _selectedMultiIndices.length == correctSet.length &&
              _selectedMultiIndices.containsAll(correctSet);
          score = correct ? 1.0 : 0.0;
        } else {
          // Partial credit: (correct selections - false selections) / total correct
          int correctSelected = _selectedMultiIndices
              .intersection(correctSet)
              .length;
          int incorrectSelected = _selectedMultiIndices
              .difference(correctSet)
              .length;
          int totalCorrect = correctSet.isNotEmpty ? correctSet.length : 1;
          score = ((correctSelected - incorrectSelected) / totalCorrect).clamp(
            0.0,
            1.0,
          );
          correct = score >= 0.99;
        }

        feedback = correct
            ? 'Practice evidence: All criteria identified'
            : (score > 0
                  ? 'Partial alignment: review all options'
                  : 'Needs reinforcement');
        break;

      case AssessmentInteractionType.orderedResponse:
        final items = (item.responseSpec['items'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
        final correctOrder = (scoring['correct_order'] as List? ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList();
        final hasValidOrder =
            items.isNotEmpty &&
            correctOrder.length == items.length &&
            correctOrder.every((index) => index >= 0 && index < items.length);
        if (!hasValidOrder) return _markUnscorable();
        final expectedOrder = hasValidOrder
            ? correctOrder.map((index) => items[index]).toList()
            : <String>[];

        correct =
            hasValidOrder &&
            _orderedItems.length == expectedOrder.length &&
            List.generate(
              expectedOrder.length,
              (i) => _orderedItems[i] == expectedOrder[i],
            ).every((value) => value);
        score = correct ? 1.0 : 0.0;
        feedback = correct
            ? 'Practice evidence: Sequential protocol validated'
            : 'Incorrect sequence. Compare with standard protocol below.';
        break;

      case AssessmentInteractionType.matching:
        final Map<String, dynamic> correctPairs =
            (scoring['correct_pairs'] as Map?)?.cast<String, dynamic>() ?? {};
        if (correctPairs.isEmpty) return _markUnscorable();
        int matchedCount = 0;
        correctPairs.forEach((k, v) {
          if (_userMatches[k] == v.toString()) {
            matchedCount++;
          }
        });
        int total = correctPairs.isNotEmpty ? correctPairs.length : 1;
        score = (matchedCount / total).clamp(0.0, 1.0);
        correct = score >= 0.99;
        feedback = correct
            ? 'Practice evidence: All relationships accurately paired'
            : 'Partial pairing: review concept relationships';
        break;

      case AssessmentInteractionType.numericEntry:
        final rawKey = scoring['correct_value'];
        if (rawKey is! num) return _markUnscorable();
        final rawTolerance = scoring['tolerance'];
        final tolerance = rawTolerance is num && rawTolerance > 0
            ? rawTolerance.toDouble()
            : 0.0;
        final given = parseNumericAnswer(_numericController.text);
        correct = given != null && (given - rawKey).abs() <= tolerance + 1e-12;
        score = correct ? 1.0 : 0.0;
        feedback = correct
            ? 'Practice evidence: Correct value'
            : given == null
            ? 'Enter a single number, such as 12 or 0.5'
            : 'Needs reinforcement on this concept';
        break;

      default:
        // Unsupported types are not graded as wrong.
        return _markUnscorable();
    }

    setState(() {
      _submitted = true;
      _isCorrect = correct;
      _score = score;
      _feedbackMessage = feedback;
    });

    widget.onAnswerSubmitted?.call(correct, score);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = _item;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stimulus Exhibit if present
          if (item.stimulus != null) ...[
            StimulusViewer(stimulus: item.stimulus!),
            const SizedBox(height: 12),
          ],
          // Question Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Interaction Type Badge & Cognitive Level
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _interactionLabel(item.interactionType),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.cognitiveLevel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.cognitiveLevel!.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.grey[300]
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _difficultyColor(
                          item.difficulty,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.difficulty.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: _difficultyColor(item.difficulty),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Question Prompt
                mathAwareText(
                  item.prompt,
                  GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 18),
                // Specialized Interactive Response Input
                _buildInteractionContent(context, isDark),
                const SizedBox(height: 20),
                // Submit Button
                if (!widget.isExamMode && !_submitted)
                  ElevatedButton(
                    onPressed: _canSubmit() && !_grading ? _submitAnswer : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _grading ? 'Checking…' : 'Check Answer',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (_gradingError != null && !_submitted) ...[
                  const SizedBox(height: 10),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _gradingError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
                // Submitted Feedback & Explanations
                if (!widget.isExamMode && _submitted) ...[
                  _buildFeedbackBanner(context, isDark),
                  if (item.explanation != null &&
                      item.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.school_rounded,
                                size: 16,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'CLINICAL / ARCHITECTURAL RATIONALE',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF3B82F6),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          mathAwareText(
                            item.explanation!,
                            GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.5,
                              color: isDark
                                  ? Colors.grey[200]
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: retry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          'Try Again',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      if (widget.onCompleted != null) ...[
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: widget.onCompleted,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'Next Question',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Opt-in scratchpad (learning.scratchpad); empty unless enabled.
          QuestionScratchpad(key: ValueKey('scratchpad-${item.id}')),
        ],
      ),
    );
  }

  bool _canSubmit() {
    switch (widget.item.interactionType) {
      case AssessmentInteractionType.singleChoice:
        return _selectedSingleChoice != null;
      case AssessmentInteractionType.multiSelect:
        return _selectedMultiIndices.isNotEmpty;
      case AssessmentInteractionType.orderedResponse:
        return true;
      case AssessmentInteractionType.numericEntry:
        return _numericController.text.trim().isNotEmpty;
      case AssessmentInteractionType.matching:
        final leftItems =
            widget.item.responseSpec['left_items'] as List? ??
            widget.item.responseSpec['keys'] as List? ??
            const [];
        return leftItems.isNotEmpty && _userMatches.length >= leftItems.length;
      default:
        return false;
    }
  }

  Widget _buildInteractionContent(BuildContext context, bool isDark) {
    switch (widget.item.interactionType) {
      case AssessmentInteractionType.singleChoice:
        return _buildSingleChoice(context, isDark);
      case AssessmentInteractionType.multiSelect:
        return _buildMultiSelect(context, isDark);
      case AssessmentInteractionType.orderedResponse:
        return _buildOrderedResponse(context, isDark);
      case AssessmentInteractionType.matching:
        return _buildMatching(context, isDark);
      case AssessmentInteractionType.numericEntry:
        return _buildNumericEntry(context);
      default:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'This interaction type is not yet supported in the lesson reader.',
          ),
        );
    }
  }

  // 1. Single Choice Renderer
  Widget _buildSingleChoice(BuildContext context, bool isDark) {
    return SingleChoiceAnswerView(
      item: widget.item,
      revealedItem: _item,
      presentationOrder: _presentationOrder,
      selected: _selectedSingleChoice,
      submitted: _submitted,
      isDark: isDark,
      onSelect: (origIdx) {
        setState(() => _selectedSingleChoice = origIdx);
        if (widget.isExamMode) {
          widget.onResponseChanged?.call(origIdx);
        }
      },
    );
  }

  // 2. Multi-Select (SATA) Renderer
  Widget _buildMultiSelect(BuildContext context, bool isDark) {
    return MultiSelectAnswerView(
      item: widget.item,
      revealedItem: _item,
      presentationOrder: _presentationOrder,
      selected: _selectedMultiIndices,
      submitted: _submitted,
      isDark: isDark,
      onToggle: (origIdx) {
        setState(() {
          if (_selectedMultiIndices.contains(origIdx)) {
            _selectedMultiIndices.remove(origIdx);
          } else {
            _selectedMultiIndices.add(origIdx);
          }
        });
        if (widget.isExamMode) {
          widget.onResponseChanged?.call(_selectedMultiIndices.toList());
        }
      },
    );
  }

  // 3. Ordered Response Renderer
  Widget _buildOrderedResponse(BuildContext context, bool isDark) {
    return OrderedResponseAnswerView(
      orderedItems: _orderedItems,
      submitted: _submitted,
      isDark: isDark,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _orderedItems.removeAt(oldIndex);
          _orderedItems.insert(newIndex, item);
        });
        if (widget.isExamMode) {
          widget.onResponseChanged?.call(List<String>.from(_orderedItems));
        }
      },
    );
  }

  // 4. Matching Renderer
  Widget _buildNumericEntry(BuildContext context) {
    return TextField(
      key: ValueKey('numeric-entry-${widget.item.id}'),
      controller: _numericController,
      enabled: !_submitted && !_grading,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) {
        if (_canSubmit()) _submitAnswer();
      },
      decoration: const InputDecoration(
        labelText: 'Your answer',
        hintText: 'A number, such as 12 or 0.5',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildMatching(BuildContext context, bool isDark) {
    return MatchingAnswerView(
      item: widget.item,
      selectedKey: _selectedMatchKey,
      matches: _userMatches,
      submitted: _submitted,
      isDark: isDark,
      onPickKey: (key) => setState(() => _selectedMatchKey = key),
      onMatch: (val) {
        setState(() {
          _userMatches[_selectedMatchKey!] = val;
          _selectedMatchKey = null;
        });
        if (widget.isExamMode) {
          widget.onResponseChanged?.call(
            Map<String, String>.from(_userMatches),
          );
        }
      },
    );
  }

  Widget _buildFeedbackBanner(BuildContext context, bool isDark) {
    final color = _isCorrect
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);
    final icon = _isCorrect
        ? Icons.check_circle_rounded
        : Icons.info_outline_rounded;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _feedbackMessage,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (_score > 0 && _score < 1.0)
            Text(
              '${(_score * 100).toInt()}% credit',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  String _interactionLabel(AssessmentInteractionType type) {
    switch (type) {
      case AssessmentInteractionType.singleChoice:
        return 'SINGLE CHOICE';
      case AssessmentInteractionType.multiSelect:
        return 'MULTI-SELECT (SATA)';
      case AssessmentInteractionType.orderedResponse:
        return 'ORDERED RESPONSE';
      case AssessmentInteractionType.matching:
        return 'MATCHING';
      case AssessmentInteractionType.matrixGrid:
        return 'MATRIX GRID';
      case AssessmentInteractionType.numericEntry:
        return 'NUMERIC ENTRY';
      case AssessmentInteractionType.cloze:
        return 'CLOZE';
      case AssessmentInteractionType.codeOutput:
        return 'CODE PREDICTION';
    }
  }

  Color _difficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF10B981);
      case 'advanced':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF3B82F6);
    }
  }
}
