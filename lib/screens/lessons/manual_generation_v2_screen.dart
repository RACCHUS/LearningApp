import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/content_generation/slot_plan.dart';
import 'package:learning_pwa/providers/byok_session_provider.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/managed_ai_provider.dart';
import 'package:learning_pwa/providers/manual_generation_v2_provider.dart';
import 'package:learning_pwa/services/ai/llm_client.dart';
import 'package:learning_pwa/services/ai/managed_ai_service.dart';
import 'package:learning_pwa/services/content_generation/lesson_composer.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/manual_job_store.dart';
import 'package:learning_pwa/services/content_generation/manual_prompt_builder.dart';
import 'package:learning_pwa/services/content_generation/model_capability_profile.dart';
import 'package:learning_pwa/services/content_generation/model_capability_store.dart';
import 'package:learning_pwa/services/content_generation/reuse_gate.dart';
import 'package:learning_pwa/models/content_generation/content_resolution_decision.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';
import 'package:learning_pwa/services/lesson/lesson_quality_check.dart';
import 'package:learning_pwa/widgets/ai/byok_settings_dialog.dart';
import 'package:learning_pwa/widgets/lesson/ai_chat_profile_section.dart';

/// Additive slot-based manual generator (master plan v2.6 §5, PR-C).
///
/// The learner plans a small job, copies a prompt into their own AI chat,
/// pastes the reply, and repeats for whatever is still missing. Nothing is
/// sent anywhere by the app unless the learner sets up their own API key
/// and taps "Ask … for me" (BYOK, off unless released); that reply goes
/// through the same checks as a pasted one. Nothing is guessed, and the
/// result imports as a private, unreviewed lesson through the normal
/// validated importer.
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
  String _level = 'beginner';
  ModelSizeTier _tier = ModelSizeTier.compact;
  LessonObjectiveType _objective = LessonObjectiveType.understand;
  bool _lines = false;
  String? _planError;
  ManualJobSession? _session;
  bool _importing = false;
  bool _leaving = false;
  String? _importError;
  ManualSaveOutcome? _saveOutcome;
  SavedManualJob? _offer;

  /// A Reuse Gate result waiting for the learner's choice.
  ReuseGateResult? _reuse;
  ManualJobRequest? _reuseRequest;
  CapabilityProfiles _profiles = const CapabilityProfiles();

  /// The batch and mode of the last copied prompt. A checked reply counts
  /// toward the capability profile once, and only after a prompt copy.
  ({List<String> batch, ManualOutputMode mode})? _awaitingReply;

  ManualJobStore get _store => ref.read(manualJobStoreProvider);
  ModelCapabilityStore get _capabilities =>
      ref.read(modelCapabilityStoreProvider);
  String get _owner => ref.read(manualJobOwnerProvider);

  /// The owner whose saved job and AI profiles were loaded.
  String? _loadedOwner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSaved());
  }

  /// Loads saved progress and AI profiles once the switch is known to be
  /// on. After a page refresh the switch settings and the signed-in
  /// account arrive after the first frame, so this also runs when either
  /// changes (see [build]); it never replaces a job already in progress.
  Future<void> _loadSaved() async {
    if (!mounted || !ref.read(manualGenerationV2EnabledProvider)) return;
    final owner = _owner;
    if (owner == _loadedOwner || _session != null) return;
    _loadedOwner = owner;
    final profiles = await _capabilities.load(owner);
    if (!mounted || owner != _owner) return;
    setState(() => _applyProfiles(profiles));
    final saved = await _store.load(owner);
    if (mounted && saved != null && _session == null && owner == _owner) {
      setState(() => _offer = saved);
    }
  }

  /// Loads [profiles] and starts from the selected chat's suggestion.
  void _applyProfiles(CapabilityProfiles profiles) {
    _profiles = profiles;
    final label = profiles.selected;
    if (label != null) _useSuggestion(profiles.profileFor(label));
  }

  void _useSuggestion(ModelCapabilityProfile p) {
    _tier = p.suggestedTier;
    final mode = p.suggestedMode;
    if (mode != null) _lines = mode == ManualOutputMode.lines;
  }

  void _selectAi(AiChatLabel? label) {
    setState(() {
      _profiles = CapabilityProfiles(
        selected: label,
        profiles: _profiles.profiles,
      );
      if (label != null) _useSuggestion(_profiles.profileFor(label));
    });
    _capabilities.save(_owner, _profiles);
  }

  /// Stores the optional probe result for the selected chat and starts
  /// from its (new) suggestion.
  void _recordProbe(bool passed) {
    final label = _profiles.selected;
    if (label == null) return;
    final updated = _profiles.profileFor(label).withProbe(passed);
    setState(() {
      _profiles = CapabilityProfiles(
        selected: label,
        profiles: {..._profiles.profiles, label: updated},
      );
      _useSuggestion(updated);
    });
    _capabilities.save(_owner, _profiles);
  }

  void _forgetAi(AiChatLabel label) {
    setState(() {
      _profiles = CapabilityProfiles(
        selected: _profiles.selected,
        profiles: {..._profiles.profiles}..remove(label),
      );
    });
    _capabilities.save(_owner, _profiles);
  }

  /// Copies [text] and tells the learner how it went. Browsers may refuse
  /// clipboard access; that must never throw out of a button handler.
  Future<bool> _copyText(String text, String done, String failed) async {
    var ok = true;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      ok = false;
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ok ? done : failed)));
    }
    return ok;
  }

  Future<void> _copyProfiles() => _copyText(
    ModelCapabilityStore.encode(_owner, _profiles),
    'Copied what this device has learned.',
    "Couldn't copy here. Your browser blocked the clipboard.",
  );

  /// The next checked reply answers the prompt for the current batch.
  void _armReply(ManualJobSession s) => _awaitingReply = (
    batch: s.nextBatch(_tier),
    mode: _lines ? ManualOutputMode.lines : ManualOutputMode.package,
  );

  /// Counts one checked reply toward the selected chat's profile.
  void _observe(ManualJobSession s, PasteOutcome outcome) {
    final label = _profiles.selected;
    final awaiting = _awaitingReply;
    if (label == null || awaiting == null) return;
    _awaitingReply = null;
    final updated = _profiles
        .profileFor(label)
        .record(
          ReplyObservation.from(
            mode: awaiting.mode,
            requested: awaiting.batch,
            outcome: outcome,
            nowAccepted: s.accepted.keys.toSet(),
          ),
        );
    _profiles = CapabilityProfiles(
      selected: label,
      profiles: {..._profiles.profiles, label: updated},
    );
    _capabilities.save(_owner, _profiles);
  }

  Future<void> _persist() async {
    final s = _session;
    if (s == null || _saveOutcome == ManualSaveOutcome.conflict) return;
    final outcome = await _store.save(_owner, s);
    if (mounted) setState(() => _saveOutcome = outcome);
  }

  void _resume(SavedManualJob saved) {
    final s = saved.session;
    setState(() {
      _session = s;
      _offer = null;
      _saveOutcome = ManualSaveOutcome.saved;
      _subject.text = s.job.request.subject;
      _ideas.text = s.job.request.concepts.join('\n');
      _questions = s.job.request.questionsPerConcept.clamp(0, 3);
      _terms = s.job.request.includeTerms;
      _level = s.job.request.level;
      _title.text = s.job.request.subject;
    });
  }

  Future<void> _discardSaved() async {
    await _store.clear(_owner);
    if (mounted) setState(() => _offer = null);
  }

  Future<void> _copyProgress(ManualJobSession s) => _copyText(
    s.acceptedPackage(),
    'Progress copied as text. Keep it somewhere safe as a backup.',
    "Couldn't copy here. Your browser blocked the clipboard.",
  );

  @override
  void dispose() {
    _subject.dispose();
    _ideas.dispose();
    _paste.dispose();
    _title.dispose();
    super.dispose();
  }

  /// Checks for existing content first (Reuse Gate, §6.3). When something
  /// already covers the ideas, the plan waits for the learner to open it,
  /// plan only what is missing, or make their own version anyway.
  Future<void> _makePlan() async {
    final ManualJobRequest request;
    try {
      request = ManualJobRequest(
        subject: _subject.text,
        concepts: _ideas.text.split('\n'),
        questionsPerConcept: _questions,
        includeTerms: _terms,
        level: _level,
      );
    } on ArgumentError catch (e) {
      setState(() => _planError = '${e.message}');
      return;
    }
    List<ReuseSource> sources;
    try {
      sources = await ref
          .read(reuseSourcesProvider.future)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      sources = const [];
    }
    if (!mounted) return;
    final gate = ReuseGate.evaluate(
      subject: request.subject,
      ideas: request.concepts,
      sources: sources,
    );
    if (gate.suggestsReuse) {
      setState(() {
        _reuse = gate;
        _reuseRequest = request;
        _planError = null;
      });
      return;
    }
    _startPlan(request, gate.decision);
  }

  /// "Make my own version": the learner's explicit override is recorded.
  void _overrideReuse() {
    final request = _reuseRequest;
    final gate = _reuse;
    if (request == null || gate == null) return;
    _startPlan(
      request,
      ContentResolutionDecision(
        kind: ContentResolutionKind.generate,
        reason:
            'Learner chose to make their own version. ${gate.decision.reason}',
        eligibleAssetRef: gate.decision.eligibleAssetRef,
      ),
    );
  }

  /// "Plan only what is missing": keep the ideas nothing covers yet.
  void _planMissing() {
    final request = _reuseRequest;
    final gate = _reuse;
    if (request == null || gate == null) return;
    final missing = [
      for (final (i, c) in request.concepts.indexed)
        if (!gate.coveredIdeas.contains(i)) c,
    ];
    if (missing.isEmpty) return;
    _ideas.text = missing.join('\n');
    _startPlan(
      ManualJobRequest(
        subject: request.subject,
        concepts: missing,
        questionsPerConcept: request.questionsPerConcept,
        includeTerms: request.includeTerms,
        level: request.level,
      ),
      ContentResolutionDecision(
        kind: ContentResolutionKind.adapt,
        reason: 'Planned only uncovered ideas. ${gate.decision.reason}',
        eligibleAssetRef: gate.decision.eligibleAssetRef,
      ),
    );
  }

  void _startPlan(
    ManualJobRequest request,
    ContentResolutionDecision decision,
  ) {
    try {
      final job = ManualJob.plan(request);
      setState(() {
        _reuse = null;
        _reuseRequest = null;
        _session = ManualJobSession(job, resolution: decision);
        _offer = null;
        _planError = null;
        _importError = null;
        _paste.clear();
        _title.text = job.request.subject;
      });
      _persist();
    } on ArgumentError catch (e) {
      setState(() => _planError = '${e.message}');
    }
  }

  String _prompt(ManualJobSession s) => ManualPromptBuilder.build(
    s.job,
    s.nextBatch(_tier),
    mode: _lines ? ManualOutputMode.lines : ManualOutputMode.package,
    fixNotes: _fixNotes,
  );

  /// What to fix in slots set aside for a redo, by slot code.
  final Map<String, List<String>> _fixNotes = {};

  /// The slot a quality tip refers to: the n-th accepted slot of its kind,
  /// in plan order (the order the lesson is built in).
  String? _slotFor(ManualJobSession s, QualityTip t) {
    final kind = switch (t.kind) {
      QualityTipKind.question => SlotKind.mcq,
      QualityTipKind.term => SlotKind.term,
      QualityTipKind.explanation => SlotKind.explanation,
      QualityTipKind.lesson => null,
    };
    final i = t.index;
    if (kind == null || i == null) return null;
    final codes = [
      for (final spec in s.job.plan.slots)
        if (spec.kind == kind && s.accepted.containsKey(spec.code)) spec.code,
    ];
    return i < codes.length ? codes[i] : null;
  }

  String _tipLabel(ManualJobSession s, QualityTip t) {
    final code = _slotFor(s, t);
    return code == null ? '$t' : '$code · $t';
  }

  /// Sets the weak items aside and remembers what to fix, so the next
  /// prompt asks only for them, with the problems spelled out.
  void _redo(ManualJobSession s, Map<String, List<String>> bySlot) {
    setState(() {
      s.discard(bySlot.keys);
      for (final e in bySlot.entries) {
        _fixNotes[e.key] = e.value;
      }
    });
    _persist();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Set aside ${bySlot.keys.join(', ')}. Copy the prompt again: it '
            'asks only for these, with what to fix.',
          ),
        ),
      );
  }

  Future<void> _copyPrompt(ManualJobSession s) async {
    // Armed even if the copy fails: the learner can still copy the prompt
    // by hand from "Show the prompt".
    _armReply(s);
    await _copyText(
      _prompt(s),
      'Prompt copied. Paste it into your AI chat.',
      "Couldn't copy automatically. Open \"Show the prompt\" below and "
          'copy it yourself.',
    );
  }

  /// Sends the prompt with the learner's own key and checks the reply
  /// exactly as if it had been pasted. Failures leave copy and paste as
  /// it was; a used-up quota switches "Ask" off and says so.
  Future<void> _askAi(ManualJobSession s) async {
    _armReply(s);
    final name = ref.read(byokSessionProvider).providerName;
    try {
      final reply = await ref
          .read(byokSessionProvider.notifier)
          .ask(_prompt(s));
      if (!mounted) return;
      _paste.text = reply;
      _check(s);
    } on LlmException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.kind.message(name))));
    }
  }

  /// Free AI on LearningApp's own free Gemini allowance. The reply goes
  /// through the same checks as a pasted one.
  Future<void> _askFreeAi(ManualJobSession s) async {
    final controller = ref.read(managedAiProvider.notifier);
    if (!ref.read(managedAiProvider).adultConfirmed) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('manual_v2_free_ai_confirm'),
          title: const Text('Before you use free AI'),
          content: const Text(
            "Free AI uses Google's Gemini. Google only allows people 18 or "
            'older to use it. Google may have people review prompts on its '
            "free plan, so don't put personal details in your topic or ideas.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('manual_v2_free_ai_confirm_yes'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("I'm 18 or older"),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await controller.confirmAdult();
    }
    _armReply(s);
    try {
      final reply = await controller.ask(_prompt(s));
      if (!mounted) return;
      _paste.text = reply;
      _check(s);
    } on ManagedAiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.failure.message)));
    }
  }

  Widget _freeAiSection(ManualJobSession s, ThemeData theme) {
    if (!ref.watch(managedAiEnabledProvider)) return const SizedBox.shrink();
    final m = ref.watch(managedAiProvider);
    if (!m.status.enabled) return const SizedBox.shrink();
    if (m.status.paused || m.outOfRequests) {
      return Card(
        key: const Key('manual_v2_free_ai_off'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              m.status.paused
                  ? ManagedAiFailure.paused.message
                  : ManagedAiFailure.userLimit.message,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          key: const Key('manual_v2_free_ai'),
          onPressed: m.busy ? null : () => _askFreeAi(s),
          icon: m.busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(m.busy ? 'Writing…' : 'Generate with free AI'),
        ),
        const SizedBox(height: 4),
        Text(
          "Uses LearningApp's free Gemini allowance: "
          '${m.status.remainingToday} left for you today. It turns off when '
          "the free allowance is used up. Don't include personal details.",
          key: const Key('manual_v2_free_ai_note'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _openByokSettings() => ByokSettingsDialog.show(
    context,
    storageService: ref.read(byokStorageProvider),
    onSaved: ref.read(byokSessionProvider.notifier).useConfig,
    clientFactory: ref.read(llmClientFactoryProvider),
    releaseApproved: ref.read(byokReleaseApprovedProvider),
  );

  Widget _askAiSection(ManualJobSession s, ThemeData theme) {
    if (!ref.watch(byokAvailableProvider)) return const SizedBox.shrink();
    final b = ref.watch(byokSessionProvider);
    if (b.paused) {
      return Card(
        key: const Key('manual_v2_byok_paused'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  LlmFailureKind.quotaExhausted.message(b.providerName),
                ),
              ),
              TextButton(
                key: const Key('manual_v2_byok_resume'),
                onPressed: ref.read(byokSessionProvider.notifier).resume,
                child: const Text('Try my key again'),
              ),
            ],
          ),
        ),
      );
    }
    if (!b.configured) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('manual_v2_byok_setup'),
          onPressed: _openByokSettings,
          icon: const Icon(Icons.key_outlined),
          label: const Text('Or use your own API key'),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          key: const Key('manual_v2_ask_ai'),
          onPressed: b.busy ? null : () => _askAi(s),
          icon: b.busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            b.busy
                ? 'Asking ${b.providerName}…'
                : 'Ask ${b.providerName} for me',
          ),
        ),
        TextButton(
          onPressed: b.busy ? null : _openByokSettings,
          child: const Text('Key settings'),
        ),
      ],
    );
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && mounted) {
        setState(() => _paste.text = data!.text!);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't read the clipboard here. Paste into the box instead.",
            ),
          ),
        );
    }
  }

  void _check(ManualJobSession s) {
    if (_paste.text.trim().isEmpty) return;
    setState(() {
      final outcome = s.applyPaste(_paste.text);
      _observe(s, outcome);
      // Redone slots no longer need their notes once accepted again.
      outcome.newlyAccepted.forEach(_fixNotes.remove);
    });
    _persist();
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
      await _store.clear(_owner);
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
    ref.listen(manualGenerationV2EnabledProvider, (_, on) {
      if (on) _loadSaved();
    });
    ref.listen(manualJobOwnerProvider, (_, __) => _loadSaved());
    final enabled = ref.watch(manualGenerationV2EnabledProvider);
    if (!enabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create with your AI chat')),
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
      canPop:
          _leaving ||
          s == null ||
          s.accepted.isEmpty ||
          _saveOutcome == ManualSaveOutcome.saved,
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
        appBar: AppBar(title: const Text('Create with your AI chat')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Experimental. Uses your own AI chat: the app sends nothing. '
              'Progress is saved on this device (best effort).',
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
                DropdownButton<String>(
                  key: const Key('manual_v2_level'),
                  value: _level,
                  items: [
                    for (final l in ManualJobRequest.levels)
                      DropdownMenuItem(
                        value: l,
                        child: Text(
                          '${l[0].toUpperCase()}${l.substring(1)} level',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _level = v ?? _level),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AiChatProfileSection(
              selected: _profiles.selected,
              profile: _profiles.selected == null
                  ? null
                  : _profiles.profileFor(_profiles.selected!),
              tier: _tier,
              onSelect: _selectAi,
              onUseSuggestion: () => setState(
                () => _useSuggestion(_profiles.profileFor(_profiles.selected!)),
              ),
              onForget: () => _forgetAi(_profiles.selected!),
              onCopy: _copyProfiles,
              onCopyText: (text) => _copyText(
                text,
                'Test copied. Paste it into your AI chat.',
                "Couldn't copy here. Select the test text and copy it.",
              ),
              onProbeResult: _recordProbe,
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
            if (_reuse != null) _reuseCard(_reuse!, theme),
            if (_offer != null) _resumeCard(_offer!, theme),
            if (s != null) _saveStatus(s, theme),
            if (s != null) ..._jobSections(s, theme, heading),
          ],
        ),
      ),
    );
  }

  /// Improvement hints for the draft (never blocking). Each says what to
  /// ask the AI to change.
  List<Widget> _qualityTips(
    ManualJobSession s,
    Map<String, dynamic> lesson,
    ThemeData theme,
  ) {
    final tips = LessonQualityCheck.check(lesson);
    final bySlot = <String, List<String>>{};
    for (final t in tips) {
      final code = _slotFor(s, t);
      if (code != null) bySlot.putIfAbsent(code, () => []).add(t.message);
    }
    if (tips.isEmpty) {
      return [
        Text(
          'Quality check: no problems found.',
          key: const Key('manual_v2_quality_ok'),
          style: theme.textTheme.bodySmall,
        ),
      ];
    }
    return [
      const SizedBox(height: 8),
      ExpansionTile(
        key: const Key('manual_v2_quality_tips'),
        tilePadding: EdgeInsets.zero,
        title: Text('Quality tips (${tips.length})'),
        subtitle: Text(
          'Optional. You can import as is, or ask your AI to fix these.',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          for (final t in tips)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '• ${_tipLabel(s, t)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (bySlot.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('manual_v2_redo'),
                onPressed: () => _redo(s, bySlot),
                icon: const Icon(Icons.auto_fix_high),
                label: Text('Redo ${bySlot.keys.join(', ')} with your AI'),
              ),
            ),
        ],
      ),
    ];
  }

  /// Opens an open textbook section in a new tab (never an embedded view).
  Future<void> _openSection(ReuseSource source) async {
    final uri = Uri.tryParse(source.url ?? '');
    if (uri == null || uri.scheme != 'https') return;
    var opened = false;
    try {
      opened = await ref.read(externalLinkLauncherProvider)(uri);
    } catch (_) {}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text("Couldn't open the link: ${source.url}")),
        );
    }
  }

  Widget _reuseCard(ReuseGateResult gate, ThemeData theme) {
    final open = gate.decision.kind == ContentResolutionKind.externalLink;
    final complete =
        gate.decision.kind == ContentResolutionKind.exactReuse || open;
    final ideas = _reuseRequest?.concepts ?? const <String>[];
    final coveredNames = [
      for (final (i, c) in ideas.indexed)
        if (gate.coveredIdeas.contains(i)) c,
    ];
    return Card(
      key: const Key('manual_v2_reuse_card'),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              open
                  ? 'Free open content covers this'
                  : complete
                  ? 'We already have this'
                  : 'Some of this already exists',
              style: theme.textTheme.titleSmall,
            ),
            Text(
              open
                  ? 'An openly licensed textbook section covers it. Read it '
                        'now for free; no AI needed.'
                  : complete
                  ? 'You can open it now, without using your AI chat.'
                  : 'Already covered: ${coveredNames.join(', ')}.',
              key: const Key('manual_v2_reuse_reason'),
            ),
            for (final c in gate.candidates)
              ListTile(
                key: Key(
                  'manual_v2_reuse_${c.source.kind.name}_${c.source.id}',
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(switch (c.source.kind) {
                  ReuseSourceKind.lesson => Icons.menu_book_outlined,
                  ReuseSourceKind.bridge => Icons.school_outlined,
                  ReuseSourceKind.openSection => Icons.auto_stories_outlined,
                }),
                title: Text(c.source.title),
                subtitle: Text(
                  '${switch (c.source.kind) {
                    ReuseSourceKind.lesson => 'Lesson',
                    ReuseSourceKind.bridge => 'Short help lesson (Learning help)',
                    ReuseSourceKind.openSection => 'Free open textbook · ${c.source.credit}',
                  }}'
                  ' · covers ${c.coveredIdeas.length} of ${ideas.length}',
                ),
                trailing: c.source.kind == ReuseSourceKind.bridge
                    ? null
                    : const Icon(Icons.open_in_new),
                onTap: switch (c.source.kind) {
                  ReuseSourceKind.lesson => () => context.push(
                    '/lesson/${c.source.id}',
                  ),
                  ReuseSourceKind.bridge => null,
                  ReuseSourceKind.openSection => () => _openSection(c.source),
                },
              ),
            Wrap(
              spacing: 8,
              children: [
                if (!complete)
                  FilledButton(
                    key: const Key('manual_v2_reuse_missing'),
                    onPressed: _planMissing,
                    child: const Text('Plan only what is missing'),
                  ),
                TextButton(
                  key: const Key('manual_v2_reuse_override'),
                  onPressed: _overrideReuse,
                  child: const Text('Make my own version'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumeCard(SavedManualJob saved, ThemeData theme) {
    final s = saved.session;
    return Card(
      key: const Key('manual_v2_resume_card'),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have a saved job: "${s.job.request.subject}", '
              '${s.accepted.length} of ${s.job.plan.slots.length} items ready.',
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: const Key('manual_v2_resume'),
                  onPressed: () => _resume(saved),
                  child: const Text('Resume'),
                ),
                TextButton(
                  key: const Key('manual_v2_discard_saved'),
                  onPressed: _discardSaved,
                  child: const Text('Discard it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveStatus(ManualJobSession s, ThemeData theme) {
    final text = switch (_saveOutcome) {
      ManualSaveOutcome.saved => 'Saved on this device.',
      ManualSaveOutcome.conflict =>
        'This job was changed in another tab or window, so this one stopped '
            'saving. Copy your progress to keep it.',
      ManualSaveOutcome.failed =>
        "Couldn't save on this device. Copy your progress to keep it.",
      null => null,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (text != null)
            Text(
              text,
              key: const Key('manual_v2_save_status'),
              style: theme.textTheme.bodySmall,
            ),
          if (s.accepted.isNotEmpty)
            TextButton.icon(
              key: const Key('manual_v2_copy_progress'),
              onPressed: () => _copyProgress(s),
              icon: const Icon(Icons.copy_all),
              label: const Text('Copy my progress'),
            ),
        ],
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
            objectiveType: _objective,
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
        _freeAiSection(s, theme),
        FilledButton.icon(
          key: const Key('manual_v2_copy_prompt'),
          onPressed: () => _copyPrompt(s),
          icon: const Icon(Icons.copy),
          label: Text(done == 0 ? 'Copy prompt' : 'Copy prompt for the rest'),
        ),
        ExpansionTile(
          key: const Key('manual_v2_show_prompt'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Show the prompt'),
          // Copying by hand from here is the fallback when the clipboard
          // is blocked, so it counts like "Copy prompt".
          onExpansionChanged: (open) {
            if (open) _armReply(s);
          },
          children: [
            SelectableText(
              _prompt(s),
              key: const Key('manual_v2_prompt_text'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        _askAiSection(s, theme),
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
        ..._qualityTips(s, lesson, theme),
        const SizedBox(height: 8),
        Text('Lesson order', style: theme.textTheme.titleSmall),
        DropdownButton<LessonObjectiveType>(
          key: const Key('manual_v2_objective'),
          value: _objective,
          isExpanded: true,
          items: [
            for (final t in LessonObjectiveType.values)
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (v) => setState(() => _objective = v ?? _objective),
        ),
        for (final (i, code) in LessonComposer.compose(
          s.job.plan,
          s.accepted.keys.toSet(),
          _objective,
        ).indexed)
          ListTile(
            key: Key('manual_v2_composed_$i'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text('${i + 1}.'),
            title: Text(describe(s.job.plan[code]!)),
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
