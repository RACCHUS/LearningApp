import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner view of the five prompt-pack feedback signals (master plan v2.6
/// §5.7.6), per pack version, with sample sizes and suppressed groups
/// shown as suppressed:
///   1. reply checks (opt-in codes and counts),
///   2. learner feedback chips,
///   3. review evidence (source checks, volunteers, owner),
///   4. later checks on the same topic (opt-in, scope 2),
///   5. maintainer golden runs, recorded here.
class PromptPackSignalsScreen extends StatefulWidget {
  const PromptPackSignalsScreen({super.key, this.rpc});

  /// Test seam; defaults to Supabase RPCs.
  final Future<dynamic> Function(String fn, Map<String, dynamic> params)? rpc;

  @override
  State<PromptPackSignalsScreen> createState() => _PromptPackSignalsScreenState();
}

class _PromptPackSignalsScreenState extends State<PromptPackSignalsScreen> {
  Map<String, dynamic>? _replyChecks;
  Map<String, dynamic>? _chips;
  Map<String, dynamic>? _signals;
  String? _error;

  Future<dynamic> _call(String fn, [Map<String, dynamic> params = const {}]) {
    if (widget.rpc != null) return widget.rpc!(fn, params);
    return Supabase.instance.client.rpc(fn, params: params);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _call('get_prompt_quality_overview', {'p_days': 30}),
        _call('get_generated_lesson_feedback_overview', {'p_days': 90}),
        _call('get_prompt_pack_signals', {'p_days': 90}),
      ]);
      if (!mounted) return;
      setState(() {
        _replyChecks = Map<String, dynamic>.from(results[0] as Map);
        _chips = Map<String, dynamic>.from(results[1] as Map);
        _signals = Map<String, dynamic>.from(results[2] as Map);
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the signals. Admins only.');
    }
  }

  Future<void> _recordGoldenRun() async {
    final recorded = await showDialog<bool>(
      context: context,
      builder: (_) => _GoldenRunDialog(call: _call),
    );
    if (recorded == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt pack signals'),
        actions: [
          IconButton(
            key: const Key('signals-record-golden-run'),
            tooltip: 'Record a golden run',
            icon: const Icon(Icons.playlist_add_check),
            onPressed: _signals == null ? null : _recordGoldenRun,
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _signals == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Section(
                      title: '1. Reply checks (30 days, opted-in accounts)',
                      rows: _list(_replyChecks, 'groups'),
                      describe: (g) =>
                          '${g['pack_version']} · ${g['ai_label']} · ${g['tier']}: '
                          '${g['accounts']} accounts, ${g['replies']} replies, '
                          'clean first pass ${_pct(g['clean_first_pass_rate'])}, '
                          'slots complete ${_pct(g['slots_complete_rate'])}',
                      label: (g) => '${g['pack_version']} · ${g['ai_label']} · ${g['tier']}',
                    ),
                    _Section(
                      title: '2. Feedback chips (90 days)',
                      rows: _list(_chips, 'packs'),
                      describe: (g) =>
                          '${g['pack_version']}: ${g['accounts']} accounts — '
                          'too hard ${g['too_hard']}, too easy ${g['too_easy']}, '
                          'confusing ${g['confusing']}, wrong ${g['wrong']}, '
                          'not what I needed ${g['not_what_i_needed']}',
                      label: (g) => '${g['pack_version']}',
                    ),
                    _Section(
                      title: '3. Review evidence on AI lessons (90 days)',
                      rows: _list(_signals, 'review_evidence'),
                      describe: (g) =>
                          '${g['pack_version']} · ${g['aspect']}: ${g['lessons']} lessons, '
                          '${g['ok']} ok, ${g['concern']} concerns',
                      label: (g) => '${g['pack_version']} · ${g['aspect']}',
                    ),
                    _Section(
                      title: '4. Later checks on the same topic (90 days)',
                      note: 'Only accounts whose opt-in names this. Not a controlled comparison.',
                      rows: _list(_signals, 'downstream'),
                      describe: (g) =>
                          '${g['pack_version']}: ${g['accounts']} accounts, '
                          '${g['answered']} answers, ${_pct(g['later_check_accuracy'])} correct',
                      label: (g) => '${g['pack_version']}',
                    ),
                    _Section(
                      title: '5. Maintainer golden runs (90 days)',
                      rows: _list(_signals, 'golden_runs'),
                      describe: (g) =>
                          '${g['run_on']} · ${g['pack_version']} · ${g['ai_label']}: '
                          '${g['cases_passed']}/${g['cases_total']} '
                          '(${_pct(g['pass_rate'])})'
                          '${g['note'] == null ? '' : ' — ${g['note']}'}',
                      label: (g) => '${g['pack_version']}',
                    ),
                  ],
                ),
    );
  }

  static List<Map<String, dynamic>> _list(Map<String, dynamic>? m, String key) => [
        for (final r in (m?[key] as List? ?? const []))
          Map<String, dynamic>.from(r as Map),
      ];

  static String _pct(Object? v) {
    final n = v is num ? v : num.tryParse('$v');
    return n == null ? '—' : '${(n * 100).round()}%';
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    required this.describe,
    required this.label,
    this.note,
  });

  final String title;
  final String? note;
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) describe;
  final String Function(Map<String, dynamic>) label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (note != null) Text(note!, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          if (rows.isEmpty) const Text('Nothing yet.'),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(r['status'] == 'small_cohort_suppressed'
                  ? '${label(r)}: fewer than 5 accounts, not shown'
                  : describe(r)),
            ),
        ],
      ),
    );
  }
}

class _GoldenRunDialog extends StatefulWidget {
  const _GoldenRunDialog({required this.call});

  final Future<dynamic> Function(String fn, [Map<String, dynamic> params]) call;

  @override
  State<_GoldenRunDialog> createState() => _GoldenRunDialogState();
}

class _GoldenRunDialogState extends State<_GoldenRunDialog> {
  static const labels = ['chatgpt', 'gemini', 'claude', 'copilot', 'other'];
  final _pack = TextEditingController(text: 'la-gen-1.1');
  final _total = TextEditingController();
  final _passed = TextEditingController();
  final _note = TextEditingController();
  String _label = 'gemini';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _pack.dispose();
    _total.dispose();
    _passed.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final total = int.tryParse(_total.text.trim());
    final passed = int.tryParse(_passed.text.trim());
    if (total == null || passed == null || total < 1 || passed < 0 || passed > total) {
      setState(() => _error = 'Passed must be between 0 and the total.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.call('record_prompt_golden_run', {
        'p_pack_version': _pack.text.trim(),
        'p_ai_label': _label,
        'p_cases_total': total,
        'p_cases_passed': passed,
        'p_note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not record the run.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record a golden run'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('golden-pack'),
              controller: _pack,
              decoration: const InputDecoration(labelText: 'Prompt pack version'),
            ),
            DropdownButtonFormField<String>(
              key: const Key('golden-label'),
              value: _label,
              decoration: const InputDecoration(labelText: 'AI chat used'),
              items: [for (final l in labels) DropdownMenuItem(value: l, child: Text(l))],
              onChanged: (v) => setState(() => _label = v ?? _label),
            ),
            TextField(
              key: const Key('golden-total'),
              controller: _total,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cases run'),
            ),
            TextField(
              key: const Key('golden-passed'),
              controller: _passed,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cases passed'),
            ),
            TextField(
              key: const Key('golden-note'),
              controller: _note,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Note (optional, e.g. free tier)'),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          key: const Key('golden-save'),
          onPressed: _saving ? null : _save,
          child: const Text('Record'),
        ),
      ],
    );
  }
}
