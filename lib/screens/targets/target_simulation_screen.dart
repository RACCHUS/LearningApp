import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/assessment_engine/mock_exam_session.dart';
import '../../providers/assessment_engine_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/learning_target_provider.dart';
import '../../services/assessment/clep_simulation_service.dart';
import '../../theme/design_tokens.dart';
import '../assessment/mock_exam_screen.dart';

/// Student-facing screen that guides learners through the pre-exam briefing,
/// authentication verification, server-side issuance, attempt recovery, and execution of
/// official, full-length timed simulation exams (e.g., CLEP College Algebra).
class TargetSimulationScreen extends ConsumerStatefulWidget {
  final String targetId;
  final String targetVersionId;

  const TargetSimulationScreen({
    super.key,
    required this.targetId,
    required this.targetVersionId,
  });

  @override
  ConsumerState<TargetSimulationScreen> createState() =>
      _TargetSimulationScreenState();
}

class _TargetSimulationScreenState
    extends ConsumerState<TargetSimulationScreen> {
  MockExamSession? _session;
  bool _isIssuing = false;
  String? _errorMessage;

  bool _hasActiveAttempt = false;
  int? _secondsRemaining;

  @override
  void initState() {
    super.initState();
    _checkActiveAttempt();
  }

  Future<void> _checkActiveAttempt() async {
    final authState = ref.read(authProvider);
    if (authState is! AuthSuccess || authState.user.isAnonymous) {
      return;
    }

    try {
      final res = await ref
          .read(clepSimulationServiceProvider)
          .getActiveSimulationAttempt(widget.targetVersionId);
      if (mounted) {
        setState(() {
          _hasActiveAttempt = res.hasActiveAttempt;
          _secondsRemaining = res.secondsRemaining;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleStartOrResume({
    required String examCode,
    required String examTitle,
    required Set<String> allowedTools,
  }) async {
    setState(() {
      _isIssuing = true;
      _errorMessage = null;
    });

    try {
      final clepService = ref.read(clepSimulationServiceProvider);
      final session = _hasActiveAttempt
          ? await clepService.recoverSimulationExam(
              targetVersionId: widget.targetVersionId,
              examCode: examCode,
              examTitle: examTitle,
              allowedTools: allowedTools,
            )
          : await clepService.issueSimulationExam(
              targetVersionId: widget.targetVersionId,
              examCode: examCode,
              examTitle: examTitle,
              allowedTools: allowedTools,
            );

      if (!mounted) return;
      setState(() {
        _session = session;
        _isIssuing = false;
      });
    } on ClepSimulationException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isIssuing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to issue or resume simulation exam: $e';
        _isIssuing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null) {
      return MockExamScreen(initialSession: _session!);
    }

    final authState = ref.watch(authProvider);
    final isGuestOrAnonymous = authState is! AuthSuccess || authState.user.isAnonymous;
    final theme = Theme.of(context);

    // 1. Unauthenticated or Anonymous Guest Gate
    if (isGuestOrAnonymous) {
      return Scaffold(
        appBar: AppBar(title: const Text('Simulation Exam')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(DesignTokens.space5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_person_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: DesignTokens.space3),
                      Text(
                        isGuestOrAnonymous
                            ? 'Registered Account Required'
                            : 'Authentication Required',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DesignTokens.space2),
                      Text(
                        isGuestOrAnonymous
                            ? 'Official timed CLEP simulation exams enforce single-attempt security and require a verified, registered learner account. Anonymous guest sessions are not eligible to take or hold official attempts.'
                            : 'Official timed CLEP simulation exams require an authenticated learner account to record attempt timing and protect exam bank confidentiality.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: DesignTokens.space4),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('simulation-auth-sign-in-button'),
                          onPressed: () => context.push('/login'),
                          icon: const Icon(Icons.login),
                          label: Text(isGuestOrAnonymous
                              ? 'Sign In / Register with Google'
                              : 'Sign In to Continue'),
                        ),
                      ),
                      const SizedBox(height: DesignTokens.space2),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Return to Course Details'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 2. Load target and version details
    final targetAsync = ref.watch(targetDetailProvider(widget.targetId));
    final versionAsync = ref.watch(targetVersionProvider(widget.targetId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_hasActiveAttempt
            ? 'Resume Simulation Exam'
            : 'Official Simulation Exam Briefing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: targetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load target: $err')),
        data: (target) {
          return versionAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) =>
                Center(child: Text('Failed to load target version: $err')),
            data: (version) {
              if (version == null || !version.isSimulationExamEligible) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.space4),
                    child: Text(
                      'This course does not offer an official timed simulation exam.',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                );
              }

              final meta = version.metadata;
              final examCode = meta['exam_code'] as String? ?? 'CLEP-ALG';
              final examTitle = version.title ?? target?.title ?? 'CLEP College Algebra';
              final timeLimit =
                  (meta['time_limit_minutes'] as num?)?.toInt() ?? 90;
              final questionCount =
                  (meta['default_question_count'] as num?)?.toInt() ??
                      (meta['question_count_approx'] as num?)?.toInt() ??
                      60;
              final allowsCalculator = version.allowsCalculator;
              final allowedTools = version.allowedExamTools;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(DesignTokens.space4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _hasActiveAttempt
                              ? theme.colorScheme.error.withValues(alpha: 0.5)
                              : theme.colorScheme.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(DesignTokens.space5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _hasActiveAttempt
                                        ? theme.colorScheme.errorContainer
                                        : theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _hasActiveAttempt
                                        ? Icons.timelapse
                                        : Icons.school_outlined,
                                    size: 32,
                                    color: _hasActiveAttempt
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: DesignTokens.space3),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        examTitle,
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _hasActiveAttempt
                                            ? 'Active Simulation Attempt in Progress'
                                            : 'Official Full-Length Timed Simulation ($examCode)',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: DesignTokens.space5),
                            if (_hasActiveAttempt) ...[
                              Container(
                                padding: const EdgeInsets.all(DesignTokens.space3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: theme.colorScheme.error.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.history_toggle_off,
                                        color: theme.colorScheme.error, size: 24),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'In-Progress Examination Found',
                                            style: theme.textTheme.labelLarge?.copyWith(
                                              color: theme.colorScheme.onErrorContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'You have an active attempt currently in progress with '
                                            '${_secondsRemaining != null ? (_secondsRemaining! / 60).ceil() : timeLimit} minutes remaining. '
                                            'You can resume your session seamlessly without penalty.',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onErrorContainer,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: DesignTokens.space4),
                            ],
                            Text(
                              'Examination Blueprint Specifications',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: DesignTokens.space2),
                            _buildSpecRow(
                              context,
                              icon: Icons.quiz_outlined,
                              title: 'Total Questions',
                              detail: '$questionCount multiple-choice questions',
                            ),
                            _buildSpecRow(
                              context,
                              icon: Icons.timer_outlined,
                              title: 'Time Limit',
                              detail: _hasActiveAttempt && _secondsRemaining != null
                                  ? '${(_secondsRemaining! / 60).ceil()} minutes remaining (from original $timeLimit continuous minutes)'
                                  : '$timeLimit continuous minutes (timer cannot be paused)',
                            ),
                            _buildSpecRow(
                              context,
                              icon: Icons.pie_chart_outline,
                              title: 'Domain Allocations',
                              detail: '1.0 Operations (25%) · 2.0 Equations (25%) · 3.0 Functions (30%) · 4.0 Number Systems (20%)',
                            ),
                            if (allowsCalculator)
                              _buildSpecRow(
                                context,
                                icon: Icons.calculate_outlined,
                                title: 'Permitted Tools',
                                detail: 'Built-in Scientific Calculator available in the exam navigation bar',
                              ),
                            _buildSpecRow(
                              context,
                              icon: Icons.verified_outlined,
                              title: 'ACE Credit Recommendation',
                              detail: 'Scaled score of 50 recommended for 3 semester credit hours (20-80 scale)',
                            ),
                            const SizedBox(height: DesignTokens.space3),
                            Container(
                              padding: const EdgeInsets.all(DesignTokens.space3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: theme.colorScheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Single Official Attempt Policy',
                                          style: theme.textTheme.labelLarge?.copyWith(
                                            color: theme.colorScheme.onErrorContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Exactly one official timed simulation attempt is permitted per learner account. '
                                          'Answer keys and item explanations remain confidential to preserve testing integrity.',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onErrorContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: DesignTokens.space3),
                              Container(
                                padding: const EdgeInsets.all(DesignTokens.space3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: theme.colorScheme.error),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: theme.colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: DesignTokens.space4),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const Key('confirm-start-simulation-button'),
                                onPressed: _isIssuing
                                    ? null
                                    : () => _handleStartOrResume(
                                          examCode: examCode,
                                          examTitle: examTitle,
                                          allowedTools: allowedTools,
                                        ),
                                icon: _isIssuing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(_hasActiveAttempt
                                        ? Icons.replay
                                        : Icons.play_arrow),
                                label: Text(
                                  _isIssuing
                                      ? (_hasActiveAttempt
                                          ? 'Resuming Secure Exam...'
                                          : 'Issuing Secure Exam...')
                                      : (_hasActiveAttempt
                                          ? 'Resume In-Progress Exam (${(_secondsRemaining != null ? (_secondsRemaining! / 60).ceil() : timeLimit)} min left)'
                                          : 'Begin $timeLimit-Minute Exam'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSpecRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: detail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
