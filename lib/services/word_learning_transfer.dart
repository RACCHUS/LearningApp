import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/word_learning.dart';
import 'word_list_service.dart';

/// Explicit, portable Word Learning backup used when Google is already tied
/// to another account. Never contains Supabase tokens, passwords, or sessions.
/// A backup may include children's names: the user must initiate its transfer.
class WordLearningTransfer {
  static const format = 'learningapp-word-learning';
  static const version = 1;
  static const maxChars = 2000000;
  static const maxLists = 100;
  static const maxEntries = 10000;
  static const maxReviews = 10000;

  final SupabaseClient _client;
  final WordListService _lists;

  WordLearningTransfer({SupabaseClient? client, WordListService? lists})
      : _client = client ?? Supabase.instance.client,
        _lists = lists ?? WordListService(client: client);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Sign in or Continue as Guest first.');
    }
    return id;
  }

  /// Create an explicit user-managed backup. Sensitive names are never
  /// transmitted to a separate analytics or word-validation provider.
  Future<String> exportJson() async {
    final userId = _userId;
    final lists = await _lists.getLists();
    if (lists.length > maxLists) {
      throw StateError('Too many lists for a single backup.');
    }
    var total = 0;
    final exported = <Map<String, dynamic>>[];
    for (final list in lists) {
      final entries = await _lists.getEntries(list.id);
      total += entries.length;
      if (total > maxEntries) {
        throw StateError('Too many words for a single backup.');
      }
      exported.add({
        'source_id': list.id,
        'title': list.title,
        'description': list.description,
        'entries': [
          for (final entry in entries)
            {
              'word': entry.word,
              'form_key': entry.formKey,
              'locale': entry.locale,
              'entry_kind': entry.kind.dbValue,
              'case_policy': entry.casePolicy.dbValue,
              'accepted_forms': entry.acceptedForms,
              'pronunciation_hint': entry.pronunciationHint,
              'sort_order': entry.sortOrder,
            },
        ],
      });
    }
    final rows = await _client.from('review_items')
        .select('content_id,title,repetition_level,ease_factor,'
            'next_review_date,last_reviewed_at,total_reviews,correct_reviews')
        .eq('user_id', userId)
        .eq('content_type', 'word_skill');
    if ((rows as List).length > maxReviews) {
      throw StateError('Too much review history for a single backup.');
    }
    final payload = {
      'format': format,
      'version': version,
      'source_user_id': userId,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'lists': exported,
      'reviews': rows,
    };
    final json = jsonEncode(payload);
    if (json.length > maxChars) {
      throw StateError('Word backup is too large to transfer by text.');
    }
    return json;
  }

  /// Decode strictly before any database writes. Unknown schema revisions
  /// fail closed rather than importing attacker-controlled table rows.
  static Map<String, dynamic> validate(String source) {
    if (source.isEmpty || source.length > maxChars) {
      throw const FormatException('Invalid word backup size.');
    }
    final parsed = jsonDecode(source);
    if (parsed is! Map<String, dynamic> ||
        parsed['format'] != format ||
        parsed['version'] != version) {
      throw const FormatException('Not a supported Word Learning backup.');
    }
    final sourceUserId = parsed['source_user_id'];
    final uuid = RegExp(r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$');
    if (sourceUserId is! String || !uuid.hasMatch(sourceUserId)) {
      throw const FormatException('Missing source account identity.');
    }
    final rawLists = parsed['lists'];
    final rawReviews = parsed['reviews'];
    if (rawLists is! List || rawLists.length > maxLists ||
        rawReviews is! List || rawReviews.length > maxReviews) {
      throw const FormatException('Invalid backup list or review counts.');
    }

    final seenListIds = <String>{};
    var count = 0;
    for (final raw in rawLists) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid list in backup.');
      }
      final id = raw['source_id'];
      final title = raw['title'];
      if (id is! String || !uuid.hasMatch(id) || !seenListIds.add(id) ||
          title is! String || title.trim().isEmpty || title.length > 160) {
        throw const FormatException('Invalid list identity or title.');
      }
      if (raw['description'] != null &&
          (raw['description'] is! String ||
           (raw['description'] as String).length > 2000)) {
        throw const FormatException('Invalid list description.');
      }
      final entries = raw['entries'];
      if (entries is! List) {
        throw const FormatException('Invalid backup entries.');
      }
      count += entries.length;
      if (count > maxEntries) {
        throw const FormatException('Too many backup entries.');
      }
      final seenForms = <String>{};
      for (final rawEntry in entries) {
        if (rawEntry is! Map<String, dynamic>) {
          throw const FormatException('Invalid word entry.');
        }
        final word = rawEntry['word'];
        final locale = rawEntry['locale'];
        final key = rawEntry['form_key'];
        final kindName = rawEntry['entry_kind'];
        final caseName = rawEntry['case_policy'];
        if (word is! String || locale != 'en-US' ||
            key is! String || kindName is! String || caseName is! String ||
            !WordEntryKind.values.any((e) => e.dbValue == kindName) ||
            !WordCasePolicy.values.any((e) => e.dbValue == caseName)) {
          throw const FormatException('Invalid word identity.');
        }
        final calculated = WordFormIdentity.formKey(
          word: word,
          locale: locale as String,
          kind: WordEntryKind.parse(kindName),
          casePolicy: WordCasePolicy.parse(caseName),
        );
        if (key != calculated || !seenForms.add(key)) {
          throw const FormatException('Inconsistent or duplicate word identity.');
        }
        final accepted = rawEntry['accepted_forms'];
        final hint = rawEntry['pronunciation_hint'];
        final order = rawEntry['sort_order'];
        if (accepted is! List || accepted.length > 8 ||
            accepted.any((e) => e is! String || e.isEmpty || e.length > 160) ||
            (hint != null && (hint is! String || hint.length > 160)) ||
            order is! int || order < 0 || order > maxEntries) {
          throw const FormatException('Invalid word preferences.');
        }
      }
    }
    final seenReviews = <String>{};
    final content = RegExp(
      r'^word:v1:en-US:(ordinary|proper_name|custom):(ignore_case|exact):[A-Za-z0-9_-]+:spelling$',
    );
    for (final raw in rawReviews) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid spelling review.');
      }
      final id = raw['content_id'];
      final title = raw['title'];
      final level = raw['repetition_level'];
      final ease = raw['ease_factor'];
      final total = raw['total_reviews'];
      final correct = raw['correct_reviews'];
      final next = raw['next_review_date'];
      final last = raw['last_reviewed_at'];
      if (id is! String || id.length > 1200 || !content.hasMatch(id) ||
          !seenReviews.add(id) ||
          title is! String || title.isEmpty || title.length > 160 ||
          level is! int || level < 0 || level > 100 ||
          ease is! num || ease < 1.3 || ease > 2.5 ||
          total is! int || total < 0 ||
          correct is! int || correct < 0 || correct > total ||
          next is! String || DateTime.tryParse(next) == null ||
          (last != null && (last is! String || DateTime.tryParse(last) == null))) {
        throw const FormatException('Invalid spelling review history.');
      }

      // A syntactically valid ID is insufficient: ensure the exported review
      // really belongs to its stated target word, including the locale,
      // proper-name policy and case-sensitivity. Reviews remain portable even
      // when their original list has since been deleted.
      final match = content.firstMatch(id);
      final kind = WordEntryKind.parse(match!.group(1));
      final casePolicy = WordCasePolicy.parse(match.group(2));
      final expectedId = WordFormIdentity.spellingReviewContentId(
        WordFormIdentity.formKey(
          word: title,
          kind: kind,
          casePolicy: casePolicy,
        ),
      );
      if (id != expectedId) {
        throw const FormatException('Spelling review does not match its word.');
      }
    }
    return parsed;
  }

  /// Import uses only the currently signed-in user's permissions and RLS.
  /// Existing destination lists/reviews are never overwritten. A retry uses
  /// import_origin and unique form/review keys so it cannot create duplicates.
  Future<WordTransferResult> importJson(String source) async {
    final payload = validate(source);
    final userId = _userId;
    if (payload['source_user_id'] == userId) {
      throw StateError('This backup already belongs to this account.');
    }
    var listsCreated = 0;
    var wordsCreated = 0;
    var reviewsCreated = 0;
    var conflictsPreserved = 0;
    for (final raw in payload['lists'] as List) {
      final list = raw as Map<String, dynamic>;
      final importOrigin = '${payload['source_user_id']}:${list['source_id']}';
      final existing = await _client.from('word_lists')
          .select('id')
          .eq('user_id', userId)
          .eq('import_origin', importOrigin)
          .maybeSingle();
      final String listId;
      if (existing == null) {
        final inserted = await _client.from('word_lists').insert({
          'user_id': userId,
          'title': list['title'],
          'description': list['description'],
          'import_origin': importOrigin,
        }).select('id').single();
        listId = inserted['id'] as String;
        listsCreated++;
      } else {
        listId = existing['id'] as String;
      }
      final oldEntries = await _lists.getEntries(listId);
      final keys = oldEntries.map((e) => e.formKey).toSet();
      final inserts = <Map<String, dynamic>>[];
      for (final rawEntry in list['entries'] as List) {
        final entry = rawEntry as Map<String, dynamic>;
        if (!keys.add(entry['form_key'] as String)) {
          conflictsPreserved++;
          continue;
        }
        inserts.add({
          'list_id': listId,
          'word': entry['word'],
          'form_key': entry['form_key'],
          'locale': entry['locale'],
          'entry_kind': entry['entry_kind'],
          'case_policy': entry['case_policy'],
          'accepted_forms': entry['accepted_forms'],
          'pronunciation_hint': entry['pronunciation_hint'],
          'sort_order': entry['sort_order'],
        });
      }
      if (inserts.isNotEmpty) {
        await _client.from('word_list_entries').upsert(inserts,
          onConflict: 'list_id,form_key', ignoreDuplicates: true);
        wordsCreated += inserts.length;
      }
    }
    final existingRows = await _client.from('review_items')
        .select('content_id').eq('user_id', userId)
        .eq('content_type', 'word_skill');
    final existingIds = (existingRows as List)
        .map((r) => (r as Map)['content_id'] as String).toSet();
    final newReviews = <Map<String, dynamic>>[];
    for (final raw in payload['reviews'] as List) {
      final review = raw as Map<String, dynamic>;
      final id = review['content_id'] as String;
      if (!existingIds.add(id)) {
        conflictsPreserved++;
        continue;
      }
      newReviews.add({
        'user_id': userId,
        'content_id': id,
        'content_type': 'word_skill',
        'lesson_id': null,
        'title': review['title'],
        'repetition_level': review['repetition_level'],
        'ease_factor': review['ease_factor'],
        'next_review_date': review['next_review_date'],
        'last_reviewed_at': review['last_reviewed_at'],
        'total_reviews': review['total_reviews'],
        'correct_reviews': review['correct_reviews'],
      });
    }
    if (newReviews.isNotEmpty) {
      await _client.from('review_items').upsert(newReviews,
        onConflict: 'user_id,content_id', ignoreDuplicates: true);
      reviewsCreated = newReviews.length;
    }
    return WordTransferResult(
      listsCreated: listsCreated,
      wordsCreated: wordsCreated,
      reviewsCreated: reviewsCreated,
      destinationConflictsPreserved: conflictsPreserved,
    );
  }
}

class WordTransferResult {
  final int listsCreated;
  final int wordsCreated;
  final int reviewsCreated;
  final int destinationConflictsPreserved;
  const WordTransferResult({
    required this.listsCreated,
    required this.wordsCreated,
    required this.reviewsCreated,
    required this.destinationConflictsPreserved,
  });
}
