import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/canonical_taxonomy_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/scope_resolver_provider.dart';
import 'package:learning_pwa/screens/library/library_screen.dart';
import 'package:learning_pwa/services/learning_target_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

/// Which goals each Library source shows (audit gap T1, plan v0.6).
///
/// The source decision is a client filter over targets the server already
/// returned (`targets_read` RLS mirrors `isTrustedPublic`). These cases pin
/// the client half: trusted/official/reviewed never surface private or
/// unreviewed rows, and "My goals" shows only the signed-in user's own.

const _me = 'user-me';

LearningTarget _target(
  String id, {
  bool isPublic = true,
  bool isOfficial = false,
  TargetStatus status = TargetStatus.published,
  TargetReviewStatus reviewStatus = TargetReviewStatus.approved,
  String? createdBy,
}) =>
    LearningTarget(
      id: id,
      title: 'Goal $id',
      slug: id,
      targetType: TargetType.career,
      isPublic: isPublic,
      isOfficial: isOfficial,
      status: status,
      reviewStatus: reviewStatus,
      createdBy: createdBy,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

final _all = <LearningTarget>[
  _target('official', isOfficial: true),
  _target('catalog'), // approved, no creator
  _target('reviewed', createdBy: 'someone-else'),
  _target('pending',
      createdBy: 'someone-else', reviewStatus: TargetReviewStatus.pending),
  _target('my-draft',
      isPublic: false,
      status: TargetStatus.draft,
      reviewStatus: TargetReviewStatus.pending,
      createdBy: _me),
  _target('my-reviewed', createdBy: _me),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(AuthState auth) => ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FakeAuthNotifier(auth)),
        learningContextsProvider.overrideWith(
          (ref) => LearningContextsNotifier.stub(const LearningContextsState()),
        ),
        activeResolvedScopeProvider.overrideWith((ref) => Future.value(null)),
        catalogClustersProvider.overrideWith((ref) => Future.value(const [])),
        assetLessonsProvider.overrideWith((ref) => Future.value(const [])),
        remoteCatalogLessonsProvider.overrideWith((ref) => Future.value(const [])),
        offlineCatalogLessonsProvider.overrideWith((ref) => Future.value(const [])),
        learningTargetServiceProvider.overrideWithValue(_NoTargetsService()),
        targetsListProvider((type: null, types: null, search: null))
            .overrideWith((ref) => Future.value(_all)),
      ],
      child: const MaterialApp(home: LibraryScreen()),
    );

Future<Set<String>> _shownFor(WidgetTester tester, String? source) async {
  if (source != null) {
    await tester.tap(find.byKey(const Key('library-source-picker')));
    await _settle(tester);
    await tester.tap(find.byKey(Key('library-source-$source')).last);
    await _settle(tester);
  }
  return {
    for (final t in _all)
      if (find.byKey(Key('library-target-${t.id}'), skipOffstage: false).evaluate().isNotEmpty) t.id,
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, AuthState auth) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(auth));
    await _settle(tester);
  }

  final signedIn = AuthSuccess(User(
    id: _me,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.utc(2026).toIso8601String(),
  ));

  testWidgets('Trusted (default) shows only trusted public goals',
      (tester) async {
    await pump(tester, signedIn);
    expect(await _shownFor(tester, null),
        {'official', 'catalog', 'reviewed', 'my-reviewed'});
  });

  testWidgets('Official shows only official goals', (tester) async {
    await pump(tester, signedIn);
    expect(await _shownFor(tester, 'official'), {'official'});
  });

  testWidgets('Reviewed community excludes official, catalog and pending',
      (tester) async {
    await pump(tester, signedIn);
    expect(await _shownFor(tester, 'reviewed'), {'reviewed', 'my-reviewed'});
  });

  testWidgets('My goals shows only the signed-in user\'s own goals',
      (tester) async {
    await pump(tester, signedIn);
    expect(await _shownFor(tester, 'mine'), {'my-draft', 'my-reviewed'});
  });

  testWidgets('My goals shows nothing for a guest', (tester) async {
    await pump(tester, GuestMode());
    expect(await _shownFor(tester, 'mine'), isEmpty);
  });
}

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoTargetsService extends Fake implements LearningTargetService {
  @override
  Future<List<LearningTarget>> getTargets({
    TargetType? type,
    List<TargetType>? types,
    String? fieldId,
    String? search,
    int limit = 50,
  }) async =>
      const [];
}
