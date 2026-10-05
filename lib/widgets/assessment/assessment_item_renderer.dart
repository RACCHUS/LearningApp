import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/widgets/assessment/stimulus_viewer.dart';

class AssessmentItemRenderer extends StatefulWidget {
  final AssessmentItem item;
  final VoidCallback? onCompleted;
  final Function(bool isCorrect, double score)? onAnswerSubmitted;

  const AssessmentItemRenderer({
    super.key,
    required this.item,
    this.onCompleted,
    this.onAnswerSubmitted,
  });

  @override
  State<AssessmentItemRenderer> createState() => _AssessmentItemRendererState();
}

class _AssessmentItemRendererState extends State<AssessmentItemRenderer> {
  // State for single choice
  int? _selectedSingleChoice;

  // State for multi-select (SATA)
  final Set<int> _selectedMultiIndices = {};

  // State for ordered response
  late List<String> _orderedItems;

  // State for matching
  final Map<String, String> _userMatches = {};
  String? _selectedMatchKey;

  // Submission & evaluation state
  bool _submitted = false;
  bool _isCorrect = false;
  double _score = 0.0;
  String _feedbackMessage = '';

  @override
  void initState() {
    super.initState();
    _initInteractionState();
  }

  @override
  void didUpdateWidget(covariant AssessmentItemRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _resetState();
      _initInteractionState();
    }
  }

  void _resetState() {
    _selectedSingleChoice = null;
    _selectedMultiIndices.clear();
    _userMatches.clear();
    _selectedMatchKey = null;
    _submitted = false;
    _isCorrect = false;
    _score = 0.0;
    _feedbackMessage = '';
  }

  void _initInteractionState() {
    final spec = widget.item.responseSpec;
    if (widget.item.interactionType == AssessmentInteractionType.orderedResponse) {
      final itemsRaw = spec['items'] as List? ?? [];
      _orderedItems = itemsRaw.map((e) => e.toString()).toList();
    }
  }

  void _submitAnswer() {
    if (_submitted) return;

    final item = widget.item;
    final scoring = item.scoringSpec;

    bool correct = false;
    double score = 0.0;
    String feedback = '';

    switch (item.interactionType) {
      case AssessmentInteractionType.singleChoice:
        final correctIdx = scoring['correct_index'] as int? ??
            scoring['correct_answer'] as int? ??
            0;
        correct = _selectedSingleChoice == correctIdx;
        score = correct ? 1.0 : 0.0;
        feedback = correct
            ? 'Practice evidence: Correct retrieval'
            : 'Needs reinforcement on this concept';
        break;

      case AssessmentInteractionType.multiSelect:
        final List<dynamic> correctIndicesRaw = scoring['correct_indices'] as List? ?? [];
        final correctSet = correctIndicesRaw.map((e) => (e as num).toInt()).toSet();
        final method = scoring['scoring_method'] as String? ?? 'all_or_nothing';

        if (method == 'all_or_nothing') {
          correct = _selectedMultiIndices.length == correctSet.length &&
              _selectedMultiIndices.containsAll(correctSet);
          score = correct ? 1.0 : 0.0;
        } else {
          // Partial credit: (correct selections - false selections) / total correct
          int correctSelected = _selectedMultiIndices.intersection(correctSet).length;
          int incorrectSelected = _selectedMultiIndices.difference(correctSet).length;
          int totalCorrect = correctSet.isNotEmpty ? correctSet.length : 1;
          score = ((correctSelected - incorrectSelected) / totalCorrect).clamp(0.0, 1.0);
          correct = score >= 0.99;
        }

        feedback = correct
            ? 'Practice evidence: All criteria identified'
            : (score > 0 ? 'Partial alignment: review all options' : 'Needs reinforcement');
        break;

      case AssessmentInteractionType.orderedResponse:
        final List<dynamic> correctSequence = scoring['correct_sequence'] as List? ??
            scoring['correct_order'] as List? ??
            [];
        correct = true;
        if (correctSequence.length == _orderedItems.length) {
          for (int i = 0; i < correctSequence.length; i++) {
            if (_orderedItems[i] != correctSequence[i].toString()) {
              correct = false;
              break;
            }
          }
        } else {
          correct = false;
        }
        score = correct ? 1.0 : 0.0;
        feedback = correct
            ? 'Practice evidence: Sequential protocol validated'
            : 'Incorrect sequence. Compare with standard protocol below.';
        break;

      case AssessmentInteractionType.matching:
        final Map<String, dynamic> correctPairs = (scoring['correct_pairs'] as Map?)?.cast<String, dynamic>() ?? {};
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

      default:
        correct = true;
        score = 1.0;
        feedback = 'Response recorded';
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
    final item = widget.item;

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
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.cognitiveLevel!.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _difficultyColor(item.difficulty).withValues(alpha: 0.12),
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
                Text(
                  item.prompt,
                  style: GoogleFonts.outfit(
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
                if (!_submitted)
                  ElevatedButton(
                    onPressed: _canSubmit() ? _submitAnswer : null,
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
                      'Check Answer',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                // Submitted Feedback & Explanations
                if (_submitted) ...[
                  _buildFeedbackBanner(context, isDark),
                  if (item.explanation != null && item.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.school_rounded, size: 16, color: Color(0xFF3B82F6)),
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
                          Text(
                            item.explanation!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.5,
                              color: isDark ? Colors.grey[200] : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
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
      case AssessmentInteractionType.matching:
        final pairs = widget.item.responseSpec['pairs'] as Map? ?? widget.item.responseSpec['keys'] as List? ?? [];
        return _userMatches.length >= (pairs is Map ? pairs.length : (pairs as List).length);
      default:
        return true;
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
      default:
        return _buildSingleChoice(context, isDark);
    }
  }

  // 1. Single Choice Renderer
  Widget _buildSingleChoice(BuildContext context, bool isDark) {
    final optionsRaw = widget.item.responseSpec['options'] as List? ?? [];
    final options = optionsRaw.map((o) => o.toString()).toList();
    final correctIdx = widget.item.scoringSpec['correct_index'] as int? ??
        widget.item.scoringSpec['correct_answer'] as int? ??
        0;

    return Column(
      children: options.asMap().entries.map((entry) {
        final idx = entry.key;
        final text = entry.value;
        final isSelected = _selectedSingleChoice == idx;

        Color? borderColor;
        Color? bgColor;

        if (_submitted) {
          if (idx == correctIdx) {
            borderColor = const Color(0xFF10B981);
            bgColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.08);
          } else if (isSelected) {
            borderColor = const Color(0xFFEF4444);
            bgColor = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.08);
          }
        } else if (isSelected) {
          borderColor = Theme.of(context).colorScheme.primary;
          bgColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: InkWell(
            onTap: _submitted ? null : () => setState(() => _selectedSingleChoice = idx),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor ?? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: borderColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  width: isSelected || (_submitted && idx == correctIdx) ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                      ),
                    ),
                    child: Text(
                      String.fromCharCode(65 + idx),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        color: isDark ? Colors.grey[100] : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  if (_submitted && idx == correctIdx)
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  if (_submitted && isSelected && idx != correctIdx)
                    const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 2. Multi-Select (SATA) Renderer
  Widget _buildMultiSelect(BuildContext context, bool isDark) {
    final optionsRaw = widget.item.responseSpec['options'] as List? ?? [];
    final options = optionsRaw.map((o) => o.toString()).toList();
    final List<dynamic> correctIndicesRaw = widget.item.scoringSpec['correct_indices'] as List? ?? [];
    final correctSet = correctIndicesRaw.map((e) => (e as num).toInt()).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_box_outlined, size: 14, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              Text(
                'Select all that apply (${_selectedMultiIndices.length} selected)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ),
        ...options.asMap().entries.map((entry) {
          final idx = entry.key;
          final text = entry.value;
          final isSelected = _selectedMultiIndices.contains(idx);
          final isCorrectChoice = correctSet.contains(idx);

          Color? borderColor;
          Color? bgColor;

          if (_submitted) {
            if (isCorrectChoice) {
              borderColor = const Color(0xFF10B981);
              bgColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.08);
            } else if (isSelected) {
              borderColor = const Color(0xFFEF4444);
              bgColor = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.08);
            }
          } else if (isSelected) {
            borderColor = Theme.of(context).colorScheme.primary;
            bgColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: InkWell(
              onTap: _submitted
                  ? null
                  : () {
                      setState(() {
                        if (_selectedMultiIndices.contains(idx)) {
                          _selectedMultiIndices.remove(idx);
                        } else {
                          _selectedMultiIndices.add(idx);
                        }
                      });
                    },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor ?? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: borderColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: isSelected || (_submitted && isCorrectChoice) ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : (isDark ? Colors.grey[500] : Colors.grey[400]),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          color: isDark ? Colors.grey[100] : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (_submitted && isCorrectChoice)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    if (_submitted && isSelected && !isCorrectChoice)
                      const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // 3. Ordered Response Renderer
  Widget _buildOrderedResponse(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Drag items into the correct chronological or operational sequence:',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _orderedItems.length,
          onReorder: _submitted
              ? (oldIdx, newIdx) {}
              : (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _orderedItems.removeAt(oldIndex);
                    _orderedItems.insert(newIndex, item);
                  });
                },
          itemBuilder: (ctx, index) {
            final itemText = _orderedItems[index];
            return Container(
              key: ValueKey(itemText),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      itemText,
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                  if (!_submitted)
                    const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 20),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // 4. Matching Renderer
  Widget _buildMatching(BuildContext context, bool isDark) {
    final keysRaw = widget.item.responseSpec['keys'] as List? ?? [];
    final valuesRaw = widget.item.responseSpec['values'] as List? ?? [];
    final keys = keysRaw.map((e) => e.toString()).toList();
    final values = valuesRaw.map((e) => e.toString()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap a prompt on the left, then tap its matching response on the right:',
          style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Keys
            Expanded(
              child: Column(
                children: keys.map((key) {
                  final isSelected = _selectedMatchKey == key;
                  final hasMatch = _userMatches.containsKey(key);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: _submitted ? null : () => setState(() => _selectedMatchKey = key),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                              : (hasMatch
                                  ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : (hasMatch
                                    ? const Color(0xFF3B82F6)
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                          ),
                        ),
                        child: Text(
                          key,
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 12),
            // Right Column: Values
            Expanded(
              child: Column(
                children: values.map((val) {
                  final isMatched = _userMatches.containsValue(val);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: _submitted || _selectedMatchKey == null
                          ? null
                          : () {
                              setState(() {
                                _userMatches[_selectedMatchKey!] = val;
                                _selectedMatchKey = null;
                              });
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMatched
                              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isMatched
                                ? const Color(0xFF3B82F6)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        ),
                        child: Text(
                          val,
                          style: GoogleFonts.inter(fontSize: 13.5),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackBanner(BuildContext context, bool isDark) {
    final color = _isCorrect ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final icon = _isCorrect ? Icons.check_circle_rounded : Icons.info_outline_rounded;

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
