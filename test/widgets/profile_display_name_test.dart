import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/display_name_provider.dart';
import 'package:learning_pwa/screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class _FakeRepo extends DisplayNameRepository {
  _FakeRepo(this.name);
  String? name;
  final saved = <String>[];

  @override
  Future<String?> fetch(String userId) async => name;

  @override
  Future<void> save(String userId, String value) async {
    saved.add(value.trim());
    name = value.trim();
  }
}

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final user = User(
    id: 'learner-1',
    email: 'learner@example.com',
    appMetadata: const {'provider': 'google'},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2026, 1, 1).toIso8601String(),
  );

  Widget app(_FakeRepo repo) => ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(AuthSuccess(user))),
          displayNameRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      );

  test('validateDisplayName enforces 2-100 printable characters', () {
    expect(validateDisplayName(' A '), isNotNull);
    expect(validateDisplayName('Al'), isNull);
    expect(validateDisplayName('x' * 101), isNotNull);
    expect(validateDisplayName('Line\nbreak'), isNotNull);
  });

  testWidgets('headline shows the display name, email moves below',
      (tester) async {
    await tester.pumpWidget(app(_FakeRepo('Ashley')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('profile-headline'))).data,
      'Ashley',
    );
    expect(find.byKey(const Key('profile-email')), findsOneWidget);
  });

  testWidgets('falls back to email when no display name is set',
      (tester) async {
    await tester.pumpWidget(app(_FakeRepo(null)));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('profile-headline'))).data,
      'learner@example.com',
    );
    expect(find.byTooltip('Add display name'), findsOneWidget);
  });

  testWidgets('editing validates, saves, and refreshes the headline',
      (tester) async {
    final repo = _FakeRepo(null);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-edit-display-name')));
    await tester.pumpAndSettle();
    expect(find.textContaining("doesn't change how you sign in"), findsOneWidget);

    await tester.enterText(find.byKey(const Key('display-name-field')), 'A');
    await tester.tap(find.byKey(const Key('display-name-save')));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 2 characters.'), findsOneWidget);
    expect(repo.saved, isEmpty);

    await tester.enterText(
        find.byKey(const Key('display-name-field')), '  Ashley R  ');
    await tester.tap(find.byKey(const Key('display-name-save')));
    await tester.pumpAndSettle();

    expect(repo.saved, ['Ashley R']);
    expect(find.byKey(const Key('display-name-field')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-headline'))).data,
      'Ashley R',
    );
  });
}
