import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/lesson_block.dart';

class CodeBlockWidget extends StatefulWidget {
  final LessonBlock block;
  final double fontSizeFactor;

  const CodeBlockWidget({
    super.key,
    required this.block,
    this.fontSizeFactor = 1.0,
  });

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _copied = false;

  void _copyToClipboard(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      setState(() => _copied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.block.content['language'] as String? ??
        widget.block.content['lang'] as String? ??
        'code';
    final code = widget.block.content['code'] as String? ??
        widget.block.content['text'] as String? ??
        '';
    final caption = widget.block.content['caption'] as String? ??
        widget.block.metadata['caption'] as String?;
    final output = widget.block.content['output'] as String?;

    if (code.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final lines = code.split('\n');
    final baseFontSize = 13.5 * widget.fontSizeFactor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Deep Slate Navy
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar with macOS-style dots, language badge, and copy button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  // Decorative terminal dots
                  Row(
                    children: [
                      Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Language badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      language.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11 * widget.fontSizeFactor,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (caption != null && caption.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        caption,
                        style: GoogleFonts.inter(
                          fontSize: 12 * widget.fontSizeFactor,
                          color: const Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  // Copy Button
                  InkWell(
                    onTap: () => _copyToClipboard(code),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 14 * widget.fontSizeFactor,
                            color: _copied ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _copied ? 'Copied' : 'Copy',
                            style: GoogleFonts.inter(
                              fontSize: 12 * widget.fontSizeFactor,
                              color: _copied ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Code Content with Line Numbers
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line numbers column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(
                        lines.length,
                        (index) => Text(
                          '${index + 1}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: baseFontSize,
                            height: 1.5,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Code content column
                    SelectableText(
                      code,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: baseFontSize,
                        height: 1.5,
                        color: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Optional Terminal Execution Output Section
            if (output != null && output.trim().isNotEmpty) ...[
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                  color: Color(0xFF0B1120),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.terminal_rounded, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Text(
                          'OUTPUT',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5 * widget.fontSizeFactor,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      output,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.5 * widget.fontSizeFactor,
                        height: 1.4,
                        color: const Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
