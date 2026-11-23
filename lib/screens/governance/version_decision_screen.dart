import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records a champion/challenger decision (master plan v2.6 §7.3) with the
/// evidence beside it: what each version contains, review evidence on its
/// lessons, and how learners did on the published one (only from five
/// learners up). Replacing needs a documented defect or a rubric margin of
/// 2+ without lower accuracy; the server checks the same rule.
class VersionDecisionScreen extends StatefulWidget {
  const VersionDecisionScreen({super.key, this.rpc});

  /// Test seam; defaults to Supabase RPCs.
  final Future<dynamic> Function(String fn, Map<String, dynamic> params)? rpc;

  @override
  State<VersionDecisionScreen> createState() => _VersionDecisionScreenState();
}

class _VersionDecisionScreenState extends State<VersionDecisionScreen> {
  static const aspects = ['clarity', 'accuracy', 'accessibility'];

  List<Map<String, dynamic>>? _candidates;
  Map<String, dynamic>? _target;
  String? _challengerId;
  Map<String, dynamic>? _comparison;
  String? _error;
  bool _saving = false;

  String _decision = 'replace';
  String _basis = 'fixes_defect';
  final _defect = TextEditingController();
  final _note = TextEditingController();
  final Map<String, int> _champion = {for (final a in aspects) a: 3};
  final Map<String, int> _challenger = {for (final a in aspects) a: 3};

  Future<dynamic> _call(String fn, [Map<String, dynamic> params = const {}]) {
    if (widget.rpc != null) return widget.rpc!(fn, params);
    return Supabase.instance.client.rpc(fn, params: params);
  }

  @override
  void initState() {
    super.initState();
    _call('get_version_decision_candidates').then((r) {
      if (!mounted) return;
      setState(() => _candidates = [
            for (final c in (r as List? ?? const [])) Map<String, dynamic>.from(c as Map),
          ]);
    }).catchError((_) {
      if (mounted) setState(() => _error = 'Could not load versions. Admins only.');
    });
  }

  @override
  void dispose() {
    _defect.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(Map<String, dynamic> target, String challengerId) async {
    setState(() {
      _target = target;
      _challengerId = challengerId;
      _comparison = null;
    });
    try {
      final r = await _call('get_version_comparison', {
        'p_champion_version_id': target['champion_id'],
        'p_challenger_version_id': challengerId,
      });
      if (mounted && _challengerId == challengerId) {
        setState(() => _comparison = Map<String, dynamic>.from(r as Map));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not compare the versions.');
    }
  }

  int get _margin =>
      aspects.fold(0, (sum, a) => sum + _challenger[a]! - _champion[a]!);

  /// Why "Record" is not allowed yet, or null when it is.
  String? get _blocker {
    if (_decision != 'replace') return null;
    if (_basis == 'none') return 'Replacing needs a documented defect or a rubric margin.';
    if (_basis == 'fixes_defect' && _defect.text.trim().length < 5) {
      return 'Name the documented defect this version fixes.';
    }
    if (_basis == 'rubric_margin') {
      if (_challenger['accuracy']! < _champion['accuracy']!) {
        return 'The new version scores lower on accuracy, so it cannot replace the published one.';
      }
      if (_margin < 2) return 'The new version must score at least 2 points higher in total.';
    }
    return null;
  }

  Future<void> _record() async {
    setState(() => _saving = true);
    try {
      await _call('record_content_version_decision', {
        'p_champion_version_id': _target!['champion_id'],
        'p_challenger_version_id': _challengerId,
        'p_decision': _decision,
        'p_basis': _decision == 'replace' ? _basis : (_basis == 'rubric_margin' ? 'rubric_margin' : 'none'),
        'p_defect_ref': _basis == 'fixes_defect' ? _defect.text.trim() : null,
        'p_rubric': _basis == 'rubric_margin' ? {'champion': _champion, 'challenger': _challenger} : null,
        'p_note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Decision recorded. Publishing with "retire previous" can now use it.'),
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not recorded: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Replace a published version?')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _candidates == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'A new version replaces the published one only if it fixes a documented '
                      'defect or scores clearly better. Otherwise keep it as an alternate or reject it.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_candidates!.isEmpty)
                      const ListTile(title: Text('No book has a review-ready version waiting.')),
                    for (final t in _candidates!)
                      for (final c in (t['challengers'] as List? ?? const []))
                        RadioListTile<String>(
                          key: Key('decision-pick-${c['id']}'),
                          value: '${c['id']}',
                          groupValue: _challengerId,
                          onChanged: (_) => _pick(t, '${c['id']}'),
                          title: Text('${t['target_title']}: ${t['champion_code']} → ${c['code']}'),
                        ),
                    if (_challengerId != null && _comparison == null)
                      const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                    if (_comparison != null) ...[
                      const Divider(),
                      _evidenceTable(theme),
                      const Divider(),
                      _form(theme),
                    ],
                  ],
                ),
    );
  }

  Widget _evidenceTable(ThemeData theme) {
    final a = Map<String, dynamic>.from(_comparison!['champion'] as Map);
    final b = Map<String, dynamic>.from(_comparison!['challenger'] as Map);
    String review(Map<String, dynamic> v, String aspect) {
      final r = (v['review'] as Map?)?[aspect] as Map?;
      if (r == null) return 'none';
      return '${r['ok']} ok, ${r['concern']} concern';
    }

    String learners(Map<String, dynamic> v) => switch (v['learner_evidence']) {
          'measured' => '${v['learner_accounts']} learners, '
              '${((v['check_accuracy'] as num? ?? 0) * 100).round()}% correct',
          'not_published' => 'not published yet',
          _ => 'fewer than 5 learners',
        };

    TableRow row(String label, String x, String y) => TableRow(children: [
          Padding(padding: const EdgeInsets.all(4), child: Text(label)),
          Padding(padding: const EdgeInsets.all(4), child: Text(x)),
          Padding(padding: const EdgeInsets.all(4), child: Text(y)),
        ]);

    return Table(
      key: const Key('decision-evidence'),
      columnWidths: const {0: FlexColumnWidth(1.2)},
      children: [
        TableRow(children: [
          const SizedBox.shrink(),
          Text('Published ${a['version_code']}', style: theme.textTheme.titleSmall),
          Text('New ${b['version_code']}', style: theme.textTheme.titleSmall),
        ]),
        row('Lessons', '${a['lessons']}', '${b['lessons']}'),
        row('Teaching blocks', '${a['teach_blocks']}', '${b['teach_blocks']}'),
        row('Worked examples', '${a['example_blocks']}', '${b['example_blocks']}'),
        row('Practice', '${a['practice_items']}', '${b['practice_items']}'),
        row('Checks', '${a['check_items']}', '${b['check_items']}'),
        for (final x in ['accuracy', 'accessibility', 'rights'])
          row('Review: $x', review(a, x), review(b, x)),
        row('Learners', learners(a), learners(b)),
      ],
    );
  }

  Widget _score(String side, String aspect, Map<String, int> scores) => DropdownButton<int>(
        key: Key('decision-score-$side-$aspect'),
        value: scores[aspect],
        items: [for (var i = 1; i <= 5; i++) DropdownMenuItem(value: i, child: Text('$i'))],
        onChanged: (v) => setState(() => scores[aspect] = v ?? scores[aspect]!),
      );

  Widget _form(ThemeData theme) {
    final blocker = _blocker;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Decision', style: theme.textTheme.titleSmall),
        SegmentedButton<String>(
          key: const Key('decision-kind'),
          segments: const [
            ButtonSegment(value: 'replace', label: Text('Replace')),
            ButtonSegment(value: 'alternate', label: Text('Keep as alternate')),
            ButtonSegment(value: 'reject', label: Text('Reject')),
          ],
          selected: {_decision},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _decision = s.first),
        ),
        const SizedBox(height: 8),
        Text('Why', style: theme.textTheme.titleSmall),
        SegmentedButton<String>(
          key: const Key('decision-basis'),
          segments: const [
            ButtonSegment(value: 'fixes_defect', label: Text('Fixes a defect')),
            ButtonSegment(value: 'rubric_margin', label: Text('Scores better')),
            ButtonSegment(value: 'none', label: Text('Other')),
          ],
          selected: {_basis},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _basis = s.first),
        ),
        if (_basis == 'fixes_defect')
          TextField(
            key: const Key('decision-defect'),
            controller: _defect,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'The documented defect it fixes'),
          ),
        if (_basis == 'rubric_margin') ...[
          const SizedBox(height: 8),
          Table(
            key: const Key('decision-rubric'),
            children: [
              const TableRow(children: [SizedBox.shrink(), Text('Published'), Text('New')]),
              for (final a in aspects)
                TableRow(children: [
                  Text(a[0].toUpperCase() + a.substring(1)),
                  _score('champion', a, _champion),
                  _score('challenger', a, _challenger),
                ]),
            ],
          ),
          Text('Margin: ${_margin >= 0 ? '+' : ''}$_margin', key: const Key('decision-margin')),
        ],
        TextField(
          key: const Key('decision-note'),
          controller: _note,
          maxLength: 500,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        if (blocker != null)
          Text(blocker, key: const Key('decision-blocker'), style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('decision-record'),
          onPressed: _saving || blocker != null ? null : _record,
          child: const Text('Record decision'),
        ),
      ],
    );
  }
}
