import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/exam_reference_drill_account_export_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_helpers/fake_supabase_client.dart';

const manifestA = '33333333-3333-4333-8333-333333333333';
const manifestRetired = '55555555-5555-4555-8555-555555555555';
const eventA = '11111111-1111-4111-8111-111111111111';
const eventB = '22222222-2222-4222-8222-222222222222';

User _user(String id, {bool guest=false}) => User(
  id:id,isAnonymous:guest,appMetadata:const {},userMetadata:const {},
  aud:'authenticated',createdAt:'2026-10-21T00:00:00Z',
);

Map<String,dynamic> _row({
  String id=eventA,
  String edition=manifestA,
  String owner='account-a',
  String step='resource_choice',
  bool responded=true,
  bool? correct=true,
  int? version=1,
  String recorded='2027-03-01T12:00:00Z',
}) => {
  'event_id':id,
  'owner_auth_uid':owner,
  'client_attempt_id':'66666666-6666-4666-8666-666666666666',
  'assessment_item_id':'77777777-7777-4777-8777-777777777777',
  'approved_binding_id':'88888888-8888-4888-8888-888888888888',
  'manifest_revision_id':edition,
  'exam_part_key':'project_management',
  'administration_date':'2027-06-01',
  'item_content_revision':1,
  'answer_location_revision':1,
  'drill_step':step,
  'responded':responded,
  'app_elapsed_ms':1200,
  'self_reported_book_ms':null,
  'started_at':'2027-03-01T11:59:55Z',
  'completed_at':'2027-03-01T11:59:59Z',
  'recorded_at':recorded,
  'verification_state':'unverified',
  'is_correct':correct,
  'scoring_version':correct == null ? null : version,
  'graded_at':correct == null ? null : '2027-03-01T12:00:01Z',
};

Map<String,dynamic> _envelope(List<Map<String,dynamic>> rows, {
  String owner='account-a',
}) => {
  'format':'learningapp-exm-reference-practice-account-v1',
  'scope':'reference-practice-all-editions',
  'owner_auth_uid':owner,
  'record_count':rows.length,
  'generated_at':'2027-03-01T12:01:00Z',
  'snapshot_consistency':'single-sql-statement',
  'steps':rows,
};

class _MutableClient implements SupabaseClient {
  final _MutableAuth stub=_MutableAuth();
  @override
  GoTrueClient get auth=>stub;
  @override
  dynamic noSuchMethod(Invocation i)=>throw UnimplementedError();
}
class _MutableAuth implements GoTrueClient {
  User? active;
  @override
  User? get currentUser=>active;
  @override
  dynamic noSuchMethod(Invocation i)=>throw UnimplementedError();
}

void main() {
  test('Owner gets consistent all-edition history, with honest export scope',() async {
    final client=FakeSupabaseClient(currentUser:_user('account-a'));
    final service=ExamReferenceDrillAccountExportService(
      client:client,
      testTransport:(limit) async {
        expect(limit,5000);
        return _envelope([
          _row(),
          _row(
            id:eventB, edition:manifestRetired,step:'section_location',
            responded:false,correct:null,version:null,
            recorded:'2027-02-28T11:00:00Z',
          ),
        ]);
      },
    );
    final export=await service.load(expectedOwnerId:'account-a');
    expect(export.events.length,2);
    expect(export.manifestCount,2);
    expect(export.gradedCorrect,1);
    expect(export.gradedIncorrect,0);
    expect(export.skipped,1);
    final json=jsonDecode(export.toJsonExport()) as Map<String,dynamic>;
    expect(json['scope'],'reference-practice-all-editions');
    expect(json['complete_within_limit'],true);
    expect(json['snapshot_consistency'],'single-sql-statement');
    expect(json['disclaimer'],contains('not a whole LearningApp account archive'));
    expect((json['steps'] as List).length,2);
    expect(json.toString().contains('step_tokens'),false);
    expect(json.toString().contains('scoring_spec'),false);
    expect(json.toString().contains('reviewer_ref'),false);
  });

  test('Guest and wrong owner cannot call export API',() async {
    final client=FakeSupabaseClient(currentUser:_user('guest',guest:true));
    var invoked=0;
    final service=ExamReferenceDrillAccountExportService(
      client:client,testTransport:(l) async {invoked++;return _envelope([]);},
    );
    await expectLater(service.load(expectedOwnerId:'guest'),throwsStateError);
    await expectLater(service.load(expectedOwnerId:'account-a'),throwsStateError);
    expect(invoked,0);
  });

  test('Async owner switch invalidates entire response',() async {
    final client=_MutableClient()..stub.active=_user('account-a');
    final pending=Completer<dynamic>();
    final service=ExamReferenceDrillAccountExportService(
      client:client,testTransport:(limit)=>pending.future);
    final request=service.load(expectedOwnerId:'account-a');
    client.stub.active=_user('account-b');
    pending.complete(_envelope([_row()]));
    await expectLater(request,throwsStateError);
  });

  test('Untrusted envelope, wrong owner and private fields fail closed',() async {
    final client=FakeSupabaseClient(currentUser:_user('account-a'));
    final candidate=_envelope([_row()]);
    final bad=[
      {...candidate,'owner_auth_uid':'account-b'},
      {...candidate,'record_count':2},
      {...candidate,'snapshot_consistency':'eventually-consistent'},
      {...candidate,'scoring_spec':{'answer':'private'}},
      _envelope([_row(owner:'account-b')]),
      _envelope([_row()..['step_tokens']=['private']]),
      _envelope([_row(correct:true,version:null)]),
      _envelope([_row(edition:'untrusted-edition')]),
    ];
    for (final value in bad) {
      final service=ExamReferenceDrillAccountExportService(
        client:client,testTransport:(l) async=>value);
      await expectLater(service.load(expectedOwnerId:'account-a'),
          throwsFormatException);
    }
  });

  test('Duplicate, reordered and out-of-range exports are rejected',() async {
    final client=FakeSupabaseClient(currentUser:_user('account-a'));
    for (final payload in [
      _envelope([_row(),_row()]),
      _envelope([
        _row(id:eventB,recorded:'2027-02-28T12:00:00Z'),
        _row(id:eventA,recorded:'2027-03-01T12:00:00Z'),
      ]),
      _envelope([_row(), _row(id:eventB,
          recorded:'2027-02-28T12:00:00Z')]),
    ]) {
      final service=ExamReferenceDrillAccountExportService(
        client:client,testTransport:(l) async=>payload);
      if (payload['steps'].length==2 &&
          (payload['steps'] as List)[0]['event_id']==eventA &&
          (payload['steps'] as List)[1]['event_id']==eventB) {
        await expectLater(service.load(
          expectedOwnerId:'account-a',maxRecords:1),throwsFormatException);
      } else {
        await expectLater(service.load(
          expectedOwnerId:'account-a'),throwsFormatException);
      }
    }
  });
}
