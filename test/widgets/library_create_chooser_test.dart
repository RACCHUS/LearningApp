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
import 'package:learning_pwa/screens/home/home_courses_list.dart';
import 'package:learning_pwa/screens/library/library_screen.dart';
import 'package:learning_pwa/services/learning_target_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget app({String? initialQuery}) {
    final search = initialQuery;
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FakeAuthNotifier(GuestMode())),
        learningContextsProvider.overrideWith(
          (ref) => LearningContextsNotifier.stub(const LearningContextsState()),
        ),
        activeResolvedScopeProvider.overrideWith((ref) => Future.value(null)),
        // Healthy, empty catalogs: without these the screen reached an
        // uninitialized Supabase.instance and rendered its error states.
        catalogClustersProvider.overrideWith((ref) => Future.value(const [])),
        assetLessonsProvider.overrideWith((ref) => Future.value(const [])),
        remoteCatalogLessonsProvider.overrideWith((ref) => Future.value(const [])),
        offlineCatalogLessonsProvider.overrideWith((ref) => Future.value(const [])),
        learningTargetServiceProvider.overrideWithValue(_NoTargetsService()),
        targetsListProvider((type: null, types: null, search: search))
            .overrideWith((ref) => Future.value(const <LearningTarget>[])),
        if (search != null) ...[
          searchCoursesProvider(search).overrideWith((ref) => Future.value([])),
          searchConceptsProvider(search).overrideWith((ref) => Future.value([])),
        ],
      ],
      child: MaterialApp(home: LibraryScreen(initialQuery: initialQuery)),
    );
  }

  testWidgets('browse state has exactly one Create entry', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.byKey(const Key('library-create')), findsOneWidget);
    expect(find.text('Create Goal'), findsNothing);
    expect(find.text('Create Lesson'), findsNothing);
    expect(find.text('12 Domains'), findsNothing);
  });

  testWidgets('Create opens the single chooser with every option',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.byKey(const Key('library-create')));
    await settle(tester);

    expect(find.text('What would you like to make?'), findsOneWidget);
    expect(find.byKey(const Key('create-chooser-goal')), findsOneWidget);
    expect(find.byKey(const Key('create-chooser-studySet')), findsOneWidget);
    expect(find.byKey(const Key('create-chooser-lesson')), findsOneWidget);
    expect(find.byKey(const Key('create-chooser-import')), findsOneWidget);
  });

  testWidgets('source chips collapse into one picker defaulting to Trusted',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('Source: Trusted catalog'), findsOneWidget);
    expect(find.byKey(const Key('library-source-official')), findsNothing);

    await tester.tap(find.byKey(const Key('library-source-picker')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('library-source-mine')));
    await settle(tester);

    expect(find.text('Source: My goals'), findsOneWidget);
  });

  testWidgets('empty search offers Create carrying the query into the goal',
      (tester) async {
    await tester.pumpWidget(app(initialQuery: 'beekeeping'));
    await settle(tester);

    expect(find.text('Nothing found for "beekeeping".'), findsOneWidget);
    final create = find.byKey(const Key('library-empty-search-create'));
    expect(create, findsOneWidget);
    expect(find.text('Create "beekeeping"'), findsOneWidget);

    await tester.tap(create);
    await settle(tester);
    expect(find.text('Starting from "beekeeping"'), findsOneWidget);

    await tester.tap(find.byKey(const Key('create-chooser-goal')));
    await settle(tester);

    final titleField = tester.widgetList<EditableText>(find.byType(EditableText))
        .where((e) => e.controller.text == 'beekeeping');
    expect(titleField, isNotEmpty);
  });

  testWidgets('Words is visible in browse state',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byKey(const Key('library-words')), findsOneWidget);
    expect(find.text('My spelling words'), findsNothing);
  });

  testWidgets('Words stays visible during an unrelated search',
      (tester) async {
    await tester.pumpWidget(app(initialQuery: 'photosynthesis'));
    await settle(tester);
    expect(find.byKey(const Key('library-words')), findsOneWidget);
    expect(find.byKey(const Key('library-search-words')), findsNothing);
  });

  testWidgets('searching for word practice surfaces Words as a result',
      (tester) async {
    await tester.pumpWidget(app(initialQuery: 'spelling'));
    await settle(tester);

    expect(find.byKey(const Key('library-search-words')), findsOneWidget);
    expect(find.byKey(const Key('library-empty-search-create')), findsNothing);
  });
}

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier([AuthState? initial]) : super(initial ?? GuestMode());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No targets exist. Any other service call fails loudly (Fake throws).
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
