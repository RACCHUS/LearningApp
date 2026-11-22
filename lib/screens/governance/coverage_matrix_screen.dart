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
  const CoverageMatrixScreen({super.key, this.loadTargets, this.loadMatrix});

  /// Test seams; default to the Supabase RPCs.
  final Future<List<String>> Function()? loadTargets;
  final Future<Map<String, dynamic>> Function(String slug)? loadMatrix;

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
      appBar: AppBar(title: const Text('Coverage matrix')),
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
