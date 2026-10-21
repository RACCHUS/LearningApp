import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_account_export_service.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_progress_service.dart';
import 'package:learning_pwa/services/assessment/reference_practice_json_chunker.dart';

ReferenceDrillEvidence synthetic(int i) => ReferenceDrillEvidence(
  id:'e0000000-0000-4000-8000-${i.toString().padLeft(12,'0')}',
  ownerId:'synthetic-owner',
  manifestId:'33333333-3333-4333-8333-333333333333',
  attemptId:'a0000000-0000-4000-8000-${i.toString().padLeft(12,'0')}',
  itemId:'77777777-7777-4777-8777-777777777777',
  bindingId:'88888888-8888-4888-8888-888888888888',
  partKey:'project_management',
  examDate:'2027-06-01',
  itemRevision:1,
  answerRevision:1,
  step:'resource_choice',
  responded:true,
  appElapsedMs:900,
  selfReportedBookMs:null,
  startedAt:DateTime.utc(2027,3,1,0,0,0),
  completedAt:DateTime.utc(2027,3,1,0,0,1),
  recordedAt:DateTime.utc(2027,3,1).subtract(Duration(milliseconds:i)),
  isCorrect:null,
  scoringVersion:null,
  gradedAt:null,
);

void main() {
  test('Opt-in synthetic 50k-step export load and bounded serialization',
      () {
    const size=50000;
    final watch=Stopwatch()..start();
    final model=ReferencePracticeAccountExport(
      ownerId:'synthetic-owner',
      generatedAt:DateTime.utc(2027,3,1),
      snapshotConsistency:'pre-and-post-inventory-verified-not-atomic',
      events:List<ReferenceDrillEvidence>.generate(size,(i)=>synthetic(i+1)),
    );

    var parts=0;
    var totalBytes=0;
    for(final chunk in ReferencePracticeJsonChunker.encode(
      model.toJsonExportChunks(),
    )) {
      parts++;
      totalBytes+=chunk.length;
      expect(chunk.length,lessThanOrEqualTo(
          ReferencePracticeJsonChunker.defaultPartBytes));
    }
    watch.stop();
    expect(model.events.length,size);
    expect(totalBytes,greaterThan(size));
    expect(totalBytes,lessThanOrEqualTo(
        ReferencePracticeJsonChunker.defaultMaxBytes));
    // Diagnostics only: elapsed time/RSS are platform dependent and are NOT
    // strict performance gates. This fixture never reads real user data.
    // ignore: avoid_print
    print('EXM 50k synthetic export: $parts parts, $totalBytes bytes, '
        '${watch.elapsedMilliseconds} ms.');
  }, skip: !const bool.fromEnvironment('EXM_STRESS'));
}
