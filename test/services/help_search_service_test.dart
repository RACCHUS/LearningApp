import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/data/help_topics.dart';
import 'package:learning_pwa/services/help_search_service.dart';

void main() {
  const service = HelpSearchService();

  String firstTitle(String query) => service.search(helpTopics, query).first.title;

  test('timer aliases find Study timer & breaks', () {
    expect(firstTitle('timer'), 'Study timer & breaks');
    expect(firstTitle('pomodoro'), 'Study timer & breaks');
    expect(firstTitle('break'), 'Study timer & breaks');
  });

  test('goal finds Daily study goal', () {
    final results = service.search(helpTopics, 'goal');
    expect(results.map((topic) => topic.title), contains('Daily study goal'));
  });

  test('batch finds Cards per study session', () {
    expect(firstTitle('batch'), 'Cards per study session');
  });

  test('retention finds Completion vs retention', () {
    expect(firstTitle('retention'), 'Completion vs retention');
  });

  test('mock exam finds Mock exams', () {
    expect(firstTitle('mock exam'), 'Mock exams');
  });

  test('search is case and punctuation insensitive', () {
    expect(firstTitle('POMODORO!'), 'Study timer & breaks');
  });

  test('nonsense query returns no results', () {
    expect(service.search(helpTopics, 'xyzzy-no-such-help-topic'), isEmpty);
  });

  test('empty query preserves catalog order', () {
    expect(service.search(helpTopics, ''), helpTopics);
  });
}
