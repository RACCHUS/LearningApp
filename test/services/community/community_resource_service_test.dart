import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/community_resource.dart';
import 'package:learning_pwa/services/community/community_resource_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunityResourceService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initializes with seed resources when storage is empty', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = CommunityResourceService(prefs: prefs);

      expect(service.resources, isNotEmpty);
      expect(service.resources.any((r) => r.id.contains('osha')), isTrue);
      expect(service.resources.any((r) => r.id.contains('fl_driver')), isTrue);
    });

    test('fetches resources filtered by subject and status', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = CommunityResourceService(prefs: prefs);

      final oshaPublished = await service.fetchResources(
        subjectId: 'workplace_safety',
        status: CommunityResourceStatus.published,
      );
      expect(oshaPublished, isNotEmpty);
      expect(oshaPublished.every((r) => r.subjectId == 'workplace_safety'), isTrue);
      expect(oshaPublished.every((r) => r.status == CommunityResourceStatus.published), isTrue);

      final drafts = await service.fetchResources(status: CommunityResourceStatus.draft);
      expect(drafts, isEmpty); // Seeds are published
    });

    test('saves new draft resource and persists to storage', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = CommunityResourceService(prefs: prefs);

      final newResource = CommunityResource(
        id: 'res_test_custom_1',
        authorId: 'ed_custom_99',
        authorName: 'Alex Rivera',
        subjectId: 'workplace_safety',
        topic: 'Ladder Safety Standard',
        title: '3-Point Contact Ladder Safety Guide',
        contentType: CommunityResourceContentType.lesson,
        status: CommunityResourceStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await service.saveResourceDraft(newResource);
      expect(saved.status, equals(CommunityResourceStatus.draft));

      final retrieved = await service.getResourceById('res_test_custom_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('3-Point Contact Ladder Safety Guide'));

      final authorResources = await service.fetchAuthorResources('ed_custom_99');
      expect(authorResources.length, equals(1));
    });

    test('submits draft for review and approves resource', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = CommunityResourceService(prefs: prefs);

      final draft = CommunityResource(
        id: 'res_review_lifecycle_1',
        authorId: 'ed_100',
        authorName: 'Dr. Smith',
        subjectId: 'food_and_health',
        topic: 'Food Storage Temperature Rules',
        title: 'FDA Danger Zone Guide',
        contentType: CommunityResourceContentType.studyGuide,
        status: CommunityResourceStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await service.saveResourceDraft(draft);

      final submitted = await service.submitResourceForReview('res_review_lifecycle_1');
      expect(submitted.status, equals(CommunityResourceStatus.submittedForReview));

      final approved = await service.approveResource('res_review_lifecycle_1');
      expect(approved.status, equals(CommunityResourceStatus.published));
      expect(approved.publishedAt, isNotNull);
    });

    test('generates AI draft with regulatory citations and synthetic flag', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = CommunityResourceService(prefs: prefs);

      final draft = await service.generateAiDraft(
        topic: 'OSHA Hazard Communication',
        subjectId: 'workplace_safety',
        contentType: CommunityResourceContentType.flashcardSet,
        authorId: 'ed_author_test',
        authorName: 'Jordan Lee',
      );

      expect(draft.isAiAssisted, isTrue);
      expect(draft.status, equals(CommunityResourceStatus.draft));
      expect(draft.citations, isNotEmpty);
      expect(draft.citations.first.authorityCode, contains('29 CFR 1910'));
      expect(draft.flashcards, isNotEmpty);
    });
  });
}

