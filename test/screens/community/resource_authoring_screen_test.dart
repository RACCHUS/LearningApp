import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/community/community_resource_service.dart';
import 'package:learning_pwa/screens/community/resource_authoring_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ResourceAuthoringScreen generates AI draft and saves draft',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = CommunityResourceService();

    await tester.pumpWidget(
      MaterialApp(
        home: ResourceAuthoringScreen(
          resourceService: service,
          authorId: 'ed_test_author',
          authorName: 'Alex Educator',
          authorHeadline: 'OSHA Trainer',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Author New Resource'), findsOneWidget);
    expect(find.byKey(const Key('ai_draft_button')), findsOneWidget);

    // Enter topic
    await tester.enterText(
        find.byKey(const Key('resource_topic_field')), 'OSHA PPE Controls');
    await tester.pumpAndSettle();

    // Tap AI draft button
    await tester.tap(find.byKey(const Key('ai_draft_button')));
    await tester.pumpAndSettle();

    // Verify title was populated
    final titleField = tester.widget<TextField>(
      find.byKey(const Key('resource_title_field')),
    );
    expect(titleField.controller?.text, contains('Guide to OSHA PPE Controls'));

    // Tap Add Citation button to test citation dialog
    await tester.tap(find.byKey(const Key('add_citation_button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Regulatory Citation'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Authority Code'), '29 CFR 1910.133');
    await tester.enterText(
        find.widgetWithText(TextField, 'Standard / Title'), 'Eye Protection');
    await tester.tap(find.widgetWithText(FilledButton, 'Add Citation'));
    await tester.pumpAndSettle();

    expect(find.textContaining('29 CFR 1910.133'), findsOneWidget);

    // Tap Save Draft
    await tester.ensureVisible(find.byKey(const Key('save_draft_button')));
    await tester.tap(find.byKey(const Key('save_draft_button')));
    await tester.pumpAndSettle();

    final drafts = await service.fetchAuthorResources('ed_test_author');
    expect(drafts, isNotEmpty);
    expect(drafts.first.topic, equals('OSHA PPE Controls'));
  });
}

