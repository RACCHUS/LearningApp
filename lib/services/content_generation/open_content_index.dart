import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:learning_pwa/services/content_generation/reuse_gate.dart';

/// Sections of approved open textbooks, bundled with the app so the
/// Reuse Gate can offer them before anyone generates content with AI
/// (master plan v2.6 §4.3 steps 3-4). Built by
/// `tool/build_open_content_index.py` from sources registered in
/// `data/content_sources.json`; the app never fetches the books itself.
class OpenContentIndex {
  static const assetPath = 'assets/open_content/index.json';

  /// Human-readable license names for the credit line.
  static const _licenseNames = {
    'openstax-college-algebra-1e': 'CC BY 4.0',
    'openstax-prealgebra-1e': 'CC BY 4.0',
    'openstax-psychology-1e': 'CC BY 4.0',
  };

  static Future<List<ReuseSource>> load(AssetBundle bundle) async {
    try {
      return parse(jsonDecode(await bundle.loadString(assetPath)));
    } catch (_) {
      return const [];
    }
  }

  /// Turns the index into Reuse Gate sources. Entries without an https
  /// URL or a title are skipped rather than shown half-formed.
  static List<ReuseSource> parse(Object? json) {
    if (json is! Map || json['sections'] is! List) return const [];
    final out = <ReuseSource>[];
    for (final raw in json['sections'] as List) {
      if (raw is! Map) continue;
      final url = '${raw['url'] ?? ''}';
      final title = '${raw['title'] ?? ''}'.trim();
      final number = '${raw['number'] ?? ''}'.trim();
      final sourceId = '${raw['source_id'] ?? ''}';
      if (!url.startsWith('https://') || title.isEmpty) continue;
      final book = '${raw['book'] ?? ''}'.trim();
      final license = _licenseNames[sourceId];
      out.add(
        ReuseSource(
          kind: ReuseSourceKind.openSection,
          id: url,
          title: number.isEmpty ? title : '$number $title',
          text: '${raw['chapter'] ?? ''} ${raw['subject'] ?? ''} $book',
          tags: [
            for (final t in (raw['key_terms'] as List? ?? const []))
              if (t is String) t,
          ],
          url: url,
          credit: [
            'OpenStax $book',
            if (license != null) license,
          ].join(' · '),
        ),
      );
    }
    return out;
  }
}
