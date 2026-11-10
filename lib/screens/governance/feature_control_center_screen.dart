import 'package:flutter/material.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

/// Owner-facing release controls. All mutations are verified by database RPCs.
/// This route is deferred and never added to learner navigation.
class FeatureControlCenterScreen extends StatefulWidget {
  final SiteFeatureService? service;
  const FeatureControlCenterScreen({super.key, this.service});

  @override
  State<FeatureControlCenterScreen> createState() =>
      _FeatureControlCenterScreenState();
}

class _FeatureControlCenterScreenState
    extends State<FeatureControlCenterScreen> {
  late final SiteFeatureService _service;
  List<AdminSiteFeature> _features = const [];
  bool _loading = true;
  bool _saving = false;
  bool _isAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SiteFeatureService();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final admin = await _service.isAdmin();
      if (!mounted) return;
      if (!admin) {
        setState(() {
          _isAdmin = false;
          _features = const [];
          _loading = false;
        });
        return;
      }
      final features = await _service.listAdminFeatures();
      if (!mounted) return;
      setState(() {
        _isAdmin = true;
        _features = features;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The control plane is unavailable or its migration has not '
            'been deployed. No feature settings were changed.';
        _loading = false;
      });
    }
  }

  Future<void> _askForChange(
    AdminSiteFeature feature, {
    required bool enabled,
    required String maturity,
  }) async {
    if (_saving || (enabled && !feature.releaseReady)) return;
    var reason = '';
    final recordedReason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refreshDialog) => AlertDialog(
          title: Text('Update ${feature.label}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Availability: ${enabled ? "On" : "Off"}'),
              Text('Verification: ${maturity == "verified" ? "Verified" : "Experimental"}'),
              const SizedBox(height: 12),
              TextField(
                key: const Key('feature-change-reason'),
                onChanged: (value) => refreshDialog(() => reason = value),
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Audit reason (at least 8 characters)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: reason.trim().length < 8
                  ? null
                  : () => Navigator.of(ctx).pop(reason.trim()),
              child: const Text('Confirm change'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || recordedReason == null) return;
    setState(() => _saving = true);
    try {
      await _service.updateFeature(
        current: feature,
        enabled: enabled,
        maturity: maturity,
        reason: recordedReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feature change recorded.')),
      );
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Change rejected. Refresh the registry and review permissions, '
          'release readiness, and any concurrent edits.',
        )),
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Control Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _saving ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _refresh, child: const Text('Retry')),
                  ],
                ))
              : !_isAdmin
                  ? const Center(child: Text('Administrator access required.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'These are release controls, not proof of backend enforcement. '
                          'Entries marked planned are not yet wired; their OFF '
                          'position must not be mistaken for a live shutdown. '
                          'When connected, switches preserve user data. '
                          'Sensitive operations require server-side gates.',
                        ),
                        const SizedBox(height: 12),
                        ..._features.map((feature) => Card(
                          key: ValueKey('feature-${feature.key}'),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(feature.label),
                                  subtitle: Text(
                                    '${feature.key} · ${feature.category} · '
                                    '${feature.releaseReady ? "Connected after rollout" : "Planned; not yet connected"}',
                                  ),
                                  value: feature.enabled,
                                  onChanged: (_saving ||
                                          (!feature.releaseReady &&
                                              !feature.enabled))
                                      ? null
                                      : (value) => _askForChange(
                                          feature,
                                          enabled: value,
                                          maturity: feature.maturity,
                                        ),
                                ),
                                Text(feature.description,
                                    style: theme.textTheme.bodySmall),
                                Row(
                                  children: [
                                    const Text('Verification'),
                                    const SizedBox(width: 12),
                                    DropdownButton<String>(
                                      value: feature.maturity,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'experimental',
                                          child: Text('Experimental'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'verified',
                                          child: Text('Verified'),
                                        ),
                                      ],
                                      onChanged: _saving || !feature.releaseReady
                                          ? null
                                          : (status) {
                                              if (status != null &&
                                                  status != feature.maturity) {
                                                _askForChange(feature,
                                                    enabled: feature.enabled,
                                                    maturity: status);
                                              }
                                            },
                                    ),
                                    const Spacer(),
                                    Text('Rev ${feature.revision}',
                                        style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                      ],
                    ),
    );
  }
}
