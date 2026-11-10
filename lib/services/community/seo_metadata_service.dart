import 'dart:convert';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';

/// Editorial metadata for published curated content (ECO-01).
///
/// Published curated answers are NOT automatically eligible for QAPage rich
/// results: this app does not expose a verified public route with a way to
/// submit alternative answers. Never suggest otherwise in JSON-LD.
///
/// This helper is for internal/potential public editorial metadata only.
/// Actual indexing must wait for reviewed, server-rendered public HTML and a
/// verified canonical URL; draft and private learner records are rejected.
class SeoMetadataService {
  // Retained for backward compatibility; do not presume these paths return
  // public HTML merely because a catalog entry exists.
  static const String baseUrl = 'https://app.learningapp.io';

  /// Plain WebPage JSON-LD with no QAPage/FAQPage, artificial vote counts or
  /// invented public URL. Only accepted/published curated content is included.
  static String generateEditorialWebPageJsonLd({
    required CommunityQuestion question,
    required List<CommunityAnswer> answers,
  }) {
    if (question.status != 'published' || !question.isSeeded) {
      throw ArgumentError(
        'Editorial metadata is restricted to published curated content. '
        'Private or under-review learner materials cannot be indexed.',
      );
    }
    final safeAnswers = answers.where((a) => a.status == 'published');
    final accepted = safeAnswers.where((a) => a.isAccepted).firstOrNull ??
        safeAnswers.firstOrNull;

    final page = <String, dynamic>{
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      'name': question.title,
      'description': question.bodyMarkdown,
      'datePublished': question.createdAt.toIso8601String(),
      if (accepted != null) 'text': accepted.bodyMarkdown,
    };
    return jsonEncode(page);
  }

  /// Deprecated name retained so legacy consumers continue to compile.
  /// It intentionally returns editorial WebPage rather than ineligible QAPage.
  @Deprecated('Curated FAQs are not QAPage eligible; use generateEditorialWebPageJsonLd.')
  static String generateQaPageJsonLd({
    required CommunityQuestion question,
    required List<CommunityAnswer> answers,
  }) =>
      generateEditorialWebPageJsonLd(question: question, answers: answers);

  /// Social preview metadata is not proof that a public HTML URL exists.
  /// Until the static site publishes and verifies an exact article route,
  /// preserve noindex and omit the unverified og:url entirely.
  static Map<String, String> generateOpenGraphTags({
    required CommunityQuestion question,
  }) {
    if (question.status != 'published' || !question.isSeeded) {
      return {'robots': 'noindex, nofollow'};
    }
    return {
      'og:title': question.title,
      'og:description': question.bodyMarkdown,
      'og:type': 'article',
      'twitter:card': 'summary',
      'twitter:title': question.title,
      'twitter:description': question.bodyMarkdown,
      'robots': 'noindex, follow',
    };
  }
}
