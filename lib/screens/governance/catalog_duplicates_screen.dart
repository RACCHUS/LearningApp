import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Possible duplicates across the published catalog (master plan v2.6
/// §6.4), for moderators: pairs with a reason and a confidence. These are
/// suggestions only. "Not a duplicate" hides a pair; nothing is merged,
/// hidden or retired from here.
class CatalogDuplicatesScreen extends StatefulWidget {
  const CatalogDuplicatesScreen({super.key, this.load, this.dismiss});

  /// Test seams; default to the Supabase RPCs.
  final Future<List<dynamic>> Function()? load;
  final Future<void> Function(String a, String b)? dismiss;

  @override
  State<CatalogDuplicatesScreen> createState() => _CatalogDuplicatesScreenState();
}

class _CatalogDuplicatesScreenState extends State<CatalogDuplicatesScreen> {
  static const _reasons = {
    'same_content': 'same text',
    'similar_title': 'similar title',
    'similar_content': 'similar text',
  };

  List<dynamic>? _pairs;
  String? _error;

  Future<List<dynamic>> _load() async {
    if (widget.load != null) return widget.load!();
    final res = await Supabase.instance.client
        .rpc('get_catalog_duplicate_candidates', params: {'p_limit': 100});
    return (res as List?) ?? const [];
  }

  Future<void> _dismiss(String a, String b) async {
    if (widget.dismiss != null) return widget.dismiss!(a, b);
    await Supabase.instance.client.rpc('dismiss_catalog_duplicate',
        params: {'p_lesson_a': a, 'p_lesson_b': b});
  }

  Future<void> _refresh() async {
    try {
      final pairs = await _load();
      if (mounted) setState(() => _pairs = pairs);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load duplicates. Moderators only.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Possible duplicates')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _pairs == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Published lessons that look alike, strongest first. Check them by hand: '
                      'different editions, exams or languages are not duplicates.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_pairs!.isEmpty)
                      const ListTile(title: Text('No likely duplicates.')),
                    for (final raw in _pairs!) _pair(Map<String, dynamic>.from(raw as Map)),
                  ],
                ),
    );
  }

  Widget _pair(Map<String, dynamic> p) {
    final a = p['a_id'] as String;
    final b = p['b_id'] as String;
    String where(Object? t) => t == null ? 'standalone' : '$t';
    final confidence = ((p['confidence'] as num? ?? 0) * 100).round();
    return Card(
      key: Key('dup_${a}_$b'),
      child: ListTile(
        title: Text('${p['a_title']}  ↔  ${p['b_title']}'),
        subtitle: Text(
          '${_reasons[p['reason']] ?? p['reason']}, $confidence% · '
          '${where(p['a_target'])} / ${where(p['b_target'])}'
          '${p['same_book'] == true ? ' · same book' : ''}',
        ),
        trailing: TextButton(
          key: Key('dup_dismiss_${a}_$b'),
          onPressed: () async {
            try {
              await _dismiss(a, b);
              await _refresh();
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not dismiss that pair.')),
                );
              }
            }
          },
          child: const Text('Not a duplicate'),
        ),
      ),
    );
  }
}
