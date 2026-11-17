import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/community_qa_provider.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/display_name_provider.dart';
import 'package:learning_pwa/providers/device_avatar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final user = User(
    id: 'learner-1',
    email: 'learner@example.com',
    appMetadata: const {'provider': 'google'},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime(2026, 1, 1).toIso8601String(),
  );

  Widget app(_FakeRepo repo,
          {bool withAvatar = false, bool withContributor = false, User? as}) =>
      ProviderScope(
        overrides: [
          if (withAvatar)
            avatarCustomizerEnabledProvider.overrideWithValue(true),
          if (withContributor)
            educatorProfilesFeatureEnabledProvider.overrideWithValue(true),
          authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(AuthSuccess(as ?? user))),
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
  testWidgets('customize avatar saves a device-local profile appearance',
      (tester) async {
    await tester.pumpWidget(app(_FakeRepo('Ashley'), withAvatar: true));
    await tester.pumpAndSettle();

    final editAvatar = find.byKey(const Key('profile-customize-avatar'));
    expect(editAvatar, findsOneWidget);
    await tester.tap(editAvatar);
    await tester.pumpAndSettle();

    expect(find.text('Customize Your Persona'), findsOneWidget);
    await tester.tap(find.text('😎 Confident'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save Avatar'));
    await tester.tap(find.text('Save Avatar'));
    await tester.pumpAndSettle();

    expect(find.text('😎'), findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Avatar'),
        findsOneWidget,
        reason: 'the emoji face is announced as "Avatar"');
  });

  testWidgets('a guest never gets the avatar customizer, even when ON',
      (tester) async {
    final guest = User(
      id: 'guest-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime(2026, 1, 1).toIso8601String(),
      isAnonymous: true,
    );
    await tester.pumpWidget(app(_FakeRepo('Guest'), withAvatar: true, as: guest));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-customize-avatar')), findsNothing);
    expect(find.byKey(const Key('profile-local-avatar')), findsNothing);
  });

  testWidgets('feature OFF keeps the initial avatar', (tester) async {
    await tester.pumpWidget(app(_FakeRepo('Ashley')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-customize-avatar')), findsNothing);
    expect(find.text('A'), findsWidgets);
  });

  testWidgets('learning.educator_profiles: contributor profile link for accounts',
      (tester) async {
    await tester.pumpWidget(app(_FakeRepo('Ashley'), withContributor: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-contributor-profile')), findsOneWidget);
  });

  testWidgets('no contributor profile link when OFF', (tester) async {
    await tester.pumpWidget(app(_FakeRepo('Ashley')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-contributor-profile')), findsNothing);
  });

  testWidgets('no contributor profile link for guests, even when ON', (tester) async {
    final guest = User(
      id: 'guest-2',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime(2026, 1, 1).toIso8601String(),
      isAnonymous: true,
    );
    await tester.pumpWidget(app(_FakeRepo('Guest'), withContributor: true, as: guest));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-contributor-profile')), findsNothing);
  });
}
