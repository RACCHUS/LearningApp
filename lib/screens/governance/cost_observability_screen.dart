import 'package:flutter/material.dart';
import 'package:learning_pwa/models/governance/usage_quota.dart';
import 'package:learning_pwa/services/governance/cost_observability_service.dart';
import 'package:learning_pwa/services/supabase_health_service.dart';
import 'package:learning_pwa/widgets/error_retry_view.dart';

class CostObservabilityScreen extends StatefulWidget {
  final CostObservabilityService? service;

  const CostObservabilityScreen({super.key, this.service});

  @override
  State<CostObservabilityScreen> createState() => _CostObservabilityScreenState();
}

class _CostObservabilityScreenState extends State<CostObservabilityScreen> {
  late final CostObservabilityService _service;

  bool _isCheckingAuth = true;
  bool _isAdmin = false;
  bool _isLoading = false;
  Object? _error;

  int _selectedHours = 24;
  ObservabilityHealthSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CostObservabilityService();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    setState(() {
      _isCheckingAuth = true;
      _error = null;
    });

    try {
      final isAdmin = await _service.isAdmin();
      if (!mounted) return;

      setState(() {
        _isAdmin = isAdmin;
        _isCheckingAuth = false;
      });

      if (isAdmin) {
        await _loadSnapshot();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await _service.measureHealthSnapshot(hours: _selectedHours);
      if (!mounted) return;

      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cost & Observability Console'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Telemetry',
              onPressed: _isLoading ? null : _loadSnapshot,
            ),
        ],
      ),
      body: _buildBody(theme, colorScheme),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isCheckingAuth) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorRetryView(
        message: 'Failed to load cost observability metrics: $_error',
        onRetry: _checkAccessAndLoad,
      );
    }

    if (!_isAdmin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You must have the "admin" role to view platform cost metrics and observability telemetry.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _checkAccessAndLoad,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Access Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading && _snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Governance Notice
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.insights, size: 20, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ECO-00C Observability Mode — System quotas enforce rate-limiting across AI inference, Cloud TTS, and storage to protect operating budgets.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Controls Bar: Time Window Selection
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Observation Window',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 24, label: Text('24h')),
                ButtonSegment(value: 168, label: Text('7d')),
                ButtonSegment(value: 720, label: Text('30d')),
              ],
              selected: {_selectedHours},
              onSelectionChanged: (newSelection) {
                setState(() => _selectedHours = newSelection.first);
                _loadSnapshot();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Section 1: Backend Health & Latency
        _buildHealthCard(theme, colorScheme),
        const SizedBox(height: 16),

        // Section 2: Consumed Resources & Costs
        if (_snapshot?.telemetry != null) ...[
          _buildTelemetrySummary(theme, colorScheme, _snapshot!.telemetry!),
          const SizedBox(height: 16),
          _buildMetricsGrid(theme, colorScheme, _snapshot!.telemetry!),
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No telemetry recorded in the selected window.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHealthCard(ThemeData theme, ColorScheme colorScheme) {
    final status = _snapshot?.supabaseStatus ?? SupabaseStatus.unknown;
    final ping = _snapshot?.pingLatencyMs ?? 0;

    Color statusColor;
    String statusText;
    switch (status) {
      case SupabaseStatus.reachable:
        statusColor = Colors.green;
        statusText = 'Operational / Reachable';
        break;
      case SupabaseStatus.unreachable:
        statusColor = Colors.red;
        statusText = 'Degraded / Unreachable';
        break;
      case SupabaseStatus.unknown:
        statusColor = Colors.orange;
        statusText = 'Checking Status...';
        break;
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Backend Reachability & Edge Health',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Latency: ${ping}ms',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.record_voice_over_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fallback Protection: On-device Web Speech API activates automatically at 80% quota or during degraded connectivity.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetrySummary(
    ThemeData theme,
    ColorScheme colorScheme,
    SystemUsageTelemetry telemetry,
  ) {
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.attach_money, color: colorScheme.onPrimary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Spend (${telemetry.windowHours}h window)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${telemetry.estimatedCostUsd.toStringAsFixed(4)} USD',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${telemetry.activeUsers} Active Users',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${telemetry.totalEvents} Metered Events',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(
    ThemeData theme,
    ColorScheme colorScheme,
    SystemUsageTelemetry telemetry,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricTile(
          theme: theme,
          colorScheme: colorScheme,
          title: 'AI Tokens Consumed',
          value: '${telemetry.totalAiTokens}',
          subtitle: 'Unit cost: \$0.15 / 1M',
          icon: Icons.psychology_outlined,
          accentColor: Colors.purple,
        ),
        _buildMetricTile(
          theme: theme,
          colorScheme: colorScheme,
          title: 'TTS Characters',
          value: '${telemetry.totalTtsChars}',
          subtitle: 'Unit cost: \$16.00 / 1M',
          icon: Icons.volume_up_outlined,
          accentColor: Colors.blue,
        ),
        _buildMetricTile(
          theme: theme,
          colorScheme: colorScheme,
          title: 'STT Audio Processed',
          value: '${telemetry.totalSttSeconds}s',
          subtitle: 'Unit cost: \$0.006 / min',
          icon: Icons.mic_outlined,
          accentColor: Colors.amber,
        ),
        _buildMetricTile(
          theme: theme,
          colorScheme: colorScheme,
          title: 'Storage Stored',
          value: _formatBytes(telemetry.totalStorageBytes),
          subtitle: 'Unit cost: \$0.021 / GB-mo',
          icon: Icons.folder_open_outlined,
          accentColor: Colors.teal,
        ),
        _buildMetricTile(
          theme: theme,
          colorScheme: colorScheme,
          title: 'Rate-Limit Policy',
          value: 'Enforced',
          subtitle: 'Atomic RPC serialization',
          icon: Icons.speed_outlined,
          accentColor: Colors.green,
        ),
        _buildMetricTile(
          theme: theme,
          colorScheme: colorScheme,
          title: 'Abuse Prevention',
          value: 'Hardened',
          subtitle: '4KB meta & event caps active',
          icon: Icons.shield_outlined,
          accentColor: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(icon, size: 20, color: accentColor),
              ],
            ),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
