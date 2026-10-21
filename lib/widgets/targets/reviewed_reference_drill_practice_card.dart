import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/assessment_engine/reference_drill_engine.dart';
import '../../providers/auth_provider.dart';
import '../../services/assessment/exam_reference_drill_event_service.dart';
import '../../services/assessment/exam_reference_drill_practice_service.dart';
import '../../services/assessment/exam_reference_drill_scoring_service.dart';
import '../../services/assessment/reference_drill_attempt_recorder.dart';

/// In-context R1-R4 practice. No hidden answer data or synthetic engine task
/// is bundled with this UI. The database must independently approve each item,
/// rubric, original prompt, book revision and actual administration date.
class ReviewedReferenceDrillPracticeCard extends ConsumerWidget {
  final String manifestRevisionId;
  final String examPartKey;
  final DateTime administrationDate;
  final ExamReferenceDrillPracticeService? practiceService;
  final ExamReferenceDrillEventService? eventService;
  final ExamReferenceDrillScoringService? scoringService;

  const ReviewedReferenceDrillPracticeCard({
    super.key,
    required this.manifestRevisionId,
    required this.examPartKey,
    required this.administrationDate,
    this.practiceService,
    this.eventService,
    this.scoringService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    if (session is! AuthSuccess || session.user.isAnonymous) {
      return const Text(
        'Sign in with a permanent account to practice reviewed reference drills. '
        'Guest sessions cannot save verified practice.',
      );
    }
    final date = DateTime.utc(
      administrationDate.year, administrationDate.month,
      administrationDate.day,
    );
    return _OwnedPractice(
      key: ValueKey(
        'reviewed-practice:${session.user.id}:$manifestRevisionId:'
        '$examPartKey:${date.toIso8601String()}',
      ),
      ownerId: session.user.id,
      manifestId: manifestRevisionId,
      partKey: examPartKey,
      examDate: date,
      practiceService: practiceService,
      eventService: eventService,
      scoringService: scoringService,
    );
  }
}

class _OwnedPractice extends StatefulWidget {
  final String ownerId;
  final String manifestId;
  final String partKey;
  final DateTime examDate;
  final ExamReferenceDrillPracticeService? practiceService;
  final ExamReferenceDrillEventService? eventService;
  final ExamReferenceDrillScoringService? scoringService;

  const _OwnedPractice({
    super.key,
    required this.ownerId,
    required this.manifestId,
    required this.partKey,
    required this.examDate,
    this.practiceService,
    this.eventService,
    this.scoringService,
  });

  @override
  State<_OwnedPractice> createState() => _OwnedPracticeState();
}

class _OwnedPracticeState extends State<_OwnedPractice> {
  ApprovedReferenceDrillPractice? _practice;
  ReferenceDrillAttemptRecorder? _recorder;
  Stopwatch? _watch;
  final TextEditingController _bookSeconds = TextEditingController();
  final List<String> _feedback = [];
  String? _selected;
  String? _pendingEventId;
  String? _pendingAnswer;
  ReferenceDrillStep? _awaitingStep;
  String? _error;
  bool _working = false;
  bool _noAvailable = false;

  late final ExamReferenceDrillPracticeService _defaultPractice =
      ExamReferenceDrillPracticeService();
  late final ExamReferenceDrillEventService _defaultEvents =
      ExamReferenceDrillEventService();
  late final ExamReferenceDrillScoringService _defaultScorer =
      ExamReferenceDrillScoringService();

  ExamReferenceDrillPracticeService get _practiceApi =>
      widget.practiceService ?? _defaultPractice;
  ExamReferenceDrillEventService get _eventApi =>
      widget.eventService ?? _defaultEvents;
  ExamReferenceDrillScoringService get _scoringApi =>
      widget.scoringService ?? _defaultScorer;

  @override
  void dispose() {
    _watch?.stop();
    _bookSeconds.dispose();
    super.dispose();
  }

  static String _stepKey(ReferenceDrillStep step) => switch (step) {
    ReferenceDrillStep.resourceChoice => 'resource_choice',
    ReferenceDrillStep.sectionLocation => 'section_location',
    ReferenceDrillStep.interpretation => 'interpretation',
    ReferenceDrillStep.application => 'application',
  };

  static String _stepTitle(ReferenceDrillStep step) => switch (step) {
    ReferenceDrillStep.resourceChoice => 'R1 · Choose the reference',
    ReferenceDrillStep.sectionLocation => 'R2 · Locate the section',
    ReferenceDrillStep.interpretation => 'R3 · Interpret the rule',
    ReferenceDrillStep.application => 'R4 · Apply the rule',
  };

  Future<void> _start() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final practice = await _practiceApi.fetch(
        expectedOwnerId: widget.ownerId,
        manifestRevisionId: widget.manifestId,
        examPartKey: widget.partKey,
        administrationDate: widget.examDate,
      );
      if (!mounted) return;
      if (practice == null) {
        setState(() => _noAvailable = true);
        return;
      }
      // The reader already enforces owner, exact manifest/part/date and a
      // strict projection shape. A client flag never approves a server item.
      final recorder = ReferenceDrillAttemptRecorder(
        eventService: _eventApi,
        binding: practice.binding,
        expectedOwnerId: widget.ownerId,
      );
      setState(() {
        _practice = practice;
        _recorder = recorder;
        _watch = Stopwatch()..start();
        _noAvailable = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Reviewed practice is unavailable. Confirm the exam date and retry.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _submit() async {
    if (_working || _recorder == null ||
        (_recorder!.isComplete && _pendingEventId == null)) return;
    final step = _awaitingStep ?? _recorder!.nextStep!;
    final token = _pendingAnswer ?? _selected;
    final isRetry = _recorder!.hasPendingWrite;
    final elapsed = _watch?.elapsed ?? Duration.zero;

    Duration? bookTime;
    if (!isRetry && _pendingEventId == null) {
      final entered = _bookSeconds.text.trim();
      if (entered.isNotEmpty) {
        final seconds = int.tryParse(entered);
        if (seconds == null || seconds < 0 || seconds > 86400) {
          setState(() => _error =
              'Book time must be between 0 and 86,400 seconds, or blank.');
          return;
        }
        bookTime = Duration(seconds: seconds);
      }
    }
    _watch?.stop();
    setState(() {
      _working = true;
      _error = null;
      _pendingAnswer = token;
      _awaitingStep = step;
    });
    try {
      if (_pendingEventId == null) {
        final event = isRetry
            ? await _recorder!.retryPending()
            : await _recorder!.submitStep(
                step: step,
                responded: token != null,
                appElapsed: elapsed,
                selfReportedBookTime: bookTime,
              );
        if (!mounted) return;
        final eventId = event['id'];
        if (eventId is! String || eventId.isEmpty) {
          throw const FormatException('Missing durable event receipt');
        }
        _pendingEventId = eventId;
      }

      String feedback = 'Skipped · activity recorded without scoring';
      if (token != null) {
        final grade = await _scoringApi.scoreRecordedStep(
          expectedOwnerId: widget.ownerId,
          eventId: _pendingEventId!,
          answerToken: token,
        );
        if (!mounted) return;
        if (grade.step != _stepKey(step)) {
          throw StateError('Unexpected score step from the server');
        }
        feedback = grade.isCorrect
            ? 'Correct response · server-checked'
            : 'Review this step · server-checked response';
      }
      if (!mounted) return;
      setState(() {
        _feedback.add('${_stepTitle(step)} — $feedback');
        _pendingAnswer = null;
        _awaitingStep = null;
        _pendingEventId = null;
        _selected = null;
        _bookSeconds.clear();
        _watch = Stopwatch()..start();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = _pendingEventId != null
            ? 'Step saved, but scoring is unavailable. Retry scoring '
              'without changing your response.'
            : 'Could not save this step. Retry the original submission.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recorder = _recorder;
    final step = _awaitingStep ?? recorder?.nextStep;
    final prompt = step == null ? null : _practice?.steps[_stepKey(step)];
    return Card(
      key: const Key('reviewed-reference-practice'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reviewed reference practice',
                style: Theme.of(context).textTheme.titleSmall),
            const Text(
              'Original practice questions for the selected exam date. '
              'Checked answers measure a response token, not physical '
              'book use or official exam readiness.',
            ),
            if (_practice == null) ...[
              if (_noAvailable)
                const Text('No independently reviewed practice is available '
                    'for this reference list and date. General study remains available.'),
              TextButton(
                onPressed: _working ? null : _start,
                child: const Text('Start reviewed practice'),
              ),
            ],
            if (prompt != null && step != null) ...[
              const SizedBox(height: 12),
              Text(_stepTitle(step), key: const Key('reviewed-drill-step')),
              Text(prompt.prompt, key: const Key('reviewed-drill-prompt')),
              for (final choice in prompt.choices)
                ChoiceChip(
                  key: Key('drill-choice:${choice.value}'),
                  label: Text(choice.label),
                  selected: _selected == choice.value,
                  onSelected: _working || _pendingEventId != null ||
                          recorder!.hasPendingWrite
                      ? null
                      : (on) => setState(
                          () => _selected = on ? choice.value : null),
                ),
              TextField(
                key: const Key('self-reported-book-seconds'),
                controller: _bookSeconds,
                keyboardType: TextInputType.number,
                enabled: !_working && _pendingEventId == null &&
                    !recorder!.hasPendingWrite,
                decoration: const InputDecoration(
                  labelText: 'Physical-book time in seconds (optional, self-reported)',
                ),
              ),
              TextButton(
                key: const Key('submit-reviewed-drill-step'),
                onPressed: _working ? null : _submit,
                child: Text(_pendingEventId != null
                    ? 'Retry scoring' : recorder!.hasPendingWrite
                    ? 'Retry saving step' : _selected == null
                    ? 'Skip and record step' : 'Save and check response'),
              ),
            ],
            for (final outcome in _feedback) Text(outcome),
            if (recorder != null && recorder.isComplete &&
                _pendingEventId == null)
              const Text(
                'Four steps recorded. This is learning practice only; '
                'these results do not predict licensing-exam success.',
                key: Key('reviewed-drill-complete'),
              ),
            if (_working) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, key: const Key('reviewed-drill-error')),
          ],
        ),
      ),
    );
  }
}
