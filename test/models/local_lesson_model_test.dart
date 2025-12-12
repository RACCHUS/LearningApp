import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/local_lesson.dart';

void main() {
  group('LocalLesson Model Tests', () {
    final testLesson = LocalLesson(
      id: 'local_001',
      title: 'Local Test Lesson',
      description: 'Local Description',
      tags: ['local', 'test'],
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 2),
      userId: 'user_001',
    );

    test('should create local lesson with all fields', () {
      expect(testLesson.id, 'local_001');
      expect(testLesson.title, 'Local Test Lesson');
      expect(testLesson.description, 'Local Description');
      expect(testLesson.tags, ['local', 'test']);
      expect(testLesson.userId, 'user_001');
      expect(testLesson.isLocal, true);
    });

    test('should serialize to JSON', () {
      final json = testLesson.toJson();
      
      expect(json['id'], 'local_001');
      expect(json['title'], 'Local Test Lesson');
      expect(json['description'], 'Local Description');
      expect(json['tags'], ['local', 'test']);
      expect(json['userId'], 'user_001');
      expect(json['isLocal'], true);
      expect(json['createdAt'], isA<String>());
      expect(json['updatedAt'], isA<String>());
    });

    test('should deserialize from JSON', () {
      final json = {
        'id': 'local_002',
        'title': 'Another Local Lesson',
        'description': 'Another Description',
        'tags': ['tag1'],
        'createdAt': '2023-01-01T00:00:00.000Z',
        'updatedAt': '2023-01-02T00:00:00.000Z',
        'userId': 'user_002',
        'isLocal': true,
      };
      
      final lesson = LocalLesson.fromJson(json);
      
      expect(lesson.id, 'local_002');
      expect(lesson.title, 'Another Local Lesson');
      expect(lesson.isLocal, true);
    });

    test('should create copy with modified fields', () {
      final modified = testLesson.copyWith(
        title: 'Modified Title',
        description: 'Modified Description',
      );
      
      expect(modified.title, 'Modified Title');
      expect(modified.description, 'Modified Description');
      expect(modified.id, testLesson.id); // Unchanged
      expect(modified.isLocal, testLesson.isLocal); // Unchanged
    });

    test('should handle equality correctly', () {
      final lesson1 = LocalLesson(
        id: 'same_id',
        title: 'Title',
        description: 'Desc',
        tags: [],
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 1),
        userId: 'user_001',
      );
      
      final lesson2 = LocalLesson(
        id: 'same_id',
        title: 'Title',
        description: 'Desc',
        tags: [],
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 1),
        userId: 'user_001',
      );
      
      expect(lesson1 == lesson2, true);
      expect(lesson1.hashCode == lesson2.hashCode, true);
    });
  });
}

