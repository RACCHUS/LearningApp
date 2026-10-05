import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/lesson_block.dart';

class FormulaBlockWidget extends StatelessWidget {
  final LessonBlock block;
  final double fontSizeFactor;

  const FormulaBlockWidget({
    super.key,
    required this.block,
    this.fontSizeFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final latex = block.content['latex'] as String? ??
        block.content['formula'] as String? ??
        block.content['expression'] as String? ??
        '';
    final name = block.content['name'] as String? ??
        block.content['title'] as String?;
    final explanation = block.content['explanation'] as String? ??
        block.content['notes'] as String?;
    final variables = block.content['variables'] as Map?;

    if (latex.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.4) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (name != null && name.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.functions_rounded,
                  size: 18 * fontSizeFactor,
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5 * fontSizeFactor,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // LaTeX Equation Rendering
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Math.tex(
                  latex,
                  textStyle: TextStyle(
                    fontSize: 18 * fontSizeFactor,
                    color: isDark ? const Color(0xFFE0E7FF) : const Color(0xFF1E1B4B),
                  ),
                  onErrorFallback: (err) {
                    return Text(
                      latex,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14 * fontSizeFactor,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (explanation != null && explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              explanation,
              style: GoogleFonts.inter(
                fontSize: 13.5 * fontSizeFactor,
                height: 1.4,
                color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3),
              ),
            ),
          ],
          if (variables != null && variables.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: variables.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${entry.key}: ',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.5 * fontSizeFactor,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: GoogleFonts.inter(
                        fontSize: 12.5 * fontSizeFactor,
                        color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
