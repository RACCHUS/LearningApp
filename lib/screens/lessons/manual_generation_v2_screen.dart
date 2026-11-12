import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/content_generation/slot_plan.dart';
import 'package:learning_pwa/providers/manual_generation_v2_provider.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/manual_prompt_builder.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';

/// Additive slot-based manual generator (master plan v2.6 §5, PR-C).
///
/// The learner plans a small job, copies a prompt into their own AI chat,
/// pastes the reply, and repeats for whatever is still missing. Nothing is
/// sent anywhere by the app, nothing is guessed, and the result imports as
/// a private, unreviewed lesson through the normal validated importer.
class ManualGenerationV2Screen extends ConsumerStatefulWidget {
  const ManualGenerationV2Screen({super.key, this.initialSubject});

  final String? initialSubject;

  @override
  ConsumerState<ManualGenerationV2Screen> createState() =>
      _ManualGenerationV2ScreenState();
}

class _ManualGenerationV2ScreenState
    extends ConsumerState<ManualGenerationV2Screen> {
  late final _subject = TextEditingController(text: widget.initialSubject);
  final _ideas = TextEditingController();
  final _paste = TextEditingController();
  final _title = TextEditingController();
  int _questions = 2;
  bool _terms = true;
  ModelSizeTier _tier = ModelSizeTier.compact;
  bool _lines = false;
  String? _planError;
  ManualJobSession? _session;
  bool _importing = false;
  bool _leaving = false;
  String? _importError;

  @override
  void dispose() {
    _subject.dispose();
    _ideas.dispose();
    _paste.dispose();
    _title.dispose();
    super.dispose();
  }

  void _makePlan() {
    try {
      final job = ManualJob.plan(
        ManualJobRequest(
          subject: _subject.text,
          concepts: _ideas.text.split('\n'),
          questionsPerConcept: _questions,
          includeTerms: _terms,
        ),
      );
      setState(() {
        _session = ManualJobSession(job);
        _planError = null;
        _importError = null;
        _paste.clear();
        _title.text = job.request.subject;
      });
    } on ArgumentError catch (e) {
      setState(() => _planError = '${e.message}');
    }
  }

  String _prompt(ManualJobSession s) => ManualPromptBuilder.build(
    s.job,
    s.nextBatch(_tier),
    mode: _lines ? ManualOutputMode.lines : ManualOutputMode.package,
  );

  Future<void> _copyPrompt(ManualJobSession s) async {
    await Clipboard.setData(ClipboardData(text: _prompt(s)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prompt copied. Paste it into your AI chat.'),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => _paste.text = data!.text!);
  }

  void _check(ManualJobSession s) {
    if (_paste.text.trim().isEmpty) return;
    setState(() => s.applyPaste(_paste.text));
  }

  Future<void> _import(ManualJobSession s, Map<String, dynamic> lesson) async {
    setState(() {
      _importing = true;
      _importError = null;
    });
    try {
      final id = await ref.read(manualDraftImporterProvider)(
        jsonEncode(lesson),
      );
      if (!mounted) return;
      context.go('/lesson/$id');
    } on LessonImportValidationException catch (e) {
      setState(() => _importError = e.issues.map((i) => i.message).join('\n'));
    } catch (_) {
      setState(
        () => _importError =
            'The lesson could not be saved. Your work here is still on this page.',
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<bool> _confirmLeave() async {
    final s = _session;
    if (s == null || s.accepted.isEmpty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this generator?'),
        content: const Text(
          'Accepted items on this page are not saved yet. '
          'Import them first, or they will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            key: const Key('manual_v2_leave_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(manualGenerationV2EnabledProvider);
    if (!enabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Slot-based generator')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This generator is not available right now. '
                  'AI-Guided Generation and Quick Generate still work.',
                  key: Key('manual_v2_disabled'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/create-lesson'),
                  child: const Text('Back to lesson creation'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final s = _session;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );

    return PopScope(
      canPop: _leaving || s == null || s.accepted.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          // Pop after the rebuild so PopScope sees canPop == true.
          setState(() => _leaving = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Slot-based generator')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Experimental. Uses your own AI chat: the app sends nothing. '
              'Progress on this page is kept only while it is open.',
              style: theme.textTheme.bodySmall,
            ),
            heading('1. Plan'),
            TextField(
              key: const Key('manual_v2_subject'),
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('manual_v2_ideas'),
              controller: _ideas,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Ideas to learn (one per line, up to 5)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<int>(
                  key: const Key('manual_v2_questions'),
                  value: _questions,
                  items: [
                    for (var i = 0; i <= 3; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text('$i questions per idea'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _questions = v ?? 2),
                ),
                FilterChip(
                  label: const Text('Key terms'),
                  selected: _terms,
                  onSelected: (v) => setState(() => _terms = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'How much can your AI handle at once?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            SegmentedButton<ModelSizeTier>(
              key: const Key('manual_v2_tier'),
              segments: [
                for (final t in ModelSizeTier.values)
                  ButtonSegment(
                    value: t,
                    label: Text('${t.label} (${t.slotsPerMessage})'),
                  ),
              ],
              selected: {_tier},
              onSelectionChanged: (v) => setState(() => _tier = v.first),
            ),
            SwitchListTile(
              key: const Key('manual_v2_lines'),
              contentPadding: EdgeInsets.zero,
              title: const Text('One item per line'),
              subtitle: const Text(
                'Can help small AIs. A cut-off reply then loses only its '
                'last line.',
              ),
              value: _lines,
              onChanged: (v) => setState(() => _lines = v),
            ),
            if (_planError != null)
              Text(
                _planError!,
                key: const Key('manual_v2_plan_error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            FilledButton(
              key: const Key('manual_v2_make_plan'),
              onPressed: _makePlan,
              child: Text(s == null ? 'Make plan' : 'Start a new plan'),
            ),
            if (s != null) ..._jobSections(s, theme, heading),
          ],
        ),
      ),
    );
  }

  List<Widget> _jobSections(
    ManualJobSession s,
    ThemeData theme,
    Widget Function(String) heading,
  ) {
    final total = s.job.plan.slots.length;
    final done = s.accepted.length;
    final batch = s.nextBatch(_tier);
    final outcome = s.lastOutcome;
    final lesson = done == 0
        ? null
        : s.toPersonalLesson(
            title: _title.text.trim().isEmpty
                ? s.job.request.subject
                : _title.text.trim(),
          );
    final preview = lesson == null ? null : LessonImportService.preview(lesson);

    String describe(SlotSpec spec) =>
        '${spec.code} · ${spec.kind.wire} · '
        '${s.job.conceptNames[spec.conceptCode]}';

    return [
      heading('2. Copy the prompt'),
      Text(
        'Job ${s.job.plan.jobCode}: $done of $total items ready.',
        key: const Key('manual_v2_progress'),
      ),
      if (batch.isNotEmpty) ...[
        Text(
          done == 0
              ? 'This prompt asks for ${batch.join(', ')}.'
              : 'Still needed: ${s.missing.join(', ')}. '
                    'The next prompt asks for ${batch.join(', ')}.',
          key: const Key('manual_v2_batch'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('manual_v2_copy_prompt'),
          onPressed: () => _copyPrompt(s),
          icon: const Icon(Icons.copy),
          label: Text(done == 0 ? 'Copy prompt' : 'Copy prompt for the rest'),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Show the prompt'),
          children: [
            SelectableText(
              _prompt(s),
              key: const Key('manual_v2_prompt_text'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ] else
        const Text('All planned items are ready.'),
      heading("3. Paste the AI's reply"),
      TextField(
        key: const Key('manual_v2_paste'),
        controller: _paste,
        minLines: 4,
        maxLines: 10,
        decoration: const InputDecoration(
          hintText: 'Paste the whole reply here',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste from clipboard'),
          ),
          FilledButton(
            key: const Key('manual_v2_check'),
            onPressed: () => _check(s),
            child: const Text('Check reply'),
          ),
        ],
      ),
      if (outcome != null) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            outcome.result.fatal != null
                ? '${outcome.result.fatal!.errorCode.userMessage} '
                      '${outcome.result.fatal!.errorCode.recovery}'
                : 'Accepted ${outcome.newlyAccepted.length} new item(s)'
                      '${outcome.alreadyAccepted.isEmpty ? '' : ' (${outcome.alreadyAccepted.length} already accepted, kept as before)'}.',
            key: const Key('manual_v2_check_result'),
          ),
        ),
        for (final e in outcome.result.errors)
          Text(
            '• ${[if (e.slot != null) e.slot, if (e.line != null) 'line ${e.line}'].join(' ')}'
            '${e.slot == null && e.line == null ? '' : ': '}'
            '${e.errorCode.userMessage}',
            style: theme.textTheme.bodySmall,
          ),
        if (outcome.result.fatal == null && !outcome.result.sentinelPresent)
          Text(
            'The end marker was missing, so the reply may have been cut off.',
            style: theme.textTheme.bodySmall,
          ),
      ],
      if (lesson != null && preview != null) ...[
        heading('4. Preview and import'),
        TextField(
          key: const Key('manual_v2_title'),
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'Lesson title',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(
          'Private draft · Unreviewed AI content · '
          '${preview.conceptCount} explanation(s), ${preview.termCount} '
          'term(s), ${preview.questionCount} question(s).',
          key: const Key('manual_v2_preview_counts'),
        ),
        for (final spec in s.job.plan.slots)
          if (s.accepted.containsKey(spec.code))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(describe(spec)),
            ),
        for (final issue in preview.issues)
          Text(
            '• ${issue.message}',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        if (_importError != null)
          Text(
            _importError!,
            key: const Key('manual_v2_import_error'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('manual_v2_import'),
          onPressed: preview.canImport && !_importing
              ? () => _import(s, lesson)
              : null,
          child: Text(
            s.isComplete
                ? 'Import private lesson'
                : 'Import the $done ready item(s) only',
          ),
        ),
      ],
      const SizedBox(height: 32),
    ];
  }
}
