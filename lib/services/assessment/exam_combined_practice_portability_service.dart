import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exact bounded summary of both EXM-02B (R1-R4) and EXM-03 histories.
class ExamPracticeInventory {
  final String owner;
  final int referenceEvents, referenceGrades, assignments, attempts;
  final String fingerprint;
  const ExamPracticeInventory(this.owner, this.referenceEvents,
      this.referenceGrades, this.assignments, this.attempts, this.fingerprint);

  static const scope = 'exm-educational-practice-all-editions-v1';
  static const fields = {
    'scope','owner_id','reference_events','reference_grades',
    'part_assignments','part_attempts','snapshot_fingerprint','bound_per_store'
  };
  factory ExamPracticeInventory.parse(dynamic raw,String owner) {
    if (raw is! Map) throw const FormatException('Invalid EXM inventory');
    final r=Map<String,dynamic>.from(raw);
    final e=r['reference_events'],g=r['reference_grades'];
    final a=r['part_assignments'],t=r['part_attempts'],f=r['snapshot_fingerprint'];
    if (r.length!=fields.length ||
        r.keys.toSet().difference(fields).isNotEmpty ||
        r['scope']!=scope || r['owner_id']!=owner ||
        r['bound_per_store']!=5000 ||
        e is! int || e<0 || e>5000 ||
        g is! int || g<0 || g>e ||
        a is! int || a<0 || a>5000 ||
        t is! int || t<0 || t>a ||
        f is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(f)) {
      throw const FormatException('Unsafe EXM inventory');
    }
    return ExamPracticeInventory(owner,e,g,a,t,f);
  }
  bool get hasHistory => referenceEvents+assignments>0;
}

/// Validates a single SQL snapshot; rejects extra/secret fields, missing rows,
/// foreign owner rows and any mismatch with the server inventory.
class ExamPracticeArchive {
  final String owner;
  final Map<String,dynamic> _data;
  const ExamPracticeArchive._(this.owner,this._data);
  String toJson()=>jsonEncode(_data);

  factory ExamPracticeArchive.parse(dynamic raw,String owner) {
    if (raw is! Map) throw const FormatException('Invalid EXM export');
    final r=Map<String,dynamic>.from(raw);
    const fields={
      'format','scope','owner_id','generated_at','snapshot_consistency',
      'inventory','reference_practice','part_practice',
      'includes_unsubmitted_assignments','official_exam_result'
    };
    if (r.length!=fields.length ||
        r.keys.toSet().difference(fields).isNotEmpty ||
        r['format']!='learningapp-exm-combined-practice-v1' ||
        r['scope']!='educational-practice-history-not-entire-account' ||
        r['owner_id']!=owner ||
        r['snapshot_consistency']!='single-stable-rpc-statement' ||
        r['includes_unsubmitted_assignments']!=true ||
        r['official_exam_result']!=false ||
        DateTime.tryParse(r['generated_at']?.toString()??'')==null) {
      throw const FormatException('Unsafe EXM export envelope');
    }
    final inventory=ExamPracticeInventory.parse(r['inventory'],owner);
    final refRaw=r['reference_practice'],parts=r['part_practice'];
    if(refRaw is! Map || parts is! List) {
      throw const FormatException('Missing EXM export stores');
    }
    final ref=Map<String,dynamic>.from(refRaw);
    const refFields={
      'format','scope','owner_auth_uid','record_count','generated_at',
      'snapshot_consistency','steps'
    };
    if(ref.length!=refFields.length ||
       ref.keys.toSet().difference(refFields).isNotEmpty ||
       ref['format']!='learningapp-exm-reference-practice-account-v1' ||
       ref['scope']!='reference-practice-all-editions' ||
       ref['owner_auth_uid']!=owner ||
       ref['snapshot_consistency']!='single-sql-statement' ||
       ref['record_count']!=inventory.referenceEvents ||
       ref['steps'] is! List ||
       (ref['steps'] as List).length!=inventory.referenceEvents ||
       parts.length!=inventory.assignments) {
      throw const FormatException('Incomplete reference/practice export');
    }
    const stepFields={
      'event_id','owner_auth_uid','client_attempt_id','assessment_item_id',
      'approved_binding_id','manifest_revision_id','exam_part_key',
      'administration_date','item_content_revision','answer_location_revision',
      'drill_step','responded','app_elapsed_ms','self_reported_book_ms',
      'started_at','completed_at','recorded_at','verification_state',
      'is_correct','scoring_version','graded_at'
    };
    final stepIds=<String>{};var graded=0;
    for(final rawStep in ref['steps'] as List) {
      if(rawStep is! Map) throw const FormatException('Bad EXM step');
      final step=Map<String,dynamic>.from(rawStep);
      if(step.length!=stepFields.length ||
         step.keys.toSet().difference(stepFields).isNotEmpty ||
         step['owner_auth_uid']!=owner ||
         step['event_id'] is! String ||
         !stepIds.add(step['event_id'] as String) ||
         step['verification_state']!='unverified' ||
         (step['is_correct']==null &&
          (step['scoring_version']!=null || step['graded_at']!=null)) ||
         (step['is_correct']!=null &&
          (step['is_correct'] is! bool ||
           step['scoring_version'] is! int || step['graded_at']==null))) {
        throw const FormatException('Unsafe EXM step');
      }
      if(step['is_correct']!=null) graded++;
    }
    if(graded!=inventory.referenceGrades) {
      throw const FormatException('Missing graded evidence');
    }
    const partFields={
      'assignment_id','target_id','target_version_id','exam_part_key',
      'curriculum_root_node_id','manifest_revision_id','practice_kind',
      'issued_at','expires_at','attempt'
    };
    const scoreFields={
      'attempt_id','completed_at','question_count','fully_correct_count',
      'partial_count','practice_score','question_edition_fingerprint',
      'official_exam_result'
    };
    final assignmentIds=<String>{};var completed=0;
    for(final rawPart in parts) {
      if(rawPart is! Map) throw const FormatException('Bad EXM assignment');
      final part=Map<String,dynamic>.from(rawPart);
      if(part.length!=partFields.length ||
         part.keys.toSet().difference(partFields).isNotEmpty ||
         part['assignment_id'] is! String ||
         !assignmentIds.add(part['assignment_id'] as String) ||
         !{'diagnostic','mock'}.contains(part['practice_kind'])) {
        throw const FormatException('Unsafe EXM assignment');
      }
      final rawScore=part['attempt'];
      if(rawScore==null) continue;
      if(rawScore is! Map) throw const FormatException('Bad EXM score');
      final score=Map<String,dynamic>.from(rawScore);
      final n=score['question_count'],correct=score['fully_correct_count'];
      final partial=score['partial_count'],value=score['practice_score'];
      if(score.length!=scoreFields.length ||
         score.keys.toSet().difference(scoreFields).isNotEmpty ||
         score['official_exam_result']!=false ||
         score['attempt_id'] is! String ||
         n is! int || n<1 || n>500 ||
         correct is! int || partial is! int || correct<0 || partial<0 ||
         correct+partial>n || value is! num || value<0 || value>1) {
        throw const FormatException('Unsafe EXM score');
      }
      completed++;
    }
    if(completed!=inventory.attempts) {
      throw const FormatException('Missing EXM score');
    }
    return ExamPracticeArchive._(owner,r);
  }
}

/// Runs only after independent review of the inventory and exact phrase.
class ExamCombinedPracticePortabilityService {
  static const confirmationPhrase='DELETE ALL EXAM PRACTICE';
  final SupabaseClient _client;
  final Future<dynamic> Function()? _testInventory, _testExport;
  final Future<dynamic> Function(int,int,int,String,String)? _testErase;

  ExamCombinedPracticePortabilityService({
    SupabaseClient? client,
    Future<dynamic> Function()? testInventory,
    Future<dynamic> Function()? testExport,
    Future<dynamic> Function(int,int,int,String,String)? testErase
  }):_client=client??Supabase.instance.client,
     _testInventory=testInventory,_testExport=testExport,_testErase=testErase;

  void _owner(String expected) {
    final user=_client.auth.currentUser;
    if(expected.isEmpty || user==null || user.isAnonymous || user.id!=expected) {
      throw StateError('EXM practice account changed');
    }
  }

  Future<ExamPracticeInventory> inventory({required String expectedOwnerId}) async {
    _owner(expectedOwnerId);
    final raw=_testInventory!=null ? await _testInventory()
      : await _client.rpc('exm03_account_practice_inventory');
    _owner(expectedOwnerId);
    return ExamPracticeInventory.parse(raw,expectedOwnerId);
  }

  Future<ExamPracticeArchive> export({required String expectedOwnerId}) async {
    _owner(expectedOwnerId);
    final raw=_testExport!=null ? await _testExport()
      : await _client.rpc('exm03_account_practice_export');
    _owner(expectedOwnerId);
    return ExamPracticeArchive.parse(raw,expectedOwnerId);
  }

  Future<void> erase({
    required String expectedOwnerId,
    required ExamPracticeInventory preview,
    required String exactConfirmation,
  }) async {
    _owner(expectedOwnerId);
    if(preview.owner!=expectedOwnerId || !preview.hasHistory ||
       exactConfirmation!=confirmationPhrase) {
      throw StateError('Exact EXM erasure preview and confirmation required');
    }
    final raw=_testErase!=null
      ? await _testErase(preview.referenceEvents,preview.assignments,
                       preview.attempts,preview.fingerprint,exactConfirmation)
      : await _client.rpc('exm03_erase_account_practice',params:{
          'p_expected_events':preview.referenceEvents,
          'p_expected_assignments':preview.assignments,
          'p_expected_attempts':preview.attempts,
          'p_expected_fingerprint':preview.fingerprint,
          'p_confirmation':exactConfirmation,
        });
    _owner(expectedOwnerId);
    if(raw is! Map) throw const FormatException('Invalid EXM erase receipt');
    final r=Map<String,dynamic>.from(raw);
    const fields={
      'scope','owner_id','deleted_reference_events','deleted_part_assignments',
      'remaining_reference_events','remaining_reference_grades',
      'remaining_part_assignments','remaining_part_attempts','irreversible'
    };
    if(r.length!=fields.length ||
       r.keys.toSet().difference(fields).isNotEmpty ||
       r['scope']!=ExamPracticeInventory.scope ||
       r['owner_id']!=expectedOwnerId ||
       r['deleted_reference_events']!=preview.referenceEvents ||
       r['deleted_part_assignments']!=preview.assignments ||
       r['remaining_reference_events']!=0 ||
       r['remaining_reference_grades']!=0 ||
       r['remaining_part_assignments']!=0 ||
       r['remaining_part_attempts']!=0 || r['irreversible']!=true) {
      throw const FormatException('Untrusted EXM erase receipt');
    }
  }
}
