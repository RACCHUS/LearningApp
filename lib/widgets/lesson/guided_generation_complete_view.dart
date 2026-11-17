import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/generation_session.dart';
import '../../services/content_quality_service.dart';

/// The "complete" step of guided lesson generation: the assembled lesson,
/// its review summary and validation, and the import button.
///
/// Moved unchanged from `GuidedGenerationScreen` (code-efficiency plan §14,
/// Phase 2). The screen owns the session and the import itself; this view
/// only shows the result and calls [onImport].
class GuidedGenerationCompleteView extends StatefulWidget {
  const GuidedGenerationCompleteView({
    super.key,
    required this.session,
    required this.isImporting,
    required this.onImport,
  });

  final GenerationSession session;
  final bool isImporting;
  final Future<void> Function(String lessonJson) onImport;

  @override
  State<GuidedGenerationCompleteView> createState() =>
      _GuidedGenerationCompleteViewState();
}

class _GuidedGenerationCompleteViewState
    extends State<GuidedGenerationCompleteView> {
  @override
  Widget build(BuildContext context) =>
      _buildCompleteView(widget.session, Theme.of(context));

  Widget _buildCompleteView(GenerationSession session, ThemeData theme) {
    final assembled = session.assemble();
    final prettyJson =
        const JsonEncoder.withIndent('  ').convert(assembled);

    // Check for MCQs needing review
    final questions = assembled['questions'] as List<Map<String, dynamic>>? ?? [];
    final reviewItems = questions
        .where((q) => q['_needs_review'] == true)
        .toList();
    // Unresolved answer keys block import; quality hints alone do not.
    final answerErrorItems = questions
        .where((q) => q['_answer_error'] != null)
        .toList();
    final canImport = answerErrorItems.isEmpty;

    // Run manifest validation if plan is available
    ManifestValidationResult? validationResult;
    if (session.lessonPlan != null) {
      validationResult = ManifestValidator.validate(
        lessonPlan: session.lessonPlan!,
        generatedContent: session.allContent,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Lesson Generation Complete!',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${session.terms.length} terms · '
                  '${session.concepts.length} concepts · '
                  '${session.mcqs.length} MCQs',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Needs-review warning for MCQs with answer mismatches
          if (reviewItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${reviewItems.length} MCQ(s) need review',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    answerErrorItems.isEmpty
                        ? 'These are quality notes. You can import now and '
                            'improve them later.'
                        : '${answerErrorItems.length} question(s) have no '
                            'clear correct answer. LearningApp will not guess '
                            'one. Fix them in the MCQ step (or copy the JSON '
                            'and correct "correct_answer"), then import.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  for (final q in reviewItems)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• ${q['question']}: ${q['_review_reason']}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Manifest validation results
          if (validationResult != null &&
              !validationResult.isValid) ...[
            const SizedBox(height: 12),
            _buildValidationCard(validationResult, theme),
          ],

          // Review summary (if review was done)
          if (session.reviewResult != null) ...[
            const SizedBox(height: 16),
            _buildReviewSummary(session, theme),
          ],

          const SizedBox(height: 24),

          // Action buttons
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (widget.isImporting || !canImport)
                  ? null
                  : () => widget.onImport(prettyJson),
              icon: widget.isImporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              label: Text(widget.isImporting
                  ? 'Importing…'
                  : canImport
                      ? 'Import Lesson'
                      : 'Fix answers to import'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: prettyJson));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Lesson JSON copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy JSON'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // JSON preview
          Text('Assembled Lesson JSON', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 400),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                prettyJson,
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSummary(GenerationSession session, ThemeData theme) {
    final summary =
        session.reviewResult?['review_summary'] as Map<String, dynamic>?;
    if (summary == null) return const SizedBox.shrink();

    final issues = (summary['issues_found'] as List?)?.cast<String>() ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review Summary', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              '${summary['items_passed']}/${summary['total_items']} items passed · '
              '${summary['items_revised']} revised',
            ),
            if (issues.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final issue in issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(issue, style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidationCard(
      ManifestValidationResult result, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.isValid ? Icons.verified : Icons.warning_amber_rounded,
                  size: 20,
                  color: result.isValid ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text('Content Validation', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${result.completenessScore.toStringAsFixed(0)}% complete',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            if (result.missingItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Missing content:',
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold)),
              for (final item in result.missingItems)
                Text('  • $item', style: theme.textTheme.bodySmall),
            ],
            if (result.terminologyDrifts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Terminology issues:',
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold)),
              for (final drift in result.terminologyDrifts)
                Text('  • $drift', style: theme.textTheme.bodySmall),
            ],
            if (result.mcqIssues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('MCQ issues:',
                  style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold)),
              for (final issue in result.mcqIssues)
                Text('  • $issue', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
