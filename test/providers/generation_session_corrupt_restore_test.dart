// PR-0a (master plan v2.6 §14.8): an unreadable V1 generation session keeps
// its raw bytes before any later write can overwrite them.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/generation_session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupt V1 session raw text is preserved on failed restore', () async {
    const raw = '{"id": "s1", "subject": "Broken", "created_at": 42}';
    SharedPreferences.setMockInitialValues({'generation_session_v1': raw});

    final notifier = GenerationSessionNotifier();
    expect(await notifier.tryRestore(), isFalse);
    expect(await GenerationSessionNotifier.readCorruptSessionBackup(), raw);

    // A new session overwrites the live key but not the preserved copy.
    notifier.startSession(
      subject: 'New',
      targetAudience: 'adult',
      durationMinutes: 10,
      difficulty: 'beginner',
      contentFocus: 'balanced',
    );
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('generation_session_v1'), isNot(raw));
    expect(await GenerationSessionNotifier.readCorruptSessionBackup(), raw);
  });

  test('a later corrupt session does not replace the first backup', () async {
    SharedPreferences.setMockInitialValues({
      'generation_session_v1': 'not json',
      GenerationSessionNotifier.corruptSessionBackupKey: 'first',
    });
    expect(await GenerationSessionNotifier().tryRestore(), isFalse);
    expect(await GenerationSessionNotifier.readCorruptSessionBackup(), 'first');
  });
}
