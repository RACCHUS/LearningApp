import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/services/assessment/exam_combined_practice_portability_service.dart';
import 'package:learning_pwa/services/assessment/reference_practice_json_download.dart';
import 'package:learning_pwa/widgets/progress/combined_exam_practice_portability_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../test_helpers/fake_supabase_client.dart';

User _user(String id, {bool guest=false}) => User(
  id: id,
  isAnonymous: guest,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-23T00:00:00Z',
);

class _AuthController extends StateNotifier<AuthState> implements AuthNotifier {
  _AuthController(AuthState initial) : super(initial);

  void switchTo(AuthState next) => state = next;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDownload extends ReferencePracticeJsonDownload {
  String? filename;
  String? payload;
  int calls = 0;

  @override
  bool get isSupported => true;

  @override
  void requestChunkedDownload({
    required String filename,
    required Iterable<String> chunks,
  }) {
    calls++;
    this.filename = filename;
    payload = chunks.join();
  }
}

Map<String, dynamic> _inventory({
  String owner='learner-a',
  int count=1,
  int attempts=1,
  String fingerprint='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
}) => {
  'scope': ExamPracticeInventory.scope,
  'owner_id': owner,
  'reference_events': 0,
  'reference_grades': 0,
  'part_assignments': count,
  'part_attempts': attempts,
  'snapshot_fingerprint': fingerprint,
  'bound_per_store': 5000,
};

Map<String, dynamic> _archive() => {
  'format': 'learningapp-exm-combined-practice-v1',
  'scope': 'educational-practice-history-not-entire-account',
  'owner_id': 'learner-a',
  'generated_at': '2026-10-23T12:00:00Z',
  'snapshot_consistency': 'single-stable-rpc-statement',
  'inventory': _inventory(),
  'reference_practice': {
    'format': 'learningapp-exm-reference-practice-account-v1',
    'scope': 'reference-practice-all-editions',
    'owner_auth_uid': 'learner-a',
    'record_count': 0,
    'generated_at': '2026-10-23T12:00:00Z',
    'snapshot_consistency': 'single-sql-statement',
    'steps': <dynamic>[],
  },
  'part_practice': [
    {
      'assignment_id': '11111111-1111-4111-8111-111111111111',
      'target_id': '22222222-2222-4222-8222-222222222222',
      'target_version_id': '33333333-3333-4333-8333-333333333333',
      'exam_part_key': 'part_a',
      'curriculum_root_node_id': '44444444-4444-4444-8444-444444444444',
      'manifest_revision_id': '55555555-5555-4555-8555-555555555555',
      'practice_kind': 'diagnostic',
      'issued_at': '2026-10-23T10:00:00Z',
      'expires_at': '2026-10-23T11:30:00Z',
      'attempt': {
        'attempt_id': '66666666-6666-4666-8666-666666666666',
        'completed_at': '2026-10-23T10:15:00Z',
        'question_count': 6,
        'fully_correct_count': 4,
        'partial_count': 0,
        'practice_score': 0.666667,
        'question_edition_fingerprint': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        'official_exam_result': false,
      },
    }
  ],
  'includes_unsubmitted_assignments': true,
  'official_exam_result': false,
};

Map<String, dynamic> _receipt() => {
  'scope': ExamPracticeInventory.scope,
  'owner_id': 'learner-a',
  'deleted_reference_events': 0,
  'deleted_part_assignments': 1,
  'remaining_reference_events': 0,
  'remaining_reference_grades': 0,
  'remaining_part_assignments': 0,
  'remaining_part_attempts': 0,
  'irreversible': true,
};

Widget _app({
  required _AuthController auth,
  required ExamCombinedPracticePortabilityService service,
  _FakeDownload? downloader,
}) => ProviderScope(
  overrides: [authProvider.overrideWith((ref) => auth)],
  child: MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CombinedExamPracticePortabilityCard(
          service: service,
          fileDownload: downloader,
        ),
      ),
    ),
  ),
);

Future<void> _tapVisible(WidgetTester tester, String key) async {
  final found = find.byKey(Key(key));
  await tester.ensureVisible(found);
  await tester.pumpAndSettle();
  await tester.tap(found);
  await tester.pumpAndSettle();
}

void main() {
  test('Archive chunk iterator produces the same validated JSON', () {
    final archive = ExamPracticeArchive.parse(_archive(), 'learner-a');
    final chunked = archive.toJsonChunks().join();
    expect(jsonDecode(chunked), jsonDecode(archive.toJson()));
    expect(chunked, isNot(contains('scoring_spec')));
    expect(chunked, isNot(contains('issued_session_id')));
    expect(chunked, isNot(contains('assigned_items')));
    expect(archive.inventory.attempts, 1);
  });

  testWidgets('Owner verifies complete archive and explicitly downloads',
      (tester) async {
    final auth = _AuthController(AuthSuccess(_user('learner-a')));
    final download = _FakeDownload();
    final service = ExamCombinedPracticePortabilityService(
      client: FakeSupabaseClient(currentUser: _user('learner-a')),
      testInventory: () async => _inventory(),
      testExport: () async => _archive(),
    );
    await tester.pumpWidget(_app(auth: auth, service: service,
        downloader: download));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exm-combined-counts')), findsNothing);

    await _tapVisible(tester, 'exm-combined-preview');
    expect(find.textContaining('1 issued part assignments'), findsOneWidget);
    await _tapVisible(tester, 'exm-combined-prepare');
    expect(find.byKey(const Key('exm-combined-verified')), findsOneWidget);
    await _tapVisible(tester, 'exm-combined-download');
    expect(download.calls, 0);
    await _tapVisible(tester, 'exm-combined-download-confirm');
    expect(download.calls, 1);
    expect(download.filename, matches(RegExp(
      r'^learningapp-exm-combined-practice-\d{8}T\d{6}Z\.json$')));
    expect((jsonDecode(download.payload!) as Map)['owner_id'], 'learner-a');
  });

  testWidgets('Stale server inventory blocks download and erasure preview',
      (tester) async {
    final auth = _AuthController(AuthSuccess(_user('learner-a')));
    final download = _FakeDownload();
    final service = ExamCombinedPracticePortabilityService(
      client: FakeSupabaseClient(currentUser: _user('learner-a')),
      testInventory: () async => _inventory(),
      testExport: () async => {
        ..._archive(),
        'inventory': _inventory(
          fingerprint: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'),
      },
    );
    await tester.pumpWidget(_app(auth: auth, service: service,
        downloader: download));
    await tester.pumpAndSettle();
    await _tapVisible(tester, 'exm-combined-preview');
    await _tapVisible(tester, 'exm-combined-prepare');
    expect(find.byKey(const Key('exm-combined-error')), findsOneWidget);
    expect(find.byKey(const Key('exm-combined-download')), findsNothing);
    expect(find.byKey(const Key('exm-combined-delete')), findsNothing);
    expect(download.calls, 0);
  });

  testWidgets('Typed phrase and second confirmation are required to erase',
      (tester) async {
    final auth = _AuthController(AuthSuccess(_user('learner-a')));
    var deletes = 0;
    final service = ExamCombinedPracticePortabilityService(
      client: FakeSupabaseClient(currentUser: _user('learner-a')),
      testInventory: () async => _inventory(),
      testErase: (events,assignments,attempts,fingerprint,phrase) async {
        deletes++;
        expect([events,assignments,attempts], [0,1,1]);
        expect(phrase, 'DELETE ALL EXAM PRACTICE');
        return _receipt();
      },
    );
    await tester.pumpWidget(_app(auth: auth, service: service));
    await tester.pumpAndSettle();
    await _tapVisible(tester, 'exm-combined-preview');
    expect(tester.widget<OutlinedButton>(
      find.byKey(const Key('exm-combined-delete'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('exm-combined-phrase')),
        'delete all exam practice');
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(
      find.byKey(const Key('exm-combined-delete'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('exm-combined-phrase')),
        'DELETE ALL EXAM PRACTICE');
    await tester.pumpAndSettle();
    await _tapVisible(tester, 'exm-combined-delete');
    expect(deletes, 0);
    expect(find.byKey(const Key('exm-combined-delete-confirm')), findsOneWidget);
    await _tapVisible(tester, 'exm-combined-delete-confirm');
    expect(deletes, 1);
    expect(find.byKey(const Key('exm-combined-result')), findsOneWidget);
    expect(find.byKey(const Key('exm-combined-delete')), findsNothing);
  });

  testWidgets('Logout or account switch suppresses an in-flight archive',
      (tester) async {
    final auth = _AuthController(AuthSuccess(_user('learner-a')));
    final pending = Completer<dynamic>();
    final service = ExamCombinedPracticePortabilityService(
      client: FakeSupabaseClient(currentUser: _user('learner-a')),
      testInventory: () => pending.future,
    );
    await tester.pumpWidget(_app(auth: auth, service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exm-combined-preview')));
    await tester.pump();
    auth.switchTo(AuthSuccess(_user('learner-b')));
    await tester.pump();
    pending.complete(_inventory());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exm-combined-counts')), findsNothing);
    expect(find.byKey(const Key('exm-combined-download')), findsNothing);
    expect(find.byKey(const Key('exm-combined-delete')), findsNothing);
    auth.switchTo(GuestMode());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exm-combined-practice-card')), findsNothing);
  });
}
