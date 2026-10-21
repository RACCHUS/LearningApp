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
      expect(ppeSeeds.first.title, contains('Hierarchy of Controls'));

      final ceSeeds = await service.fetchSeedFaqs(conceptId: 'licensure.cosmetology.ce');
      expect(ceSeeds.length, 1);
      expect(ceSeeds.first.conceptId, 'licensure.cosmetology.ce');
      expect(ceSeeds.first.title, contains('Florida Cosmetology'));
    });

    test('returns empty list for unknown conceptId during offline fallback instead of unrelated FAQs', () async {
      final service = CommunityQaService();
      final unknownSeeds = await service.fetchSeedFaqs(conceptId: 'unrelated.unknown.concept');
      expect(unknownSeeds, isEmpty);
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

    test('verifies Florida DBPR regulatory accuracy in offline licensing FAQ answers', () async {
      final service = CommunityQaService();

      // 1. Florida Cosmetology CE (seed-faq-013)
      final cosmoAnswers = await service.fetchAnswersForQuestion('seed-faq-013');
      expect(cosmoAnswers.length, 1);
      final cosmoBody = cosmoAnswers.first.bodyMarkdown;
      expect(cosmoBody, contains('10 hours'));
      expect(cosmoBody, contains('Rule 61G5-20.002, Florida Administrative Code'));
      expect(cosmoBody, contains('Group 1 expires October 31 of odd-numbered years'));
      expect(cosmoBody, contains('Group 2 expires October 31 of even-numbered years'));
      expect(cosmoBody, contains('0.5 hour of Occupational Safety and Health Administration (OSHA)'));
      expect(cosmoBody, contains('0.5 hour of Workers\' Compensation'));
      expect(cosmoBody, contains('Platform-curated educational reference'));

      // 2. Florida Electrical Endorsement (seed-faq-016)
      final elecAnswers = await service.fetchAnswersForQuestion('seed-faq-016');
      expect(elecAnswers.length, 1);
      final elecBody = elecAnswers.first.bodyMarkdown;
      expect(elecBody, contains('Florida does not have reciprocal licensing agreements with any other state'));
      expect(elecBody, contains('Section 489.511, Florida Statutes'));
      expect(elecBody, contains('Licensure by Endorsement'));
      expect(elecBody, contains('substantially equivalent'));
      expect(elecBody, contains('10 years'));
      expect(elecBody, contains('Platform-curated educational reference'));

      // 3. Florida General Contractor Qualifications (seed-faq-018)
      final cgcAnswers = await service.fetchAnswersForQuestion('seed-faq-018');
      expect(cgcAnswers.length, 1);
      final cgcBody = cgcAnswers.first.bodyMarkdown;
      expect(cgcBody, contains('structures of not less than four stories'));
      expect(cgcBody, contains('Section 489.111, Florida Statutes'));
      expect(cgcBody, contains('Rule 61G4-15.001'));
      expect(cgcBody, contains('Platform-curated educational reference'));
    });
  });
}
