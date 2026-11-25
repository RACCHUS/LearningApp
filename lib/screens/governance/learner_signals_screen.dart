import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner view of the objective-level learner signals (ingestion plan v1.2
/// slice 13 and §16.4): per objective, how many opted-in learners finished
/// the teaching, how they then did on its independent checks, and their
/// study time against the estimate. Groups under 5 accounts are withheld.
/// Descriptive evidence only: it is not a comparison and proves no effect.
class LearnerSignalsScreen extends StatefulWidget {
  const LearnerSignalsScreen({super.key, this.loadVersions, this.rpc});

  /// Test seams; default to Supabase.
  final Future<List<Map<String, dynamic>>> Function()? loadVersions;
  final Future<dynamic> Function(String fn, Map<String, dynamic> params)? rpc;

  @override
  State<LearnerSignalsScreen> createState() => _LearnerSignalsScreenState();
}

class _LearnerSignalsScreenState extends State<LearnerSignalsScreen> {
  List<Map<String, dynamic>>? _versions;
  String? _versionId;
  Map<String, dynamic>? _report;
  String? _error;
  String? _notice;
  bool _opening = false;

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
    final out = [
      for (final r in res as List)
        {
          'id': r['id'].toString(),
          'label':
              '${(r['learning_targets'] as Map?)?['title'] ?? 'Target'} · ${r['version_code']}',
        },
    ]..sort((a, b) => a['label']!.compareTo(b['label']!));
    return out;
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
          if (mounted) setState(() => _error = 'Could not load targets.');
        });
  }

  Future<void> _select(String id) async {
    setState(() {
      _versionId = id;
      _report = null;
      _notice = null;
    });
    try {
      final r = await _call('get_learner_signal_report', {
        'p_target_version_id': id,
      });
      if (mounted && _versionId == id) {
        setState(() => _report = Map<String, dynamic>.from(r as Map));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load the signals. Admins and moderators only.',
        );
      }
    }
  }

  Future<void> _openReviews() async {
    final id = _versionId;
    if (id == null) return;
    setState(() => _opening = true);
    try {
      final r = Map<String, dynamic>.from(
        await _call('open_learner_signal_reviews', {'p_target_version_id': id})
            as Map,
      );
      if (mounted) {
        setState(
          () => _notice =
              'Opened ${r['opened']} review item(s) in the moderation queue; '
              '${r['already_open']} already open.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _notice = 'Could not open review items.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  List<Map<String, dynamic>> get _objectives => [
    for (final o in (_report?['objectives'] as List? ?? const []))
      Map<String, dynamic>.from(o as Map),
  ];

  bool get _hasFailureSignal => _objectives.any(
    (o) => (o['signals'] as List? ?? const []).contains(
      'repeated_failure_after_teaching',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Learner signals')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _versions == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_versions!.isEmpty)
                  const Text('No published targets.')
                else
                  DropdownButton<String>(
                    key: const Key('signals-version'),
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
                  'Descriptive evidence, not a comparison: it cannot show that a change worked.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (_report == null && _versionId != null)
                  const Center(child: CircularProgressIndicator())
                else if (_report != null) ...[
                  Text(
                    _report!['learners_status'] == 'small_cohort_suppressed'
                        ? 'Learners with progress: fewer than 5, not shown'
                        : 'Learners with progress: ${_report!['consenting_learners']}',
                    key: const Key('signals-learners'),
                  ),
                  const SizedBox(height: 8),
                  if (_objectives.isEmpty) const Text('No objectives.'),
                  for (final o in _objectives) _ObjectiveSignal(o: o),
                  const SizedBox(height: 8),
                  if (_hasFailureSignal)
                    FilledButton.icon(
                      key: const Key('signals-open-reviews'),
                      onPressed: _opening ? null : _openReviews,
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Open review items'),
                    ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_notice!, key: const Key('signals-notice')),
                    ),
                ],
              ],
            ),
    );
  }
}

class _ObjectiveSignal extends StatelessWidget {
  const _ObjectiveSignal({required this.o});

  final Map<String, dynamic> o;

  static const _signalText = {
    'repeated_failure_after_teaching':
        'Learners keep failing the checks after the teaching: review the teaching and Bridges first',
    'time_off_estimate':
        'Study time is outside the estimate: update the estimate',
  };

  static String _pct(Object? v) {
    final n = v is num ? v : num.tryParse('$v');
    return n == null ? '—' : '${(n * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = '${o['code'] ?? ''} ${o['title'] ?? ''}'.trim();
    final low = o['estimate_low'];
    final high = o['estimate_high'];
    final estimate = low == null ? 'no estimate' : 'estimate $low–$high min';
    final suppressed = o['status'] == 'small_cohort_suppressed';
    final signals = [
      for (final s in (o['signals'] as List? ?? const [])) s.toString(),
    ];
    return Card(
      key: Key('signal-${o['objective_id']}'),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: theme.textTheme.titleSmall),
            Text(
              '${o['held_out_items']} independent checks · $estimate',
              style: theme.textTheme.bodySmall,
            ),
            if (suppressed)
              const Text(
                'Fewer than 5 learners finished the teaching, not shown',
              )
            else ...[
              Text('${o['completed_learners']} finished the teaching'),
              Text(
                o['checked_after_teaching'] == null
                    ? 'Fewer than 5 took the checks afterwards, not shown'
                    : '${o['checked_after_teaching']} took the checks afterwards; '
                          '${_pct(o['fail_rate'])} scored below 60%',
              ),
              Text(
                o['median_active_minutes'] == null
                    ? 'Fewer than 5 with study time, not shown'
                    : 'Median study time ${o['median_active_minutes']} min '
                          '(${o['timed_learners']} learners)',
              ),
            ],
            for (final s in signals)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '⚑ ${_signalText[s] ?? s}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
