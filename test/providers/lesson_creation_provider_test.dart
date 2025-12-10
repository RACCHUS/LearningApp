import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/lesson_creation_provider.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/models/question_content.dart';

void main() {
  group('LessonCreationProvider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Initial State', () {
      test('should have correct default values', () {
        final state = container.read(lessonCreationProvider);

        expect(state.title, '');
        expect(state.description, '');
        expect(state.tags, isEmpty);
        expect(state.content, isEmpty);
        expect(state.isLoading, false);
        expect(state.error, null);
      });
    });

    group('updateTitle', () {
      test('should update title', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.updateTitle('Test Lesson');
        final state = container.read(lessonCreationProvider);

        expect(state.title, 'Test Lesson');
      });

      test('should update title multiple times', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.updateTitle('First Title');
        notifier.updateTitle('Second Title');
        final state = container.read(lessonCreationProvider);

        expect(state.title, 'Second Title');
      });

      test('should allow empty title', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.updateTitle('Some Title');
        notifier.updateTitle('');
        final state = container.read(lessonCreationProvider);

        expect(state.title, '');
      });
    });

    group('updateDescription', () {
      test('should update description', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.updateDescription('Test Description');
        final state = container.read(lessonCreationProvider);

        expect(state.description, 'Test Description');
      });

      test('should preserve other state when updating description', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.updateTitle('Title');
        notifier.updateDescription('Description');
        final state = container.read(lessonCreationProvider);

        expect(state.title, 'Title');
        expect(state.description, 'Description');
      });
    });

    group('Tag Management', () {
      test('should add tag', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.addTag('flutter');
        final state = container.read(lessonCreationProvider);

        expect(state.tags, ['flutter']);
      });

      test('should add multiple tags', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.addTag('flutter');
        notifier.addTag('dart');
        notifier.addTag('mobile');
        final state = container.read(lessonCreationProvider);

        expect(state.tags, ['flutter', 'dart', 'mobile']);
      });

      test('should not add duplicate tag', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.addTag('flutter');
        notifier.addTag('flutter');
        final state = container.read(lessonCreationProvider);

        expect(state.tags, ['flutter']);
      });

      test('should remove tag', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.addTag('flutter');
        notifier.addTag('dart');
        notifier.removeTag('flutter');
        final state = container.read(lessonCreationProvider);

        expect(state.tags, ['dart']);
      });

      test('should handle removing non-existent tag', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.addTag('flutter');
        notifier.removeTag('nonexistent');
        final state = container.read(lessonCreationProvider);

        expect(state.tags, ['flutter']);
      });
    });

    group('Content Management', () {
      test('should add content', () {
        final notifier = container.read(lessonCreationProvider.notifier);
        final content = TermContent(
          id: '1',
          lessonId: 'lesson-1',
          order: 0,
          term: 'Test Term',
          definition: 'Test Definition',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        notifier.addContent(content);
        final state = container.read(lessonCreationProvider);

        expect(state.content.length, 1);
        expect(state.content[0].id, '1');
      });

      test('should add multiple content items', () {
        final notifier = container.read(lessonCreationProvider.notifier);
        final content1 = TermContent(
          id: '1',
          lessonId: 'lesson-1',
          order: 0,
          term: 'Term 1',
          definition: 'Definition 1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final content2 = TermContent(
          id: '2',
          lessonId: 'lesson-1',
          order: 1,
          term: 'Term 2',
          definition: 'Definition 2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        notifier.addContent(content1);
        notifier.addContent(content2);
        final state = container.read(lessonCreationProvider);

        expect(state.content.length, 2);
        expect(state.content[0].id, '1');
        expect(state.content[1].id, '2');
      });

      test('should remove content by id', () {
        final notifier = container.read(lessonCreationProvider.notifier);
        final content1 = TermContent(
          id: '1',
          lessonId: 'lesson-1',
          order: 0,
          term: 'Term 1',
          definition: 'Definition 1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final content2 = TermContent(
          id: '2',
          lessonId: 'lesson-1',
          order: 1,
          term: 'Term 2',
          definition: 'Definition 2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        notifier.addContent(content1);
        notifier.addContent(content2);
        notifier.removeContent('1');
        final state = container.read(lessonCreationProvider);

        expect(state.content.length, 1);
        expect(state.content[0].id, '2');
      });

      test('should handle removing non-existent content', () {
        final notifier = container.read(lessonCreationProvider.notifier);
        final content = TermContent(
          id: '1',
          lessonId: 'lesson-1',
          order: 0,
          term: 'Test',
          definition: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        notifier.addContent(content);
        notifier.removeContent('nonexistent');
        final state = container.read(lessonCreationProvider);

        expect(state.content.length, 1);
      });

      test('should update existing content', () {
        final notifier = container.read(lessonCreationProvider.notifier);
        final originalContent = TermContent(
          id: '1',
          lessonId: 'lesson-1',
          order: 0,
          term: 'Original Term',
          definition: 'Original Definition',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final updatedContent = TermContent(
          id: '1',
          lessonId: 'lesson-1',
          order: 0,
          term: 'Updated Term',
          definition: 'Updated Definition',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        notifier.addContent(originalContent);
        notifier.updateContent('1', updatedContent);
        final state = container.read(lessonCreationProvider);

        expect(state.content.length, 1);
        final termContent = state.content[0] as TermContent;
        expect(termContent.term, 'Updated Term');
        expect(termContent.definition, 'Updated Definition');
      });

      test('should not update if content id not found', () {
        final notifier = container.read(lessonCreationProvider.notifier);
        final originalContent = TermContent(
          id: '1',
          lessonId: 'lesson-1',
          order: 0,
          term: 'Original',
          definition: 'Original',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final updatedContent = TermContent(
          id: '2',
          lessonId: 'lesson-1',
          order: 1,
          term: 'Updated',
          definition: 'Updated',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        notifier.addContent(originalContent);
        notifier.updateContent('nonexistent', updatedContent);
        final state = container.read(lessonCreationProvider);

        expect(state.content.length, 1);
        final termContent = state.content[0] as TermContent;
        expect(termContent.term, 'Original');
      });

      test('should add different content types', () {
        final notifier = container.read(lessonCreationProvider.notifier);
        final termContent = TermContent(
          id: '1',
          lessonId: 'lesson-1',
          order: 0,
          term: 'Term',
          definition: 'Definition',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final questionContent = QuestionContent(
          id: '2',
          lessonId: 'lesson-1',
          order: 1,
          questionText: 'Question',
          options: ['A', 'B', 'C', 'D'],
          correctAnswer: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        notifier.addContent(termContent);
        notifier.addContent(questionContent);
        final state = container.read(lessonCreationProvider);

        expect(state.content.length, 2);
        expect(state.content[0], isA<TermContent>());
        expect(state.content[1], isA<QuestionContent>());
      });
    });

    group('Loading and Error State', () {
      test('should set loading state', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.setLoading(true);
        var state = container.read(lessonCreationProvider);
        expect(state.isLoading, true);

        notifier.setLoading(false);
        state = container.read(lessonCreationProvider);
        expect(state.isLoading, false);
      });

      test('should set error message', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.setError('Test error');
        final state = container.read(lessonCreationProvider);

        expect(state.error, 'Test error');
      });

      test('should clear error message', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.setError('Test error');
        // Clear error by resetting to initial state or calling reset
        notifier.reset();
        final state = container.read(lessonCreationProvider);

        expect(state.error, null);
      });
    });

    group('Reset', () {
      test('should reset to initial state', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        // Modify state
        notifier.updateTitle('Title');
        notifier.updateDescription('Description');
        notifier.addTag('flutter');
        notifier.addContent(TermContent(
          id: '1',
          lessonId: 'lesson-1',
          order: 0,
          term: 'Term',
          definition: 'Definition',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        notifier.setLoading(true);
        notifier.setError('Error');

        // Reset
        notifier.reset();
        final state = container.read(lessonCreationProvider);

        expect(state.title, '');
        expect(state.description, '');
        expect(state.tags, isEmpty);
        expect(state.content, isEmpty);
        expect(state.isLoading, false);
        expect(state.error, null);
      });
    });

    group('State Preservation', () {
      test('should preserve unrelated state when updating title', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.updateDescription('Description');
        notifier.addTag('flutter');
        notifier.updateTitle('Title');
        final state = container.read(lessonCreationProvider);

        expect(state.description, 'Description');
        expect(state.tags, ['flutter']);
      });

      test('should preserve unrelated state when managing tags', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.updateTitle('Title');
        notifier.addContent(TermContent(
          id: '1',
          lessonId: 'lesson-1',
          order: 0,
          term: 'Term',
          definition: 'Definition',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        notifier.addTag('flutter');
        final state = container.read(lessonCreationProvider);

        expect(state.title, 'Title');
        expect(state.content.length, 1);
      });

      test('should preserve unrelated state when managing content', () {
        final notifier = container.read(lessonCreationProvider.notifier);

        notifier.updateTitle('Title');
        notifier.addTag('flutter');
        notifier.addContent(TermContent(
          id: '1',
          lessonId: 'lesson-1',
          order: 0,
          term: 'Term',
          definition: 'Definition',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        final state = container.read(lessonCreationProvider);

        expect(state.title, 'Title');
        expect(state.tags, ['flutter']);
      });
    });
  });
}
