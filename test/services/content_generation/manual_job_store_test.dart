import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/manual_job_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

ManualJobSession session() {
  final job = ManualJob.plan(
    ManualJobRequest(
      subject: 'Percentages',
      concepts: ['Percent change'],
      questionsPerConcept: 1,
      includeTerms: false,
    ),
    random: Random(3),
  );
  return ManualJobSession(job)..applyPaste(
    jsonEncode({
      'schema': 'la-gen/1.1',
      'job': job.plan.jobCode,
      'items': [
        {
          'slot': 'S1',
          'kind': 'explanation',
          'concept': 'C1',
          'title': 'Change',
          'text': 'Compare with the start.',
        },
        {
          'slot': 'S2',
          'kind': 'mcq',
          'concept': 'C1',
          'stem': '100 to 120?',
          'options': ['10%', '20%', '25%'],
          'answer': 'B',
        },
      ],
    }),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('session round-trips through JSON and is re-validated', () {
    final s = session();
    final back = ManualJobSession.fromJson(jsonDecode(jsonEncode(s.toJson())))!;
    expect(back.job.plan.jobCode, s.job.plan.jobCode);
    expect(back.accepted.keys, ['S1', 'S2']);
    expect(back.accepted['S2']!.correctIndex, 1);
    expect(back.isComplete, isTrue);
  });

  test('a tampered save loses items instead of adding unchecked ones', () {
    final json = session().toJson();
    final pkg = jsonDecode(json['accepted']! as String) as Map;
    ((pkg['items'] as List)[1] as Map)['answer'] = 'Z';
    json['accepted'] = jsonEncode(pkg);
    final back = ManualJobSession.fromJson(json)!;
    expect(back.accepted.keys, ['S1']);
  });

  test('unusable saves are ignored', () {
    expect(ManualJobSession.fromJson({'version': 99}), isNull);
    final bad = session().toJson()..['job_code'] = 'nope';
    expect(ManualJobSession.fromJson(bad), isNull);
  });

  test('save, load and clear for one owner', () async {
    final store = ManualJobStore(editorId: 'tab-1');
    expect(await store.save('user-a', session()), ManualSaveOutcome.saved);
    final loaded = await ManualJobStore(editorId: 'tab-1').load('user-a');
    expect(loaded!.session.accepted.length, 2);
    expect(await store.load('user-b'), isNull, reason: 'owner isolation');
    await store.clear('user-a');
    expect(await store.load('user-a'), isNull);
  });

  test('a second tab never overwrites without loading first', () async {
    final tab1 = ManualJobStore(editorId: 'tab-1');
    final tab2 = ManualJobStore(editorId: 'tab-2');
    expect(await tab1.save('u', session()), ManualSaveOutcome.saved);
    expect(await tab2.save('u', session()), ManualSaveOutcome.conflict);

    // After tab2 loads (resumes), it may save; then tab1 is the stale one.
    await tab2.load('u');
    expect(await tab2.save('u', session()), ManualSaveOutcome.saved);
    expect(await tab1.save('u', session()), ManualSaveOutcome.conflict);
  });

  test('corrupt stored data is ignored', () async {
    SharedPreferences.setMockInitialValues({
      ManualJobStore.keyFor('u'): '{not json',
    });
    expect(await ManualJobStore().load('u'), isNull);
  });
}
