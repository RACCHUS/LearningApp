// PR-0a/PR-A1 (master plan v2.6 §12.5, §14.8, Appendix G.5): a stored
// session this build cannot open is protected byte-for-byte; new work is
// saved separately until the learner explicitly copies or discards it.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/generation_session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/generation_session_codec_test.dart' show v1Fixture;

const _primary = 'generation_session_v1';

void _start(GenerationSessionNotifier n, String subject) => n.startSession(
  subject: subject,
  targetAudience: 'adults',
  durationMinutes: 10,
  difficulty: 'beginner',
  contentFocus: 'balanced',
);

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('unreadable legacy session', () {
    const raw = '{"id": "s1", "subject": "Broken", "created_at": 42}';

    setUp(() => SharedPreferences.setMockInitialValues({_primary: raw}));

    test('is preserved, flagged, and never overwritten by new work', () async {
      final n = GenerationSessionNotifier();
      expect(await n.tryRestore(), isFalse);
      expect(n.recovery?.reason, SessionRecoveryReason.unreadable);
      expect(n.recovery?.field, 'created_at');
      expect(await GenerationSessionNotifier.readCorruptSessionBackup(), raw);

      _start(n, 'New work');
      await n.flushPersistence();
      final prefs = await _prefs();
      expect(prefs.getString(_primary), raw, reason: 'byte-for-byte');
      expect(
        jsonDecode(
          prefs.getString(GenerationSessionNotifier.recoveryWorkKey)!,
        )['subject'],
        'New work',
      );

      // Starting fresh clears only the separate work copy.
      n.clearSession();
      await n.flushPersistence();
      expect(prefs.getString(_primary), raw);
      expect(
        prefs.getString(GenerationSessionNotifier.recoveryWorkKey),
        isNull,
      );
    });

    test('work saved during recovery is restored after a reload', () async {
      final first = GenerationSessionNotifier();
      await first.tryRestore();
      _start(first, 'Survives reload');
      await first.flushPersistence();

      final second = GenerationSessionNotifier();
      expect(await second.tryRestore(), isTrue);
      expect(second.state?.subject, 'Survives reload');
      expect(second.recovery, isNotNull);
      expect((await _prefs()).getString(_primary), raw);
    });

    test('export returns the original text exactly', () async {
      final n = GenerationSessionNotifier();
      await n.tryRestore();
      expect(await n.exportProtectedSession(), raw);
    });

    test(
      'discard promotes new work and then writes go to the normal key',
      () async {
        final n = GenerationSessionNotifier();
        await n.tryRestore();
        _start(n, 'Keep me');
        await n.flushPersistence();

        expect(await n.discardProtectedSession(), isTrue);
        expect(n.recovery, isNull);
        final prefs = await _prefs();
        expect(jsonDecode(prefs.getString(_primary)!)['subject'], 'Keep me');
        expect(
          prefs.getString(GenerationSessionNotifier.recoveryWorkKey),
          isNull,
        );
        expect(
          await GenerationSessionNotifier.readCorruptSessionBackup(),
          isNull,
        );

        _start(n, 'After discard');
        await n.flushPersistence();
        expect(
          jsonDecode(prefs.getString(_primary)!)['subject'],
          'After discard',
        );
      },
    );

    test('discard with no new work removes the protected session', () async {
      final n = GenerationSessionNotifier();
      await n.tryRestore();
      expect(await n.discardProtectedSession(), isTrue);
      expect((await _prefs()).getString(_primary), isNull);
    });

    test('a later failure does not replace the first backup', () async {
      SharedPreferences.setMockInitialValues({
        _primary: 'not json',
        GenerationSessionNotifier.corruptSessionBackupKey: 'first',
      });
      expect(await GenerationSessionNotifier().tryRestore(), isFalse);
      expect(
        await GenerationSessionNotifier.readCorruptSessionBackup(),
        'first',
      );
    });
  });

  test('newer schema version is protected, not coerced', () async {
    final raw = jsonEncode(v1Fixture()..['schema_version'] = 2);
    SharedPreferences.setMockInitialValues({_primary: raw});
    final n = GenerationSessionNotifier();
    expect(await n.tryRestore(), isFalse);
    expect(n.recovery?.reason, SessionRecoveryReason.newerVersion);
    _start(n, 'Old build work');
    await n.flushPersistence();
    expect((await _prefs()).getString(_primary), raw);
  });

  group('account isolation on a shared device', () {
    final ownedByA = jsonEncode(v1Fixture()..['owner_scope'] = 'user-a');

    setUp(() => SharedPreferences.setMockInitialValues({_primary: ownedByA}));

    test("user B does not get user A's draft, and cannot export it", () async {
      final n = GenerationSessionNotifier();
      expect(await n.tryRestore(ownerScope: 'user-b'), isFalse);
      expect(n.state, isNull);
      expect(n.recovery?.reason, SessionRecoveryReason.otherAccount);
      expect(n.recovery?.canExport, isFalse);
      expect(await n.exportProtectedSession(), isNull);

      _start(n, 'B work');
      await n.flushPersistence();
      expect((await _prefs()).getString(_primary), ownedByA);
    });

    test('a signed-out visitor does not get an account draft', () async {
      final n = GenerationSessionNotifier();
      expect(await n.tryRestore(), isFalse);
      expect(n.recovery?.reason, SessionRecoveryReason.otherAccount);
    });

    test('user A still gets their own draft', () async {
      final n = GenerationSessionNotifier();
      expect(await n.tryRestore(ownerScope: 'user-a'), isTrue);
      expect(n.recovery, isNull);
      expect(n.state?.subject, 'Percent change');
    });
  });

  test('legacy session without an owner restores as before', () async {
    SharedPreferences.setMockInitialValues({_primary: jsonEncode(v1Fixture())});
    final n = GenerationSessionNotifier();
    expect(await n.tryRestore(ownerScope: 'anyone'), isTrue);
    expect(n.recovery, isNull);
  });

  test('new sessions record their owner', () async {
    SharedPreferences.setMockInitialValues({});
    final n = GenerationSessionNotifier()..ownerScope = 'user-a';
    _start(n, 'Mine');
    await n.flushPersistence();
    expect(
      jsonDecode((await _prefs()).getString(_primary)!)['owner_scope'],
      'user-a',
    );
  });

  test('rapid saves land in order (last write wins on disk)', () async {
    SharedPreferences.setMockInitialValues({});
    final n = GenerationSessionNotifier();
    for (var i = 0; i < 5; i++) {
      _start(n, 'Subject $i');
    }
    await n.flushPersistence();
    expect(
      jsonDecode((await _prefs()).getString(_primary)!)['subject'],
      'Subject 4',
    );
  });
}
