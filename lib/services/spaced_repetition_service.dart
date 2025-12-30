import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';
import 'package:uuid/uuid.dart';

/// Service for managing spaced repetition review items
class SpacedRepetitionService {
  final SupabaseClient _supabase;
  static const _uuid = Uuid();

  SpacedRepetitionService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Get all review items for the current user
  Future<List<ReviewableItem>> getAllReviewItems() async {
    if (_userId == null) return [];

    try {
      final response = await _supabase
          .from('review_items')
          .select()
          .eq('user_id', _userId!)
          .order('next_review_date', ascending: true);

      return (response as List)
          .map((row) => ReviewableItem.fromJson(row))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching review items: $e');
      }
      return [];
    }
  }

  /// Get items due for review today
  Future<List<ReviewableItem>> getDueItems() async {
    if (_userId == null) return [];

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final response = await _supabase
          .from('review_items')
          .select()
          .eq('user_id', _userId!)
          .lte('next_review_date', today.toIso8601String())
          .order('next_review_date', ascending: true);

      return (response as List)
          .map((row) => ReviewableItem.fromJson(row))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching due items: $e');
      }
      return [];
    }
  }

  /// Get review summary for the current user
  Future<ReviewSummary> getReviewSummary() async {
    final items = await getAllReviewItems();
    return ReviewSummary.fromItems(items);
  }

  /// Add a new item to the review queue
  Future<ReviewableItem?> addToReviewQueue({
    required String contentId,
    required ReviewableContentType contentType,
    required String lessonId,
    required String title,
    String? subtitle,
  }) async {
    if (_userId == null) return null;

    try {
      // Check if already exists
      final existing = await _supabase
          .from('review_items')
          .select('id')
          .eq('user_id', _userId!)
          .eq('content_id', contentId)
          .maybeSingle();

      if (existing != null) {
        if (kDebugMode) {
          print('Item already in review queue: $contentId');
        }
        return null;
      }

      final item = ReviewableItem(
        id: _uuid.v4(),
        contentId: contentId,
        contentType: contentType,
        lessonId: lessonId,
        title: title,
        subtitle: subtitle,
        nextReviewDate: DateTime.now().add(const Duration(days: 1)),
      );

      await _supabase.from('review_items').insert({
        ...item.toJson(),
        'user_id': _userId,
      });

      return item;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding to review queue: $e');
      }
      return null;
    }
  }

  /// Add multiple items to the review queue (e.g., all terms from a lesson)
  Future<int> addLessonToReviewQueue(String lessonId) async {
    if (_userId == null) return 0;

    int addedCount = 0;

    try {
      // Fetch terms from the lesson
      final terms = await _supabase
          .from('terms')
          .select('id, term, definition')
          .eq('lesson_id', lessonId);

      for (final term in terms as List) {
        final result = await addToReviewQueue(
          contentId: term['id'] as String,
          contentType: ReviewableContentType.term,
          lessonId: lessonId,
          title: term['term'] as String,
          subtitle: term['definition'] as String?,
        );
        if (result != null) addedCount++;
      }

      // Fetch questions from the lesson
      final questions = await _supabase
          .from('questions')
          .select('id, question_text')
          .eq('lesson_id', lessonId);

      for (final question in questions as List) {
        final result = await addToReviewQueue(
          contentId: question['id'] as String,
          contentType: ReviewableContentType.question,
          lessonId: lessonId,
          title: question['question_text'] as String,
        );
        if (result != null) addedCount++;
      }

      return addedCount;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding lesson to review queue: $e');
      }
      return addedCount;
    }
  }

  /// Process a review and update the item
  Future<ReviewableItem?> processReview(
    ReviewableItem item,
    RecallQuality quality,
  ) async {
    if (_userId == null) return null;

    try {
      final updatedItem = item.processReview(quality);

      await _supabase
          .from('review_items')
          .update(updatedItem.toJson())
          .eq('id', item.id)
          .eq('user_id', _userId!);

      return updatedItem;
    } catch (e) {
      if (kDebugMode) {
        print('Error processing review: $e');
      }
      return null;
    }
  }

  /// Remove an item from the review queue
  Future<bool> removeFromReviewQueue(String itemId) async {
    if (_userId == null) return false;

    try {
      await _supabase
          .from('review_items')
          .delete()
          .eq('id', itemId)
          .eq('user_id', _userId!);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error removing from review queue: $e');
      }
      return false;
    }
  }

  /// Reset an item's progress (start over)
  Future<ReviewableItem?> resetItemProgress(ReviewableItem item) async {
    if (_userId == null) return null;

    try {
      final resetItem = item.copyWith(
        repetitionLevel: 0,
        easeFactor: 2.5,
        nextReviewDate: DateTime.now().add(const Duration(days: 1)),
        totalReviews: 0,
        correctReviews: 0,
      );

      await _supabase
          .from('review_items')
          .update(resetItem.toJson())
          .eq('id', item.id)
          .eq('user_id', _userId!);

      return resetItem;
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting item progress: $e');
      }
      return null;
    }
  }
}

/// Provider for SpacedRepetitionService
final spacedRepetitionServiceProvider = Provider<SpacedRepetitionService>((ref) {
  return SpacedRepetitionService();
});

/// Provider for all review items
final allReviewItemsProvider = FutureProvider<List<ReviewableItem>>((ref) async {
  final service = ref.read(spacedRepetitionServiceProvider);
  return service.getAllReviewItems();
});

/// Provider for items due today
final dueReviewItemsProvider = FutureProvider<List<ReviewableItem>>((ref) async {
  final service = ref.read(spacedRepetitionServiceProvider);
  return service.getDueItems();
});

/// Provider for review summary
final reviewSummaryProvider = FutureProvider<ReviewSummary>((ref) async {
  final service = ref.read(spacedRepetitionServiceProvider);
  return service.getReviewSummary();
});

/// StateNotifier for managing the current review session
class ReviewSessionNotifier extends StateNotifier<ReviewSessionState> {
  final SpacedRepetitionService _service;
  final Ref _ref;

  ReviewSessionNotifier(this._service, this._ref)
      : super(const ReviewSessionState());

  /// Start a new review session with due items
  Future<void> startSession() async {
    state = state.copyWith(isLoading: true);
    
    final items = await _service.getDueItems();
    
    state = ReviewSessionState(
      items: items,
      currentIndex: 0,
      isLoading: false,
      isComplete: items.isEmpty,
    );
  }

  /// Process the current item's review
  Future<void> processCurrentReview(RecallQuality quality) async {
    if (state.currentItem == null) return;

    state = state.copyWith(isLoading: true);

    final updatedItem = await _service.processReview(
      state.currentItem!,
      quality,
    );

    if (updatedItem != null) {
      final updatedItems = List<ReviewableItem>.from(state.items);
      updatedItems[state.currentIndex] = updatedItem;

      // Move to next item or mark complete
      final nextIndex = state.currentIndex + 1;
      final isComplete = nextIndex >= updatedItems.length;

      state = state.copyWith(
        items: updatedItems,
        currentIndex: isComplete ? state.currentIndex : nextIndex,
        isComplete: isComplete,
        isLoading: false,
        reviewedCount: state.reviewedCount + 1,
        correctCount: quality.value >= 3 ? state.correctCount + 1 : state.correctCount,
      );

      // Invalidate providers to refresh data
      if (isComplete) {
        _ref.invalidate(dueReviewItemsProvider);
        _ref.invalidate(reviewSummaryProvider);
      }
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Skip the current item (move to end of queue)
  void skipCurrentItem() {
    if (state.items.isEmpty || state.isComplete) return;

    final items = List<ReviewableItem>.from(state.items);
    final skippedItem = items.removeAt(state.currentIndex);
    items.add(skippedItem);

    state = state.copyWith(items: items);
  }

  /// Reset the session
  void reset() {
    state = const ReviewSessionState();
  }
}

/// State for a review session
class ReviewSessionState {
  final List<ReviewableItem> items;
  final int currentIndex;
  final bool isLoading;
  final bool isComplete;
  final int reviewedCount;
  final int correctCount;

  const ReviewSessionState({
    this.items = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.isComplete = false,
    this.reviewedCount = 0,
    this.correctCount = 0,
  });

  ReviewableItem? get currentItem =>
      items.isNotEmpty && currentIndex < items.length
          ? items[currentIndex]
          : null;

  int get remainingCount => items.length - currentIndex;

  double get sessionAccuracy =>
      reviewedCount > 0 ? correctCount / reviewedCount : 0.0;

  ReviewSessionState copyWith({
    List<ReviewableItem>? items,
    int? currentIndex,
    bool? isLoading,
    bool? isComplete,
    int? reviewedCount,
    int? correctCount,
  }) {
    return ReviewSessionState(
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      isComplete: isComplete ?? this.isComplete,
      reviewedCount: reviewedCount ?? this.reviewedCount,
      correctCount: correctCount ?? this.correctCount,
    );
  }
}

/// Provider for review session
final reviewSessionProvider =
    StateNotifierProvider<ReviewSessionNotifier, ReviewSessionState>((ref) {
  final service = ref.read(spacedRepetitionServiceProvider);
  return ReviewSessionNotifier(service, ref);
});
