import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/screens/words/word_transfer_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../test_helper.dart';

class _TestAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _TestAuthNotifier() : super(GuestMode());

  void become(AuthState next) => state = next;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

User _user(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-16T00:00:00Z',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await TestHelper.initializeSupabase();
  });

  testWidgets('word backup UI is replaced on an account switch', (tester) async {
    final auth = _TestAuthNotifier();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => auth),
      ],
      child: const MaterialApp(home: WordTransferScreen()),
    ));

    expect(find.byKey(const ValueKey('word-transfer:signed-out')), findsOneWidget);

    auth.become(AuthSuccess(_user('learner-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('word-transfer:learner-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-transfer:signed-out')), findsNothing);

    auth.become(AuthSuccess(_user('learner-b')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('word-transfer:learner-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-transfer:learner-a')), findsNothing);

    auth.become(GuestMode());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('word-transfer:signed-out')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-transfer:learner-b')), findsNothing);
  });
}
