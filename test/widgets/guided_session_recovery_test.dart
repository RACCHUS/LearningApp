// PR-A1: the guided screen explains a protected session and only deletes it
// after explicit confirmation (master plan v2.6 §12.5 / Appendix G.5).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/screens/lessons/guided_generation_screen.dart';
import 'package:learning_pwa/theme/semantic_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../models/generation_session_codec_test.dart' show v1Fixture;

const _primary = 'generation_session_v1';
const _broken = '{"id": "s1", "subject": "Broken"';

class _UserAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _UserAuthNotifier(String userId)
    : super(
        AuthSuccess(
          User(
            id: userId,
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: '2026-01-01',
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The screen shows a progress spinner while restoring, so pumpAndSettle
/// never settles; pump a bounded number of frames instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpScreen(WidgetTester tester, {String user = 'user-b'}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith((ref) => _UserAuthNotifier(user))],
      child: MaterialApp(
        theme: ThemeData(extensions: const [SemanticColors.light]),
        home: const GuidedGenerationScreen(),
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  String? clipboard;

  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  testWidgets('unreadable session: explained, copyable, kept', (tester) async {
    SharedPreferences.setMockInitialValues({_primary: _broken});
    await _pumpScreen(tester);

    expect(find.text('Saved session kept safe'), findsOneWidget);
    expect(find.textContaining('could not be opened'), findsOneWidget);
    await tester.tap(find.text('Copy saved data'));
    await _settle(tester);

    expect(clipboard, _broken);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_primary), _broken);
  });

  testWidgets('discard requires a second confirmation', (tester) async {
    SharedPreferences.setMockInitialValues({_primary: _broken});
    await _pumpScreen(tester);

    await tester.tap(find.text('Discard it'));
    await _settle(tester);
    expect(find.text('Discard saved session?'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await _settle(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_primary), _broken);
  });

  testWidgets('confirmed discard removes the protected session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({_primary: _broken});
    await _pumpScreen(tester);

    await tester.tap(find.text('Discard it'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await _settle(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_primary), isNull);
  });

  testWidgets("another account's session offers no copy or discard", (
    tester,
  ) async {
    final ownedByA = jsonEncode(v1Fixture()..['owner_scope'] = 'user-a');
    SharedPreferences.setMockInitialValues({_primary: ownedByA});
    await _pumpScreen(tester, user: 'user-b');

    expect(
      find.textContaining('belongs to a different account'),
      findsOneWidget,
    );
    expect(find.text('Copy saved data'), findsNothing);
    expect(find.text('Discard it'), findsNothing);
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(find.text('Resume Session?'), findsNothing);
  });

  testWidgets('own readable session still offers Resume', (tester) async {
    SharedPreferences.setMockInitialValues({
      _primary: jsonEncode(v1Fixture()..['owner_scope'] = 'user-a'),
    });
    await _pumpScreen(tester, user: 'user-a');
    expect(find.text('Saved session kept safe'), findsNothing);
    expect(find.text('Resume Session?'), findsOneWidget);
  });
}
