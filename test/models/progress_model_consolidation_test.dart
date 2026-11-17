import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson_progress.dart' as canonical;

void main() {
  group('ANA-001B canonical progress model', () {
    test('legacy Hive-style model retains local-only identity and sync state', () {
      final canonical.UserProgress cached = canonical.UserProgress(
        id: 'user_lesson_123',
        userId: 'user',
        lessonId: 'legacy-lesson',
        studyMode: canonical.StudyMode.flashcard,
        date: DateTime.utc(2026, 11, 9),
        questionsAnswered: 2,
        correctCount: 1,
        lessonCompleted: false,
        studyTimeSeconds: 75,
        isSynced: false,
        metadata: const {'locally_created': true},
      );
      final data = cached.toJson();
      expect(data['id'], 'user_lesson_123');
      expect(data['is_synced'], isFalse);
      final restored = canonical.UserProgress.fromJson(data);
      expect(restored.studyTimeSeconds, 75);
      expect(restored.studyMode, canonical.StudyMode.flashcard);
      expect(restored.metadata?['locally_created'], isTrue);
    });
  });
}
