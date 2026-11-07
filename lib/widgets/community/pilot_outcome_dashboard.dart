import 'package:flutter/material.dart';
import '../../models/community/family_abe_pilot.dart';
import '../../services/community/outcome_assessment_service.dart';

/// Comprehensive dashboard aggregating field pilot learning gains,
/// retention statistics, and learner feedback distributions (ECO-09, Phase 3).
class PilotOutcomeDashboard extends StatefulWidget {
  final OutcomeAssessmentService assessmentService;
  final String? initialCohortId;

  const PilotOutcomeDashboard({
    super.key,
    required this.assessmentService,
    this.initialCohortId,
  });

  @override
  State<PilotOutcomeDashboard> createState() => _PilotOutcomeDashboardState();
}

class _PilotOutcomeDashboardState extends State<PilotOutcomeDashboard> {
  String? _selectedCohortId;
  Map<String, dynamic>? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedCohortId = widget.initialCohortId;
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final rep = await widget.assessmentService
        .calculatePilotEfficacyReport(cohortId: _selectedCohortId);
    if (mounted) {
      setState(() {
        _report = rep;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const Key('pilot_outcome_dashboard'),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Cohort Filter Dropdown
            Row(
              children: [
                const Icon(Icons.insights, color: Colors.indigo, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Field Pilot Outcomes & Gain Evidence',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DropdownButton<String?>(
                  value: _selectedCohortId,
                  underline: const SizedBox(),
                  hint: const Text('All Cohorts'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Cohorts'),
                    ),
                    ...PilotCohort.standardCohorts.map((c) {
                      return DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.shortTag),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedCohortId = val);
                    _loadReport();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_report == null || (_report!['sample_size'] as int) == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'No completed assessments in this cohort yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              )
            else ...[
              // Summary Metric Cards
              Row(
                children: [
                  _buildMetricTile(
                    context,
                    label: 'Sample Size',
                    value: '${_report!['sample_size']}',
                    subtext: 'verified learners',
                  ),
                  const SizedBox(width: 8),
                  _buildMetricTile(
                    context,
                    label: 'Mean Pre-Score',
                    value:
                        '${((_report!['average_pre_score'] as double) * 100).toInt()}%',
                    subtext: 'baseline diagnostic',
                  ),
                  const SizedBox(width: 8),
                  _buildMetricTile(
                    context,
                    label: 'Mean Post-Score',
                    value:
                        '${((_report!['average_post_score'] as double) * 100).toInt()}%',
                    subtext: 'outcome assessment',
                  ),
                  const SizedBox(width: 8),
                  _buildMetricTile(
                    context,
                    label: 'Mean Gain (Hake g)',
                    value:
                        'g = ${(_report!['average_normalized_gain'] as double).toStringAsFixed(2)}',
                    subtext: _report!['aggregate_gain_category'] as String,
                    isHighlight: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gain Distribution Bar
              Text('Normalized Gain Distribution',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _buildGainDistributionBar(
                  context, _report!['gain_distribution'] as Map<String, dynamic>),
              const SizedBox(height: 16),

              // Feedback Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceAround,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'Clarity: ${(_report!['average_clarity_rating'] as double).toStringAsFixed(1)} / 5.0',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up,
                            color: theme.colorScheme.primary, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'Audio: ${(_report!['average_audio_helpfulness'] as double).toStringAsFixed(1)} / 5.0',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.thumb_up, color: Colors.teal, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Confidence: ${(_report!['average_confidence_rating'] as double).toStringAsFixed(1)} / 5.0',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required String subtext,
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isHighlight
              ? theme.colorScheme.primary.withOpacity(0.1)
              : theme.colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: isHighlight
              ? Border.all(color: theme.colorScheme.primary.withOpacity(0.5))
              : null,
        ),
        child: Column(
          children: [
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.outline,
                )),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isHighlight ? theme.colorScheme.primary : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtext,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.outline,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildGainDistributionBar(
      BuildContext context, Map<String, dynamic> dist) {
    final high = dist['high'] as int? ?? 0;
    final med = dist['medium'] as int? ?? 0;
    final low = dist['low'] as int? ?? 0;
    final loss = dist['loss'] as int? ?? 0;
    final total = high + med + low + loss;

    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                if (high > 0)
                  Expanded(
                    flex: high,
                    child: Container(color: Colors.green),
                  ),
                if (med > 0)
                  Expanded(
                    flex: med,
                    child: Container(color: Colors.blue),
                  ),
                if (low > 0)
                  Expanded(
                    flex: low,
                    child: Container(color: Colors.amber),
                  ),
                if (loss > 0)
                  Expanded(
                    flex: loss,
                    child: Container(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _legendItem(Colors.green, 'High Gain (g ≥ 0.7): $high'),
            _legendItem(Colors.blue, 'Medium (0.3–0.7): $med'),
            _legendItem(Colors.amber, 'Low (< 0.3): $low'),
            if (loss > 0) _legendItem(Colors.red, 'Loss: $loss'),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

