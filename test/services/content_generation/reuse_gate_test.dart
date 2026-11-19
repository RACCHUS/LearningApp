import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_generation/content_resolution_decision.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/reuse_gate.dart';

const lessons = [
  ReuseSource(
    kind: ReuseSourceKind.lesson,
    id: 'l1',
    title: 'Excel percentages: format and percent change',
    text: 'Format cells as percentages and compute percent change.',
    tags: ['excel'],
  ),
  ReuseSource(
    kind: ReuseSourceKind.lesson,
    id: 'l2',
    title: 'Photosynthesis basics',
    tags: ['biology'],
  ),
  ReuseSource(
    kind: ReuseSourceKind.bridge,
    id: 'bridge-fraction-decimal',
    title: 'Fractions, decimals and percents',
    text: 'Convert fractions to decimals. fraction decimal percent',
  ),
];

ReuseGateResult gate(String subject, List<String> ideas) =>
    ReuseGate.evaluate(subject: subject, ideas: ideas, sources: lessons);

void main() {
  test('words drop stop words and plural s', () {
    expect(ReuseGate.words('How to use the Percentages!'), {'percentage'});
    expect(ReuseGate.words('class basics'), {'class'});
  });

  test('everything covered by one lesson: reuse, naming that lesson', () {
    final r = gate('Excel', ['Percent change', 'Percentage format']);
    expect(r.decision.kind, ContentResolutionKind.exactReuse);
    expect(r.decision.eligibleAssetRef, 'lesson:l1');
    expect(r.decision.createsGenerationJob, isFalse);
    expect(r.candidates.first.source.id, 'l1');
    expect(r.suggestsReuse, isTrue);
  });

  test('partly covered: adapt, with the covered ideas', () {
    final r = gate('Excel', ['Percent change', 'Pivot tables']);
    expect(r.decision.kind, ContentResolutionKind.adapt);
    expect(r.coveredIdeas, {0});
  });

  test('nothing relevant: generate', () {
    final r = gate('Excel', ['Pivot tables', 'Macros']);
    expect(r.decision.kind, ContentResolutionKind.generate);
    expect(r.candidates, isEmpty);
    expect(r.suggestsReuse, isFalse);
  });

  test('off-subject sources need every word of an idea', () {
    // "biology" lesson mentions photosynthesis but the subject is Excel.
    expect(
      gate('Excel', ['Photosynthesis']).decision.kind,
      ContentResolutionKind.exactReuse,
      reason: 'all idea words match, so it still counts',
    );
    expect(
      gate('Excel', ['Photosynthesis light reactions']).decision.kind,
      ContentResolutionKind.generate,
      reason: 'partial overlap off-subject is not enough',
    );
  });

  test('a Bridge can cover an idea; lessons rank first on ties', () {
    final r = gate('Math', ['Fractions to decimals']);
    expect(r.candidates.first.source.kind, ReuseSourceKind.bridge);
    expect(r.decision.kind, ContentResolutionKind.exactReuse);
  });

  test('the decision is saved with the job and read back', () {
    final session = ManualJobSession(
      ManualJob.plan(
        ManualJobRequest(subject: 'Excel', concepts: ['Pivot tables']),
      ),
      resolution: const ContentResolutionDecision(
        kind: ContentResolutionKind.generate,
        reason: 'Learner chose to make their own version.',
        eligibleAssetRef: 'lesson:l1',
      ),
    );
    final back = ManualJobSession.fromJson(
      jsonDecode(jsonEncode(session.toJson())),
    )!;
    expect(back.resolution!.kind, ContentResolutionKind.generate);
    expect(back.resolution!.eligibleAssetRef, 'lesson:l1');

    final json = session.toJson()..['resolution'] = {'kind': 'bogus'};
    final tolerant = ManualJobSession.fromJson(jsonDecode(jsonEncode(json)))!;
    expect(tolerant.resolution, isNull, reason: 'an audit note never blocks');
    expect(tolerant.job.request.subject, 'Excel');
  });
}
