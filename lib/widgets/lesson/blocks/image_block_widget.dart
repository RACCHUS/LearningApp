import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/models/lesson_block.dart';

class ImageBlockWidget extends StatelessWidget {
  final LessonBlock block;
  final double fontSizeFactor;

  const ImageBlockWidget({
    super.key,
    required this.block,
    this.fontSizeFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final url = block.content['url'] as String? ??
        block.content['src'] as String? ??
        block.content['asset'] as String? ??
        '';
    final caption = block.content['caption'] as String? ??
        block.content['alt'] as String? ??
        block.metadata['caption'] as String?;

    if (url.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final isNetwork = url.startsWith('http://') || url.startsWith('https://');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => _openZoomDialog(context, url, isNetwork, caption),
                child: isNetwork
                    ? Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => _buildPlaceholder(context, url),
                      )
                    : Image.asset(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => _buildPlaceholder(context, url),
                      ),
              ),
            ),
          ),
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                caption,
                style: GoogleFonts.inter(
                  fontSize: 12.5 * fontSizeFactor,
                  fontStyle: FontStyle.italic,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, String path) {
    return Container(
      height: 160,
      color: Colors.grey.withValues(alpha: 0.1),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_rounded, size: 36, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'Diagram / Image: $path',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openZoomDialog(BuildContext context, String url, bool isNetwork, String? caption) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: isNetwork
                      ? Image.network(url, fit: BoxFit.contain)
                      : Image.asset(url, fit: BoxFit.contain),
                ),
              ),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    caption,
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
