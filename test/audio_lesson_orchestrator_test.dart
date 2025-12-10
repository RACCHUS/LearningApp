import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/audio_lesson_orchestrator.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';

void main() {
  // Helper to create test content with all required fields
  ConceptContent createTestConcept(String id, String text, {String? example}) {
    return ConceptContent(
      id: id,
      lessonId: 'test_lesson',
      order: 0,
      conceptText: text,
      exampleText: example,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  TermContent createTestTerm(String id, String term, String definition, {String? example}) {
    return TermContent(
      id: id,
      lessonId: 'test_lesson',
      order: 0,
      term: term,
      definition: definition,
      example: example,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  QuestionContent createTestQuestion(String id, String question, List<String> options, int correctAnswer) {
    return QuestionContent(
      id: id,
      lessonId: 'test_lesson',
      order: 0,
      questionText: question,
      options: options,
      correctAnswer: correctAnswer,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('AudioLessonOrchestrator - Initialization & Setup', () {
    late AudioLessonOrchestrator orchestrator;

    setUp(() {
      orchestrator = AudioLessonOrchestrator();
    });

    test('should initialize successfully', () async {
      await orchestrator.initialize();

      expect(orchestrator.isActive, isFalse);
      expect(orchestrator.currentState, AudioLessonState.idle);
      expect(orchestrator.currentIndex, 0);
      expect(orchestrator.totalContent, 0);
    });

    test('should accept voice service injection', () {
      // Voice service injection is tested through integration
      // This test verifies the method exists and doesn't crash
      expect(() => orchestrator.updateSettings(const AudioLessonSettings()), returnsNormally);
    });

    test('should update settings correctly', () {
      final newSettings = const AudioLessonSettings(
        handsFreeModeEnabled: true,
        voiceNavigationEnabled: true,
      );

      orchestrator.updateSettings(newSettings);
      
      expect(orchestrator.settings, equals(newSettings));
    });

    test('should start with correct initial state', () {
      expect(orchestrator.currentState, AudioLessonState.idle);
      expect(orchestrator.isActive, isFalse);
      expect(orchestrator.isFirstContent, isTrue);
      expect(orchestrator.isLastContent, isTrue); // No content loaded yet
    });
  });

  group('AudioLessonOrchestrator - Lesson Lifecycle', () {
    late AudioLessonOrchestrator orchestrator;
    late List<LessonContent> testContent;

    setUp(() {
      orchestrator = AudioLessonOrchestrator();
      
      // Create test content
      testContent = [
        createTestConcept('1', 'First concept', example: 'First example'),
        createTestConcept('2', 'Second concept', example: 'Second example'),
        createTestConcept('3', 'Third concept', example: 'Third example'),
      ];
    });

    tearDown(() async {
      // Clean up orchestrator state after each test
      await orchestrator.stopLesson();
    });

    test('should start lesson with valid content', () async {
      await orchestrator.startLesson(testContent);

      expect(orchestrator.isActive, isTrue);
      expect(orchestrator.totalContent, equals(3));
      expect(orchestrator.currentIndex, equals(0));
      expect(orchestrator.currentState, isNot(AudioLessonState.idle));
    });

    test('should not start lesson with empty content', () async {
      await orchestrator.startLesson([]);

      expect(orchestrator.isActive, isFalse);
      expect(orchestrator.totalContent, equals(0));
    });

    test('should start lesson at specific index', () async {
      await orchestrator.startLesson(testContent, startIndex: 1);

      expect(orchestrator.currentIndex, equals(1));
    });

    test('should clamp invalid start index', () async {
      await orchestrator.startLesson(testContent, startIndex: 10);

      expect(orchestrator.currentIndex, equals(2)); // Last valid index
    });

    test('should stop lesson correctly', () async {
      await orchestrator.startLesson(testContent);
      expect(orchestrator.isActive, isTrue);

      await orchestrator.stopLesson();

      expect(orchestrator.isActive, isFalse);
      expect(orchestrator.currentState, AudioLessonState.idle);
    });

    test('should pause lesson', () async {
      await orchestrator.startLesson(testContent);
      
      await orchestrator.pauseLesson();

      expect(orchestrator.currentState, AudioLessonState.paused);
      expect(orchestrator.isActive, isTrue); // Still active, just paused
    });

    test('should resume paused lesson', () async {
      await orchestrator.startLesson(testContent);
      await orchestrator.pauseLesson();
      
      await orchestrator.resumeLesson();

      expect(orchestrator.currentState, isNot(AudioLessonState.paused));
      expect(orchestrator.isActive, isTrue);
    });

    test('should not resume if not paused', () async {
      await orchestrator.startLesson(testContent);
      final stateBefore = orchestrator.currentState;
      
      await orchestrator.resumeLesson();
      
      // State should not change if not paused
      expect(orchestrator.currentState, stateBefore);
    });

    test('should track lesson completion', () async {
      await orchestrator.startLesson(testContent);
      
      // Navigate to last content
      await orchestrator.nextContent();
      await orchestrator.nextContent();
      
      // Should be at last content
      expect(orchestrator.isLastContent, isTrue);
      
      // Next should complete the lesson
      await orchestrator.nextContent();
      
      expect(orchestrator.currentState, AudioLessonState.completed);
      expect(orchestrator.isActive, isFalse);
    });
  });

  group('AudioLessonOrchestrator - Content Navigation', () {
    late AudioLessonOrchestrator orchestrator;
    late List<LessonContent> testContent;

    setUp(() {
      orchestrator = AudioLessonOrchestrator();
      
      testContent = List.generate(5, (index) => createTestConcept(
        'concept_$index',
        'Concept $index',
      ));
    });

    tearDown(() async {
      await orchestrator.stopLesson();
    });

    test('should navigate to next content', () async {
      await orchestrator.startLesson(testContent);
      expect(orchestrator.currentIndex, equals(0));

      await orchestrator.nextContent();

      expect(orchestrator.currentIndex, equals(1));
    });

    test('should navigate to previous content', () async {
      await orchestrator.startLesson(testContent, startIndex: 2);
      expect(orchestrator.currentIndex, equals(2));

      await orchestrator.previousContent();

      expect(orchestrator.currentIndex, equals(1));
    });

    test('should not go before first content', () async {
      await orchestrator.startLesson(testContent);
      expect(orchestrator.currentIndex, equals(0));

      await orchestrator.previousContent();

      expect(orchestrator.currentIndex, equals(0)); // Should stay at 0
    });

    test('should repeat current content', () async {
      await orchestrator.startLesson(testContent, startIndex: 2);
      
      await orchestrator.repeatContent();

      expect(orchestrator.currentIndex, equals(2)); // Should stay at same index
      expect(orchestrator.isActive, isTrue);
    });

    test('should track first content correctly', () async {
      await orchestrator.startLesson(testContent);
      
      expect(orchestrator.isFirstContent, isTrue);
      
      await orchestrator.nextContent();
      
      expect(orchestrator.isFirstContent, isFalse);
    });

    test('should track last content correctly', () async {
      await orchestrator.startLesson(testContent);
      
      expect(orchestrator.isLastContent, isFalse);
      
      // Navigate to last content
      for (int i = 0; i < testContent.length - 1; i++) {
        await orchestrator.nextContent();
      }
      
      expect(orchestrator.isLastContent, isTrue);
    });

    test('should emit progress updates', () async {
      await orchestrator.startLesson(testContent);
      
      final progressUpdates = <int>[];
      orchestrator.progressStream.listen((progress) {
        progressUpdates.add(progress);
      });

      await orchestrator.nextContent();
      await orchestrator.nextContent();

      // Wait for stream updates
      await Future.delayed(const Duration(milliseconds: 100));

      expect(progressUpdates, contains(1));
      expect(progressUpdates, contains(2));
    });

    test('should emit state changes', () async {
      final stateChanges = <AudioLessonState>[];
      orchestrator.stateStream.listen((state) {
        stateChanges.add(state);
      });
      await Future.microtask(() {}); // Ensure listener is set up

      await orchestrator.startLesson(testContent);
      await Future.delayed(const Duration(milliseconds: 50));
      
      await orchestrator.pauseLesson();
      await Future.delayed(const Duration(milliseconds: 50));
      
      await orchestrator.stopLesson();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(stateChanges, contains(AudioLessonState.paused));
      expect(stateChanges, contains(AudioLessonState.idle));
    });
  });

  group('AudioLessonOrchestrator - Voice Command Integration', () {
    late AudioLessonOrchestrator orchestrator;
    late List<LessonContent> testContent;

    setUp(() {
      orchestrator = AudioLessonOrchestrator();
      
      testContent = List.generate(3, (index) => createTestConcept(
        'concept_$index',
        'Concept $index',
      ));
    });

    test('should simulate next voice command', () async {
      await orchestrator.startLesson(testContent);
      expect(orchestrator.currentIndex, equals(0));

      await orchestrator.simulateVoiceCommand('next');

      expect(orchestrator.currentIndex, equals(1));
    });

    test('should simulate previous voice command', () async {
      await orchestrator.startLesson(testContent, startIndex: 1);

      await orchestrator.simulateVoiceCommand('previous');

      expect(orchestrator.currentIndex, equals(0));
    });

    test('should simulate repeat voice command', () async {
      await orchestrator.startLesson(testContent, startIndex: 1);

      await orchestrator.simulateVoiceCommand('repeat');

      expect(orchestrator.currentIndex, equals(1));
    });

    test('should simulate pause voice command', () async {
      await orchestrator.startLesson(testContent);

      await orchestrator.simulateVoiceCommand('pause');

      expect(orchestrator.currentState, AudioLessonState.paused);
    });

    test('should simulate resume voice command', () async {
      await orchestrator.startLesson(testContent);
      await orchestrator.pauseLesson();

      await orchestrator.simulateVoiceCommand('resume');

      expect(orchestrator.currentState, isNot(AudioLessonState.paused));
    });

    test('should simulate stop voice command', () async {
      await orchestrator.startLesson(testContent);

      await orchestrator.simulateVoiceCommand('stop');

      expect(orchestrator.isActive, isFalse);
      expect(orchestrator.currentState, AudioLessonState.idle);
    });

    test('should handle voice commands case-insensitively', () async {
      await orchestrator.startLesson(testContent);

      await orchestrator.simulateVoiceCommand('NEXT');
      expect(orchestrator.currentIndex, equals(1));

      await orchestrator.simulateVoiceCommand('Previous');
      expect(orchestrator.currentIndex, equals(0));
    });
  });

  group('AudioLessonOrchestrator - Different Content Types', () {
    late AudioLessonOrchestrator orchestrator;

    setUp(() {
      orchestrator = AudioLessonOrchestrator();
    });

    tearDown(() async {
      await orchestrator.stopLesson();
    });

    test('should handle concept content', () async {
      final content = [
        createTestConcept('1', 'Test concept', example: 'Test example'),
      ];

      await orchestrator.startLesson(content);

      expect(orchestrator.isActive, isTrue);
      expect(orchestrator.totalContent, equals(1));
    });

    test('should handle term content', () async {
      final content = [
        createTestTerm('1', 'Test term', 'Test definition', example: 'Test example'),
      ];

      await orchestrator.startLesson(content);

      expect(orchestrator.isActive, isTrue);
      expect(orchestrator.totalContent, equals(1));
    });

    test('should handle question content', () async {
      final content = [
        createTestQuestion('1', 'What is 2+2?', ['2', '3', '4', '5'], 2),
      ];

      await orchestrator.startLesson(content);

      expect(orchestrator.isActive, isTrue);
      expect(orchestrator.totalContent, equals(1));
    });

    test('should handle mixed content types', () async {
      final content = [
        createTestConcept('1', 'Concept'),
        createTestTerm('2', 'Term', 'Definition'),
        createTestQuestion('3', 'Question?', ['A', 'B'], 0),
      ];

      await orchestrator.startLesson(content);

      expect(orchestrator.totalContent, equals(3));
      
      // Navigate through all content types
      await orchestrator.nextContent();
      expect(orchestrator.currentIndex, equals(1));
      
      await orchestrator.nextContent();
      expect(orchestrator.currentIndex, equals(2));
    });
  });

  group('AudioLessonOrchestrator - Edge Cases & Error Handling', () {
    late AudioLessonOrchestrator orchestrator;

    setUp(() {
      orchestrator = AudioLessonOrchestrator();
    });

    tearDown(() async {
      // Reset orchestrator state between tests
      await orchestrator.stopLesson();
    });

    test('should handle empty content list gracefully', () async {
      await orchestrator.startLesson([]);

      expect(orchestrator.isActive, isFalse);
      expect(orchestrator.totalContent, equals(0));
    });

    test('should handle negative start index', () async {
      final content = [
        createTestConcept('1', 'Test'),
      ];

      await orchestrator.startLesson(content, startIndex: -1);

      expect(orchestrator.currentIndex, equals(0)); // Should clamp to 0
    });

    test('should handle operations when inactive', () async {
      // Try operations without starting lesson
      await orchestrator.nextContent();
      await orchestrator.previousContent();
      await orchestrator.pauseLesson();

      expect(orchestrator.isActive, isFalse);
      expect(orchestrator.currentIndex, equals(0));
    });

    test('should handle stopping already stopped lesson', () async {
      await orchestrator.stopLesson();
      await orchestrator.stopLesson(); // Stop again

      expect(orchestrator.isActive, isFalse);
      expect(orchestrator.currentState, AudioLessonState.idle);
    });

    test('should handle rapid state transitions', () async {
      final content = [
        createTestConcept('1', 'Test'),
      ];

      await orchestrator.startLesson(content);
      await orchestrator.pauseLesson();
      await orchestrator.resumeLesson();
      await orchestrator.pauseLesson();
      await orchestrator.stopLesson();

      expect(orchestrator.isActive, isFalse);
    });

    test('should handle single content lesson', () async {
      final content = [
        createTestConcept('1', 'Only one'),
      ];

      await orchestrator.startLesson(content);

      expect(orchestrator.isFirstContent, isTrue);
      expect(orchestrator.isLastContent, isTrue);
      
      // Next should complete
      await orchestrator.nextContent();
      expect(orchestrator.currentState, AudioLessonState.completed);
    });

    test('should maintain state consistency after errors', () async {
      final content = [
        createTestConcept('1', 'Test'),
      ];

      await orchestrator.startLesson(content);
      
      // Try to go before first
      await orchestrator.previousContent();
      
      // Should still be active and at first position
      expect(orchestrator.isActive, isTrue);
      expect(orchestrator.currentIndex, equals(0));
    });
  });

  group('AudioLessonOrchestrator - Settings Integration', () {
    late AudioLessonOrchestrator orchestrator;

    setUp(() {
      orchestrator = AudioLessonOrchestrator();
    });

    test('should respect hands-free mode setting', () {
      final settings = const AudioLessonSettings(
        handsFreeModeEnabled: true,
      );

      orchestrator.updateSettings(settings);

      expect(orchestrator.settings.handsFreeModeEnabled, isTrue);
    });

    test('should respect voice navigation setting', () {
      final settings = const AudioLessonSettings(
        voiceNavigationEnabled: true,
      );

      orchestrator.updateSettings(settings);

      expect(orchestrator.settings.voiceNavigationEnabled, isTrue);
    });

    test('should respect auto-progression setting', () {
      final settings = const AudioLessonSettings(
        autoProgressAfterReading: true,
        autoProgressDelay: Duration(seconds: 2),
      );

      orchestrator.updateSettings(settings);

      expect(orchestrator.settings.autoProgressAfterReading, isTrue);
      expect(orchestrator.settings.autoProgressDelay, equals(const Duration(seconds: 2)));
    });

    test('should respect confirmations setting', () {
      final settings = const AudioLessonSettings(
        confirmationsEnabled: true,
      );

      orchestrator.updateSettings(settings);

      expect(orchestrator.settings.confirmationsEnabled, isTrue);
    });

    test('should allow settings updates during lesson', () async {
      final content = [
        createTestConcept('1', 'Test'),
      ];

      await orchestrator.startLesson(content);

      final newSettings = const AudioLessonSettings(
        handsFreeModeEnabled: true,
      );

      orchestrator.updateSettings(newSettings);

      expect(orchestrator.settings.handsFreeModeEnabled, isTrue);
      expect(orchestrator.isActive, isTrue); // Should still be active
    });
  });

  group('AudioLessonOrchestrator - Stream Events', () {
    late AudioLessonOrchestrator orchestrator;

    setUp(() {
      orchestrator = AudioLessonOrchestrator();
    });

    test('should emit action events', () async {
      final actions = <LessonFlowAction>[];
      orchestrator.actionStream.listen((action) {
        actions.add(action);
      });

      final content = [
        createTestConcept('1', 'Test'),
        createTestConcept('2', 'Test2'),
      ];

      await orchestrator.startLesson(content);
      await Future.delayed(const Duration(milliseconds: 50));
      
      await orchestrator.nextContent(); // Should emit next action
      await Future.delayed(const Duration(milliseconds: 50));
      
      await orchestrator.nextContent(); // Should complete since at last item
      await Future.delayed(const Duration(milliseconds: 50));

      expect(actions, contains(LessonFlowAction.next));
      expect(actions, contains(LessonFlowAction.complete));
    });

    test('should emit state changes on lifecycle events', () async {
      final states = <AudioLessonState>[];
      orchestrator.stateStream.listen((state) {
        states.add(state);
      });
      await Future.microtask(() {}); // Ensure listener is set up

      final content = [
        createTestConcept('1', 'Test'),
      ];

      await orchestrator.startLesson(content);
      await Future.delayed(const Duration(milliseconds: 50));
      
      await orchestrator.pauseLesson();
      await Future.delayed(const Duration(milliseconds: 50));
      
      await orchestrator.resumeLesson();
      await Future.delayed(const Duration(milliseconds: 50));
      
      await orchestrator.stopLesson();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(states.length, greaterThan(0));
      expect(states, contains(AudioLessonState.paused));
      expect(states, contains(AudioLessonState.idle));
    });

    test('should allow multiple stream listeners', () async {
      final progressListener1 = <int>[];
      final progressListener2 = <int>[];

      orchestrator.progressStream.listen((p) => progressListener1.add(p));
      orchestrator.progressStream.listen((p) => progressListener2.add(p));

      final content = List.generate(3, (i) => 
        createTestConcept('$i', 'Test $i'),
      );

      await orchestrator.startLesson(content);
      await orchestrator.nextContent();

      await Future.delayed(const Duration(milliseconds: 100));

      expect(progressListener1, isNotEmpty);
      expect(progressListener2, isNotEmpty);
    });
  });
}
