import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maintainer view of the Coverage Matrix (master plan v2.6 §4.2): pick a
/// curriculum target and see, per objective, which roles are covered and
/// how (reviewed, imported, gap, not yet verified). Gaps are the planner's
/// fill list.
class CoverageMatrixScreen extends ConsumerStatefulWidget {
  const CoverageMatrixScreen({super.key, this.loadTargets, this.loadMatrix, this.loadFillList});

  /// Test seams; default to the Supabase RPCs.
  final Future<List<String>> Function()? loadTargets;
  final Future<Map<String, dynamic>> Function(String slug)? loadMatrix;
  final Future<List<dynamic>> Function()? loadFillList;

  @override
  ConsumerState<CoverageMatrixScreen> createState() => _CoverageMatrixScreenState();
}

class _CoverageMatrixScreenState extends ConsumerState<CoverageMatrixScreen> {
  List<String>? _targets;
  String? _slug;
  Map<String, dynamic>? _matrix;
  String? _error;

  Future<List<String>> _fetchTargets() async {
    if (widget.loadTargets != null) return widget.loadTargets!();
    // The freshness view lists every published version (admin-only).
    final res = await Supabase.instance.client.rpc('get_curriculum_freshness');
    final versions = (res as Map)['versions'] as List? ?? const [];
    return {for (final v in versions) (v as Map)['target_slug'].toString()}.toList()..sort();
  }

  Future<Map<String, dynamic>> _fetchMatrix(String slug) async {
    if (widget.loadMatrix != null) return widget.loadMatrix!(slug);
    final res = await Supabase.instance.client.rpc(
      'get_coverage_matrix',
      params: {'p_target_slug': slug},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  @override
  void initState() {
    super.initState();
    _fetchTargets().then((t) {
      if (!mounted) return;
      setState(() => _targets = t);
      if (t.isNotEmpty) _select(t.first);
    }).catchError((_) {
      if (mounted) setState(() => _error = 'Could not load targets. Admins only.');
    });
  }

  Future<void> _select(String slug) async {
    setState(() {
      _slug = slug;
      _matrix = null;
    });
    try {
      final m = await _fetchMatrix(slug);
      if (mounted && _slug == slug) setState(() => _matrix = m);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the matrix.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bridges = ref.watch(bridgeLibraryProvider).valueOrNull;
    final rows = _matrix == null || bridges == null
        ? null
        : [
            for (final r in (_matrix!['objectives'] as List? ?? const []))
              CoverageRow.fromServer(Map<String, dynamic>.from(r as Map), bridges),
          ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coverage matrix'),
        actions: [
          IconButton(
            key: const Key('coverage_fill_list'),
            icon: const Icon(Icons.format_list_numbered),
            tooltip: 'Fill list: every gap, most valuable first',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CoverageFillListScreen(load: widget.loadFillList),
            )),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _targets == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButton<String>(
                      key: const Key('coverage_target'),
                      value: _slug,
                      isExpanded: true,
                      items: [
                        for (final t in _targets!) DropdownMenuItem(value: t, child: Text(t)),
                      ],
                      onChanged: (v) => v == null ? null : _select(v),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final s in CoverageState.values)
                          Text('${s.icon} ${s.label}', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (rows == null)
                      const Center(child: CircularProgressIndicator())
                    else if (rows.isEmpty)
                      const Text('No objectives in the published version.')
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          key: const Key('coverage_table'),
                          columns: [
                            const DataColumn(label: Text('Objective')),
                            for (final r in CoverageRole.values) DataColumn(label: Text(r.label)),
                          ],
                          rows: [
                            for (final row in rows)
                              DataRow(cells: [
                                DataCell(Text('${row.code ?? ''} ${row.title}'.trim())),
                                for (final role in CoverageRole.values)
                                  DataCell(Tooltip(
                                    message: row.cells[role]!.label,
                                    child: Text(
                                      '${row.cells[role]!.icon} ${row.cells[role]!.label}',
                                      key: Key('cell_${row.code}_${role.name}'),
                                    ),
                                  )),
                              ]),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// The maintainer seeding list (plan v2.6 §4.2, §6.5): every published
/// topic missing a content role, ranked by reuse value, with every term of
/// the score shown so the order can be checked. It orders work only.
class CoverageFillListScreen extends StatefulWidget {
  const CoverageFillListScreen({super.key, this.load});

  /// Test seam; defaults to `get_coverage_fill_list`.
  final Future<List<dynamic>> Function()? load;

  @override
  State<CoverageFillListScreen> createState() => _CoverageFillListScreenState();
}

class _CoverageFillListScreenState extends State<CoverageFillListScreen> {
  List<dynamic>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    final load = widget.load ??
        () async => (await Supabase.instance.client
                .rpc('get_coverage_fill_list', params: {'p_limit': 200}) as List?) ??
            const [];
    load().then((r) {
      if (mounted) setState(() => _rows = r);
    }).catchError((_) {
      if (mounted) setState(() => _error = 'Could not load the fill list. Moderators only.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Fill list')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _rows == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Topics missing Teach, Example, Practice or Check, most valuable first: '
                      'how many books share the topic × learner requests × how much is missing. '
                      'Bridges and outside resources are not counted here.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_rows!.isEmpty) const ListTile(title: Text('No gaps in published curricula.')),
                    for (final (i, raw) in _rows!.indexed) _row(i + 1, Map<String, dynamic>.from(raw as Map)),
                  ],
                ),
    );
  }

  Widget _row(int rank, Map<String, dynamic> r) {
    final missing = [for (final m in (r['missing'] as List? ?? const [])) '$m'];
    final code = r['code'];
    return ListTile(
      key: Key('fill_${r['objective_id']}'),
      leading: Text('$rank'),
      title: Text('${r['target_slug']} · ${code == null ? '' : '$code '}${r['title']}'),
      subtitle: Text(
        'Missing: ${missing.join(', ')} · priority ${r['priority']} '
        '(books ${r['fan_in']} × requests ${r['frequency_boost']} × missing ${r['coverage_deficit']})',
      ),
    );
  }
}
