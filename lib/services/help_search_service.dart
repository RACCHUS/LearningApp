import 'package:learning_pwa/models/help_topic.dart';

class HelpSearchService {
  const HelpSearchService();

  List<HelpTopic> search(List<HelpTopic> topics, String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return List.unmodifiable(topics);

    final tokens = normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();

    final scored = <({HelpTopic topic, int score, int index})>[];
    for (var i = 0; i < topics.length; i++) {
      final topic = topics[i];
      final title = _normalize(topic.title);
      final keywords = _normalize(topic.keywords.join(' '));
      final summary = _normalize(topic.summary);
      final body = _normalize(topic.body);

      var score = 0;
      for (final token in tokens) {
        if (title.contains(token)) {
          score += 8;
        } else if (keywords.contains(token)) {
          score += 6;
        } else if (summary.contains(token)) {
          score += 3;
        } else if (body.contains(token)) {
          score += 1;
        } else {
          score = -1;
          break;
        }
      }

      if (score >= 0) scored.add((topic: topic, score: score, index: i));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.index.compareTo(b.index);
    });
    return scored.map((e) => e.topic).toList(growable: false);
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
