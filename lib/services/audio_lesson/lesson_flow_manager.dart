import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/content_types.dart';

/// Service responsible for managing lesson content flow and navigation
/// Handles content progression, indexing, and navigation logic
class LessonFlowManager {
  List<LessonContent> _contentList = [];
  int _currentIndex = 0;
  bool _isActive = false;

  // Stream controller for progress updates
  final StreamController<int> _progressController = 
      StreamController<int>.broadcast();

  // Getters
  List<LessonContent> get contentList => List.unmodifiable(_contentList);
  int get currentIndex => _currentIndex;
  int get totalContent => _contentList.length;
  bool get isActive => _isActive;
  bool get isFirstContent => _currentIndex == 0;
  bool get isLastContent => _currentIndex == _contentList.length - 1;
  Stream<int> get progressStream => _progressController.stream;

  /// Get the current content item
  LessonContent? get currentContent {
    if (_currentIndex < 0 || _currentIndex >= _contentList.length) {
      return null;
    }
    return _contentList[_currentIndex];
  }

  /// Initialize lesson with content list
  void initializeLesson(List<LessonContent> contentList, {int startIndex = 0}) {
    if (contentList.isEmpty) {
      if (kDebugMode) {
        print('📚 Cannot initialize lesson with empty content list');
      }
      return;
    }

    _contentList = List.from(contentList);
    _currentIndex = max(0, min(startIndex, contentList.length - 1));
    _isActive = true;

    if (kDebugMode) {
      print('📚 Lesson initialized with ${_contentList.length} items, starting at index $_currentIndex');
    }

    _notifyProgress();
  }

  /// Move to the next content item
  bool moveNext() {
    if (!_isActive || isLastContent) {
      if (kDebugMode) {
        print('📚 Cannot move next: active=$_isActive, isLast=$isLastContent');
      }
      return false;
    }

    _currentIndex++;
    
    if (kDebugMode) {
      print('📚 Moved to next content: $_currentIndex/${_contentList.length}');
    }

    _notifyProgress();
    return true;
  }

  /// Move to the previous content item
  bool movePrevious() {
    if (!_isActive || isFirstContent) {
      if (kDebugMode) {
        print('📚 Cannot move previous: active=$_isActive, isFirst=$isFirstContent');
      }
      return false;
    }

    _currentIndex--;
    
    if (kDebugMode) {
      print('📚 Moved to previous content: $_currentIndex/${_contentList.length}');
    }

    _notifyProgress();
    return true;
  }

  /// Jump to a specific content index
  bool jumpToIndex(int index) {
    if (!_isActive || index < 0 || index >= _contentList.length) {
      if (kDebugMode) {
        print('📚 Cannot jump to index $index: active=$_isActive, valid range=0-${_contentList.length - 1}');
      }
      return false;
    }

    _currentIndex = index;
    
    if (kDebugMode) {
      print('📚 Jumped to content index: $_currentIndex');
    }

    _notifyProgress();
    return true;
  }

  /// Move to the first content item
  bool moveToFirst() {
    return jumpToIndex(0);
  }

  /// Move to the last content item
  bool moveToLast() {
    return jumpToIndex(_contentList.length - 1);
  }

  /// Get content at a specific index
  LessonContent? getContentAt(int index) {
    if (index < 0 || index >= _contentList.length) {
      return null;
    }
    return _contentList[index];
  }

  /// Get the next content item (without moving)
  LessonContent? peekNext() {
    if (isLastContent) return null;
    return getContentAt(_currentIndex + 1);
  }

  /// Get the previous content item (without moving)
  LessonContent? peekPrevious() {
    if (isFirstContent) return null;
    return getContentAt(_currentIndex - 1);
  }

  /// Calculate progress percentage
  double get progressPercentage {
    if (_contentList.isEmpty) return 0.0;
    return (_currentIndex + 1) / _contentList.length;
  }

  /// Get remaining content count
  int get remainingContentCount {
    if (!_isActive) return 0;
    return _contentList.length - _currentIndex - 1;
  }

  /// Check if lesson is complete
  bool get isComplete {
    return _isActive && isLastContent;
  }

  /// Stop the lesson flow
  void stopLesson() {
    if (kDebugMode) {
      print('📚 Stopping lesson flow');
    }
    _isActive = false;
  }

  /// Reset lesson to beginning
  void resetLesson() {
    if (kDebugMode) {
      print('📚 Resetting lesson to beginning');
    }
    _currentIndex = 0;
    _notifyProgress();
  }

  /// Get lesson summary for debugging
  Map<String, dynamic> get lessonSummary {
    return {
      'totalContent': _contentList.length,
      'currentIndex': _currentIndex,
      'isActive': _isActive,
      'isFirstContent': isFirstContent,
      'isLastContent': isLastContent,
      'progressPercentage': progressPercentage,
      'remainingContent': remainingContentCount,
    };
  }

  /// Filter content by type
  List<LessonContent> getContentByType(String type) {
    return _contentList.where((content) {
      if (content is ConceptContent) return type == 'concept';
      if (content is QuestionContent) return type == 'question';
      return false;
    }).toList();
  }

  /// Get indices of content by type
  List<int> getIndicesByType(String type) {
    final indices = <int>[];
    for (int i = 0; i < _contentList.length; i++) {
      final content = _contentList[i];
      if (content is ConceptContent && type == 'concept') {
        indices.add(i);
      } else if (content is QuestionContent && type == 'question') {
        indices.add(i);
      }
    }
    return indices;
  }

  /// Notify progress update
  void _notifyProgress() {
    _progressController.add(_currentIndex);
  }

  /// Dispose of resources
  void dispose() {
    if (kDebugMode) {
      print('🗑️ Disposing lesson flow manager');
    }
    _progressController.close();
    _isActive = false;
  }
}
