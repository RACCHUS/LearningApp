import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/lesson_block.dart';

class MarkdownBlockWidget extends StatelessWidget {
  final LessonBlock block;
  final double fontSizeFactor;

  const MarkdownBlockWidget({
    super.key,
    required this.block,
    this.fontSizeFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bodyText = block.content['body'] as String? ??
        block.content['text'] as String? ??
        block.content['markdown'] as String? ??
        '';

    if (bodyText.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final baseFontSize = 16.0 * fontSizeFactor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: MarkdownBody(
        data: bodyText,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: GoogleFonts.inter(
            fontSize: baseFontSize,
            height: 1.6,
            color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
            letterSpacing: 0.15,
          ),
          h1: GoogleFonts.outfit(
            fontSize: baseFontSize * 1.6,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            height: 1.3,
          ),
          h2: GoogleFonts.outfit(
            fontSize: baseFontSize * 1.35,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
            height: 1.35,
          ),
          h3: GoogleFonts.outfit(
            fontSize: baseFontSize * 1.15,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            height: 1.4,
          ),
          strong: const TextStyle(fontWeight: FontWeight.bold),
          em: const TextStyle(fontStyle: FontStyle.italic),
          listBullet: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: baseFontSize,
          ),
          blockquote: TextStyle(
            color: isDark ? Colors.grey[300] : const Color(0xFF475569),
            fontStyle: FontStyle.italic,
          ),
          blockquoteDecoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(
                color: theme.colorScheme.primary,
                width: 4,
              ),
            ),
          ),
          code: GoogleFonts.jetBrainsMono(
            fontSize: baseFontSize * 0.9,
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
