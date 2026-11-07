import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/services/community/seo_metadata_service.dart';

void main() {
  group('SeoMetadataService (ECO-01, Priority 5 Discovery Boundary)', () {
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

    test('generates compliant Schema.org QAPage JSON-LD for published seed FAQs', () {
      final jsonLd = SeoMetadataService.generateQaPageJsonLd(
        question: publishedSeedQuestion,
        answers: [publishedAnswer],
      );

      final parsed = jsonDecode(jsonLd) as Map<String, dynamic>;
      expect(parsed['@context'], equals('https://schema.org'));
      expect(parsed['@type'], equals('QAPage'));

      final mainEntity = parsed['mainEntity'] as Map<String, dynamic>;
      expect(mainEntity['@type'], equals('Question'));
      expect(mainEntity['name'], equals('What are CVC words in phonics?'));

      final accepted = mainEntity['acceptedAnswer'] as Map<String, dynamic>;
      expect(accepted['@type'], equals('Answer'));
      expect(accepted['text'], equals('CVC words have short vowel sounds between consonants.'));
    });

    test('strictly forbids generating public JSON-LD for private learner drafts', () {
      expect(
        () => SeoMetadataService.generateQaPageJsonLd(
          question: privateDraftQuestion,
          answers: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('generates OpenGraph tags for published seed FAQ with index/follow', () {
      final tags = SeoMetadataService.generateOpenGraphTags(question: publishedSeedQuestion);

      expect(tags['og:title'], equals('What are CVC words in phonics?'));
      expect(tags['robots'], equals('index, follow'));
      expect(tags['og:url'], equals('https://app.learningapp.io/faqs/seed-faq-001'));
    });

    test('shields private learner draft from search indexing via noindex robots tag', () {
      final tags = SeoMetadataService.generateOpenGraphTags(question: privateDraftQuestion);

      expect(tags['robots'], equals('noindex, nofollow'));
      expect(tags['og:title'], isNull);
    });
  });
}
