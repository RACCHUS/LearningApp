import 'package:flutter/material.dart';

import '../../models/assessment_engine/reference_mastery_drill.dart';

/// Internal-only, disposable reference-navigation drill experience.
/// Never add to public routes before validated learner-safe server delivery.
class ReferenceMasteryDrillScreen extends StatefulWidget {
  final ReferenceDrillExercise exercise;
  final DateTime Function()? clock;

  const ReferenceMasteryDrillScreen({
    super.key,
    required this.exercise,
    this.clock,
  });

  @override
  State<ReferenceMasteryDrillScreen> createState() =>
      _ReferenceMasteryDrillScreenState();
}

class _ReferenceMasteryDrillScreenState
    extends State<ReferenceMasteryDrillScreen> {
  late ReferenceDrillSession _session;
  final TextEditingController _sectionController = TextEditingController();
  final TextEditingController _physicalMinutesController =
      TextEditingController();
  int? _selectedOption;
  ReferenceStepOutcome? _feedback;

  @override
  void initState() {
    super.initState();
    _session = ReferenceDrillSession(widget.exercise, clock: widget.clock);
  }

  @override
  void didUpdateWidget(covariant ReferenceMasteryDrillScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise != widget.exercise) {
      _session = ReferenceDrillSession(widget.exercise, clock: widget.clock);
      _sectionController.clear();
      _physicalMinutesController.clear();
      _selectedOption = null;
      _feedback = null;
    }
  }

  @override
  void dispose() {
    _sectionController.dispose();
    _physicalMinutesController.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final step = _session.currentStep;
      if (step == null || _feedback != null) return;
      final outcome = step.skill == ReferenceSkill.locateSection
          ? _session.submitSection(_sectionController.text)
          : _session.submitOption(_selectedOption!);
      setState(() => _feedback = outcome);
    } on FormatException {
      // Ignore invalid input; missing choices have a disabled submit button.
    }
  }

  void _next() {
    setState(() {
      _feedback = null;
      _selectedOption = null;
      _sectionController.clear();
    });
  }

  void _recordPhysicalMinutes() {
    final typed = _physicalMinutesController.text.trim();
    try {
      final minutes = typed.isEmpty ? null : int.parse(typed);
      _session.reportPhysicalBookMinutes(minutes);
      setState(() {});
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter 0–1440 minutes, or leave blank.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final step = _session.currentStep;
    final showingFinalFeedback = _session.complete && _feedback != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Reference Mastery · Prototype')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'SYNTHETIC PRACTICE ONLY · NOT AN OFFICIAL EXAM',
              key: Key('reference-prototype-warning'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'This experimental session is disposable. '
              'No answers or progress are saved after leaving.',
            ),
            const SizedBox(height: 20),
            Text('Scenario', style: Theme.of(context).textTheme.titleMedium),
            Text(exercise.scenario),
            const SizedBox(height: 20),
            if (step != null) ...[
              Text(
                step.skill.label + ' · Step ' +
                  (_session.currentStepIndex + 1).toString() +
                  ' of ' + exercise.steps.length.toString(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(step.prompt),
              const SizedBox(height: 16),
              if (step.skill == ReferenceSkill.locateSection)
                TextField(
                  key: const Key('reference-section-input'),
                  controller: _sectionController,
                  enabled: _feedback == null,
                  decoration: const InputDecoration(
                    labelText: 'Section or provision identifier',
                    helperText: 'Use the section from your own reference.',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                )
              else
                for (var i = 0; i < step.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ChoiceChip(
                      key: Key('reference-choice-' + i.toString()),
                      label: Text(step.options[i]),
                      selected: _selectedOption == i,
                      onSelected: _feedback != null
                          ? null
                          : (_) => setState(() => _selectedOption = i),
                    ),
                  ),
              if (_feedback == null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: (step.skill == ReferenceSkill.locateSection
                          ? _sectionController.text.trim().isNotEmpty
                          : _selectedOption != null)
                      ? _submit
                      : null,
                  child: const Text('Check step'),
                ),
              ],
            ],
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              Text(
                _feedback!.correct ? 'Correct for this step' : 'Review this step',
                key: const Key('reference-step-result'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(_feedback!.feedback),
              Text('Time measured inside app: ' +
                  _feedback!.appElapsed.inSeconds.toString() + ' seconds'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _next,
                child: Text(showingFinalFeedback
                    ? 'View skill breakdown' : 'Next step'),
              ),
            ] else if (_session.complete) ...[
              Text('Skill breakdown',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              for (final outcome in _session.outcomes)
                Text(outcome.skill.label + ': ' +
                    (outcome.correct ? 'Correct' : 'Needs practice')),
              const SizedBox(height: 12),
              Text('Correct steps: ' + _session.correctSteps.toString()
                  + ' of ' + exercise.steps.length.toString()
                  + ' (practice only)'),
              Text('Time measured inside app: ' +
                  _session.observedAppDuration.inSeconds.toString() + ' seconds'),
              const SizedBox(height: 12),
              TextField(
                key: const Key('reference-physical-minutes-input'),
                controller: _physicalMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minutes using a physical book (optional)',
                  helperText: 'Self-reported, not measured by this app',
                  border: OutlineInputBorder(),
                ),
              ),
              TextButton(
                onPressed: _recordPhysicalMinutes,
                child: const Text('Record self-reported time'),
              ),
              if (_session.selfReportedPhysicalMinutes != null)
                Text(
                  'Self-reported physical-book time: ' +
                  _session.selfReportedPhysicalMinutes.toString() + ' minutes',
                  key: const Key('reference-self-reported-time'),
                ),
              const Text(
                'This is practice feedback, not an official scaled score '
                'or a prediction of exam readiness.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
