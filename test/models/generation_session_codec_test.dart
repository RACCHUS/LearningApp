// PR-A1: versioned guided-session reader (master plan v2.6 §12.5, D.4).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/generation_session.dart';
import 'package:learning_pwa/models/generation_session_codec.dart';

/// A valid V1 payload exactly as the shipped `toJson()` writes it.
Map<String, dynamic> v1Fixture({String phase = 'generatingMcqs'}) => {
  'id': 'session-1',
  'created_at': '2026-11-01T10:00:00.000',
  'subject': 'Percent change',
  'target_audience': 'adults',
  'duration_minutes': 20,
  'difficulty': 'beginner',
  'content_focus': 'balanced',
  'lesson_plan': {
    'lesson_plan': {'title': 'Percent Change'},
  },
  'terms': [
    {'title': 'Percent', 'content': 'Per hundred.'},
  ],
  'concepts': [
    {'title': 'Change', 'content': 'New minus old over old.'},
  ],
  'mcqs': [
    {
      'question': 'From 50 to 60?',
      'options': ['20%', '10%'],
      'correct_answer': '20%',
      'explanation': 'x',
    },
  ],
  'review_result': null,
  'current_phase': phase,
};

SessionDecodeResult decodeMap(Map<String, dynamic> m) =>
    GenerationSessionCodec.decode(jsonEncode(m));

void main() {
  group('valid V1 sessions', () {
    for (final phase in GenerationPhase.values) {
      test('phase ${phase.name} round-trips', () {
        final r = decodeMap(v1Fixture(phase: phase.name));
        expect(r.kind, SessionDecodeKind.v1);
        expect(r.session!.currentPhase, phase);
        expect(r.session!.terms, hasLength(1));
        expect(r.session!.mcqs, hasLength(1));
        // Re-encoding through the codec stays readable.
        final again = GenerationSessionCodec.decode(
          GenerationSessionCodec.encode(r.session!),
        );
        expect(again.session!.currentPhase, phase);
      });
    }

    test('missing current_phase is the only defaulted field (planning)', () {
      final m = v1Fixture()..remove('current_phase');
      expect(decodeMap(m).session!.currentPhase, GenerationPhase.planning);
    });

    test('unrecognized current_phase falls back to planning', () {
      expect(
        decodeMap(v1Fixture(phase: 'teleporting')).session!.currentPhase,
        GenerationPhase.planning,
      );
    });

    test('optional content lists may be absent', () {
      final m = v1Fixture()
        ..remove('terms')
        ..remove('concepts')
        ..remove('mcqs')
        ..remove('lesson_plan');
      expect(decodeMap(m).kind, SessionDecodeKind.v1);
    });

    test('an already-flagged MCQ stays flagged, never made correct', () {
      final m = v1Fixture(phase: 'complete');
      ((m['mcqs'] as List).first as Map)['correct_answer'] = 'Dragonfruit';
      final q = (decodeMap(m).session!.assemble()['questions'] as List).first;
      expect(q['correct_answer'], isNull);
      expect(q['_answer_error'], 'invalid_key');
    });

    test('raw text is carried unchanged for preservation', () {
      final raw = jsonEncode(v1Fixture());
      expect(GenerationSessionCodec.decode(raw).raw, same(raw));
    });
  });

  group('unreadable V1: errors, never invented defaults', () {
    for (final field in [
      'id',
      'created_at',
      'subject',
      'target_audience',
      'duration_minutes',
      'difficulty',
      'content_focus',
    ]) {
      test('missing $field', () {
        final r = decodeMap(v1Fixture()..remove(field));
        expect(r.kind, SessionDecodeKind.unreadable);
        expect(r.field, field);
        expect(r.session, isNull);
      });

      test('null $field', () {
        final r = decodeMap(v1Fixture()..[field] = null);
        expect(r.kind, SessionDecodeKind.unreadable);
        expect(r.field, field);
      });
    }

    final wrongTypes = <String, Object>{
      'id': 7,
      'subject': ['x'],
      'duration_minutes': '20',
      'lesson_plan': 'plan',
      'review_result': 3,
      'terms': 'not a list',
      'mcqs': {'a': 1},
    };
    wrongTypes.forEach((field, value) {
      test('wrong type for $field', () {
        final r = decodeMap(v1Fixture()..[field] = value);
        expect(r.kind, SessionDecodeKind.unreadable);
        expect(r.field, field);
      });
    });

    test('non-object list entry is reported with its index', () {
      final m = v1Fixture();
      m['concepts'] = <Object>[...(m['concepts'] as List), 'oops'];
      expect(decodeMap(m).field, 'concepts[1]');
    });

    test('fractional duration is not truncated', () {
      expect(
        decodeMap(v1Fixture()..['duration_minutes'] = 20.5).field,
        'duration_minutes',
      );
    });

    test('invalid created_at date', () {
      final r = decodeMap(v1Fixture()..['created_at'] = 'yesterday');
      expect(r.kind, SessionDecodeKind.unreadable);
      expect(r.field, 'created_at');
    });

    test('malformed JSON and non-object JSON', () {
      expect(
        GenerationSessionCodec.decode('{"id": ').kind,
        SessionDecodeKind.unreadable,
      );
      expect(
        GenerationSessionCodec.decode('[1,2]').kind,
        SessionDecodeKind.unreadable,
      );
      expect(
        GenerationSessionCodec.decode('').kind,
        SessionDecodeKind.unreadable,
      );
    });
  });

  group('version discriminator', () {
    test('missing version means V1', () {
      expect(decodeMap(v1Fixture()).version, isNull);
      expect(decodeMap(v1Fixture()).kind, SessionDecodeKind.v1);
    });

    test('explicit schema_version 1 is V1', () {
      expect(
        decodeMap(v1Fixture()..['schema_version'] = 1).kind,
        SessionDecodeKind.v1,
      );
    });

    test('schemaVersion alias is honoured when canonical is absent', () {
      expect(
        decodeMap(v1Fixture()..['schemaVersion'] = 1).kind,
        SessionDecodeKind.v1,
      );
      expect(
        decodeMap(v1Fixture()..['schemaVersion'] = 2).kind,
        SessionDecodeKind.unsupportedVersion,
      );
    });

    test('future version is read-only, never coerced to V1', () {
      final r = decodeMap(v1Fixture()..['schema_version'] = 2);
      expect(r.kind, SessionDecodeKind.unsupportedVersion);
      expect(r.session, isNull);
      expect(r.version, 2);
    });

    test('conflicting spellings are rejected', () {
      final r = decodeMap(
        v1Fixture()
          ..['schema_version'] = 1
          ..['schemaVersion'] = 2,
      );
      expect(r.kind, SessionDecodeKind.conflictingVersion);
    });

    test('agreeing spellings are accepted', () {
      expect(
        decodeMap(
          v1Fixture()
            ..['schema_version'] = 1
            ..['schemaVersion'] = 1,
        ).kind,
        SessionDecodeKind.v1,
      );
    });

    test('non-integer or non-positive versions are rejected', () {
      for (final v in <Object>['1', 1.0, 0, -3, true]) {
        expect(
          decodeMap(v1Fixture()..['schema_version'] = v).kind,
          SessionDecodeKind.conflictingVersion,
          reason: '$v',
        );
      }
    });
  });

  group('owner scope', () {
    test('encode records owner_scope and decode returns it', () {
      final session = decodeMap(v1Fixture()).session!;
      final raw = GenerationSessionCodec.encode(session, ownerScope: 'user-a');
      expect(jsonDecode(raw)['owner_scope'], 'user-a');
      expect(GenerationSessionCodec.decode(raw).ownerScope, 'user-a');
    });

    test('legacy sessions have no owner', () {
      expect(decodeMap(v1Fixture()).ownerScope, isNull);
    });
  });
}
