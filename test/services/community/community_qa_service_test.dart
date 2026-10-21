import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/services/community/community_qa_service.dart';

void main() {
  group('ECO-01 & ECO-02: Community Domain Models', () {
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

  group('ECO-02: Pilot FAQ Seeding & Offline Fallback', () {
    test('returns 18 curated demonstration FAQs across Literacy, Workplace Safety, and Florida Licensure when client is offline', () async {
      final service = CommunityQaService();
      final seeds = await service.fetchSeedFaqs();

      expect(seeds.length, 18);
      expect(seeds.every((s) => s.isSeeded), isTrue);

      // Verify representations of all 3 priority domains
      expect(seeds.any((s) => s.conceptId == 'literacy.cvc.basics'), isTrue);
      expect(seeds.any((s) => s.conceptId == 'workplace.safety.ppe'), isTrue);
      expect(seeds.any((s) => s.conceptId == 'licensure.cosmetology.ce'), isTrue);
      expect(seeds.any((s) => s.conceptId == 'licensure.cna.renewal'), isTrue);
      expect(seeds.any((s) => s.conceptId == 'licensure.real_estate.post_licensing'), isTrue);

      // Verify absence of fabricated engagement metrics and presence of offline-demo author
      for (final s in seeds) {
        expect(s.authorId, 'offline-demo');
        expect(s.upvoteCount, 0);
        expect(s.viewCount, 0);
        expect(s.answerCount, 1);
      }
    });

    test('filters offline seed FAQs by conceptId across domains', () async {
      final service = CommunityQaService();

      final cvcSeeds = await service.fetchSeedFaqs(conceptId: 'literacy.cvc.basics');
      expect(cvcSeeds.length, 1);
      expect(cvcSeeds.first.conceptId, 'literacy.cvc.basics');
      expect(cvcSeeds.first.title, contains('CVC pattern'));

      final ppeSeeds = await service.fetchSeedFaqs(conceptId: 'workplace.safety.ppe');
      expect(ppeSeeds.length, 1);
      expect(ppeSeeds.first.conceptId, 'workplace.safety.ppe');
      expect(ppeSeeds.first.title, contains('Personal Protective Equipment'));

      final ceSeeds = await service.fetchSeedFaqs(conceptId: 'licensure.cosmetology.ce');
      expect(ceSeeds.length, 1);
      expect(ceSeeds.first.conceptId, 'licensure.cosmetology.ce');
      expect(ceSeeds.first.title, contains('Florida Cosmetology'));
    });

    test('returns verified offline answers for offline seed FAQs', () async {
      final service = CommunityQaService();

      final answers = await service.fetchAnswersForQuestion('seed-faq-001');
      expect(answers.length, 1);
      expect(answers.first.questionId, 'seed-faq-001');
      expect(answers.first.isAccepted, isTrue);
      expect(answers.first.bodyMarkdown, contains('Consonant-Vowel-Consonant'));
      expect(answers.first.upvoteCount, 0);
    });
  });
}
