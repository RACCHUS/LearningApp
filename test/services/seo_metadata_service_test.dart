import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/services/community/seo_metadata_service.dart';

void main() {
  group('SeoMetadataService: no ineligible QAPage or phantom URLs', () {
    final now = DateTime.utc(2026, 10, 31);

    final publishedSeedQuestion = CommunityQuestion(
      id: 'seed-faq-001',
      authorId: 'curated-seed',
      title: 'What are CVC words in phonics?',
      bodyMarkdown: 'Detailed explanation of consonant-vowel-consonant decoding patterns.',
      status: 'published',
      isSeeded: true,
      createdAt: now,
      updatedAt: now,
    );

    final publishedAnswer = CommunityAnswer(
      id: 'ans-001',
      questionId: 'seed-faq-001',
      authorId: 'curated-seed',
      bodyMarkdown: 'CVC words have short vowel sounds between consonants.',
      isAiGenerated: false,
      isAccepted: true,
      status: 'published',
      upvoteCount: 15,
      createdAt: now,
      updatedAt: now,
    );

    final privateDraftQuestion = CommunityQuestion(
      id: 'draft-q-123',
      authorId: 'user-a',
      title: 'Private draft question',
      bodyMarkdown: 'This is an unapproved private learner draft.',
      status: 'draft',
      isSeeded: false,
      createdAt: now,
      updatedAt: now,
    );

    test('curated content uses ordinary WebPage, not QAPage or fabricated ranking', () {
      final jsonLd = SeoMetadataService.generateEditorialWebPageJsonLd(
        question: publishedSeedQuestion,
        answers: [publishedAnswer],
      );
      final parsed = jsonDecode(jsonLd) as Map<String, dynamic>;
      expect(parsed['@context'], equals('https://schema.org'));
      expect(parsed['@type'], equals('WebPage'));
      expect(parsed['name'], equals('What are CVC words in phonics?'));
      expect(parsed['text'], equals('CVC words have short vowel sounds between consonants.'));
      expect(parsed.containsKey('mainEntity'), false);
      expect(parsed.containsKey('acceptedAnswer'), false);
      expect(parsed.containsKey('upvoteCount'), false);
      expect(parsed.containsKey('url'), false);
      expect(jsonLd, isNot(contains('QAPage')));
      expect(jsonLd, isNot(contains('FAQPage')));
    });

    test('legacy method remains callable but no longer claims QAPage eligibility', () {
      // ignore: deprecated_member_use_from_same_package
      final jsonLd = SeoMetadataService.generateQaPageJsonLd(
        question: publishedSeedQuestion,
        answers: [publishedAnswer],
      );
      expect((jsonDecode(jsonLd) as Map<String, dynamic>)['@type'], 'WebPage');
    });

    test('private learner drafts never get public editorial JSON-LD', () {
      expect(
        () => SeoMetadataService.generateEditorialWebPageJsonLd(
          question: privateDraftQuestion,
          answers: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('published seed entries stay noindex until a real public route is verified', () {
      final tags = SeoMetadataService.generateOpenGraphTags(
          question: publishedSeedQuestion);
      expect(tags['og:title'], 'What are CVC words in phonics?');
      expect(tags['robots'], 'noindex, follow');
      expect(tags.containsKey('og:url'), false);
    });

    test('private drafts have no social preview details', () {
      final tags = SeoMetadataService.generateOpenGraphTags(
          question: privateDraftQuestion);
      expect(tags['robots'], 'noindex, nofollow');
      expect(tags['og:title'], isNull);
      expect(tags.containsKey('og:url'), false);
    });
  });
}
