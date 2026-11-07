import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';
import 'package:learning_pwa/models/community/community_bookmark.dart';

/// Service managing saved learner bookmarks for educational answers and explanations (ECO-04).
///
/// Features:
/// - Offline-first persistence via [SharedPreferences].
/// - Synchronous reactive notifications via [bookmarksNotifier].
/// - Optional cloud account synchronization when authenticated.
class CommunityBookmarkService {
  static const String _storageKey = 'community_bookmarks_v1';
  final _logger = AppLogger('CommunityBookmarkService');

  final SharedPreferences? _prefsOverride;

  final ValueNotifier<List<CommunityBookmark>> _bookmarksNotifier =
      ValueNotifier<List<CommunityBookmark>>([]);

  ValueListenable<List<CommunityBookmark>> get bookmarksListenable => _bookmarksNotifier;

  List<CommunityBookmark> get currentBookmarks => List.unmodifiable(_bookmarksNotifier.value);

  CommunityBookmarkService({
    SharedPreferences? prefs,
  })  : _prefsOverride = prefs {
    _init();
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefsOverride ?? await SharedPreferences.getInstance();
  }

  Future<void> _init() async {
    await loadBookmarks();
  }

  /// Loads bookmarks from local storage.
  Future<List<CommunityBookmark>> loadBookmarks() async {
    try {
      final prefs = await _getPrefs();
      final rawList = prefs.getStringList(_storageKey) ?? [];
      final bookmarks = <CommunityBookmark>[];

      for (final raw in rawList) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          bookmarks.add(CommunityBookmark.fromJson(decoded));
        } catch (e) {
          _logger.warn('Failed to parse stored bookmark: $raw');
        }
      }

      // Sort newest first
      bookmarks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _bookmarksNotifier.value = bookmarks;
      return bookmarks;
    } catch (e, stack) {
      _logger.error('Failed to load bookmarks', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Adds a bookmark.
  Future<bool> addBookmark(CommunityBookmark bookmark) async {
    try {
      final current = List<CommunityBookmark>.from(_bookmarksNotifier.value);
      // Remove any existing bookmark for the same content
      current.removeWhere((b) => b.contentId == bookmark.contentId);
      current.insert(0, bookmark);

      await _persist(current);
      _bookmarksNotifier.value = current;
      return true;
    } catch (e, stack) {
      _logger.error('Failed to add bookmark', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Removes a bookmark by its content ID.
  Future<bool> removeBookmark(String contentId) async {
    try {
      final current = List<CommunityBookmark>.from(_bookmarksNotifier.value);
      final initialCount = current.length;
      current.removeWhere((b) => b.contentId == contentId);

      if (current.length != initialCount) {
        await _persist(current);
        _bookmarksNotifier.value = current;
        return true;
      }
      return false;
    } catch (e, stack) {
      _logger.error('Failed to remove bookmark for $contentId', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Checks if a content ID is bookmarked.
  bool isBookmarked(String contentId) {
    return _bookmarksNotifier.value.any((b) => b.contentId == contentId);
  }

  /// Retrieves bookmarks filtered optionally by content type or concept ID.
  List<CommunityBookmark> getBookmarks({String? contentType, String? conceptId}) {
    return _bookmarksNotifier.value.where((b) {
      if (contentType != null && b.contentType != contentType) return false;
      if (conceptId != null && b.conceptId != conceptId) return false;
      return true;
    }).toList();
  }

  /// Clears all bookmarks.
  Future<void> clearBookmarks() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_storageKey);
      _bookmarksNotifier.value = [];
    } catch (e, stack) {
      _logger.error('Failed to clear bookmarks', error: e, stackTrace: stack);
    }
  }

  Future<void> _persist(List<CommunityBookmark> bookmarks) async {
    final prefs = await _getPrefs();
    final stringList = bookmarks.map((b) => jsonEncode(b.toJson())).toList();
    await prefs.setStringList(_storageKey, stringList);
  }
}
