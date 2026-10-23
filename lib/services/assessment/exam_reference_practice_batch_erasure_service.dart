import 'package:supabase_flutter/supabase_flutter.dart';

/// One server-reviewed subset. No automatic continuation between batches.
class ReferencePracticeBatchPreview {
  final String ownerId;
  final int totalEvents;
  final int batchEvents;
  final int batchGrades;
  final int batchEditions;
  final int limit;
  final String fingerprint;

  const ReferencePracticeBatchPreview({
    required this.ownerId, required this.totalEvents,
    required this.batchEvents, required this.batchGrades,
    required this.batchEditions, required this.limit,
    required this.fingerprint,
  });

  factory ReferencePracticeBatchPreview.fromRpc(
      Map<String, dynamic> value, String owner, int requestedLimit) {
    const fields = {
      'scope','owner_auth_uid','total_events','batch_events',
      'batch_grades','batch_editions','batch_limit','batch_fingerprint',
    };
    final total=value['total_events'];
    final events=value['batch_events'];
    final grades=value['batch_grades'];
    final editions=value['batch_editions'];
    final limit=value['batch_limit'];
    final fingerprint=value['batch_fingerprint'];
    if (value.length!=fields.length ||
        value.keys.toSet().difference(fields).isNotEmpty ||
        value['scope']!='reference-practice-next-batch' ||
        value['owner_auth_uid']!=owner ||
        limit is! int || limit!=requestedLimit ||
        total is! int || total<0 ||
        events is! int || events<0 || events>limit ||
        (total>0 && events==0) || events>total ||
        grades is! int || grades<0 || grades>events ||
        editions is! int || editions<0 || editions>events ||
        (events==0 && (grades!=0 || editions!=0)) ||
        fingerprint is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(fingerprint)) {
      throw const FormatException('Untrusted private batch preview');
    }
    return ReferencePracticeBatchPreview(
      ownerId: owner, totalEvents:total, batchEvents:events,
      batchGrades:grades, batchEditions:editions, limit:limit,
      fingerprint:fingerprint,
    );
  }
}

class ReferencePracticeBatchReceipt {
  final int deleted;
  final int remaining;
  const ReferencePracticeBatchReceipt({
    required this.deleted,required this.remaining,
  });

  factory ReferencePracticeBatchReceipt.fromRpc(
      Map<String, dynamic> value, String owner,
      ReferencePracticeBatchPreview preview) {
    const fields = {
      'scope','owner_auth_uid','deleted_events','remaining_events',
    };
    final deleted=value['deleted_events'];
    final remaining=value['remaining_events'];
    if (value.length!=fields.length ||
        value.keys.toSet().difference(fields).isNotEmpty ||
        value['scope']!='reference-practice-next-batch' ||
        value['owner_auth_uid']!=owner ||
        deleted is! int || deleted!=preview.batchEvents ||
        remaining is! int || remaining<0) {
      throw const FormatException('Untrusted batch delete receipt');
    }
    return ReferencePracticeBatchReceipt(
      deleted:deleted,remaining:remaining,
    );
  }
}

/// Invoker-role, permanent-owner only. Every batch requires fresh preview,
/// exact text and separate user confirmation. Never loops on its own.
class ExamReferencePracticeBatchErasureService {
  static const confirmationPhrase='DELETE NEXT BATCH';
  static const defaultLimit=1000;

  final SupabaseClient _client;
  final Future<dynamic> Function(int limit)? _testPreview;
  final Future<dynamic> Function(int limit,int count,String fingerprint,String phrase)?
      _testDelete;

  ExamReferencePracticeBatchErasureService({
    SupabaseClient? client,
    Future<dynamic> Function(int limit)? testPreview,
    Future<dynamic> Function(int limit,int count,String fingerprint,String phrase)?
        testDelete,
  }) : _client=client??Supabase.instance.client,
       _testPreview=testPreview,
       _testDelete=testDelete;

  void _requireOwner(String owner) {
    final user=_client.auth.currentUser;
    if (owner.isEmpty || user==null || user.isAnonymous || user.id!=owner) {
      throw StateError('Private EXM practice account changed');
    }
  }

  Future<ReferencePracticeBatchPreview> preview({
    required String expectedOwnerId,
    int limit=defaultLimit,
  }) async {
    _requireOwner(expectedOwnerId);
    if (limit<1 || limit>1000) {
      throw const FormatException('Invalid practice erasure batch size');
    }
    final dynamic result=_testPreview!=null
        ? await _testPreview(limit)
        : await _client.rpc(
            'exam_reference_drill_batch_erasure_preview',
            params:{'p_batch_limit':limit},
          );
    _requireOwner(expectedOwnerId);
    if (result is! Map) {
      throw const FormatException('Untrusted preview response');
    }
    return ReferencePracticeBatchPreview.fromRpc(
      Map<String,dynamic>.from(result),expectedOwnerId,limit,
    );
  }

  Future<ReferencePracticeBatchReceipt> deleteOneBatch({
    required String expectedOwnerId,
    required ReferencePracticeBatchPreview preview,
    required String exactConfirmation,
  }) async {
    _requireOwner(expectedOwnerId);
    if (preview.ownerId!=expectedOwnerId ||
        preview.batchEvents<1 ||
        preview.limit<1 || preview.limit>1000 ||
        exactConfirmation!=confirmationPhrase) {
      throw StateError('Recheck batch preview and exact confirmation');
    }
    final dynamic result=_testDelete!=null
        ? await _testDelete(
            preview.limit,preview.batchEvents,preview.fingerprint,
            exactConfirmation,
          )
        : await _client.rpc('exam_reference_drill_erase_batch',params:{
            'p_batch_limit':preview.limit,
            'p_expected_count':preview.batchEvents,
            'p_expected_fingerprint':preview.fingerprint,
            'p_confirmation':exactConfirmation,
          });
    _requireOwner(expectedOwnerId);
    if (result is! Map) {
      throw const FormatException('Untrusted batch deletion response');
    }
    return ReferencePracticeBatchReceipt.fromRpc(
      Map<String,dynamic>.from(result),expectedOwnerId,preview,
    );
  }
}
