import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/word_learning.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/screens/words/word_learning_screen.dart';
import 'package:learning_pwa/screens/words/word_transfer_screen.dart';
import 'package:learning_pwa/services/word_list_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:shared_preferences/shared_preferences.dart';

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
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('word learning screen is replaced on an account switch', (tester) async {
    final auth = _TestAuthNotifier();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => auth),
      ],
      child: const MaterialApp(home: WordLearningScreen()),
    ));

    expect(find.byKey(const ValueKey('word-learning:signed-out')), findsOneWidget);

    auth.become(AuthSuccess(_user('learner-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('word-learning:learner-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-learning:signed-out')), findsNothing);

    auth.become(AuthSuccess(_user('learner-b')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('word-learning:learner-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-learning:learner-a')), findsNothing);
  });

  testWidgets('delayed query from account A does not repopulate account B screen', (tester) async {
    final auth = _TestAuthNotifier();
    auth.become(AuthSuccess(_user('learner-a')));

    final completerA = Completer<List<WordList>>();
    final delayService = _DelayedWordListService(completerA);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => auth),
      ],
      child: MaterialApp(home: WordLearningScreen(service: delayService)),
    ));

    // learner-a's getLists is now pending on completerA
    expect(find.byKey(const ValueKey('word-learning:learner-a')), findsOneWidget);
    expect(find.text('Account A Secret List'), findsNothing);

    // Switch account to learner-b while learner-a's query is in flight
    auth.become(AuthSuccess(_user('learner-b')));
    await tester.pump();

    // Now complete learner-a's query with learner-a's private list
    completerA.complete([
      WordList(
        id: '22222222-2222-4222-8222-222222222222',
        userId: 'learner-a',
        title: 'Account A Secret List',
      ),
    ]);
    await tester.pumpAndSettle();

    // Verify learner-b's screen is active and learner-a's list was discarded
    expect(find.byKey(const ValueKey('word-learning:learner-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-learning:learner-a')), findsNothing);
    expect(find.text('Account A Secret List'), findsNothing);
  });
}

class _DelayedWordListService implements WordListService {
  final Completer<List<WordList>> completerA;
  _DelayedWordListService(this.completerA);

  @override
  Future<List<WordList>> getLists() => completerA.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
