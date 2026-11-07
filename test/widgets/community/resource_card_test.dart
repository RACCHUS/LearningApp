import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/community_resource.dart';
import 'package:learning_pwa/widgets/community/resource_card.dart';

void main() {
  testWidgets('ResourceCard renders content type, title, author, and citations',
      (tester) async {
    bool tapped = false;

    final resource = CommunityResource(
      id: 'res_card_test_1',
      authorId: 'ed_101',
      authorName: 'Sarah Jenkins, CSP',
      subjectId: 'workplace_safety',
      topic: 'PPE Standards',
      title: 'PPE Selection & Inspection Checklist',
      description: 'Comprehensive guide for selecting eye, head, and lung PPE.',
      contentType: CommunityResourceContentType.studyGuide,
      status: CommunityResourceStatus.published,
      citations: const [
        ResourceCitation(
          id: 'cit_1',
          title: 'General PPE Requirements',
          authorityCode: '29 CFR 1910.132',
          verified: true,
        ),
      ],
      guideSections: const [
        StudyGuideSection(
          id: 's1',
          heading: 'Hierarchy of Controls',
          bodyMarkdown: 'PPE is the last line of defense.',
        ),
      ],
      feedbackCount: 15,
      averageRating: 4.8,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResourceCard(
            resource: resource,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Study Guide'), findsOneWidget);
    expect(find.text('PPE Selection & Inspection Checklist'), findsOneWidget);
    expect(find.text('Sarah Jenkins, CSP'), findsOneWidget);
    expect(find.text('29 CFR 1910.132'), findsOneWidget);
    expect(find.text('1 sections'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);

    await tester.tap(find.byType(ResourceCard));
    expect(tapped, isTrue);
  });
}

