import 'dart:convert';
import 'dart:math';

import 'package:learning_pwa/models/content_generation/slot_plan.dart';
import 'package:learning_pwa/services/content_generation/la_gen_parser.dart';
import 'package:learning_pwa/services/content_generation/la_gen_personal_adapter.dart';
import 'package:learning_pwa/services/content_generation/lesson_composer.dart';

/// How much one chat message may ask for (master plan v2.6 §5.3). The
/// learner picks it; unknown defaults to [compact]. These are starting
/// guesses, not facts about any provider.
enum ModelSizeTier {
  compact(3, 'Small'),
  standard(8, 'Medium'),
  large(16, 'Large');

  const ModelSizeTier(this.slotsPerMessage, this.label);

  final int slotsPerMessage;
  final String label;
}

/// What the learner asked for.
class ManualJobRequest {
  ManualJobRequest({
    required String subject,
    required List<String> concepts,
    this.questionsPerConcept = 2,
    this.includeTerms = true,
  }) : subject = subject.trim(),
       concepts = List.unmodifiable(
         concepts.map((c) => c.trim()).where((c) => c.isNotEmpty),
       ) {
    if (this.subject.isEmpty) throw ArgumentError('Subject is required');
    if (this.subject.length > maxTextLength) {
      throw ArgumentError('Subject is too long');
    }
    if (this.concepts.isEmpty || this.concepts.length > maxConcepts) {
      throw ArgumentError('Use 1 to $maxConcepts ideas');
    }
    if (this.concepts.any((c) => c.length > maxTextLength)) {
      throw ArgumentError('An idea is too long');
    }
    if (questionsPerConcept < 0 || questionsPerConcept > 5) {
      throw ArgumentError('Use 0 to 5 questions per idea');
    }
  }

  static const maxConcepts = 5;
  static const maxTextLength = 120;

  final String subject;
  final List<String> concepts;
  final int questionsPerConcept;
  final bool includeTerms;
}

/// One planned job: app-owned codes and slots (master plan v2.6 §5.6 "Why
/// slots"). The model only fills content.
class ManualJob {
  ManualJob._(this.request, this.plan, this.conceptNames);

  /// Builds the slot plan. Per idea: one explanation, an optional key
  /// term, then the questions, so the lesson reads teach → term → check.
  ///
  /// [jobCode] restores a saved job's code; it must look like one this app
  /// issues, otherwise an [ArgumentError] is thrown.
  factory ManualJob.plan(
    ManualJobRequest request, {
    Random? random,
    String? jobCode,
  }) {
    if (jobCode != null && !_jobCode.hasMatch(jobCode)) {
      throw ArgumentError.value(jobCode, 'jobCode');
    }
    final slots = <SlotSpec>[];
    final names = <String, String>{};
    var n = 0;
    for (final (i, concept) in request.concepts.indexed) {
      final code = 'C${i + 1}';
      names[code] = concept;
      slots.add(
        SlotSpec(
          code: 'S${++n}',
          kind: SlotKind.explanation,
          conceptCode: code,
        ),
      );
      if (request.includeTerms) {
        slots.add(
          SlotSpec(code: 'S${++n}', kind: SlotKind.term, conceptCode: code),
        );
      }
      for (var q = 0; q < request.questionsPerConcept; q++) {
        slots.add(
          SlotSpec(code: 'S${++n}', kind: SlotKind.mcq, conceptCode: code),
        );
      }
    }
    return ManualJob._(
      request,
      SlotPlan(
        jobCode: jobCode ?? newJobCode(random ?? Random.secure()),
        slots: slots,
      ),
      Map.unmodifiable(names),
    );
  }

  static final RegExp _jobCode = RegExp(r'^J[A-HJKMNP-Z2-9]{4}$');

  /// `J` plus four characters without look-alikes (no 0/O, 1/I/L).
  static String newJobCode(Random random) {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    return 'J${List.generate(4, (_) => alphabet[random.nextInt(alphabet.length)]).join()}';
  }

  final ManualJobRequest request;
  final SlotPlan plan;

  /// Concept code (`C1`) → the learner's wording.
  final Map<String, String> conceptNames;
}

/// What one paste added.
class PasteOutcome {
  const PasteOutcome({
    required this.result,
    required this.newlyAccepted,
    required this.alreadyAccepted,
  });

  final LaGenParseResult result;

  /// Slots accepted for the first time by this paste.
  final List<String> newlyAccepted;

  /// Valid slots that were already accepted earlier; the first valid
  /// answer is kept so a later paste cannot silently replace it.
  final List<String> alreadyAccepted;
}

/// In-memory progress for one job: accepted slots accumulate across
/// pastes, and the next prompt asks only for what is still missing.
class ManualJobSession {
  ManualJobSession(this.job);

  final ManualJob job;
  final Map<String, LaGenSlot> _accepted = {};
  PasteOutcome? lastOutcome;

  Map<String, LaGenSlot> get accepted => Map.unmodifiable(_accepted);

  List<String> get missing => [
    for (final s in job.plan.slots)
      if (!_accepted.containsKey(s.code)) s.code,
  ];

  bool get isComplete => missing.isEmpty;

  /// The slots the next prompt should request, in plan order.
  List<String> nextBatch(ModelSizeTier tier) =>
      missing.take(tier.slotsPerMessage).toList();

  PasteOutcome applyPaste(String text) {
    final result = LaGenParser.parse(text, job.plan);
    final fresh = <String>[];
    final repeat = <String>[];
    for (final s in job.plan.slots) {
      final slot = result.accepted[s.code];
      if (slot == null) continue;
      if (_accepted.containsKey(s.code)) {
        repeat.add(s.code);
      } else {
        _accepted[s.code] = slot;
        fresh.add(s.code);
      }
    }
    return lastOutcome = PasteOutcome(
      result: result,
      newlyAccepted: fresh,
      alreadyAccepted: repeat,
    );
  }

  /// The accepted slots as one `la-gen/1.1` package, in plan order. Used
  /// for saving and for the learner's own export.
  String acceptedPackage() => jsonEncode({
    'schema': LaGenParser.schemaId,
    'job': job.plan.jobCode,
    'items': [
      for (final spec in job.plan.slots)
        if (_accepted[spec.code] case final slot?)
          {
            'slot': spec.code,
            'kind': spec.kind.wire,
            'concept': spec.conceptCode,
            ...slot.fields,
          },
    ],
    'end': job.plan.endSentinel,
  });

  static const int saveVersion = 1;

  Map<String, Object?> toJson() => {
    'version': saveVersion,
    'request': {
      'subject': job.request.subject,
      'concepts': job.request.concepts,
      'questions_per_concept': job.request.questionsPerConcept,
      'include_terms': job.request.includeTerms,
    },
    'job_code': job.plan.jobCode,
    'accepted': acceptedPackage(),
  };

  /// Restores a saved session. Saved items are re-checked by the same
  /// strict parser as a fresh paste, so a damaged or edited save can only
  /// lose items, never add unchecked ones. Returns `null` when unusable.
  static ManualJobSession? fromJson(Object? json) {
    try {
      if (json is! Map || json['version'] != saveVersion) return null;
      final r = json['request'] as Map;
      final job = ManualJob.plan(
        ManualJobRequest(
          subject: r['subject'] as String,
          concepts: [for (final c in r['concepts'] as List) c as String],
          questionsPerConcept: r['questions_per_concept'] as int,
          includeTerms: r['include_terms'] as bool,
        ),
        jobCode: json['job_code'] as String,
      );
      final session = ManualJobSession(job);
      final accepted = json['accepted'];
      if (accepted is String && accepted.isNotEmpty) {
        session.applyPaste(accepted);
        session.lastOutcome = null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  /// Personal-lesson JSON (dialect P) from the accepted slots, in plan
  /// order. The importer re-validates it before anything is saved.
  ///
  /// When [objectiveType] is given, the Lesson Composer sets each item's
  /// display order by that template; otherwise items keep plan order.
  Map<String, dynamic> toPersonalLesson({
    required String title,
    LessonObjectiveType? objectiveType,
  }) {
    final tags = <String>{'ai-generated', 'unreviewed'}.toList();
    return LaGenPersonalAdapter.toPersonalLesson(
      title: title,
      description: 'Private draft made with your own AI chat. Not reviewed.',
      tags: tags,
      result: LaGenParseResult(plan: job.plan, accepted: Map.of(_accepted)),
      orderBySlot: objectiveType == null
          ? null
          : LessonComposer.positions(
              LessonComposer.compose(
                job.plan,
                _accepted.keys.toSet(),
                objectiveType,
              ),
            ),
    );
  }
}
