import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/lesson_block.dart';

class PracticePromptBlockWidget extends StatefulWidget {
  final LessonBlock block;
  final double fontSizeFactor;

  const PracticePromptBlockWidget({
    super.key,
    required this.block,
    this.fontSizeFactor = 1.0,
  });

  @override
  State<PracticePromptBlockWidget> createState() => _PracticePromptBlockWidgetState();
}

class _PracticePromptBlockWidgetState extends State<PracticePromptBlockWidget> {
  bool _revealed = false;
  int? _selectedOptionIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final prompt = widget.block.content['prompt'] as String? ??
        widget.block.content['question'] as String? ??
        '';
    final optionsRaw = widget.block.content['options'] as List?;
    final answer = widget.block.content['answer'] as String? ??
        widget.block.content['correct_answer']?.toString();
    final explanation = widget.block.content['explanation'] as String?;

    final options = optionsRaw?.map((o) => o.toString()).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _revealed
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: _revealed ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _revealed
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      size: 16,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PRACTICE RETRIEVAL',
                    style: GoogleFonts.outfit(
                      fontSize: 11 * widget.fontSizeFactor,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8B5CF6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Active Recall Check',
                    style: GoogleFonts.inter(
                      fontSize: 11.5 * widget.fontSizeFactor,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            // Prompt Body
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prompt,
                    style: GoogleFonts.outfit(
                      fontSize: 15.5 * widget.fontSizeFactor,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      height: 1.4,
                    ),
                  ),
                  // Multiple choice options if present
                  if (options != null && options.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...options.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final optionText = entry.value;
                      final isSelected = _selectedOptionIndex == idx;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedOptionIndex = idx);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                                    ),
                                  ),
                                  child: Text(
                                    String.fromCharCode(65 + idx),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    optionText,
                                    style: GoogleFonts.inter(
                                      fontSize: 14 * widget.fontSizeFactor,
                                      color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  // Reveal / Toggle button
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _revealed = !_revealed);
                        },
                        icon: Icon(
                          _revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 16 * widget.fontSizeFactor,
                        ),
                        label: Text(
                          _revealed ? 'Hide Explanation' : 'Check Recall & Answer',
                          style: GoogleFonts.inter(
                            fontSize: 13 * widget.fontSizeFactor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _revealed
                              ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                              : theme.colorScheme.primary,
                          foregroundColor: _revealed
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Animated Revealed Explanation
                  if (_revealed) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.25)
                            : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (answer != null && answer.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                                const SizedBox(width: 6),
                                Text(
                                  'Answer: ',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5 * widget.fontSizeFactor,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    answer,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5 * widget.fontSizeFactor,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF064E3B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (explanation != null && explanation.isNotEmpty)
                            MarkdownBody(
                              data: explanation,
                              styleSheet: MarkdownStyleSheet(
                                p: GoogleFonts.inter(
                                  fontSize: 13.5 * widget.fontSizeFactor,
                                  height: 1.45,
                                  color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF065F46),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
