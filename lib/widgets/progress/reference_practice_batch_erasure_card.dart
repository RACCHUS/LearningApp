import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/assessment/exam_reference_practice_batch_erasure_service.dart';

/// Supplemental path for large EXM histories. Each 1,000-step batch
/// requires its own owner-scoped preview and two explicit confirmations.
class ReferencePracticeBatchErasureCard extends ConsumerWidget {
  final ExamReferencePracticeBatchErasureService? service;
  const ReferencePracticeBatchErasureCard({super.key,this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth=ref.watch(authProvider);
    if (auth is! AuthSuccess || auth.user.isAnonymous) {
      return const SizedBox.shrink();
    }
    return _OwnedBatches(
      key:ValueKey('exm-batch-erasure:${auth.user.id}'),
      ownerId:auth.user.id,
      service:service,
    );
  }
}

class _OwnedBatches extends StatefulWidget {
  final String ownerId;
  final ExamReferencePracticeBatchErasureService? service;
  const _OwnedBatches({
    super.key,required this.ownerId,this.service,
  });

  @override
  State<_OwnedBatches> createState()=>_OwnedBatchesState();
}

class _OwnedBatchesState extends State<_OwnedBatches> {
  late final ExamReferencePracticeBatchErasureService _defaultService=
      ExamReferencePracticeBatchErasureService();
  ExamReferencePracticeBatchErasureService get _api=>
      widget.service??_defaultService;
  final _phrase=TextEditingController();
  ReferencePracticeBatchPreview? _preview;
  ReferencePracticeBatchReceipt? _receipt;
  bool _busy=false;
  String? _error;

  @override
  void dispose() {
    _phrase.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if(_busy)return;
    setState(() {
      _busy=true;
      _error=null;
      _preview=null;
      _receipt=null;
      _phrase.clear();
    });
    try {
      final preview=await _api.preview(expectedOwnerId:widget.ownerId);
      if(!mounted)return;
      if(preview.ownerId!=widget.ownerId){
        throw StateError('Private batch owner mismatch');
      }
      setState(()=>_preview=preview);
    } catch (_) {
      if(!mounted)return;
      setState(()=>_error='Could not prepare a complete batch preview. '
          'No deletion was requested.');
    } finally {
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _deleteOne() async {
    final preview=_preview;
    if(_busy || preview==null || preview.batchEvents==0 ||
        _phrase.text!=ExamReferencePracticeBatchErasureService.confirmationPhrase){
      return;
    }
    final approved=await showDialog<bool>(
      context:context,
      builder:(dialog)=>AlertDialog(
        title:const Text('Delete this practice batch?'),
        content:Text(
          'Permanently delete exactly ${preview.batchEvents} saved EXM step(s), '
          'including ${preview.batchGrades} derived grades, across '
          '${preview.batchEditions} edition(s)? Your account currently '
          'has ${preview.totalEvents} saved steps. '
          'Only this batch will be deleted; other steps remain. '
          'You must preview and confirm each future batch separately. '
          'Previously copied files and clipboard data will not be erased.',
        ),
        actions:[
          TextButton(
            onPressed:()=>Navigator.of(dialog).pop(false),
            child:const Text('Cancel'),
          ),
          FilledButton(
            onPressed:()=>Navigator.of(dialog).pop(true),
            child:const Text('Delete this batch permanently'),
          ),
        ],
      ),
    );
    if(!mounted || approved!=true || _busy) return;
    setState((){
      _busy=true;
      _error=null;
    });
    try {
      final receipt=await _api.deleteOneBatch(
        expectedOwnerId:widget.ownerId,
        preview:preview,
        exactConfirmation:_phrase.text,
      );
      if(!mounted)return;
      setState((){
        _preview=null;
        _phrase.clear();
        _receipt=receipt;
      });
    } catch (_) {
      if(!mounted)return;
      // The network may fail after server commit. Do not retry a destructive
      // request without a fresh server-side preview.
      setState((){
        _preview=null;
        _phrase.clear();
        _error='Batch deletion status is uncertain or the preview changed. '
            'Load a fresh preview before attempting another deletion.';
      });
    } finally {
      if(mounted)setState(()=>_busy=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p=_preview;
    return Card(
      key:const Key('exm-batch-erasure-card'),
      child:Padding(
        padding:const EdgeInsets.all(12),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            Text('Large history: delete in batches',
                style:Theme.of(context).textTheme.titleSmall),
            const Text(
              'For accounts with more than 5,000 saved EXM steps, '
              'or if you prefer smaller deletions. Each batch removes '
              'up to 1,000 steps across all reference editions, '
              'including retired editions. No automatic deletion occurs.',
            const Text(
              'Export before deleting if you need a copy. The current '
              'all-edition JSON export cannot include more than 5,000 '
              'saved steps. If you need a complete export of a larger '
              'history, do not delete it until a suitable export is available.',
            ),
            ),
            TextButton.icon(
              key:const Key('exm-batch-preview'),
              onPressed:_busy?null:_load,
              icon:const Icon(Icons.fact_check_outlined),
              label:Text(p==null?'Preview next EXM batch':
                  'Refresh next EXM batch'),
            ),
            if(_busy)const LinearProgressIndicator(),
            if(_error!=null)Text(
              _error!,key:const Key('exm-batch-error'),
            ),
            if(_receipt!=null)...[
              Text(
                '${_receipt!.deleted} step(s) deleted in this batch; '
                '${_receipt!.remaining} remaining at confirmation.',
                key:const Key('exm-batch-result'),
              ),
              if(_receipt!.remaining>0)
                const Text('Another deletion requires a new preview and '
                    'a new confirmation. No additional steps are deleted '
                    'without your action.'),
            ],
            if(p!=null)...[
              Text('${p.totalEvents} total saved steps; '
                  '${p.batchEvents} selected in the next batch, '
                  '${p.batchGrades} grades, '
                  '${p.batchEditions} reference edition(s).',
                  key:const Key('exm-batch-count')),
              if(p.batchEvents==0)
                const Text('No saved EXM practice steps remain.'),
              if(p.batchEvents>0)...[
                const Text('Type exactly: DELETE NEXT BATCH'),
                TextField(
                  key:const Key('exm-batch-confirmation'),
                  controller:_phrase,
                  autocorrect:false,
                  enableSuggestions:false,
                  onChanged:(_)=>setState((){}),
                  decoration:const InputDecoration(
                    labelText:'Confirm this batch',
                  ),
                ),
                OutlinedButton.icon(
                  key:const Key('exm-batch-delete'),
                  onPressed:!_busy &&
                      _phrase.text==
                        ExamReferencePracticeBatchErasureService.confirmationPhrase
                      ? _deleteOne:null,
                  icon:const Icon(Icons.delete_forever_outlined),
                  label:const Text('Review this batch deletion'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
