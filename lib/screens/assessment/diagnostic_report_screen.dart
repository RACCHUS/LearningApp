import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/assessment/diagnostic_assessment.dart';
import '../../models/learning_context.dart';
import '../../providers/diagnostic_assessment_provider.dart';
import '../../providers/learning_context_provider.dart';
import '../../theme/design_tokens.dart';

class DiagnosticReportScreen extends ConsumerStatefulWidget {
  final DiagnosticAssessmentReport report;

  const DiagnosticReportScreen({
    super.key,
    required this.report,
  });

  @override
  ConsumerState<DiagnosticReportScreen> createState() =>
      _DiagnosticReportScreenState();
}

class _DiagnosticReportScreenState
    extends ConsumerState<DiagnosticReportScreen> {
  late DiagnosticAssessmentReport _report;
  bool _isCreatingSet = false;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Results'),
        actions: [
          IconButton(
            tooltip: 'Close report',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/target/${_report.targetId}');
              }
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryCard(report: _report),
            const SizedBox(height: DesignTokens.space4),
            if (_report.reinforcementPriorities.isNotEmpty) ...[
              Text(
                'Reinforcement priorities',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
              ..._report.reinforcementPriorities.map(
                (gap) => _ConceptEvidenceRow(
                  evaluation: gap,
                  icon: Icons.warning_amber_rounded,
                ),
              ),
              const SizedBox(height: DesignTokens.space3),
              if (_report.remedialSetCreated)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.space3),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline),
                        const SizedBox(width: DesignTokens.space2),
                        Expanded(
                          child: Text(
                            'Study set created: '
                            '${_report.remedialSetTitle ?? 'Diagnostic reinforcement'}',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('generate-remedial-set-button'),
                    onPressed: _isCreatingSet
                        ? null
                        : () async {
                            setState(() => _isCreatingSet = true);
                            try {
                              final updated = await ref
                                  .read(diagnosticAssessmentServiceProvider)
                                  .generateRemedialStudySet(report: _report);
                              if (!mounted) return;
                              setState(() {
                                _report = updated;
                                _isCreatingSet = false;
                              });
                            } catch (error) {
                              if (!mounted) return;
                              setState(() => _isCreatingSet = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not create the study set: $error',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: _isCreatingSet
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('Create Reinforcement Study Set'),
                  ),
                ),
              const SizedBox(height: DesignTokens.space5),
            ],
            if (_report.strongEvidenceConcepts.isNotEmpty) ...[
              Text(
                'Strong diagnostic evidence',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
              ..._report.strongEvidenceConcepts.map(
                (concept) => _ConceptEvidenceRow(
                  evaluation: concept,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(height: DesignTokens.space5),
            ],
            if (_report.conceptEvaluations.any(
              (concept) =>
                  !concept.isReinforcementPriority &&
                  !_report.strongEvidenceConcepts
                      .any((strong) => strong.conceptId == concept.conceptId),
            )) ...[
              Text(
                'Developing diagnostic evidence',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
              ..._report.conceptEvaluations
                  .where(
                    (concept) =>
                        !concept.isReinforcementPriority &&
                        !_report.strongEvidenceConcepts.any(
                          (strong) =>
                              strong.conceptId == concept.conceptId,
                        ),
                  )
                  .map(
                    (concept) => _ConceptEvidenceRow(
                      evaluation: concept,
                      icon: Icons.trending_up,
                    ),
                  ),
              const SizedBox(height: DesignTokens.space5),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/target/${_report.targetId}/outline'),
                    icon: const Icon(Icons.list_alt),
                    label: const Text('View Target Outline'),
                  ),
                ),
                const SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('diagnostic-start-curriculum-button'),
                    onPressed: _isStarting
                        ? null
                        : () async {
                            setState(() => _isStarting = true);
                            final userId = ref.read(learnerIdProvider);
                            final contextCreated = await ref
                                .read(learningContextsProvider.notifier)
                                .createOrSwitch(
                                  userId: userId,
                                  label: _report.targetTitle,
                                  rootType: ContextRootType.target,
                                  rootId: _report.targetId,
                                  targetVersionId: _report.targetVersionId,
                                );
                            if (!mounted) return;
                            setState(() => _isStarting = false);
                            if (contextCreated != null) {
                              context.go('/learn');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not start this curriculum. Please retry.',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: _isStarting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('Start Curriculum'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DiagnosticAssessmentReport report;

  const _SummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (report.overallEvidenceScore * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.targetTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
            Text(
              report.evidenceBand.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: DesignTokens.space1),
            Text(
              '$percentage% diagnostic evidence '
              '(${report.correctQuestions}/${report.totalQuestions} fully correct'
              '${report.partialQuestions > 0 ? ', ${report.partialQuestions} partial' : ''})',
            ),
            const SizedBox(height: DesignTokens.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: DesignTokens.space2),
                Expanded(
                  child: Text(
                    report.pedagogicalDisclaimer,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (!report.evidencePersisted) ...[
              const SizedBox(height: DesignTokens.space3),
              Text(
                'This diagnostic was scored, but concept evidence could not be saved to your learner profile.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConceptEvidenceRow extends StatelessWidget {
  final DiagnosticConceptEvaluation evaluation;
  final IconData icon;

  const _ConceptEvidenceRow({
    required this.evaluation,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.space2),
      child: ListTile(
        leading: Icon(icon),
        title: Text(evaluation.conceptName),
        subtitle: Text(
          '${(evaluation.evidenceRatio * 100).round()}% evidence across '
          '${evaluation.testedItemsCount} item'
          '${evaluation.testedItemsCount == 1 ? '' : 's'} · '
          '${evaluation.confidence.name} confidence',
        ),
        trailing: Text(evaluation.evidenceBand.displayName),
      ),
    );
  }
}
