import 'package:supabase_flutter/supabase_flutter.dart';

import 'exam_reference_drill_account_export_service.dart';
import 'exam_reference_drill_progress_service.dart';

/// Cancellation stops further *client* RPCs; an in-flight server read may
/// still finish. It does not change, write or delete any saved records.
class ReferencePracticeExportCancelled implements Exception {
  const ReferencePracticeExportCancelled();
}

/// Extended EXM reference-practice export (up to 50,000 steps).
/// Preflight and postflight are separate RLS-invoker SQL statements. This is
/// NOT a single repeatable-read transaction. Any changed ID/grade digest
/// refuses to label the collected pages a complete historical export.
class ExamReferenceVerifiedLargeExportService {
  static const maxRecords = 50000;
  static const pageLimit = 250;
  static const consistencyMarker = 'pre-and-post-inventory-digest-v1';

  final SupabaseClient _client;
  final Future<dynamic> Function()? _testInventory;
  final Future<dynamic> Function(int limit, String? beforeAt, String? beforeId)?
      _testPage;

  ExamReferenceVerifiedLargeExportService({
    SupabaseClient? client,
    Future<dynamic> Function()? testInventory,
    Future<dynamic> Function(int limit,String? beforeAt,String? beforeId)?
        testPage,
  }) : _client=client??Supabase.instance.client,
       _testInventory=testInventory,_testPage=testPage;

  static final _uuid=RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  void _requireOwner(String ownerId) {
    final user=_client.auth.currentUser;
    if(ownerId.isEmpty || user==null || user.isAnonymous ||
       user.id!=ownerId) {
      throw StateError('Signed-in export owner changed');
    }
  }

  ({int count,String fingerprint}) _inventory(dynamic raw,String ownerId) {
    if(raw is! Map)throw const FormatException('Invalid export inventory');
    final data=Map<String,dynamic>.from(raw);
    const expected={
      'scope','owner_auth_uid','record_count','record_fingerprint','verification',
    };
    final count=data['record_count'];
    final fingerprint=data['record_fingerprint'];
    if(data.length!=expected.length ||
       data.keys.toSet().difference(expected).isNotEmpty ||
       data['scope']!='reference-practice-all-editions' ||
       data['owner_auth_uid']!=ownerId ||
       data['verification']!=consistencyMarker ||
       count is! int || count<0 || count>maxRecords ||
       fingerprint is! String ||
       !RegExp(r'^[a-f0-9]{32}$').hasMatch(fingerprint)){
      throw const FormatException('Untrusted export inventory');
    }
    return (count:count,fingerprint:fingerprint);
  }

  Future<dynamic> _readInventory()=>_testInventory!=null
      ? _testInventory()
      : _client.rpc('exam_reference_drill_export_inventory');

  Future<dynamic> _readPage(int limit,String? cursorAt,String? cursorId)=>
      _testPage!=null
        ? _testPage(limit,cursorAt,cursorId)
        : _client.rpc('exam_reference_drill_export_page',params:{
            'p_limit':limit,
            'p_before_recorded_at':cursorAt,
            'p_before_event_id':cursorId,
          });

  Future<ReferencePracticeAccountExport> loadComplete({
    required String expectedOwnerId,
    void Function(int loaded, int total)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    void checkCancelled() {
      if (shouldCancel?.call() == true) {
        throw const ReferencePracticeExportCancelled();
      }
    }

    _requireOwner(expectedOwnerId);
    checkCancelled();
    final start=_inventory(await _readInventory(),expectedOwnerId);
    _requireOwner(expectedOwnerId);
    checkCancelled();
    onProgress?.call(0,start.count);
    checkCancelled();

    final rows=<ReferenceDrillEvidence>[];
    final seen=<String>{};
    DateTime? previousTime;
    String? previousId;
    while(rows.length<start.count) {
      _requireOwner(expectedOwnerId);
      checkCancelled();
      final requested=(start.count-rows.length).clamp(1,pageLimit).toInt();
      final dynamic response=await _readPage(
        requested,previousTime?.toIso8601String(),previousId);
      _requireOwner(expectedOwnerId);
      checkCancelled();
      if(response is! Map)throw const FormatException('Invalid export page');
      final packet=Map<String,dynamic>.from(response);
      const keys={'scope','owner_auth_uid','row_count','rows'};
      final page=packet['rows'];
      if(packet.length!=keys.length ||
         packet.keys.toSet().difference(keys).isNotEmpty ||
         packet['scope']!='reference-practice-all-editions' ||
         packet['owner_auth_uid']!=expectedOwnerId ||
         packet['row_count'] is! int ||
         page is! List || page.isEmpty ||
         packet['row_count']!=page.length || page.length>requested) {
        throw const FormatException('Incomplete or unsafe export page');
      }
      for (final raw in page) {
        if(raw is! Map)throw const FormatException('Malformed event');
        final eventRow=Map<String,dynamic>.from(raw);
        final manifest=eventRow['manifest_revision_id'];
        if(manifest is! String || !_uuid.hasMatch(manifest)) {
          throw const FormatException('Invalid reference manifest ID');
        }
        final event=ReferenceDrillEvidence.fromRow(
          eventRow,ownerId:expectedOwnerId,manifestId:manifest);
        if(!_uuid.hasMatch(event.id) || !seen.add(event.id)) {
          throw const FormatException('Duplicate or invalid event ID');
        }
        if(previousTime!=null &&
           (event.recordedAt.isAfter(previousTime) ||
            (event.recordedAt.isAtSameMomentAs(previousTime) &&
             event.id.compareTo(previousId!)>=0))) {
          throw const FormatException('Reordered or duplicated export page');
        }
        previousTime=event.recordedAt;
        previousId=event.id;
        rows.add(event);
      }
      if(page.length<requested && rows.length!=start.count) {
        throw const FormatException('Export ended before inventory count');
      }
      checkCancelled();
      onProgress?.call(rows.length,start.count);
      checkCancelled();
    }

    // Final server-side digest catches concurrent new/delete rows AND newly
    // graded receipts. Never silently export a stale multi-request snapshot.
    _requireOwner(expectedOwnerId);
    checkCancelled();
    final end=_inventory(await _readInventory(),expectedOwnerId);
    _requireOwner(expectedOwnerId);
    checkCancelled();
    if(end.count!=start.count || end.fingerprint!=start.fingerprint ||
       rows.length!=end.count) {
      throw StateError('Reference history changed during export. '
          'Nothing complete was prepared; retry from a fresh inventory.');
    }
    checkCancelled();
    return ReferencePracticeAccountExport(
      ownerId:expectedOwnerId,
      generatedAt:DateTime.now().toUtc(),
      snapshotConsistency:'pre-and-post-inventory-verified-not-atomic',
      events:rows,
    );
  }
}
