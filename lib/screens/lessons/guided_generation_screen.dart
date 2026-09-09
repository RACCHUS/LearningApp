import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/generation_session.dart';
import '../../providers/generation_session_provider.dart';
import '../../services/ai_prompt_service.dart';
import '../../services/content_quality_service.dart';
import '../../services/lesson_service.dart';
import '../../providers/auth_provider.dart';

/// Step-by-step wizard that walks the user through multi-prompt lesson
/// generation: Plan → Terms → Concepts → MCQs → Review → Import.
class GuidedGenerationScreen extends ConsumerStatefulWidget {
  const GuidedGenerationScreen({
    super.key,
    this.initialSubject,
    this.initialAudience,
    this.initialDuration,
    this.initialDifficulty,
    this.initialFocus,
  });

  final String? initialSubject;
  final String? initialAudience;
  final int? initialDuration;
  final String? initialDifficulty;
  final String? initialFocus;

  @override
  ConsumerState<GuidedGenerationScreen> createState() =>
      _GuidedGenerationScreenState();
}

class _GuidedGenerationScreenState
    extends ConsumerState<GuidedGenerationScreen> {
  // --- Setup form controllers ------------------------------------------------
  final _subjectController = TextEditingController();
  String _targetAudience = 'beginner';
  int _durationMinutes = 30;
  String _difficulty = 'beginner';
  String _contentFocus = 'balanced';

  // --- Response pasting area -------------------------------------------------
  final _responseController = TextEditingController();
  bool _isImporting = false;
  bool _checkingRestore = true;

  @override
  void initState() {
    super.initState();
    final w = widget;
    if (w.initialSubject != null && w.initialSubject!.isNotEmpty) {
      _subjectController.text = w.initialSubject!;
    }
    if (w.initialAudience != null) _targetAudience = w.initialAudience!;
    if (w.initialDuration != null) _durationMinutes = w.initialDuration!;
    if (w.initialDifficulty != null) _difficulty = w.initialDifficulty!;
    if (w.initialFocus != null) _contentFocus = w.initialFocus!;

    // Try to restore a saved session
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    final current = ref.read(generationSessionProvider);
    if (current != null) {
      // Already have an active session
      if (mounted) setState(() => _checkingRestore = false);
      return;
    }

    final restored = await ref
        .read(generationSessionProvider.notifier)
        .tryRestore();

    if (mounted) {
      if (restored) {
        // Show option to resume or start fresh
        final resume = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final s = ref.read(generationSessionProvider);
            return AlertDialog(
              title: const Text('Resume Session?'),
              content: Text(
                'You have an in-progress session:\n\n'
                '"${s?.subject ?? 'Unknown'}"\n'
                'Phase: ${s?.phaseLabel ?? 'Unknown'}\n'
                '${s?.terms.length ?? 0} terms · '
                '${s?.concepts.length ?? 0} concepts · '
                '${s?.mcqs.length ?? 0} MCQs',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Start Fresh'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Resume'),
                ),
              ],
            );
          },
        );

        if (resume != true) {
          ref.read(generationSessionProvider.notifier).clearSession();
        }
      }
      setState(() => _checkingRestore = false);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(generationSessionProvider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: session == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Guided Lesson Generation'),
        ),
        body: _checkingRestore
            ? const Center(child: CircularProgressIndicator())
            : session == null
                ? _buildSetupForm(theme)
                : _buildPhasedWizard(session, theme),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0 — Setup form (before the session starts)
  // ---------------------------------------------------------------------------

  Widget _buildSetupForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Icon(Icons.auto_awesome, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('AI-Guided Generation',
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Generate high-quality lessons through a phased prompt pipeline. '
            'Each step builds on the previous one to maintain consistency.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),

          // Subject
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: 'Subject *',
              hintText: 'e.g. Python Variable Types',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Prior Knowledge Level
          DropdownButtonFormField<String>(
            value: _targetAudience,
            decoration: const InputDecoration(
              labelText: 'Prior Knowledge Level',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
              DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
              DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
              DropdownMenuItem(value: 'professional', child: Text('Professional')),
            ],
            onChanged: (v) => setState(() => _targetAudience = v!),
          ),
          const SizedBox(height: 16),

          // Duration slider
          Text('Duration: $_durationMinutes min',
              style: theme.textTheme.titleSmall),
          Slider(
            value: _durationMinutes.toDouble(),
            min: 15,
            max: 120,
            divisions: 21,
            label: '$_durationMinutes min',
            onChanged: (v) =>
                setState(() => _durationMinutes = v.round()),
          ),
          const SizedBox(height: 16),

          // Difficulty
          DropdownButtonFormField<String>(
            value: _difficulty,
            decoration: const InputDecoration(
              labelText: 'Difficulty',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
              DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
              DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
            ],
            onChanged: (v) => setState(() => _difficulty = v!),
          ),
          const SizedBox(height: 16),

          // Content Focus
          DropdownButtonFormField<String>(
            value: _contentFocus,
            decoration: const InputDecoration(
              labelText: 'Content Focus',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'theoretical', child: Text('Theoretical')),
              DropdownMenuItem(value: 'practical', child: Text('Practical')),
              DropdownMenuItem(value: 'balanced', child: Text('Balanced')),
            ],
            onChanged: (v) => setState(() => _contentFocus = v!),
          ),

          const SizedBox(height: 32),

          // Start button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _subjectController.text.trim().isEmpty
                  ? null
                  : _startSession,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Generation'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16)),
            ),
          ),
        ],
      ),
    );
  }

  void _startSession() {
    ref.read(generationSessionProvider.notifier).startSession(
          subject: _subjectController.text.trim(),
          targetAudience: _targetAudience,
          durationMinutes: _durationMinutes,
          difficulty: _difficulty,
          contentFocus: _contentFocus,
        );
  }

  // ---------------------------------------------------------------------------
  // Phased wizard — shown after session is started
  // ---------------------------------------------------------------------------

  Widget _buildPhasedWizard(GenerationSession session, ThemeData theme) {
    return Column(
      children: [
        // Stepper header
        _buildStepper(session, theme),
        const Divider(height: 1),

        // Phase-specific content
        Expanded(
          child: session.currentPhase == GenerationPhase.complete
              ? _buildCompleteView(session, theme)
              : _buildPromptResponseView(session, theme),
        ),
      ],
    );
  }

  Widget _buildStepper(GenerationSession session, ThemeData theme) {
    final phases = GenerationPhase.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < phases.length; i++) ...[
            _stepChip(phases[i], session.currentPhase, theme),
            if (i < phases.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right,
                    size: 16, color: theme.colorScheme.outlineVariant),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stepChip(
      GenerationPhase phase, GenerationPhase current, ThemeData theme) {
    final isActive = phase == current;
    final isDone = phase.index < current.index;

    Color bg;
    Color fg;
    if (isDone) {
      bg = theme.colorScheme.primaryContainer;
      fg = theme.colorScheme.onPrimaryContainer;
    } else if (isActive) {
      bg = theme.colorScheme.primary;
      fg = theme.colorScheme.onPrimary;
    } else {
      bg = theme.colorScheme.surfaceContainerHighest;
      fg = theme.colorScheme.onSurfaceVariant;
    }

    return Chip(
      avatar: isDone
          ? Icon(Icons.check_circle, size: 18, color: fg)
          : null,
      label: Text(phase.label, style: TextStyle(color: fg, fontSize: 12)),
      backgroundColor: bg,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // ---------------------------------------------------------------------------
  // Prompt + Response panel (active phases)
  // ---------------------------------------------------------------------------

  Widget _buildPromptResponseView(GenerationSession session, ThemeData theme) {
    final prompt =
        ref.read(generationSessionProvider.notifier).getNextPrompt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase description
          Text(
            _phaseDescription(session.currentPhase),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),

          // Progress badge
          if (session.lessonPlan != null) _buildProgressBadge(session, theme),

          const SizedBox(height: 16),

          // Copy prompt button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: prompt == null
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: prompt));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Prompt copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Prompt to Clipboard'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(14)),
            ),
          ),
          const SizedBox(height: 8),

          // Expandable prompt preview
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('View prompt',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: theme.colorScheme.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      prompt ?? '',
                      style:
                          const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Paste response area
          Text('Paste AI Response',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),

          // Prominent paste-from-clipboard button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null && data!.text!.trim().isNotEmpty) {
                  _responseController.text = data.text!;
                  setState(() {});
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Clipboard is empty'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.paste),
              label: const Text('Paste from Clipboard'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(14)),
            ),
          ),
          const SizedBox(height: 8),

          // Auto-growing response text field
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: TextField(
              controller: _responseController,
              maxLines: null,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: 'Paste the AI\'s JSON response here…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),

          // Error display with actionable messaging
          if (session.errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 18,
                          color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.errorMessage!,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                  if (session.errorMessage!.contains('Invalid JSON'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Tip: Make sure you copied the entire AI response, '
                        'including the opening and closing brackets.',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer
                              .withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Submit response button
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _responseController.text.trim().isEmpty
                      ? null
                      : _submitResponse,
                  icon: const Icon(Icons.check),
                  label: const Text('Submit Response'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(14)),
                ),
              ),
              if (session.currentPhase == GenerationPhase.reviewing) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    ref.read(generationSessionProvider.notifier).skipReview();
                  },
                  child: const Text('Skip Review'),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // Session tools — resume prompt & export
          Text('Session Tools', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  final prompt = AiPromptService.generateResumePrompt(
                    session: session,
                  );
                  Clipboard.setData(ClipboardData(text: prompt));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Resume prompt copied! Paste into any AI chat to continue.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Copy Resume Prompt'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: session.toJsonString()),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session JSON exported to clipboard'),
                    ),
                  );
                },
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export Session'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBadge(GenerationSession session, ThemeData theme) {
    final parts = <String>[];
    if (session.terms.isNotEmpty || session.currentPhase == GenerationPhase.generatingTerms) {
      parts.add('${session.terms.length}/${session.expectedTermCount} terms');
    }
    if (session.concepts.isNotEmpty || session.currentPhase == GenerationPhase.generatingConcepts) {
      parts.add(
          '${session.concepts.length}/${session.expectedConceptCount} concepts');
    }
    if (session.mcqs.isNotEmpty || session.currentPhase == GenerationPhase.generatingMcqs) {
      parts.add('${session.mcqs.length}/${session.expectedMcqCount} MCQs');
    }

    // Add batch indicator for content generation phases
    String? batchLabel;
    if (session.currentPhase == GenerationPhase.generatingTerms && session.expectedTermCount > 0) {
      final remaining = session.expectedTermCount - session.terms.length;
      final totalBatches = (session.expectedTermCount / 8).ceil();
      final currentBatch = totalBatches - (remaining / 8).ceil() + 1;
      batchLabel = 'Term batch $currentBatch of $totalBatches';
    } else if (session.currentPhase == GenerationPhase.generatingConcepts && session.expectedConceptCount > 0) {
      final remaining = session.expectedConceptCount - session.concepts.length;
      final totalBatches = (session.expectedConceptCount / 4).ceil();
      final currentBatch = totalBatches - (remaining / 4).ceil() + 1;
      batchLabel = 'Concept batch $currentBatch of $totalBatches';
    } else if (session.currentPhase == GenerationPhase.generatingMcqs && session.expectedMcqCount > 0) {
      final remaining = session.expectedMcqCount - session.mcqs.length;
      final totalBatches = (session.expectedMcqCount / 5).ceil();
      final currentBatch = totalBatches - (remaining / 5).ceil() + 1;
      batchLabel = 'MCQ batch $currentBatch of $totalBatches';
    }

    if (parts.isEmpty && batchLabel == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            parts.join(' · '),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
          ),
        ),
        if (batchLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            batchLabel,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  void _submitResponse() {
    final notifier = ref.read(generationSessionProvider.notifier);
    final error = notifier.handleResponse(_responseController.text.trim());
    if (error == null) {
      _responseController.clear();
      // Brief success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Response accepted — moving to next step'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    // Don't clear on error — let user fix the response in-place
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Complete view — shows assembled lesson & import button
  // ---------------------------------------------------------------------------

  Widget _buildCompleteView(GenerationSession session, ThemeData theme) {
    final assembled = session.assemble();
    final prettyJson =
        const JsonEncoder.withIndent('  ').convert(assembled);

    // Check for MCQs needing review
    final questions = assembled['questions'] as List<Map<String, dynamic>>? ?? [];
    final reviewItems = questions
        .where((q) => q['_needs_review'] == true)
        .toList();

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
                    'The AI\'s answer text didn\'t match any option exactly. '
                    'These default to the first option — please verify the '
                    'correct answer after importing.',
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
              onPressed: _isImporting ? null : () => _importLesson(prettyJson),
              icon: _isImporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              label: Text(_isImporting ? 'Importing…' : 'Import Lesson'),
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _phaseDescription(GenerationPhase phase) {
    switch (phase) {
      case GenerationPhase.planning:
        return 'Step 1: Copy the prompt below and paste it into your AI tool '
            '(ChatGPT, Gemini, Claude, etc.). It will generate a lesson plan '
            '— paste the JSON response back here.\n\n'
            'How it works: 1) Copy prompt → 2) Paste into AI → '
            '3) Copy the AI\'s response → 4) Paste here & submit';
      case GenerationPhase.generatingTerms:
        return 'Step 2: This prompt will generate term definitions based on '
            'the plan. Copy it, get the AI response, and paste it back.';
      case GenerationPhase.generatingConcepts:
        return 'Step 3: Now generating concept explanations that reference '
            'the terms already created.';
      case GenerationPhase.generatingMcqs:
        return 'Step 4: Generating assessment questions that test the concepts '
            'and use consistent terminology.';
      case GenerationPhase.reviewing:
        return 'Step 5 (optional): The AI will review all content for '
            'consistency and quality. You can skip this step.';
      case GenerationPhase.complete:
        return 'All done! Review the assembled lesson and import it.';
    }
  }

  Future<void> _importLesson(String jsonString) async {
    setState(() => _isImporting = true);
    try {
      final authState = ref.read(authProvider);
      final userId = authState is AuthSuccess
          ? authState.user.id
          : '';
      final lessonService = LessonService();
      final lesson = await lessonService.importLessonFromJson(jsonString, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lesson "${lesson.title}" imported!'),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(generationSessionProvider.notifier).clearSession();
        context.go('/lessons');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave session?'),
        content: const Text(
            'Your progress is saved automatically. You can resume this session when you come back.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave')),
          TextButton(
              onPressed: () {
                ref.read(generationSessionProvider.notifier).clearSession();
                Navigator.pop(ctx, true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Discard & Leave')),
        ],
      ),
    );
    return result ?? false;
  }
}
