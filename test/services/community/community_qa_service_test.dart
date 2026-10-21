import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';

void main() {
  group('ECO-01: Community Domain Models', () {
    test('CommunityQuestion serialization and state flags', () {
      final question = CommunityQuestion(
        id: 'q-101',
        authorId: 'auth-user-1',
        title: 'How does phonics blending work?',
        bodyMarkdown: 'Detailed explanation of phonics blending in CVC words.',
        status: 'draft',
        isSeeded: false,
        conceptId: 'literacy.cvc.basics',
        viewCount: 10,
        upvoteCount: 3,
        answerCount: 1,
        createdAt: DateTime.parse('2026-10-22T10:00:00Z'),
        updatedAt: DateTime.parse('2026-10-22T10:30:00Z'),
      );

      expect(question.isDraft, isTrue);
      expect(question.isPublished, isFalse);
      expect(question.isUnderReview, isFalse);

      final json = question.toJson();
      final revived = CommunityQuestion.fromJson(json);

      expect(revived.id, 'q-101');
      expect(revived.authorId, 'auth-user-1');
      expect(revived.title, 'How does phonics blending work?');
      expect(revived.conceptId, 'literacy.cvc.basics');
      expect(revived.upvoteCount, 3);
      expect(revived.answerCount, 1);
    });

    test('CommunityAnswer serialization and AI provenance', () {
      final answer = CommunityAnswer(
        id: 'ans-201',
        questionId: 'q-101',
        authorId: 'auth-user-2',
        bodyMarkdown: 'Blending requires smoothly transitioning from the first sound to the next without pausing.',
        isAiGenerated: true,
        aiModelName: 'gemini-1.5-pro',
        isAccepted: true,
        status: 'published',
        upvoteCount: 7,
        createdAt: DateTime.parse('2026-10-22T11:00:00Z'),
        updatedAt: DateTime.parse('2026-10-22T11:05:00Z'),
      );

      expect(answer.isPublished, isTrue);
      expect(answer.isAiGenerated, isTrue);
      expect(answer.aiModelName, 'gemini-1.5-pro');
      expect(answer.isAccepted, isTrue);

      final json = answer.toJson();
      final revived = CommunityAnswer.fromJson(json);

      expect(revived.id, 'ans-201');
      expect(revived.isAiGenerated, isTrue);
      expect(revived.aiModelName, 'gemini-1.5-pro');
      expect(revived.upvoteCount, 7);
    });
  });

  group('ECO-01: CommunityQaService Offline & Fallback', () {
    test('returns default demonstration FAQs without fabricated metrics when client is offline', () async {
      final service = CommunityQaService();
      final seeds = await service.fetchSeedFaqs();

      expect(seeds.isNotEmpty, isTrue);
      expect(seeds.any((s) => s.isSeeded), isTrue);
      expect(seeds.any((s) => s.conceptId == 'literacy.cvc.basics'), isTrue);

      // Verify absence of fabricated engagement metrics and presence of offline-demo author
      for (final s in seeds) {
        expect(s.authorId, 'offline-demo');
        expect(s.upvoteCount, 0);
        expect(s.viewCount, 0);
        expect(s.answerCount, 0);
      }
    });

    test('filters offline seed FAQs by conceptId', () async {
      final service = CommunityQaService();
      final cvcSeeds = await service.fetchSeedFaqs(conceptId: 'literacy.cvc.basics');

      expect(cvcSeeds.length, 1);
      expect(cvcSeeds.first.conceptId, 'literacy.cvc.basics');
      expect(cvcSeeds.first.title, contains('CVC pattern'));
      expect(cvcSeeds.first.authorId, 'offline-demo');
      expect(cvcSeeds.first.upvoteCount, 0);
    });
  });
}
