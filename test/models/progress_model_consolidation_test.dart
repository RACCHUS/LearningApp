import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson_progress.dart' as canonical;
import 'package:learning_pwa/models/user_progress.dart' as compatibility;

void main() {
  group('ANA-001B canonical progress model import', () {
    test('legacy and canonical imports refer to the same UserProgress type', () {
      final compatibility.UserProgress progress = compatibility.UserProgress(
        id: 'local-test-record',
        userId: 'test-user',
        lessonId: 'prog_01_variables',
        studyMode: compatibility.StudyMode.lesson,
        date: DateTime.utc(2026, 11, 9),
        questionsAnswered: 0,
        correctCount: 0,
        lessonCompleted: true,
        studyTimeSeconds: 90,
      );

      // This assignment must compile without any conversion or duplicate DTO.
      final canonical.UserProgress sameInstance = progress;
      const canonical.StudyMode sameMode = compatibility.StudyMode.lesson;
      expect(identical(progress, sameInstance), isTrue);
      expect(sameMode, canonical.StudyMode.lesson);
      expect(sameInstance.lessonId, 'prog_01_variables');
    });

    test('legacy Hive-style model retains local-only identity and sync state', () {
      final compatibility.UserProgress cached = compatibility.UserProgress(
        id: 'user_lesson_123',
        userId: 'user',
        lessonId: 'legacy-lesson',
        studyMode: compatibility.StudyMode.flashcard,
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
