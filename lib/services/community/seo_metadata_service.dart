import 'dart:convert';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';

/// Service generating structured OpenGraph metadata and Schema.org QAPage JSON-LD (ECO-01, Priority 5).
///
/// Enforces discovery boundaries: only published, curated seed FAQs may be exported for public web indexing.
class SeoMetadataService {
  static const String baseUrl = 'https://app.learningapp.io';

  /// Generates Schema.org `QAPage` JSON-LD representation for a published question and answer.
  ///
  /// Throws [ArgumentError] if an unapproved or private draft is passed, preserving discovery invariants.
  static String generateQaPageJsonLd({
    required CommunityQuestion question,
    required List<CommunityAnswer> answers,
  }) {
    if (question.status != 'published' || !question.isSeeded) {
      throw ArgumentError(
        'SEO metadata generation is restricted exclusively to published seed FAQs. '
        'Private or under-review learner content cannot be indexed.',
      );
    }

    final acceptedAnswer = answers.where((a) => a.isAccepted).firstOrNull ?? answers.firstOrNull;

    final data = <String, dynamic>{
      '@context': 'https://schema.org',
      '@type': 'QAPage',
      'mainEntity': {
        '@type': 'Question',
        'name': question.title,
        'text': question.bodyMarkdown,
        'answerCount': answers.length,
        'dateCreated': question.createdAt.toIso8601String(),
        if (acceptedAnswer != null)
          'acceptedAnswer': {
            '@type': 'Answer',
            'text': acceptedAnswer.bodyMarkdown,
            'dateCreated': acceptedAnswer.createdAt.toIso8601String(),
            'upvoteCount': acceptedAnswer.upvoteCount,
          },
      },
    };

    return jsonEncode(data);
  }

  /// Generates OpenGraph and Twitter card HTML tags for social link unfurls.
  static Map<String, String> generateOpenGraphTags({
    required CommunityQuestion question,
  }) {
    if (question.status != 'published' || !question.isSeeded) {
      return {
        'robots': 'noindex, nofollow',
      };
    }

    return {
      'og:title': question.title,
      'og:description': question.bodyMarkdown,
      'og:type': 'article',
      'og:url': '$baseUrl/faqs/${question.id}',
      'twitter:card': 'summary',
      'twitter:title': question.title,
      'twitter:description': question.bodyMarkdown,
      'robots': 'index, follow',
    };
  }
}
