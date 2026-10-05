import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/unified_lesson.dart';
import 'package:learning_pwa/widgets/lesson/blocks/lesson_block_renderer.dart';
import 'package:learning_pwa/widgets/provenance/provenance_inspector_sheet.dart';
import 'package:learning_pwa/widgets/assessment/assessment_item_renderer.dart';

/// Flagship Rich Lesson Block Reader for Phase D
/// 
/// Presents ordered polymorphic instructional blocks (Markdown, Callout, Code,
/// Table, Formula, Example, Practice Prompt, Image) with verified blueprint
/// citations, concept tags, adjustable typography, and integrated assessment.
class RichLessonReader extends StatefulWidget {
  final UnifiedLesson unifiedLesson;
  final VoidCallback? onCompleted;

  const RichLessonReader({
    super.key,
    required this.unifiedLesson,
    this.onCompleted,
  });

  @override
  State<RichLessonReader> createState() => _RichLessonReaderState();
}

class _RichLessonReaderState extends State<RichLessonReader> {
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;
  double _fontSizeFactor = 1.0;
  bool _showAssessmentSection = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll > 0) {
      final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
      if ((progress - _scrollProgress).abs() > 0.02) {
        setState(() => _scrollProgress = progress);
      }
    }
  }

  void _toggleFontSize() {
    setState(() {
      if (_fontSizeFactor == 1.0) {
        _fontSizeFactor = 1.15; // Large
      } else if (_fontSizeFactor == 1.15) {
        _fontSizeFactor = 0.9; // Compact
      } else {
        _fontSizeFactor = 1.0; // Standard
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unified = widget.unifiedLesson;
    final lesson = unified.lesson;
    final blocks = unified.effectiveBlocks;
    final items = unified.assessmentItems;
    final concepts = unified.concepts;
    final provenance = unified.provenance;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          lesson.title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3.0),
          child: LinearProgressIndicator(
            value: _scrollProgress,
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            minHeight: 3.0,
          ),
        ),
        actions: [
          // Provenance Blueprint Citation Chip
          if (provenance.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: ActionChip(
                avatar: const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF10B981)),
                label: Text(
                  'Blueprint',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10B981),
                  ),
                ),
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                side: BorderSide.none,
                onPressed: () => ProvenanceInspectorSheet.show(
                  context,
                  provenanceList: provenance,
                  title: lesson.title,
                ),
              ),
            ),
          // Font Scaling Button
          IconButton(
            icon: const Icon(Icons.format_size_rounded),
            tooltip: 'Adjust text size',
            onPressed: _toggleFontSize,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // Lesson Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D31) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: GoogleFonts.outfit(
                        fontSize: 24 * _fontSizeFactor,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                    if (lesson.description != null && lesson.description!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        lesson.description!,
                        style: GoogleFonts.inter(
                          fontSize: 15 * _fontSizeFactor,
                          height: 1.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                    // Canonical Concept Badges
                    if (concepts.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: concepts.map((c) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hub_outlined, size: 13, color: Color(0xFF6366F1)),
                                const SizedBox(width: 5),
                                Text(
                                  c.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.grey[200] : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Ordered Lesson Blocks
              ...blocks.map((b) => LessonBlockRenderer(
                    block: b,
                    fontSizeFactor: _fontSizeFactor,
                  )),
              const SizedBox(height: 32),
              // Assessment & Retrieval Section
              if (items.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                          : [const Color(0xFFEEF2FF), const Color(0xFFF8FAFC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.quiz_rounded, color: Color(0xFF6366F1), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Knowledge Retrieval & Check',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                                  ),
                                ),
                                Text(
                                  '${items.length} interactive practice questions evaluate your readiness.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!_showAssessmentSection)
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _showAssessmentSection = true),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            'Begin Practice Evaluation (${items.length} items)',
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      if (_showAssessmentSection) ...[
                        const Divider(height: 24),
                        ...items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: AssessmentItemRenderer(item: item),
                            )),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Lesson Complete Action Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lesson Completed',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Your progress and retrieval evidence have been synced.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        widget.onCompleted?.call();
                        Navigator.of(context).maybePop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
