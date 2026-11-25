import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/services/companion/outline_mapper.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

String _parts(int n) => n == 1 ? '1 part' : '$n parts';

class _Draft {
  _Draft(
    this.title, {
    Set<String>? keys,
    this.source = SectionMapSource.learner,
    this.minutes,
  }) : keys = {...?keys},
       suggested = {...?keys};

  final String title;

  /// What the learner has ticked for this part.
  Set<String> keys;

  /// What was proposed (or saved before), kept visible so an unticked
  /// suggestion can be ticked again.
  Set<String> suggested;
  SectionMapSource source;

  /// The learner's own estimate for this part, if any.
  int? minutes;
}

/// The outline of one outside resource (companion plan v1.0 §3.4, EX-3):
/// the learner pastes a table of contents, the device proposes objectives
/// for each part by matching words, and the learner confirms. Their own AI
/// chat can make the proposal instead. LearningApp opens nothing and calls
/// no model; a saved map is the learner's own and is never called reviewed.
class ResourceOutlineScreen extends ConsumerStatefulWidget {
  const ResourceOutlineScreen({
    super.key,
    required this.goal,
    required this.resourceId,
  });

  final GoalRef goal;
  final String resourceId;

  @override
  ConsumerState<ResourceOutlineScreen> createState() =>
      _ResourceOutlineScreenState();
}

class _ResourceOutlineScreenState extends ConsumerState<ResourceOutlineScreen> {
  final _paste = TextEditingController();
  final _answer = TextEditingController();
  List<_Draft>? _drafts;

  /// Bumped when the drafts are replaced, so the minute fields start fresh.
  int _generation = 0;
  String? _pasteNote;
  String? _aiNote;
  bool _aiError = false;
  bool _saving = false;

  @override
  void dispose() {
    _paste.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _match(ResourceOutline outline) {
    final parsed = OutlineMapper.parse(_paste.text);
    if (parsed.titles.isEmpty) {
      setState(
        () => _pasteNote =
            'Paste the list of chapters, units or videos first, one per line.',
      );
      return;
    }
    final proposals = OutlineMapper.propose(parsed.titles, outline);
    setState(() {
      _drafts = [
        for (final (i, t) in parsed.titles.indexed)
          _Draft(
            t,
            keys: proposals[i],
            source: proposals[i].isEmpty
                ? SectionMapSource.learner
                : SectionMapSource.outlineMatch,
            minutes: parsed.minutes[i],
          ),
      ];
      _generation++;
      _pasteNote = parsed.truncated
          ? 'That was long, so only the first ${_parts(parsed.titles.length)} were kept.'
          : null;
      _aiNote = null;
      _answer.clear();
    });
  }

  void _checkAnswer(ResourceOutline outline, List<_Draft> drafts) {
    final result = OutlineMapper.parseResponse(
      _answer.text,
      sectionCount: drafts.length,
      outline: outline,
    );
    if (result.error != null) {
      setState(() {
        _aiNote = result.error;
        _aiError = true;
      });
      return;
    }
    setState(() {
      for (final e in result.bySection.entries) {
        final d = drafts[e.key];
        d.keys = {...e.value};
        d.suggested = {...d.suggested, ...e.value};
        d.source = e.value.isEmpty
            ? SectionMapSource.learner
            : SectionMapSource.ownAi;
      }
      final used = result.bySection.length;
      _aiError = false;
      _aiNote =
          'Used the answer for $used of ${_parts(drafts.length)}.'
          '${result.dropped == 0
              ? ''
              : result.dropped == 1
              ? ' 1 entry was left out because it is not in your lists.'
              : ' ${result.dropped} entries were left out because they are not in your lists.'}'
          ' An AI can be wrong, so check each part below before you save.';
    });
  }

  Future<void> _save(
    List<ResourceSection> sections, {
    required String done,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(learnerResourceStoreProvider)
          .setSections(widget.resourceId, sections);
      ref.invalidate(learnerResourcesProvider(widget.goal.targetId));
      messenger.showSnackBar(SnackBar(content: Text(done)));
      navigator.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't save that. Check your connection and try again.",
          ),
        ),
      );
    }
  }

  Future<void> _chooseAll(_Draft draft, ResourceOutline outline) async {
    final picked = {...draft.keys};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: Text(
            draft.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final g in outline.groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: DesignTokens.space2),
                    child: Text(
                      g.title,
                      style: Theme.of(c).textTheme.titleSmall,
                    ),
                  ),
                  for (final item in g.items)
                    CheckboxListTile(
                      key: Key('outline_pick_${item.key}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(item.label),
                      value: picked.contains(item.key),
                      onChanged:
                          picked.length >= ResourceSection.maxKeysPerSection &&
                              !picked.contains(item.key)
                          ? null
                          : (v) => setLocal(
                              () => v == true
                                  ? picked.add(item.key)
                                  : picked.remove(item.key),
                            ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('outline_pick_done'),
              onPressed: () => Navigator.of(c).pop(picked),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      draft.keys = result;
      draft.suggested = {...draft.suggested, ...result};
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final resources = ref.watch(learnerResourcesProvider(widget.goal.targetId));
    final nodes = ref.watch(
      targetCurriculumNodesProvider(widget.goal.targetVersionId),
    );
    final resource = resources.valueOrNull
        ?.where((r) => r.id == widget.resourceId)
        .firstOrNull;

    if (resource == null || !nodes.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text('Outline')),
        body: Center(
          child: resources.isLoading || nodes.isLoading
              ? const CircularProgressIndicator()
              : const Text(
                  "This can't be shown right now.",
                  key: Key('outline_unavailable'),
                ),
        ),
      );
    }

    final outline = ResourceOutline.fromNodes(nodes.requireValue);
    final known = outline.keys;
    final labelByKey = {
      for (final g in outline.groups)
        for (final i in g.items) i.key: i.label,
    };
    // Start from the saved outline; keys the goal no longer has are dropped.
    final drafts = _drafts ??= [
      for (final s in resource.sections)
        _Draft(
          s.title,
          keys: s.objectiveKeys.where(known.contains).toSet(),
          source: s.source,
          minutes: s.minutes,
        ),
    ];
    final mapped = drafts.where((d) => d.keys.isNotEmpty).length;

    return Scaffold(
      appBar: AppBar(title: Text('Outline: ${resource.title}')),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        children: [
          Text(
            'Paste the table of contents or syllabus, one part per line. '
            'LearningApp reads only what you paste here. It does not open your course, video or book.',
            key: const Key('outline_intro'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DesignTokens.space2),
          TextField(
            key: const Key('outline_paste'),
            controller: _paste,
            minLines: 4,
            maxLines: 10,
            maxLength: OutlineMapper.maxPasteLength,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Chapters, units or videos',
              hintText: 'Chapter 1: Linear equations\nChapter 2: Functions',
              alignLabelWithHint: true,
              counterText: '',
              errorText: drafts.isEmpty ? _pasteNote : null,
            ),
          ),
          const SizedBox(height: DesignTokens.space2),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const Key('outline_match'),
              onPressed: outline.itemCount == 0 ? null : () => _match(outline),
              icon: const Icon(Icons.manage_search),
              label: Text(
                drafts.isEmpty
                    ? 'Find matching objectives'
                    : 'Replace with this outline',
              ),
            ),
          ),
          if (outline.itemCount == 0)
            Text('This goal has no objectives to match yet.', style: muted)
          else if (drafts.isNotEmpty && _pasteNote != null)
            Text(
              _pasteNote!,
              key: const Key('outline_truncated'),
              style: muted,
            ),
          if (drafts.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.space4),
            Text(
              '${_parts(drafts.length)}, $mapped matched to objectives',
              key: const Key('outline_summary'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: DesignTokens.space1),
            Text(
              'Suggestions come from matching words in the titles, so some will be wrong or missing. '
              'Nobody has reviewed them. Untick anything a part does not really cover. '
              "Saving ticks these objectives as covered. It does not mark anything studied, and only LearningApp's checks count toward readiness.",
              key: const Key('outline_unreviewed_note'),
              style: muted,
            ),
            for (final (i, d) in drafts.indexed)
              Card(
                key: Key('outline_section_$i'),
                margin: const EdgeInsets.only(top: DesignTokens.space2),
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.space2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.space2,
                        ),
                        child: Text(
                          // A pasted line that brings its own number keeps it.
                          RegExp(r'^\d').hasMatch(d.title) ? d.title : '${i + 1}. ${d.title}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DesignTokens.space2,
                          DesignTokens.space2,
                          DesignTokens.space2,
                          0,
                        ),
                        child: SizedBox(
                          width: 180,
                          child: TextFormField(
                            key: ValueKey('outline_minutes_${_generation}_$i'),
                            initialValue: d.minutes?.toString() ?? '',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              labelText: 'Minutes (optional)',
                            ),
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              d.minutes =
                                  n != null &&
                                      n >= 1 &&
                                      n <= ResourceSection.maxMinutes
                                  ? n
                                  : null;
                            },
                          ),
                        ),
                      ),
                      if (d.suggested.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(DesignTokens.space2),
                          child: Text(
                            'Nothing matched by words.',
                            style: muted,
                          ),
                        ),
                      for (final key in labelByKey.keys.where(
                        d.suggested.contains,
                      ))
                        CheckboxListTile(
                          key: Key('outline_${i}_$key'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(labelByKey[key]!),
                          value: d.keys.contains(key),
                          onChanged: (v) => setState(
                            () => v == true
                                ? d.keys.add(key)
                                : d.keys.remove(key),
                          ),
                        ),
                      TextButton.icon(
                        key: Key('outline_choose_$i'),
                        onPressed: () => _chooseAll(d, outline),
                        icon: const Icon(Icons.playlist_add_check, size: 18),
                        label: const Text('Choose from all objectives'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: DesignTokens.space4),
            ExpansionTile(
              key: const Key('outline_ai'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Get a second opinion from your own AI chat'),
              subtitle: const Text(
                'Optional. LearningApp does not connect to any AI.',
              ),
              childrenPadding: const EdgeInsets.only(
                bottom: DesignTokens.space2,
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Copy this prompt into an AI chat you already use, then paste its answer below. '
                  'The prompt holds only your part titles and the objectives of this goal.',
                  style: muted,
                ),
                const SizedBox(height: DesignTokens.space2),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  width: double.infinity,
                  padding: const EdgeInsets.all(DesignTokens.space2),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(DesignTokens.space2),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      OutlineMapper.buildPrompt(
                        resourceTitle: resource.title,
                        sectionTitles: [for (final d in drafts) d.title],
                        outline: outline,
                      ),
                      key: const Key('outline_ai_prompt'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('outline_ai_copy'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final prompt = OutlineMapper.buildPrompt(
                        resourceTitle: resource.title,
                        sectionTitles: [for (final d in drafts) d.title],
                        outline: outline,
                      );
                      try {
                        await Clipboard.setData(ClipboardData(text: prompt));
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Prompt copied.')),
                        );
                      } catch (_) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Couldn't copy. Select the prompt text and copy it yourself.",
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy prompt'),
                  ),
                ),
                TextField(
                  key: const Key('outline_ai_response'),
                  controller: _answer,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Paste AI response',
                    alignLabelWithHint: true,
                    errorText: _aiError ? _aiNote : null,
                    errorMaxLines: 3,
                  ),
                ),
                const SizedBox(height: DesignTokens.space2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    key: const Key('outline_ai_check'),
                    onPressed: () => _checkAnswer(outline, drafts),
                    child: const Text('Check response'),
                  ),
                ),
                if (_aiNote != null && !_aiError)
                  Padding(
                    padding: const EdgeInsets.only(top: DesignTokens.space2),
                    child: Text(
                      _aiNote!,
                      key: const Key('outline_ai_result'),
                      style: muted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DesignTokens.space4),
            Wrap(
              spacing: DesignTokens.space2,
              runSpacing: DesignTokens.space2,
              children: [
                FilledButton.icon(
                  key: const Key('outline_save'),
                  onPressed: _saving
                      ? null
                      : () => _save([
                          for (final d in drafts)
                            ResourceSection(
                              title: d.title,
                              objectiveKeys: {...d.keys},
                              source: d.keys.isEmpty
                                  ? SectionMapSource.learner
                                  : d.source,
                              minutes: d.minutes,
                            ),
                        ], done: 'Outline saved.'),
                  icon: const Icon(Icons.check),
                  label: const Text('Save outline'),
                ),
                if (resource.sections.isNotEmpty)
                  TextButton(
                    key: const Key('outline_remove'),
                    onPressed: _saving
                        ? null
                        : () => _save(
                            const [],
                            done: 'Outline removed. Your ticks are kept.',
                          ),
                    child: const Text('Remove outline'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
