/// EXM-02A: internal reference-mastery drill prototype.
///
/// A production client must NEVER download private binding approval rows,
/// solution keys, or held-out item scoring specs. These in-memory exercises are
/// restricted to synthetic/nonproduction fixtures until a separately reviewed
/// server-side scoring/delivery boundary is implemented.
enum ReferenceDrillMode { r1, r2, r3, r4 }

enum ReferenceSkill { chooseReference, locateSection, interpret, solve }

extension ReferenceSkillLabel on ReferenceSkill {
  String get label {
    switch (this) {
      case ReferenceSkill.chooseReference:
        return 'Choosing the reference';
      case ReferenceSkill.locateSection:
        return 'Locating the section';
      case ReferenceSkill.interpret:
        return 'Interpreting the provision';
      case ReferenceSkill.solve:
        return 'Applying the solution';
    }
  }
}

class ReferenceDrillStep {
  final ReferenceSkill skill;
  final String prompt;
  final List<String> options;
  final int? correctOptionIndex;
  final List<String> acceptedSectionIdentifiers;
  final String feedback;

  ReferenceDrillStep.choice({
    required this.skill,
    required this.prompt,
    required List<String> options,
    required int correctOptionIndex,
    required this.feedback,
  })  : options = List.unmodifiable(options),
        correctOptionIndex = correctOptionIndex,
        acceptedSectionIdentifiers = const [] {
    if (skill == ReferenceSkill.locateSection ||
        options.length < 2 ||
        options.any((option) => option.trim().isEmpty) ||
        correctOptionIndex < 0 ||
        correctOptionIndex >= options.length ||
        prompt.trim().isEmpty ||
        feedback.trim().isEmpty) {
      throw const FormatException('Invalid reviewed choice step');
    }
  }

  ReferenceDrillStep.location({
    required this.prompt,
    required List<String> acceptedSectionIdentifiers,
    required this.feedback,
  })  : skill = ReferenceSkill.locateSection,
        options = const [],
        correctOptionIndex = null,
        acceptedSectionIdentifiers =
            List.unmodifiable(acceptedSectionIdentifiers) {
    if (prompt.trim().isEmpty ||
        feedback.trim().isEmpty ||
        acceptedSectionIdentifiers.isEmpty ||
        acceptedSectionIdentifiers.any((value) => value.trim().isEmpty)) {
      throw const FormatException('A location needs reviewed section identifiers');
    }
  }

  bool evaluate({int? option, String? section}) {
    if (skill == ReferenceSkill.locateSection) {
      if (option != null || section == null) {
        throw const FormatException('A location requires a typed identifier');
      }
      final submitted = _normalizeSection(section);
      if (submitted.isEmpty) return false;
      return acceptedSectionIdentifiers
          .map(_normalizeSection)
          .contains(submitted);
    }
    if (section != null || option == null ||
        option < 0 || option >= options.length) {
      throw const FormatException('A choice must select one offered option');
    }
    return option == correctOptionIndex;
  }
}

/// Explicitly NONPRODUCTION: no actual jurisdictional requirements are implied.
/// Server-reviewed content delivery, item binding checks, and hidden answers
/// must exist before this contract is used with real learners.
class ReferenceDrillExercise {
  final String id;
  final ReferenceDrillMode mode;
  final String manifestRevisionId;
  final String bindingRevisionId;
  final String scenario;
  final List<ReferenceDrillStep> steps;
  final bool syntheticFixture;

  ReferenceDrillExercise({
    required this.id,
    required this.mode,
    required this.manifestRevisionId,
    required this.bindingRevisionId,
    required this.scenario,
    required List<ReferenceDrillStep> steps,
    required this.syntheticFixture,
  }) : steps = List.unmodifiable(steps) {
    final expected = switch (mode) {
      ReferenceDrillMode.r1 => [ReferenceSkill.chooseReference],
      ReferenceDrillMode.r2 => [ReferenceSkill.locateSection],
      ReferenceDrillMode.r3 => [ReferenceSkill.interpret],
      ReferenceDrillMode.r4 => ReferenceSkill.values,
    };
    if (!syntheticFixture ||
        id.trim().isEmpty ||
        manifestRevisionId.trim().isEmpty ||
        bindingRevisionId.trim().isEmpty ||
        scenario.trim().isEmpty ||
        this.steps.length != expected.length ||
        !List.generate(expected.length,
            (i) => this.steps[i].skill == expected[i]).every((ok) => ok)) {
      throw const StateError(
          'Only complete, synthetic R1–R4 drill exercises are supported');
    }
  }
}

class ReferenceStepOutcome {
  final ReferenceSkill skill;
  final bool correct;
  final Duration appElapsed;
  final String feedback;
  final String response;

  const ReferenceStepOutcome({
    required this.skill,
    required this.correct,
    required this.appElapsed,
    required this.feedback,
    required this.response,
  });
}

/// Disposable client-only practice evidence. Physical-book time is explicitly
/// SELF-REPORTED and never presented as app-observed navigation activity.
class ReferenceDrillSession {
  final ReferenceDrillExercise exercise;
  final DateTime Function() _clock;
  final List<ReferenceStepOutcome> _outcomes = [];
  late DateTime _stepStartedAt;
  int? _reportedPhysicalMinutes;

  ReferenceDrillSession(
    this.exercise, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _stepStartedAt = _clock();
  }

  List<ReferenceStepOutcome> get outcomes => List.unmodifiable(_outcomes);
  bool get complete => _outcomes.length == exercise.steps.length;
  int get currentStepIndex => _outcomes.length;
  ReferenceDrillStep? get currentStep =>
      complete ? null : exercise.steps[currentStepIndex];
  int get correctSteps => _outcomes.where((result) => result.correct).length;
  int? get selfReportedPhysicalMinutes => _reportedPhysicalMinutes;
  Duration get observedAppDuration =>
      _outcomes.fold(Duration.zero, (elapsed, result) => elapsed + result.appElapsed);

  ReferenceStepOutcome submitOption(int index) =>
      _submit(option: index);

  ReferenceStepOutcome submitSection(String section) =>
      _submit(section: section);

  ReferenceStepOutcome _submit({int? option, String? section}) {
    final step = currentStep;
    if (step == null) {
      throw StateError('This practice is already complete');
    }
    final correct = step.evaluate(option: option, section: section);
    final now = _clock();
    final elapsed = now.difference(_stepStartedAt);
    final result = ReferenceStepOutcome(
      skill: step.skill,
      correct: correct,
      appElapsed: elapsed.isNegative ? Duration.zero : elapsed,
      feedback: step.feedback,
      response: section ?? step.options[option!],
    );
    _outcomes.add(result);
    _stepStartedAt = now;
    return result;
  }

  void reportPhysicalBookMinutes(int? minutes) {
    if (!complete) {
      throw StateError('Finish the drill before entering optional book time');
    }
    if (minutes != null && (minutes < 0 || minutes > 1440)) {
      throw const FormatException('Self-reported book minutes are out of range');
    }
    _reportedPhysicalMinutes = minutes;
  }

  Map<ReferenceSkill, bool> get skillAccuracy => Map.unmodifiable({
        for (final outcome in _outcomes) outcome.skill: outcome.correct,
      });
}

String _normalizeSection(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
