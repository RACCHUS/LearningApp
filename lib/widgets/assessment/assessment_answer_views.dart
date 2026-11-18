import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/assessment_item.dart';

// Answer views for AssessmentItemRenderer, one per interaction type.
// Moved from assessment_item_renderer.dart (code-efficiency plan §14,
// Phase 3). They only display and report taps: all answer state, scoring
// (_gradeWith / _gradeOnServer) and exam-mode reporting stay in the
// renderer, which owns the answer-key boundary.

class SingleChoiceAnswerView extends StatelessWidget {
  const SingleChoiceAnswerView({
    super.key,
    required this.item,
    required this.revealedItem,
    required this.presentationOrder,
    required this.selected,
    required this.submitted,
    required this.isDark,
    required this.onSelect,
  });

  /// Options come from [item]; correctness (after submit) from [revealedItem].
  final AssessmentItem item;
  final AssessmentItem revealedItem;
  final List<int> presentationOrder;
  final int? selected;
  final bool submitted;
  final bool isDark;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final optionsRaw = item.responseSpec['options'] as List? ?? [];
    final options = optionsRaw.map((o) => o.toString()).toList();
    final correctIdx =
        revealedItem.scoringSpec['correct_index'] as int? ??
        revealedItem.scoringSpec['correct_answer'] as int? ??
        0;

    final presentation =
        presentationOrder.isNotEmpty &&
            presentationOrder.length == options.length
        ? presentationOrder
        : List.generate(options.length, (i) => i);

    return Column(
      children: presentation.asMap().entries.map((presentationEntry) {
        final slotIndex = presentationEntry.key;
        final origIdx = presentationEntry.value;
        final text = options[origIdx];
        final isSelected = selected == origIdx;

        Color? borderColor;
        Color? bgColor;

        if (submitted) {
          if (origIdx == correctIdx) {
            borderColor = const Color(0xFF10B981);
            bgColor = const Color(
              0xFF10B981,
            ).withValues(alpha: isDark ? 0.2 : 0.08);
          } else if (isSelected) {
            borderColor = const Color(0xFFEF4444);
            bgColor = const Color(
              0xFFEF4444,
            ).withValues(alpha: isDark ? 0.2 : 0.08);
          }
        } else if (isSelected) {
          borderColor = Theme.of(context).colorScheme.primary;
          bgColor = Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.08);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: InkWell(
            onTap: submitted
                ? null
                : () => onSelect(origIdx),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:
                    bgColor ??
                    (isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      borderColor ??
                      (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                  width: isSelected || (submitted && origIdx == correctIdx)
                      ? 1.5
                      : 1.0,
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
                      String.fromCharCode(65 + slotIndex),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        color: isDark
                            ? Colors.grey[100]
                            : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  if (submitted && origIdx == correctIdx)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  if (submitted && isSelected && origIdx != correctIdx)
                    const Icon(
                      Icons.cancel_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class MultiSelectAnswerView extends StatelessWidget {
  const MultiSelectAnswerView({
    super.key,
    required this.item,
    required this.revealedItem,
    required this.presentationOrder,
    required this.selected,
    required this.submitted,
    required this.isDark,
    required this.onToggle,
  });

  final AssessmentItem item;
  final AssessmentItem revealedItem;
  final List<int> presentationOrder;
  final Set<int> selected;
  final bool submitted;
  final bool isDark;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final optionsRaw = item.responseSpec['options'] as List? ?? [];
    final options = optionsRaw.map((o) => o.toString()).toList();
    final List<dynamic> correctIndicesRaw =
        revealedItem.scoringSpec['correct_indices'] as List? ?? [];
    final correctSet = correctIndicesRaw.map((e) => (e as num).toInt()).toSet();

    final presentation =
        presentationOrder.isNotEmpty &&
            presentationOrder.length == options.length
        ? presentationOrder
        : List.generate(options.length, (i) => i);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_box_outlined,
                size: 14,
                color: Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 6),
              Text(
                'Select all that apply (${selected.length} selected)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ),
        ...presentation.asMap().entries.map((presentationEntry) {
          final origIdx = presentationEntry.value;
          final text = options[origIdx];
          final isSelected = selected.contains(origIdx);
          final isCorrectChoice = correctSet.contains(origIdx);

          Color? borderColor;
          Color? bgColor;

          if (submitted) {
            if (isCorrectChoice) {
              borderColor = const Color(0xFF10B981);
              bgColor = const Color(
                0xFF10B981,
              ).withValues(alpha: isDark ? 0.2 : 0.08);
            } else if (isSelected) {
              borderColor = const Color(0xFFEF4444);
              bgColor = const Color(
                0xFFEF4444,
              ).withValues(alpha: isDark ? 0.2 : 0.08);
            }
          } else if (isSelected) {
            borderColor = Theme.of(context).colorScheme.primary;
            bgColor = Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.08);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: InkWell(
              onTap: submitted
                  ? null
                  : () => onToggle(origIdx),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      bgColor ??
                      (isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        borderColor ??
                        (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                    width: isSelected || (submitted && isCorrectChoice)
                        ? 1.5
                        : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
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
                          color: isDark
                              ? Colors.grey[100]
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (submitted && isCorrectChoice)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    if (submitted && isSelected && !isCorrectChoice)
                      const Icon(
                        Icons.cancel_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class OrderedResponseAnswerView extends StatelessWidget {
  const OrderedResponseAnswerView({
    super.key,
    required this.orderedItems,
    required this.submitted,
    required this.isDark,
    required this.onReorder,
  });

  final List<String> orderedItems;
  final bool submitted;
  final bool isDark;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
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
          itemCount: orderedItems.length,
          onReorder: submitted
              ? (oldIdx, newIdx) {}
              : onReorder,
          itemBuilder: (ctx, index) {
            final itemText = orderedItems[index];
            return Container(
              key: ValueKey(itemText),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
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
                  if (!submitted)
                    const Icon(
                      Icons.drag_indicator_rounded,
                      color: Colors.grey,
                      size: 20,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class MatchingAnswerView extends StatelessWidget {
  const MatchingAnswerView({
    super.key,
    required this.item,
    required this.selectedKey,
    required this.matches,
    required this.submitted,
    required this.isDark,
    required this.onPickKey,
    required this.onMatch,
  });

  final AssessmentItem item;
  final String? selectedKey;
  final Map<String, String> matches;
  final bool submitted;
  final bool isDark;
  final ValueChanged<String> onPickKey;
  final ValueChanged<String> onMatch;

  @override
  Widget build(BuildContext context) {
    final keysRaw =
        item.responseSpec['left_items'] as List? ??
        item.responseSpec['keys'] as List? ??
        const [];
    final valuesRaw =
        item.responseSpec['right_items'] as List? ??
        item.responseSpec['values'] as List? ??
        const [];
    final keys = keysRaw.map((e) => e.toString()).toList();
    final values = valuesRaw.map((e) => e.toString()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap a prompt on the left, then tap its matching response on the right:',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Keys
            Expanded(
              child: Column(
                children: keys.map((key) {
                  final isSelected = selectedKey == key;
                  final hasMatch = matches.containsKey(key);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: submitted
                          ? null
                          : () => onPickKey(key),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.12)
                              : (hasMatch
                                    ? (isDark
                                          ? const Color(
                                              0xFF1E3A8A,
                                            ).withValues(alpha: 0.3)
                                          : const Color(0xFFEFF6FF))
                                    : (isDark
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFF8FAFC))),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : (hasMatch
                                      ? const Color(0xFF3B82F6)
                                      : (isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0))),
                          ),
                        ),
                        child: Text(
                          key,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
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
                  final isMatched = matches.containsValue(val);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: submitted || selectedKey == null
                          ? null
                          : () => onMatch(val),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMatched
                              ? (isDark
                                    ? const Color(
                                        0xFF1E3A8A,
                                      ).withValues(alpha: 0.3)
                                    : const Color(0xFFEFF6FF))
                              : (isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isMatched
                                ? const Color(0xFF3B82F6)
                                : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0)),
                          ),
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
}
