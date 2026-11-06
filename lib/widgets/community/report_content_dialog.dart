import 'package:flutter/material.dart';
import 'package:learning_pwa/models/governance/moderation_report.dart';
import 'package:learning_pwa/services/governance/moderation_service.dart';

/// Modal dialog allowing learners to submit a moderation report on community questions or answers (ECO-00B & ECO-01).
class ReportContentDialog extends StatefulWidget {
  final ModerationTargetType targetType;
  final String targetId;
  final String contentSnippet;
  final ModerationService moderationService;

  const ReportContentDialog({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.contentSnippet,
    required this.moderationService,
  });

  /// Displays the report dialog and returns true if a report was successfully lodged.
  static Future<bool?> show(
    BuildContext context, {
    required ModerationTargetType targetType,
    required String targetId,
    required String contentSnippet,
    required ModerationService moderationService,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ReportContentDialog(
        targetType: targetType,
        targetId: targetId,
        contentSnippet: contentSnippet,
        moderationService: moderationService,
      ),
    );
  }

  @override
  State<ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<ReportContentDialog> {
  ReportReason _selectedReason = ReportReason.spam;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.moderationService.submitReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _selectedReason,
        description: _detailsController.text.trim().isNotEmpty
            ? _detailsController.text.trim()
            : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you. Your report has been submitted for editorial and moderator review.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().contains('42501')
            ? 'Sign in required to submit moderation reports.'
            : 'Failed to submit report. Please try again later.';
      });
    }
  }

  String _reasonLabel(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return 'Spam or unsolicited advertising';
      case ReportReason.harassment:
        return 'Harassment, hate speech, or abuse';
      case ReportReason.misinformation:
        return 'Inaccurate or harmful factual claim';
      case ReportReason.copyright:
        return 'Copyright infringement / unlicensed text';
      case ReportReason.minorSafety:
        return 'Child safety or minor privacy concern';
      case ReportReason.inappropriate:
        return 'Inappropriate or offensive content';
      case ReportReason.other:
        return 'Other violation';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.flag_outlined, color: colorScheme.error),
          const SizedBox(width: 8),
          const Expanded(child: Text('Report Content')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Our moderation team reviews reports against our Community Guidelines and Child Safety standards.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // Content preview
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${widget.contentSnippet}"',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),

            // Reason selector
            Text(
              'Reason for reporting:',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<ReportReason>(
              value: _selectedReason,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: ReportReason.values.map((reason) {
                return DropdownMenuItem(
                  value: reason,
                  child: Text(
                    _reasonLabel(reason),
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
            ),
            const SizedBox(height: 16),

            // Optional details
            Text(
              'Additional details (optional):',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Describe why this content violates community standards...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('submit_report_button'),
          onPressed: _isSubmitting ? null : _submitReport,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}
