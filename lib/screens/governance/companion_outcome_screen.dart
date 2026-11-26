import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner view of the companion outcome report (companion plan v1.0 §10,
/// EX-10; `get_companion_outcome_report`). For one goal: how many opted-in
/// learners study with an outside resource, how far they map it, and how
/// often a LearningApp check followed something they marked studied.
/// Groups under 5 accounts are withheld by the server. Descriptive only.
class CompanionOutcomeScreen extends StatefulWidget {
  const CompanionOutcomeScreen({super.key, this.loadVersions, this.rpc});

  /// Test seams; default to Supabase.
  final Future<List<Map<String, dynamic>>> Function()? loadVersions;
  final Future<dynamic> Function(String fn, Map<String, dynamic> params)? rpc;

  @override
  State<CompanionOutcomeScreen> createState() => _CompanionOutcomeScreenState();
}

class _CompanionOutcomeScreenState extends State<CompanionOutcomeScreen> {
  List<Map<String, dynamic>>? _versions;
  String? _versionId;
  Map<String, dynamic>? _report;
  String? _error;

  Future<dynamic> _call(String fn, Map<String, dynamic> params) {
    if (widget.rpc != null) return widget.rpc!(fn, params);
    return Supabase.instance.client.rpc(fn, params: params);
  }

  Future<List<Map<String, dynamic>>> _fetchVersions() async {
    if (widget.loadVersions != null) return widget.loadVersions!();
    final res = await Supabase.instance.client
        .from('target_versions')
        .select('id, version_code, learning_targets(title)')
        .eq('status', 'published');
    return [
      for (final r in res as List)
        {
          'id': r['id'].toString(),
          'label':
              '${(r['learning_targets'] as Map?)?['title'] ?? 'Target'} · ${r['version_code']}',
        },
    ]..sort((a, b) => a['label']!.compareTo(b['label']!));
  }

  @override
  void initState() {
    super.initState();
    _fetchVersions()
        .then((v) {
          if (!mounted) return;
          setState(() => _versions = v);
          if (v.isNotEmpty) _select(v.first['id'].toString());
        })
        .catchError((_) {
          if (mounted) setState(() => _error = 'Could not load goals.');
        });
  }

  Future<void> _select(String id) async {
    setState(() {
      _versionId = id;
      _report = null;
    });
    try {
      final r = await _call('get_companion_outcome_report', {
        'p_target_version_id': id,
      });
      if (mounted && _versionId == id) {
        setState(() => _report = Map<String, dynamic>.from(r as Map));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Could not load the report. Admins and moderators only.',
        );
      }
    }
  }

  static String _pct(Object? v) {
    final n = v is num ? v : num.tryParse('$v');
    return n == null ? '—' : '${(n * 100).round()}%';
  }

  static bool _ok(Object? status) => status == 'ok';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = _report;
    final mapping = Map<String, dynamic>.from(
      (r?['mapping'] as Map?) ?? const {},
    );
    final checked = Map<String, dynamic>.from(
      (r?['studied_then_checked'] as Map?) ?? const {},
    );
    final notMeasured = [
      for (final m in (r?['not_measured'] as List? ?? const []))
        if (m is Map) Map<String, dynamic>.from(m),
    ];
    const withheld = 'fewer than 5, or would reveal a smaller group: not shown';
    return Scaffold(
      appBar: AppBar(title: const Text('Outside study outcomes')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _versions == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_versions!.isEmpty)
                  const Text('No published goals.')
                else
                  DropdownButton<String>(
                    key: const Key('outcome-version'),
                    value: _versionId,
                    isExpanded: true,
                    items: [
                      for (final v in _versions!)
                        DropdownMenuItem(
                          value: v['id'].toString(),
                          child: Text(v['label'].toString()),
                        ),
                    ],
                    onChanged: (v) => v == null ? null : _select(v),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Opted-in learners only. Groups under 5 accounts are not shown. '
                  'Descriptive only: "studied" is what learners say; this counts how often '
                  'one of LearningApp\'s own checks followed it. It proves no effect.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (r == null && _versionId != null)
                  const Center(child: CircularProgressIndicator())
                else if (r != null) ...[
                  _Section(
                    title: 'Who studies outside LearningApp',
                    lines: [
                      _ok(r['goal_learners_status'])
                          ? 'Learners on this goal: ${r['goal_learners']}'
                          : 'Learners on this goal: $withheld',
                      _ok(r['outside_resource_status'])
                          ? 'With an outside resource: ${r['with_outside_resource']} '
                                '(${_pct(r['outside_resource_share'])})'
                          : 'With an outside resource: $withheld',
                    ],
                    keyName: 'outcome-who',
                  ),
                  _Section(
                    title: 'How far they mapped it',
                    lines: _ok(mapping['status'])
                        ? [
                            'Only listed it: ${mapping['listed_only']}',
                            'Ticked what it covers: ${mapping['ticked_objectives']}',
                            'Pasted an outline: ${mapping['outline_word_match']}',
                            'Mapped the outline with their own AI: ${mapping['outline_own_ai']}',
                          ]
                        : ['Breakdown $withheld'],
                    keyName: 'outcome-mapping',
                  ),
                  _Section(
                    title: 'Marked studied, then checked',
                    lines: _ok(checked['status'])
                        ? [
                            'Objectives marked studied (with checks available): ${checked['studied_pairs']}',
                            'Followed by a LearningApp check within 7 days: '
                                '${checked['checked_within_7_days']} (${_pct(checked['checked_share'])})',
                            if (checked['mean_check_score'] != null)
                              'Mean check score: ${_pct(checked['mean_check_score'])}',
                          ]
                        : ['Counts $withheld'],
                    keyName: 'outcome-checked',
                  ),
                  if (notMeasured.isNotEmpty)
                    _Section(
                      title: 'Not measured',
                      lines: [
                        for (final m in notMeasured)
                          '${m['measure']}: ${m['reason']}',
                      ],
                      keyName: 'outcome-not-measured',
                    ),
                ],
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.lines,
    required this.keyName,
  });

  final String title;
  final List<String> lines;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key(keyName),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final l in lines) Text(l),
          ],
        ),
      ),
    );
  }
}
