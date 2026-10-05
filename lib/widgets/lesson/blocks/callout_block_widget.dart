import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/lesson_block.dart';

class CalloutBlockWidget extends StatelessWidget {
  final LessonBlock block;
  final double fontSizeFactor;

  const CalloutBlockWidget({
    super.key,
    required this.block,
    this.fontSizeFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final type = (block.content['callout_type'] as String? ??
            block.content['type'] as String? ??
            'note')
        .toLowerCase();
    final title = block.content['title'] as String? ?? _defaultTitleForType(type);
    final body = block.content['body'] as String? ??
        block.content['text'] as String? ??
        '';
    final example = block.content['example'] as String?;

    final style = _getCalloutStyle(type, isDark);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: style.borderColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accent color side strip
              Container(
                width: 5,
                color: style.accentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon and title badge
                      Row(
                        children: [
                          Icon(
                            style.icon,
                            color: style.accentColor,
                            size: 20 * fontSizeFactor,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: style.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _badgeLabel(type),
                              style: GoogleFonts.outfit(
                                fontSize: 11 * fontSizeFactor,
                                fontWeight: FontWeight.bold,
                                color: style.accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (title.isNotEmpty && title.toLowerCase() != type) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 15 * fontSizeFactor,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        MarkdownBody(
                          data: body,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.inter(
                              fontSize: 14.5 * fontSizeFactor,
                              height: 1.5,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                            ),
                            strong: const TextStyle(fontWeight: FontWeight.bold),
                            em: const TextStyle(fontStyle: FontStyle.italic),
                            code: GoogleFonts.jetBrainsMono(
                              fontSize: 13 * fontSizeFactor,
                              backgroundColor: isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                      if (example != null && example.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: style.borderColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.format_quote_rounded,
                                size: 16,
                                color: style.accentColor.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  example,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5 * fontSizeFactor,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? Colors.grey[300] : const Color(0xFF475569),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _defaultTitleForType(String type) {
    switch (type) {
      case 'exam_tip':
      case 'tip':
        return 'Exam Tip';
      case 'warning':
      case 'caution':
        return 'Caution';
      case 'clinical_pearl':
      case 'key_concept':
        return 'Key Concept';
      default:
        return 'Important Note';
    }
  }

  String _badgeLabel(String type) {
    switch (type) {
      case 'exam_tip':
        return 'EXAM TIP';
      case 'tip':
        return 'TIP';
      case 'warning':
        return 'WARNING';
      case 'caution':
        return 'CAUTION';
      case 'clinical_pearl':
        return 'CLINICAL PEARL';
      case 'key_concept':
        return 'KEY CONCEPT';
      default:
        return 'NOTE';
    }
  }

  _CalloutVisualTheme _getCalloutStyle(String type, bool isDark) {
    switch (type) {
      case 'exam_tip':
      case 'tip':
        return _CalloutVisualTheme(
          accentColor: const Color(0xFF10B981), // Emerald
          borderColor: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
          backgroundColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
          icon: Icons.lightbulb_rounded,
        );
      case 'warning':
      case 'caution':
        return _CalloutVisualTheme(
          accentColor: const Color(0xFFF59E0B), // Amber
          borderColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
          backgroundColor: isDark ? const Color(0xFF451A03).withValues(alpha: 0.3) : const Color(0xFFFFFBEB),
          icon: Icons.warning_amber_rounded,
        );
      case 'clinical_pearl':
      case 'key_concept':
        return _CalloutVisualTheme(
          accentColor: const Color(0xFF6366F1), // Indigo
          borderColor: isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE),
          backgroundColor: isDark ? const Color(0xFF312E81).withValues(alpha: 0.3) : const Color(0xFFEEF2FF),
          icon: Icons.auto_awesome_rounded,
        );
      default:
        return _CalloutVisualTheme(
          accentColor: const Color(0xFF3B82F6), // Blue
          borderColor: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE),
          backgroundColor: isDark ? const Color(0xFF172554).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
          icon: Icons.info_outline_rounded,
        );
    }
  }
}

class _CalloutVisualTheme {
  final Color accentColor;
  final Color borderColor;
  final Color backgroundColor;
  final IconData icon;

  const _CalloutVisualTheme({
    required this.accentColor,
    required this.borderColor,
    required this.backgroundColor,
    required this.icon,
  });
}
