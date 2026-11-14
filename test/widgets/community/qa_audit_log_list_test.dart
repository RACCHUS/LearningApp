import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/community_review_audit.dart';
import 'package:learning_pwa/widgets/community/qa_audit_log_list.dart';

/// Direct tests for the moderator audit trail extracted from
/// InContextQaSheet. Sheet-level wiring stays covered in
/// in_context_qa_sheet_test.dart.
CommunityReviewAudit _audit({
  String id = 'a1',
  String targetType = 'question',
  String targetId = 'q-1',
  String? reviewerId = 'moderator-123456789',
  String action = 'publish',
  String? notes,
  String? internalNotes,
}) =>
    CommunityReviewAudit(
      id: id,
      targetType: targetType,
      targetId: targetId,
      reviewerId: reviewerId,
      action: action,
      previousStatus: 'under_review',
      newStatus: action == 'reject' ? 'rejected' : 'published',
      notes: notes,
      internalNotes: internalNotes,
      createdAt: DateTime(2026, 11, 14, 9, 5),
    );

Widget _host(
  List<CommunityReviewAudit> logs, {
  Map<String, String> titles = const {},
  Map<String, String> parents = const {},
}) =>
    MaterialApp(
      home: Scaffold(
        body: QaAuditLogList(
          auditLogs: logs,
          questionTitles: titles,
          answerParentQuestionIds: parents,
        ),
      ),
    );

void main() {
  group('formatters', () {
    test('author ids are shortened and offline demo is named', () {
      expect(formatQaAuthorId('offline-demo'), 'Offline Demo');
      expect(formatQaAuthorId('abcdefghijkl'), 'Learner (abcdefgh)');
      expect(formatQaAuthorId('short'), 'Learner (short)');
    });

    test('a null reviewer is a system action', () {
      expect(formatQaReviewerId(null), 'System');
      expect(formatQaReviewerId('moderator-123'), 'Moderator (moderato)');
    });
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(_host(const []));
    expect(find.text('No Audit Records Yet'), findsOneWidget);
  });

  testWidgets('question audit shows its title, reviewer, status and time',
      (tester) async {
    await tester.pumpWidget(
        _host([_audit()], titles: const {'q-1': 'How do I cite statutes?'}));

    expect(find.text('PUBLISH'), findsOneWidget);
    expect(find.text('Question Review'), findsOneWidget);
    expect(find.text('Target: How do I cite statutes?'), findsOneWidget);
    expect(find.text('Reviewer: Moderator (moderato)'), findsOneWidget);
    expect(find.text('Status change: under_review -> published'), findsOneWidget);
    expect(find.text('11/14/2026 9:05'), findsOneWidget);
  });

  testWidgets('answer audit names its parent question when known',
      (tester) async {
    await tester.pumpWidget(_host(
      [_audit(targetType: 'answer', targetId: 'ans-1')],
      titles: const {'q-1': 'Parent title'},
      parents: const {'ans-1': 'q-1'},
    ));
    expect(find.text('Answer Review'), findsOneWidget);
    expect(find.text('Target: Answer to: "Parent title"'), findsOneWidget);
  });

  testWidgets('unknown targets fall back to shortened ids', (tester) async {
    await tester.pumpWidget(_host([
      _audit(targetId: 'question-abcdefgh-xyz'),
      _audit(id: 'a2', targetType: 'answer', targetId: 'answer-12345678'),
    ]));
    expect(find.text('Target: Question #Learner (question)'), findsOneWidget);
    expect(find.text('Target: Answer #Learner (answer-1)'), findsOneWidget);
  });

  testWidgets('author feedback and internal notes render only when present',
      (tester) async {
    await tester.pumpWidget(_host([
      _audit(
        action: 'reject',
        reviewerId: null,
        notes: 'Add citations.',
        internalNotes: 'Policy check.',
      ),
      _audit(id: 'a2', targetId: 'q-2'),
    ]));
    expect(find.text('REJECT'), findsOneWidget);
    expect(find.text('Reviewer: System'), findsOneWidget);
    expect(find.text('Author Feedback: Add citations.'), findsOneWidget);
    expect(find.text('Internal Notes: Policy check.'), findsOneWidget);
    expect(find.textContaining('Author Feedback:'), findsOneWidget);
    expect(find.textContaining('Internal Notes:'), findsOneWidget);
  });
}
