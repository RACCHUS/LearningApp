import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/assessment/exam_assigned_practice_service.dart';

/// Protected EXM-03 part diagnostic. This widget never reads assessment_items
/// or constructs an AssessmentItem containing a private scoring_spec.
/// Scoring and replay handling occur only in the canonical server RPC.
class SecureExamPartPracticeScreen extends ConsumerWidget {
  final String targetVersionId;
  final String examPartKey;
  final ExamAssignedPracticeService? service;

  const SecureExamPartPracticeScreen({
    super.key,
    required this.targetVersionId,
    required this.examPartKey,
    this.service,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth=ref.watch(authProvider);
    if(auth is! AuthSuccess || auth.user.isAnonymous) {
      return const Scaffold(
        body: Center(child: Text(
          'Sign in with a permanent account for reviewed exam-part practice.',
        )),
      );
    }
    final owner=auth.user.id;
    return _OwnerPractice(
      key: ValueKey('secure-exm-part:$owner:$targetVersionId:$examPartKey'),
      expectedOwnerId:owner,
      targetVersionId:targetVersionId,
      examPartKey:examPartKey,
      service:service,
      stillOwner:(){
        final state=ref.read(authProvider);
        return state is AuthSuccess &&
          !state.user.isAnonymous && state.user.id==owner;
      },
    );
  }
}

class _OwnerPractice extends StatefulWidget {
  final String expectedOwnerId;
  final String targetVersionId;
  final String examPartKey;
  final ExamAssignedPracticeService? service;
  final bool Function() stillOwner;

  const _OwnerPractice({
    super.key,
    required this.expectedOwnerId,
    required this.targetVersionId,
    required this.examPartKey,
    required this.stillOwner,
    this.service,
  });

  @override
  State<_OwnerPractice> createState()=>_OwnerPracticeState();
}

class _OwnerPracticeState extends State<_OwnerPractice> {
  late final ExamAssignedPracticeService _defaultService=
      ExamAssignedPracticeService();
  ExamAssignedPracticeService get _api=>widget.service??_defaultService;
  IssuedExamPractice? _issued;
  IssuedExamResult? _result;
  final Map<String,int> _answers={};
  int _index=0;
  bool _loading=true;
  bool _submitting=false;
  String? _error;

  bool get _owned=>mounted && widget.stillOwner();

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(_owned) _load();
    });
  }

  Future<void> _load() async {
    if(!_owned)return;
    setState((){
      _loading=true;
      _error=null;
      _issued=null;
      _result=null;
      _answers.clear();
      _index=0;
    });
    try{
      final issued=await _api.issue(
        expectedOwnerId:widget.expectedOwnerId,
        targetVersionId:widget.targetVersionId,
        examPartKey:widget.examPartKey,
      );
      if(!_owned)return;
      setState(()=>_issued=issued);
    }catch(_){
      if(!_owned)return;
      setState(()=>_error=
        'Reviewed practice is unavailable for this exact exam part. '
        'No questions or scores have been fabricated.');
    }finally{
      if(_owned)setState(()=>_loading=false);
    }
  }

  Future<void> _submit() async {
    final issued=_issued;
    if(!_owned || _loading || _submitting || issued==null ||
       _answers.length!=issued.questions.length)return;
    setState((){
      _submitting=true;
      _error=null;
    });
    try{
      final result=await _api.submit(
        expectedOwnerId:widget.expectedOwnerId,
        assignment:issued,
        responses:Map<String,int>.from(_answers),
      );
      if(!_owned)return;
      setState(()=>_result=result);
    }catch(_){
      if(!_owned)return;
      setState(()=>_error=
        'Unable to verify this submission. Reopen the same practice '
        'session to check its status; scores were not calculated locally.');
    }finally{
      if(_owned)setState(()=>_submitting=false);
    }
  }

  @override
  Widget build(BuildContext context){
    final issued=_issued, result=_result;
    return Scaffold(
      appBar:AppBar(title:const Text('Reviewed part diagnostic')),
      body:Padding(
        padding:const EdgeInsets.all(16),
        child:Column(
          crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            const Text(
              'Educational practice only — not an official exam score. '
              'Questions are issued by the server for your selected part.',
            ),
            const SizedBox(height:12),
            if(_loading)const LinearProgressIndicator(),
            if(_error!=null)Text(_error!,
              key:const Key('secure-exm-part-error')),
            if(!_loading && issued==null)
              OutlinedButton(
                key:const Key('secure-exm-part-retry'),
                onPressed:_load,
                child:const Text('Check reviewed questions again'),
              ),
            if(result!=null)...[
              const SizedBox(height:16),
              Text('Verified educational practice score: '
                 '${result.fullyCorrectCount} of ${result.questionCount}',
                key:const Key('secure-exm-part-result')),
              const Text('This result is not an official exam outcome.'),
              if(result.alreadyRecorded)
                const Text('Existing verified result recovered safely.'),
            ]else if(issued!=null)...[
              const SizedBox(height:12),
              Text('Question ${_index+1} of ${issued.questions.length}',
                key:const Key('secure-exm-part-count')),
              const SizedBox(height:12),
              Expanded(child:SingleChildScrollView(
                child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(issued.questions[_index].prompt),
                    const SizedBox(height:12),
                    for(var i=0;i<issued.questions[_index].options.length;i++)
                      Padding(
                        padding:const EdgeInsets.symmetric(vertical:4),
                        child:ChoiceChip(
                          key:Key('secure-exm-part-choice-$i'),
                          label:Text(issued.questions[_index].options[i]),
                          selected:_answers[issued.questions[_index].id]==i,
                          onSelected:_submitting?null:(_){
                            setState(()=>_answers[issued.questions[_index].id]=i);
                          },
                        ),
                      ),
                  ],
                ),
              )),
              Row(children:[
                OutlinedButton(
                  key:const Key('secure-exm-part-prev'),
                  onPressed:_submitting || _index==0
                    ? null:()=>setState(()=>_index--),
                  child:const Text('Previous'),
                ),
                const Spacer(),
                if(_index<issued.questions.length-1)
                  OutlinedButton(
                    key:const Key('secure-exm-part-next'),
                    onPressed:_submitting ||
                        !_answers.containsKey(issued.questions[_index].id)
                      ? null:()=>setState(()=>_index++),
                    child:const Text('Next'),
                  )
                else
                  FilledButton(
                    key:const Key('secure-exm-part-submit'),
                    onPressed:_submitting ||
                        _answers.length!=issued.questions.length
                      ? null:_submit,
                    child:Text(_submitting?'Verifying…':'Submit for verified scoring'),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
