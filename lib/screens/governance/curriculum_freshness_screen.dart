import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner view of curriculum freshness (master plan v2.6 §7.1–7.2): each
/// published version's volatility class, review-by date and source pin,
/// and the open refresh queue (review due, source changed) with resolve
/// and dismiss; and every champion/challenger decision (§7.3). Admin-only
/// on the server.
class CurriculumFreshnessScreen extends StatefulWidget {
  const CurriculumFreshnessScreen({super.key, this.load, this.resolve, this.loadDecisions});

  /// Test seams; default to the Supabase RPCs.
  final Future<Map<String, dynamic>> Function()? load;
  final Future<List<dynamic>> Function()? loadDecisions;
  final Future<void> Function(String id, String status)? resolve;

  @override
  State<CurriculumFreshnessScreen> createState() => _CurriculumFreshnessScreenState();
}

class _CurriculumFreshnessScreenState extends State<CurriculumFreshnessScreen> {
  Map<String, dynamic>? _data;
  List<dynamic> _decisions = const [];
  String? _error;
  bool _busy = false;

  Future<Map<String, dynamic>> _load() async {
    if (widget.load != null) return widget.load!();
    final res = await Supabase.instance.client.rpc('get_curriculum_freshness');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<dynamic>> _loadDecisions() async {
    if (widget.loadDecisions != null) return widget.loadDecisions!();
    final res = await Supabase.instance.client.rpc('get_content_version_decisions');
    return (res as List?) ?? const [];
  }

  Future<void> _resolve(String id, String status) async {
    if (widget.resolve != null) return widget.resolve!(id, status);
    await Supabase.instance.client.rpc(
      'resolve_curriculum_refresh_item',
      params: {'p_id': id, 'p_status': status},
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _load();
      // Decisions are a secondary list; the screen still works without them.
      final decisions = await _loadDecisions().catchError((_) => const <dynamic>[]);
      if (mounted) {
        setState(() {
          _data = data;
          _decisions = decisions;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load freshness. Admins only.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = (_data?['open_items'] as List?) ?? const [];
    final versions = (_data?['versions'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Curriculum freshness'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Needs attention (${items.length})', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Raised daily when a review-by date passes or a pinned source changes. '
                      'Nothing learners see changes until you publish a corrected version.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (items.isEmpty)
                      const ListTile(title: Text('Nothing due.')),
                    for (final raw in items)
                      _itemCard(Map<String, dynamic>.from(raw as Map)),
                    const SizedBox(height: 16),
                    Text('Published versions (${versions.length})', style: theme.textTheme.titleMedium),
                    for (final raw in versions)
                      _versionTile(Map<String, dynamic>.from(raw as Map)),
                    const SizedBox(height: 16),
                    Text('Replacement decisions (${_decisions.length})',
                        style: theme.textTheme.titleMedium),
                    Text(
                      'A new version replaces the published one only with a recorded reason: '
                      'a documented defect it fixes, or a rubric margin. Others are kept as '
                      'alternates or rejected; old versions remain, retired.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_decisions.isEmpty)
                      const ListTile(title: Text('No decisions yet.')),
                    for (final raw in _decisions)
                      _decisionTile(Map<String, dynamic>.from(raw as Map)),
                  ],
                ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final id = item['id'] as String;
    final reason = item['reason'] == 'source_changed' ? 'Source changed' : 'Review due';
    return Card(
      key: Key('freshness_item_$id'),
      child: ListTile(
        title: Text('$reason: ${item['target_slug']} (${item['version_code']})'),
        subtitle: Text('${item['detail'] ?? ''}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            TextButton(
              onPressed: _busy ? null : () => _act(id, 'resolved'),
              child: const Text('Resolved'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _act(id, 'dismissed'),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _act(String id, String status) async {
    try {
      await _resolve(id, status);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update that item.')),
        );
      }
    }
    await _refresh();
  }

  Widget _versionTile(Map<String, dynamic> v) {
    final cls = v['volatility_class'] as String?;
    return ListTile(
      dense: true,
      title: Text('${v['target_title'] ?? v['target_slug']} · ${v['version_code']}'),
      subtitle: Text(
        cls == null
            ? 'No freshness set (manifest has no volatility class)'
            : '$cls · review by ${v['review_by']}'
                '${v['source_pin'] != null ? ' · source ${v['source_pin']}' : ''}',
      ),
    );
  }

  Widget _decisionTile(Map<String, dynamic> d) {
    const labels = {'replace': 'Replaced', 'alternate': 'Kept as alternate', 'reject': 'Rejected'};
    final basis = switch (d['basis']) {
      'fixes_defect' => 'fixes: ${d['defect_ref']}',
      'rubric_margin' => 'rubric margin +${d['rubric_margin']}',
      _ => d['note'] ?? 'no basis',
    };
    final day = '${d['decided_at'] ?? ''}';
    return ListTile(
      dense: true,
      key: Key('decision_${d['target_slug']}_${d['challenger']}'),
      title: Text('${labels[d['decision']] ?? d['decision']}: ${d['target_slug']} '
          '${d['champion']} → ${d['challenger']}'),
      subtitle: Text('$basis · ${day.length >= 10 ? day.substring(0, 10) : day} · ${d['decided_via']}'),
    );
  }
}
