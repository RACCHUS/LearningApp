import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/audio_lesson/lesson_state_manager.dart';

void main() {
  group('LessonStateManager', () {
    late LessonStateManager manager;

    setUp(() {
      manager = LessonStateManager();
    });

    group('State transitions', () {
      test('updateState() transitions from idle to reading', () {
        manager.updateState(AudioLessonState.reading);

        expect(manager.currentState, AudioLessonState.reading);
      });

      test('updateState() transitions from reading to paused', () {
        manager.updateState(AudioLessonState.reading);
        manager.updateState(AudioLessonState.paused);

        expect(manager.currentState, AudioLessonState.paused);
      });

      test('updateState() transitions from reading to waitingForVoice', () {
        manager.updateState(AudioLessonState.reading);
        manager.updateState(AudioLessonState.waitingForVoice);

        expect(manager.currentState, AudioLessonState.waitingForVoice);
      });

      test('updateState() transitions from waitingForVoice to processing', () {
        manager.updateState(AudioLessonState.reading);
        manager.updateState(AudioLessonState.waitingForVoice);
        manager.updateState(AudioLessonState.processing);

        expect(manager.currentState, AudioLessonState.processing);
      });

      test('updateState() transitions to error from any state', () {
        manager.updateState(AudioLessonState.reading);
        manager.updateState(AudioLessonState.error);

        expect(manager.currentState, AudioLessonState.error);
      });

      test('updateState() transitions to completed from reading', () {
        manager.updateState(AudioLessonState.reading);
        manager.updateState(AudioLessonState.completed);

        expect(manager.currentState, AudioLessonState.completed);
      });
    });

    group('Invalid transitions', () {
      test('updateState() rejects invalid idle to paused transition', () {
        manager.updateState(AudioLessonState.paused);

        expect(manager.currentState, AudioLessonState.idle);
      });

      test('updateState() rejects paused to waitingForVoice', () {
        manager.updateState(AudioLessonState.reading);
        manager.updateState(AudioLessonState.paused);
        manager.updateState(AudioLessonState.waitingForVoice);

        expect(manager.currentState, AudioLessonState.paused);
      });

      test('updateState() rejects completed to reading', () {
        manager.updateState(AudioLessonState.reading);
        manager.updateState(AudioLessonState.completed);
        manager.updateState(AudioLessonState.reading);

        expect(manager.currentState, AudioLessonState.completed);
      });
    });

    group('Same-state updates', () {
      test('updateState() ignores same-state updates', () {
        manager.updateState(AudioLessonState.reading);
        
        final statesBefore = manager.currentState;
        manager.updateState(AudioLessonState.reading);
        final statesAfter = manager.currentState;

        expect(statesBefore, statesAfter);
      });
    });

    group('State stream', () {
      test('stateStream emits on valid transitions', () async {
        final states = <AudioLessonState>[];
        final subscription = manager.stateStream.listen(states.add);

        manager.updateState(AudioLessonState.reading);
        manager.updateState(AudioLessonState.paused);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(states, contains(AudioLessonState.reading));
        expect(states, contains(AudioLessonState.paused));

        await subscription.cancel();
      });

      test('stateStream does not emit on invalid transitions', () async {
        final states = <AudioLessonState>[];
        final subscription = manager.stateStream.listen(states.add);

        manager.updateState(AudioLessonState.paused); // Invalid from idle

        await Future.delayed(const Duration(milliseconds: 50));

        expect(states, isEmpty);

        await subscription.cancel();
      });

      test('stateStream does not emit on same-state updates', () async {
        manager.updateState(AudioLessonState.reading);
        
        final states = <AudioLessonState>[];
        final subscription = manager.stateStream.listen(states.add);

        manager.updateState(AudioLessonState.reading); // Same state

        await Future.delayed(const Duration(milliseconds: 50));

        expect(states, isEmpty);

        await subscription.cancel();
      });
    });

    group('Action notifications', () {
      test('notifyAction() emits to actionStream', () async {
        final actions = <LessonFlowAction>[];
        final subscription = manager.actionStream.listen(actions.add);

        manager.notifyAction(LessonFlowAction.next);
        manager.notifyAction(LessonFlowAction.pause);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(actions, contains(LessonFlowAction.next));
        expect(actions, contains(LessonFlowAction.pause));

        await subscription.cancel();
      });

      test('notifyAction() works for all action types', () async {
        final actions = <LessonFlowAction>[];
        final subscription = manager.actionStream.listen(actions.add);

        manager.notifyAction(LessonFlowAction.next);
        manager.notifyAction(LessonFlowAction.previous);
        manager.notifyAction(LessonFlowAction.repeat);
        manager.notifyAction(LessonFlowAction.pause);
        manager.notifyAction(LessonFlowAction.resume);
        manager.notifyAction(LessonFlowAction.restart);
        manager.notifyAction(LessonFlowAction.complete);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(actions.length, 7);

        await subscription.cancel();
      });
    });

    group('Complex state flows', () {
      test('supports full lesson flow: idle -> reading -> paused -> reading -> completed',
          () {
        manager.updateState(AudioLessonState.reading);
        expect(manager.currentState, AudioLessonState.reading);

        manager.updateState(AudioLessonState.paused);
        expect(manager.currentState, AudioLessonState.paused);

        manager.updateState(AudioLessonState.reading);
        expect(manager.currentState, AudioLessonState.reading);

        manager.updateState(AudioLessonState.completed);
        expect(manager.currentState, AudioLessonState.completed);
      });

      test('supports voice interaction flow: reading -> waiting -> processing -> reading',
          () {
        manager.updateState(AudioLessonState.reading);
        manager.updateState(AudioLessonState.waitingForVoice);
        expect(manager.currentState, AudioLessonState.waitingForVoice);

        manager.updateState(AudioLessonState.processing);
        expect(manager.currentState, AudioLessonState.processing);

        manager.updateState(AudioLessonState.reading);
        expect(manager.currentState, AudioLessonState.reading);
      });

      test('can recover from error state', () {
        manager.updateState(AudioLessonState.reading);
        manager.updateState(AudioLessonState.error);
        expect(manager.currentState, AudioLessonState.error);

        manager.updateState(AudioLessonState.idle);
        expect(manager.currentState, AudioLessonState.idle);

        manager.updateState(AudioLessonState.reading);
        expect(manager.currentState, AudioLessonState.reading);
      });
    });

    group('Initial state', () {
      test('starts in idle state', () {
        expect(manager.currentState, AudioLessonState.idle);
      });
    });
  });
}
