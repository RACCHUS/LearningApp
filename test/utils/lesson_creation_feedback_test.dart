import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/utils/lesson_creation_feedback.dart';

void main() {
  test(
    'failed curriculum binding is reported separately from lesson creation',
    () {
      final message = lessonCreationFeedback(
        lessonTitle: 'Subnetting',
        nodeId: 'node-1',
        nodeTitle: 'Networks',
        isBound: false,
      );

      expect(message, contains("couldn't attach it to Networks"));
      expect(message, contains('Find it in your lessons'));
      expect(message, isNot(contains('created and bound')));
    },
  );

  test('personal lesson without a node is not described as a binding', () {
    final message = lessonCreationFeedback(
      lessonTitle: 'Subnetting',
      nodeTitle: 'Networks',
      isBound: false,
    );

    expect(message, 'Personal study lesson "Subnetting" created for Networks.');
  });
}
