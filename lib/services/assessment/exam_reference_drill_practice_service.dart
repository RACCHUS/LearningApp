import 'package:supabase_flutter/supabase_flutter.dart';

import 'reference_drill_attempt_recorder.dart';

/// Only human-reviewed, ORIGINAL learner-visible prompts and choice labels.
/// Private scoring specifications, expected answers and reviewer evidence are
/// never a part of this model or the projection API.
class ReferenceDrillChoice {
  final String value;
  final String label;

  const ReferenceDrillChoice(this.value, this.label);
}

class ReferenceDrillStepPrompt {
  final String prompt;
  final List<ReferenceDrillChoice> choices;

  const ReferenceDrillStepPrompt(this.prompt, this.choices);
}

class ApprovedReferenceDrillPractice {
  final ReferenceDrillBindingSnapshot binding;
  final Map<String, ReferenceDrillStepPrompt> steps;

  ApprovedReferenceDrillPractice({
    required this.binding,
    required this.steps,
  });

  factory ApprovedReferenceDrillPractice.fromRpc(
    Map<String, dynamic> data, {
    required String manifestId,
    required String partKey,
    required DateTime examDate,
  }) {
    const expected = {
      'assessment_item_id',
      'approved_binding_id',
      'manifest_revision_id',
      'exam_part_key',
      'administration_date',
      'item_content_revision',
      'answer_location_revision',
      'steps',
    };
    if (data.keys.toSet().difference(expected).isNotEmpty ||
        data.keys.toSet().length != expected.length ||
        data['manifest_revision_id'] != manifestId ||
        data['exam_part_key'] != partKey ||
        data['administration_date'] !=
            DateTime.utc(examDate.year, examDate.month, examDate.day)
                .toIso8601String().substring(0, 10)) {
      throw const FormatException('Mismatched reference-practice response');
    }
    final binding = ReferenceDrillBindingSnapshot(
      assessmentItemId: data['assessment_item_id']?.toString() ?? '',
      approvedBindingId: data['approved_binding_id']?.toString() ?? '',
      manifestRevisionId: data['manifest_revision_id']?.toString() ?? '',
      examPartKey: data['exam_part_key']?.toString() ?? '',
      administrationDate: DateTime.utc(
        examDate.year, examDate.month, examDate.day,
      ),
      itemContentRevision: data['item_content_revision'] is int
          ? data['item_content_revision'] as int : 0,
      answerLocationRevision: data['answer_location_revision'] is int
          ? data['answer_location_revision'] as int : 0,
    );
    binding.validate();
    final rawSteps = data['steps'];
    const names = {
      'resource_choice',
      'section_location',
      'interpretation',
      'application',
    };
    if (rawSteps is! Map || rawSteps.keys.toSet().difference(names).isNotEmpty
        || rawSteps.length != 4) {
      throw const FormatException('Incorrect reference-practice step count');
    }
    final result = <String, ReferenceDrillStepPrompt>{};
    for (final name in names) {
      final raw = rawSteps[name];
      if (raw is! Map || raw.keys.toSet().difference({'prompt','choices'})
          .isNotEmpty || raw.length != 2 ||
          raw['prompt'] is! String ||
          (raw['prompt'] as String).trim().length < 8 ||
          raw['choices'] is! List) {
        throw const FormatException('Malformed reference-practice prompt');
      }
      final choices = <ReferenceDrillChoice>[];
      final unique = <String>{};
      for (final item in raw['choices'] as List) {
        if (item is! Map || item.length != 2 ||
            item.keys.toSet().difference({'value','label'}).isNotEmpty ||
            item['value'] is! String || item['label'] is! String) {
          throw const FormatException('Malformed reference-practice choice');
        }
        final value = item['value'] as String;
        final label = (item['label'] as String).trim();
        if (!RegExp(r'^[a-z0-9][a-z0-9 _./:-]*$').hasMatch(value) ||
            value.length > 80 || label.isEmpty || label.length > 200 ||
            !unique.add(value)) {
          throw const FormatException('Invalid reference-practice choice');
        }
        choices.add(ReferenceDrillChoice(value, label));
      }
      if (choices.length < 2 || choices.length > 6) {
        throw const FormatException('Invalid choice count');
      }
      result[name] = ReferenceDrillStepPrompt(
        raw['prompt'] as String,
        List.unmodifiable(choices),
      );
    }
    return ApprovedReferenceDrillPractice(
      binding: binding, steps: Map.unmodifiable(result),
    );
  }
}

/// Reads only a server-reviewed presentation. A valid manifest alone is not
/// permission to see unreviewed items, held-out material, or answer keys.
class ExamReferenceDrillPracticeService {
  final SupabaseClient _client;
  final Future<dynamic> Function(String manifestId, String partKey,
      String administrationDate)? _testTransport;

  ExamReferenceDrillPracticeService({
    SupabaseClient? client,
    Future<dynamic> Function(String manifestId, String partKey,
        String administrationDate)? testTransport,
  }) : _client = client ?? Supabase.instance.client,
       _testTransport = testTransport;

  void _checkOwner(String ownerId) {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous || user.id != ownerId) {
      throw StateError('Reviewed reference practice requires the same permanent account.');
    }
  }

  Future<ApprovedReferenceDrillPractice?> fetch({
    required String expectedOwnerId,
    required String manifestRevisionId,
    required String examPartKey,
    required DateTime administrationDate,
  }) async {
    _checkOwner(expectedOwnerId);
    final normalizedDate = DateTime.utc(
      administrationDate.year,
      administrationDate.month,
      administrationDate.day,
    ).toIso8601String().substring(0, 10);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    ).hasMatch(manifestRevisionId) ||
        !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(examPartKey)) {
      throw const FormatException('Unverified exam practice identity');
    }
    final dynamic raw = _testTransport != null
        ? await _testTransport(
            manifestRevisionId, examPartKey, normalizedDate,
          )
        : await _client.rpc(
            'get_exam_reference_drill_practice',
            params: {
              'p_manifest_revision_id': manifestRevisionId,
              'p_exam_part_key': examPartKey,
              'p_administration_date': normalizedDate,
            },
          );
    _checkOwner(expectedOwnerId);
    if (raw == null) return null;
    if (raw is! Map) {
      throw const FormatException('Invalid reviewed-practice projection');
    }
    return ApprovedReferenceDrillPractice.fromRpc(
      Map<String, dynamic>.from(raw),
      manifestId: manifestRevisionId,
      partKey: examPartKey,
      examDate: administrationDate,
    );
  }
}
