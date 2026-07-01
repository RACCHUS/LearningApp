import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Search result types for categorizing results
enum SearchResultType {
  lesson,
  term,
  question,
  concept,
  course,
}

/// A single search result with metadata
class SearchResult {
  final String id;
  final String title;
  final String? subtitle;
  final SearchResultType type;
  final String? matchedText;
  final double relevanceScore;

  SearchResult({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    this.matchedText,
    this.relevanceScore = 0.0,
  });

  /// Icon for this result type
  String get typeLabel {
    switch (type) {
      case SearchResultType.lesson:
        return 'Lesson';
      case SearchResultType.term:
        return 'Term';
      case SearchResultType.question:
        return 'Question';
      case SearchResultType.concept:
        return 'Concept';
      case SearchResultType.course:
        return 'Course';
    }
  }
}

/// Grouped search results by type
class SearchResults {
  final List<SearchResult> lessons;
  final List<SearchResult> terms;
  final List<SearchResult> questions;
  final List<SearchResult> concepts;
  final List<SearchResult> courses;
  final Duration searchDuration;

  SearchResults({
    this.lessons = const [],
    this.terms = const [],
    this.questions = const [],
    this.concepts = const [],
    this.courses = const [],
    this.searchDuration = Duration.zero,
  });

  factory SearchResults.empty() => SearchResults();

  /// Total number of results
  int get totalCount =>
      lessons.length +
      terms.length +
      questions.length +
      concepts.length +
      courses.length;

  /// Check if there are any results
  bool get isEmpty => totalCount == 0;
  bool get isNotEmpty => !isEmpty;

  /// All results flattened and sorted by relevance
  List<SearchResult> get allResults {
    final all = [...lessons, ...terms, ...questions, ...concepts, ...courses];
    all.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return all;
  }
}

/// Service for full-text search across all content
class SearchService {
  static const int _maxRecentSearches = 10;
  static const String _recentSearchesKey = 'recent_searches';

  final SupabaseClient _supabase;

  SearchService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Escape characters that are special to SQL LIKE/ILIKE so user input is
  /// treated as a literal substring rather than a wildcard pattern.
  String _escapeLikePattern(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  /// Perform a full-text search across all content types
  Future<SearchResults> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) {
      return SearchResults.empty();
    }

    // Escape LIKE/ILIKE wildcards so user input can't trigger expensive
    // full-table scans (e.g. a query of just "%").
    final safeQuery = _escapeLikePattern(query.trim());

    final stopwatch = Stopwatch()..start();

    try {
      // Run searches in parallel for better performance
      final results = await Future.wait([
        _searchLessons(safeQuery, limit: limit),
        _searchTerms(safeQuery, limit: limit),
        _searchQuestions(safeQuery, limit: limit),
        _searchConcepts(safeQuery, limit: limit),
        _searchCourses(safeQuery, limit: limit),
      ]);

      stopwatch.stop();

      return SearchResults(
        lessons: results[0],
        terms: results[1],
        questions: results[2],
        concepts: results[3],
        courses: results[4],
        searchDuration: stopwatch.elapsed,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Search error: $e');
      }
      return SearchResults.empty();
    }
  }

  /// Search lessons by title and description
  Future<List<SearchResult>> _searchLessons(String query, {int limit = 20}) async {
    try {
      // Use ilike for case-insensitive pattern matching
      final response = await _supabase
          .from('lessons')
          .select('id, title, description')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .limit(limit);

      return (response as List).map((row) {
        final title = row['title'] as String;
        final description = row['description'] as String?;
        
        // Calculate simple relevance score
        double score = 0.0;
        if (title.toLowerCase().contains(query.toLowerCase())) {
          score += 1.0;
          if (title.toLowerCase().startsWith(query.toLowerCase())) {
            score += 0.5;
          }
        }
        if (description?.toLowerCase().contains(query.toLowerCase()) == true) {
          score += 0.5;
        }

        return SearchResult(
          id: row['id'] as String,
          title: title,
          subtitle: description,
          type: SearchResultType.lesson,
          relevanceScore: score,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Lesson search error: $e');
      }
      return [];
    }
  }

  /// Search terms by term and definition
  Future<List<SearchResult>> _searchTerms(String query, {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('terms')
          .select('id, term, definition, lesson_id')
          .or('term.ilike.%$query%,definition.ilike.%$query%')
          .limit(limit);

      return (response as List).map((row) {
        final term = row['term'] as String;
        final definition = row['definition'] as String?;

        double score = 0.0;
        if (term.toLowerCase().contains(query.toLowerCase())) {
          score += 1.0;
        }
        if (definition?.toLowerCase().contains(query.toLowerCase()) == true) {
          score += 0.5;
        }

        return SearchResult(
          id: row['id'] as String,
          title: term,
          subtitle: definition,
          type: SearchResultType.term,
          relevanceScore: score,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Term search error: $e');
      }
      return [];
    }
  }

  /// Search questions by question text
  Future<List<SearchResult>> _searchQuestions(String query, {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('questions')
          .select('id, question_text, lesson_id')
          .ilike('question_text', '%$query%')
          .limit(limit);

      return (response as List).map((row) {
        final questionText = row['question_text'] as String;

        return SearchResult(
          id: row['id'] as String,
          title: questionText,
          type: SearchResultType.question,
          relevanceScore: 0.8,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Question search error: $e');
      }
      return [];
    }
  }

  /// Search concepts by name and description
  Future<List<SearchResult>> _searchConcepts(String query, {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('concepts')
          .select('id, name, description, lesson_id')
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .limit(limit);

      return (response as List).map((row) {
        final name = row['name'] as String;
        final description = row['description'] as String?;

        double score = 0.0;
        if (name.toLowerCase().contains(query.toLowerCase())) {
          score += 1.0;
        }
        if (description?.toLowerCase().contains(query.toLowerCase()) == true) {
          score += 0.5;
        }

        return SearchResult(
          id: row['id'] as String,
          title: name,
          subtitle: description,
          type: SearchResultType.concept,
          relevanceScore: score,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Concept search error: $e');
      }
      return [];
    }
  }

  /// Search courses by title and description
  Future<List<SearchResult>> _searchCourses(String query, {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('courses')
          .select('id, title, description')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .limit(limit);

      return (response as List).map((row) {
        final title = row['title'] as String;
        final description = row['description'] as String?;

        double score = 0.0;
        if (title.toLowerCase().contains(query.toLowerCase())) {
          score += 1.0;
        }
        if (description?.toLowerCase().contains(query.toLowerCase()) == true) {
          score += 0.5;
        }

        return SearchResult(
          id: row['id'] as String,
          title: title,
          subtitle: description,
          type: SearchResultType.course,
          relevanceScore: score,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Course search error: $e');
      }
      return [];
    }
  }

  /// Get recent searches from local storage
  Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_recentSearchesKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Save a search query to recent searches
  Future<void> saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = await getRecentSearches();

      // Remove if already exists (will be re-added at top)
      recent.remove(query);

      // Add to front
      recent.insert(0, query);

      // Trim to max size
      if (recent.length > _maxRecentSearches) {
        recent.removeRange(_maxRecentSearches, recent.length);
      }

      await prefs.setStringList(_recentSearchesKey, recent);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving recent search: $e');
      }
    }
  }

  /// Clear recent searches
  Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing recent searches: $e');
      }
    }
  }
}

/// Provider for SearchService
final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService();
});

/// Provider for search results with debouncing
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider);
  
  if (query.isEmpty) {
    return SearchResults.empty();
  }

  final service = ref.read(searchServiceProvider);
  
  // Save to recent searches
  await service.saveRecentSearch(query);
  
  return service.search(query);
});

/// Provider for recent searches
final recentSearchesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.read(searchServiceProvider);
  return service.getRecentSearches();
});
