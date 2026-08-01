import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/session_result.dart';

void main() {
  group('SessionResult', () {
    test('accuracy and missed derive from correct/total', () {
      const r = SessionResult(mode: SessionMode.mcq, correct: 3, total: 4);
      expect(r.accuracy, closeTo(0.75, 1e-9));
      expect(r.missed, 1);
    });

    test('formattedDuration is null when untracked', () {
      const r = SessionResult(mode: SessionMode.flashcards, correct: 1, total: 1);
      expect(r.formattedDuration, isNull);
    });

    test('formattedDuration renders m:ss with zero-padded seconds', () {
      const r = SessionResult(
        mode: SessionMode.flashcards,
        correct: 1,
        total: 1,
        duration: Duration(minutes: 4, seconds: 7),
      );
      expect(r.formattedDuration, '4:07');
    });
  });
}
