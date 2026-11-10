import 'package:flutter/material.dart';
import 'package:learning_pwa/services/analytics/product_analytics_overview_service.dart';

/// A deliberately narrow administrative first slice, not a general user
/// activity feed. All numbers come from the protected, aggregated server RPC.
class ProductAnalyticsOverviewScreen extends StatefulWidget {
  final ProductAnalyticsOverviewService? service;

  const ProductAnalyticsOverviewScreen({super.key, this.service});

  @override
  State<ProductAnalyticsOverviewScreen> createState() =>
      _ProductAnalyticsOverviewScreenState();
}

class _ProductAnalyticsOverviewScreenState
    extends State<ProductAnalyticsOverviewScreen> {
  late final ProductAnalyticsOverviewService _service;
  bool _checkingAccess = true;
  bool _isAdmin = false;
  bool _loading = false;
  Object? _error;
  int _days = 7;
  ProductAnalyticsOverview? _snapshot;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductAnalyticsOverviewService();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    setState(() {
      _checkingAccess = true;
      _error = null;
    });
    final allowed = await _service.isAdmin();
    if (!mounted) return;
    setState(() {
      _checkingAccess = false;
      _isAdmin = allowed;
    });
    if (allowed) await _load();
  }

  Future<void> _load() async {
    if (!_isAdmin) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _service.fetch(days: _days);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _snapshot = null; // Never show stale totals as current.
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Analytics'),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Refresh analytics',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _checkingAccess
          ? const Center(child: CircularProgressIndicator())
          : !_isAdmin
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Access Denied — administrative permission required.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _loading && _snapshot == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Only explicitly opted-in, eligible accounts are '
                          'included. Activity outside that cohort is not '
                          'measured. No assessment scores or user-level '
                          'events are included.',
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 1, label: Text('1 day')),
                            ButtonSegment(value: 7, label: Text('7 days')),
                            ButtonSegment(value: 30, label: Text('30 days')),
                          ],
                          selected: {_days},
                          onSelectionChanged: (selection) {
                            setState(() => _days = selection.first);
                            _load();
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_error != null) ...[
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Analytics unavailable. Server deployment, '
                                'authorization or connectivity may need '
                                'attention. No counts are being assumed.',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ] else if (_snapshot case final snapshot?) ...[
                          Text('Coverage: explicitly opted-in eligible accounts',
                              style: theme.textTheme.bodySmall),
                          Text(
                            'Server as of: ${snapshot.asOf.toLocal()}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          if (snapshot.status == 'not_measured')
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Not measured — no consented product events '
                                  'are present for this time window. '
                                  'This is not zero platform usage.',
                                ),
                              ),
                            )
                          else if (snapshot.status == 'small_cohort_suppressed')
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Small cohort suppressed — fewer than five '
                                  'eligible users. Counts are hidden.',
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _metric('Opt-in active users', snapshot.activeUsers),
                                _metric('Events', snapshot.eventCount),
                                _metric('Session starts', snapshot.sessionStarts),
                                _metric('Resource opens', snapshot.resourceOpens),
                                _metric('External clicks', snapshot.externalClicks),
                              ],
                            ),
                        ],
                      ],
                    ),
    );
  }

  Widget _metric(String label, int? count) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(
                count?.toString() ?? 'Not measured',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
