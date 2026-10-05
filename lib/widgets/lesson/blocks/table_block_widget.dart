import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/lesson_block.dart';

class TableBlockWidget extends StatelessWidget {
  final LessonBlock block;
  final double fontSizeFactor;

  const TableBlockWidget({
    super.key,
    required this.block,
    this.fontSizeFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final title = block.content['title'] as String?;
    final headersRaw = block.content['headers'] as List?;
    final rowsRaw = block.content['rows'] as List?;
    final markdownTable = block.content['markdown'] as String? ??
        block.content['table'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null && title.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Icon(
                      Icons.table_chart_rounded,
                      size: 16 * fontSizeFactor,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14 * fontSizeFactor,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            if (headersRaw != null && rowsRaw != null)
              _buildStructuredTable(context, headersRaw, rowsRaw, isDark)
            else if (markdownTable != null && markdownTable.isNotEmpty)
              _buildMarkdownTable(context, markdownTable, isDark)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredTable(
    BuildContext context,
    List<dynamic> headersRaw,
    List<dynamic> rowsRaw,
    bool isDark,
  ) {
    final headers = headersRaw.map((h) => h.toString()).toList();
    final rows = rowsRaw
        .whereType<List>()
        .map((r) => r.map((c) => c.toString()).toList())
        .toList();

    final baseFontSize = 13.5 * fontSizeFactor;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        ),
        dataRowColor: WidgetStateProperty.resolveWith<Color>((states) {
          return Colors.transparent;
        }),
        headingTextStyle: GoogleFonts.outfit(
          fontSize: baseFontSize,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        dataTextStyle: GoogleFonts.inter(
          fontSize: baseFontSize,
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
        ),
        columns: headers
            .map((h) => DataColumn(
                  label: Text(h),
                ))
            .toList(),
        rows: rows.asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value;
          final isEven = idx % 2 == 0;
          return DataRow(
            color: WidgetStateProperty.all(
              isEven
                  ? Colors.transparent
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : const Color(0xFFF8FAFC)),
            ),
            cells: row.map((cell) => DataCell(Text(cell))).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMarkdownTable(BuildContext context, String markdown, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: MarkdownBody(
          data: markdown,
          styleSheet: MarkdownStyleSheet(
            tableHead: GoogleFonts.outfit(
              fontSize: 13.5 * fontSizeFactor,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            tableBody: GoogleFonts.inter(
              fontSize: 13.5 * fontSizeFactor,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
            tableBorder: TableBorder.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
