import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/spaced_repetition.dart';
import '../models/word_learning.dart';
import 'spaced_repetition_service.dart';

/// Small W1 repository for private word lists. Supabase anonymous users are
/// authenticated and receive the same owner-scoped RLS rules as full accounts.
/// A truly signed-out/local guest import path is a separate W1 release gate.
class WordListService {
  final SupabaseClient _client;
  final SpacedRepetitionService _reviews;

  WordListService({
    SupabaseClient? client,
    SpacedRepetitionService? reviews,
  })  : _client = client ?? Supabase.instance.client,
        _reviews = reviews ?? SpacedRepetitionService(supabase: client);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Continue as Guest or sign in to save word lists.');
    }
    return id;
  }

  Future<List<WordList>> getLists() async {
    final rows = await _client.from('word_lists')
        .select('id,user_id,title,description')
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) =>
        WordList.fromJson(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<WordList> createList(String title) async {
    final clean = title.trim();
    if (clean.isEmpty || clean.length > 160) {
      throw ArgumentError('List title must contain 1–160 characters');
    }
    final row = await _client.from('word_lists')
        .insert({'user_id': _userId, 'title': clean})
        .select('id,user_id,title,description')
        .single();
    return WordList.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> renameList(String id, String title) async {
    final clean = title.trim();
    if (clean.isEmpty || clean.length > 160) {
      throw ArgumentError('List title must contain 1–160 characters');
    }
    await _client.from('word_lists').update({
      'title': clean,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', _userId);
  }

  Future<void> deleteList(String id) async {
    // FK cascade deletes memberships, never shared review_items.
    await _client.from('word_lists').delete().eq('user_id', _userId).eq('id', id);
  }

  Future<List<WordListEntry>> getEntries(String listId) async {
    // A single query can be capped by the Supabase Data API. Keep long lists
    // usable, and fail loudly instead of silently omitting words at the cap.
    const pageSize = 500;
    const maxEntriesPerList = 10000;
    final result = <WordListEntry>[];
    for (var offset = 0; offset <= maxEntriesPerList; offset += pageSize) {
      final rows = await _client.from('word_list_entries')
          .select('*')
          .eq('list_id', listId)
          .order('sort_order', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      result.addAll((rows as List)
          .map((r) => WordListEntry.fromJson(
              Map<String, dynamic>.from(r as Map))));
      if (result.length > maxEntriesPerList) {
        throw StateError('Word list is too large to load safely.');
      }
      if (rows.length < pageSize) break;
    }
    return result;
  }

  Future<int> addWords(
    String listId,
    String pastedWords, {
    WordEntryKind kind = WordEntryKind.ordinary,
    WordCasePolicy casePolicy = WordCasePolicy.ignoreCase,
  }) async {
    // Names containing an apostrophe or hyphen stay intact.
    final tokens = pastedWords.split(RegExp(r'[,;\n\r]+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    if (tokens.length > 100) {
      throw ArgumentError('Add up to 100 words at a time.');
    }
    final current = await getEntries(listId);
    final seen = current.map((e) => e.formKey).toSet();
    final inserts = <Map<String, dynamic>>[];
    for (final word in tokens) {
      final key = WordFormIdentity.formKey(
        word: word, kind: kind, casePolicy: casePolicy);
      if (!seen.add(key)) continue;
      inserts.add({
        'list_id': listId,
        'word': word,
        'form_key': key,
        'locale': 'en-US',
        'entry_kind': kind.dbValue,
        'case_policy': casePolicy.dbValue,
        'accepted_forms': <String>[],
        'sort_order': current.length + inserts.length,
      });
    }
    if (inserts.isNotEmpty) {
      await _client.from('word_list_entries').insert(inserts);
    }
    return inserts.length;
  }

  /// Editing the actual spelling never migrates mastery. A new form key
  /// identifies a new learning target; the previous review remains untouched
  /// and can still be reused through another list referencing that word.
  Future<void> changeWordSpelling(
    WordListEntry entry,
    String replacement,
  ) async {
    final clean = replacement.trim();
    final newKey = WordFormIdentity.formKey(
      word: clean,
      locale: entry.locale,
      kind: entry.kind,
      casePolicy: entry.casePolicy,
    );
    final changedIdentity = newKey != entry.formKey;
    await _client.from('word_list_entries').update({
      'word': clean,
      'form_key': newKey,
      // Old accepted variants and custom TTS pronunciation may describe a
      // different word. Preserve them only for an unchanged identity.
      if (changedIdentity) 'accepted_forms': <String>[],
      if (changedIdentity) 'pronunciation_hint': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', entry.id).eq('list_id', entry.listId);
  }

  /// Overrides are explicit, never inferred from dictionary suggestions.
  /// A pronunciation hint supplies spoken text to the existing TTS service;
  /// it does not change the word's tested spelling or stable skill identity.
  Future<void> updateEntryPreferences(
    WordListEntry entry, {
    String? pronunciationHint,
    List<String> acceptedForms = const [],
  }) async {
    final hint = pronunciationHint?.trim() ?? '';
    if (hint.length > 160) {
      throw ArgumentError('Pronunciation hint is limited to 160 characters');
    }
    if (acceptedForms.length > 8) {
      throw ArgumentError('Up to eight accepted spellings are supported');
    }
    final normalized = <String>{};
    final cleanForms = <String>[];
    for (final raw in acceptedForms) {
      final form = raw.trim();
      if (form.isEmpty || form.length > 160) {
        throw ArgumentError('Each accepted spelling must be 1–160 characters');
      }
      final key = entry.casePolicy == WordCasePolicy.exact
          ? form
          : form.toLowerCase();
      if (normalized.add(key)) cleanForms.add(form);
    }
    await _client.from('word_list_entries').update({
      'pronunciation_hint': hint.isEmpty ? null : hint,
      'accepted_forms': cleanForms,
    }).eq('list_id', entry.listId).eq('id', entry.id);
  }

  Future<void> removeWord(String entryId) async {
    await _client.from('word_list_entries').delete().eq('id', entryId);
  }

  /// Due-time lookup is list-independent. A never-reviewed word is due
  /// immediately; a shared word follows one schedule across all lists.
  Future<Set<String>> dueSpellingKeys(
    Iterable<WordListEntry> entries, {
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    // Only fetch review IDs for these list entries. The Data API can cap
    // unbounded selects at 1,000 rows, falsely treating older mastery as new.
    final keys = entries
        .map((e) => WordFormIdentity.spellingReviewContentId(e.formKey))
        .toSet()
        .toList();
    if (keys.isEmpty) return <String>{};
    final dates = <String, DateTime>{};
    // Bound query/URL size: base64 form keys can be long, so avoid sending
    // a single oversized IN(...) argument for a full word list.
    const chunkSize = 50;
    for (var offset = 0; offset < keys.length; offset += chunkSize) {
      final batch = keys.skip(offset).take(chunkSize).toList();
      final rows = await _client.from('review_items')
          .select('content_id,next_review_date')
          .eq('user_id', _userId)
          .eq('content_type', 'word_skill')
          .inFilter('content_id', batch);
      for (final row in (rows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
      final id = map['content_id'] as String?;
      final date = DateTime.tryParse(
        map['next_review_date']?.toString() ?? '',
      );
        if (id != null && date != null) dates[id] = date;
      }
    }
    return entries.where((entry) {
      final contentId = WordFormIdentity.spellingReviewContentId(entry.formKey);
      final next = dates[contentId];
      return next == null || !next.isAfter(current);
    }).map((e) => e.formKey).toSet();
  }

  /// Deliberate, separate erasure of ONE spelling skill's history.
  /// Never removes the word from any list and never touches meaning skills.
  Future<void> forgetSpellingProgress(WordListEntry entry) async {
    final contentId = WordFormIdentity.spellingReviewContentId(entry.formKey);
    await _client.from('review_items').delete()
        .eq('user_id', _userId)
        .eq('content_type', 'word_skill')
        .eq('content_id', contentId);
  }

  Future<void> recordUnassistedSpelling(
    WordListEntry entry,
    SpellingGrade grade,
  ) async {
    // Assisted success is not retention evidence.
    if (grade.assisted) return;
    final contentId = WordFormIdentity.spellingReviewContentId(entry.formKey);
    var row = await _client.from('review_items').select()
        .eq('user_id', _userId).eq('content_id', contentId).maybeSingle();
    if (row == null) {
      // Two active tabs can both see no record. Ignore the second creation,
      // preserving the first schedule and the unique user/content identity.
      await _client.from('review_items').upsert({
        'id': const Uuid().v4(),
        'user_id': _userId,
        'content_id': contentId,
        'content_type': 'word_skill',
        'lesson_id': null,
        'title': entry.word,
        'next_review_date': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,content_id', ignoreDuplicates: true);
      row = await _client.from('review_items').select()
          .eq('user_id', _userId).eq('content_id', contentId).single();
    }
    final item = ReviewableItem.fromJson(Map<String, dynamic>.from(row));
    final processed = await _reviews.processReview(
      item, grade.correct ? RecallQuality.good : RecallQuality.incorrect,
    );
    if (processed == null) {
      throw StateError('Unable to save spelling review. Try again.');
    }
  }
}
