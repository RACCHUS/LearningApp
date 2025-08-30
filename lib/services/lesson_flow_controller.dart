import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/content_types.dart';

/// Controller for lesson flow logic and progression
/// Extracted from AudioLessonOrchestrator for better separation of concerns
class LessonFlowController {
  static final LessonFlowController _instance = LessonFlowController._internal();
  factory LessonFlowController() => _instance;
  LessonFlowController._internal();

  // Lesson state
  List<LessonContent> _contentList = [];
  int _currentIndex = 0;
  bool _isActive = false;
  
  // Retry logic
  int _currentRetryAttempt = 0;
  
  // Stream controllers for lesson events
  final StreamController<int> _progressController = StreamController<int>.broadcast();
  final StreamController<LessonFlowAction> _actionController = StreamController<LessonFlowAction>.broadcast();

  // Getters
  Stream<int> get progressStream => _progressController.stream;
  Stream<LessonFlowAction> get actionStream => _actionController.stream;
  
  bool get isActive => _isActive;
  int get currentIndex => _currentIndex;
  int get totalContent => _contentList.length;
  bool get isFirstContent => _currentIndex == 0;
  bool get isLastContent => _currentIndex == _contentList.length - 1;
  LessonContent? get currentContent => _currentIndex < _contentList.length ? _contentList[_currentIndex] : null;
  List<LessonContent> get contentList => List.unmodifiable(_contentList);

  /// Start a new lesson with content
  void startLesson(List<LessonContent> contentList, {int startIndex = 0}) {
    if (contentList.isEmpty) {
      if (kDebugMode) {
        print('📚 Cannot start lesson - no content provided');
      }
      return;
    }
    
    _contentList = contentList;
    _currentIndex = _clampIndex(startIndex);
    _isActive = true;
    _currentRetryAttempt = 0;
    
    _notifyProgress();
    
    if (kDebugMode) {
      print('📚 Lesson started with ${contentList.length} items, starting at index $_currentIndex');
    }
  }

  /// Stop the current lesson
  void stopLesson() {
    _isActive = false;
    _contentList.clear();
    _currentIndex = 0;
    _currentRetryAttempt = 0;
    
    if (kDebugMode) {
      print('📚 Lesson stopped');
    }
  }

  /// Move to next content item
  bool nextContent() {
    if (!_isActive || isLastContent) {
      if (isLastContent) {
        _completeLesson();
      }
      return false;
    }
    
    _currentIndex++;
    _currentRetryAttempt = 0;
    _notifyProgress();
    
    if (kDebugMode) {
      print('📚 Moved to next content: ${_currentIndex + 1}/${_contentList.length}');
    }
    
    return true;
  }

  /// Move to previous content item
  bool previousContent() {
    if (!_isActive || isFirstContent) {
      return false;
    }
    
    _currentIndex--;
    _currentRetryAttempt = 0;
    _notifyProgress();
    
    if (kDebugMode) {
      print('📚 Moved to previous content: ${_currentIndex + 1}/${_contentList.length}');
    }
    
    return true;
  }

  /// Repeat current content
  void repeatContent() {
    if (!_isActive) return;
    
    _currentRetryAttempt = 0;
    
    if (kDebugMode) {
      print('📚 Repeating current content: ${_currentIndex + 1}/${_contentList.length}');
    }
  }

  /// Jump to specific content index
  bool jumpToContent(int index) {
    if (!_isActive) return false;
    
    final newIndex = _clampIndex(index);
    if (newIndex == _currentIndex) return false;
    
    _currentIndex = newIndex;
    _currentRetryAttempt = 0;
    _notifyProgress();
    
    if (kDebugMode) {
      print('📚 Jumped to content: ${_currentIndex + 1}/${_contentList.length}');
    }
    
    return true;
  }

  /// Jump to first content
  bool jumpToFirst() {
    return jumpToContent(0);
  }

  /// Jump to last content
  bool jumpToLast() {
    return jumpToContent(_contentList.length - 1);
  }

  /// Handle answer for current question content
  bool handleAnswer(dynamic answer, {String? explanation}) {
    final content = currentContent;
    if (content is! QuestionContent) {
      if (kDebugMode) {
        print('📚 Cannot handle answer - current content is not a question');
      }
      return false;
    }
    
    // Process the answer and determine correctness
    bool isCorrect = false;
    
    if (content.type == 'mcq' && answer is String) {
      final answerIndex = answer.codeUnitAt(0) - 65; // A=0, B=1, etc.
      isCorrect = answerIndex >= 0 && answerIndex < content.options.length && 
                  answerIndex == content.correctAnswer;
    } else if (content.type == 'true_false' && answer is bool) {
      isCorrect = answer == (content.correctAnswer == 0); // Assuming 0=true, 1=false
    } else if (content.type == 'short_answer' && answer is String) {
      // For short answer, you might want more sophisticated matching
      isCorrect = answer.toLowerCase().trim() == 
                  content.options[content.correctAnswer].toLowerCase().trim();
    }
    
    if (kDebugMode) {
      print('📚 Answer processed: $answer, correct: $isCorrect');
    }
    
    _currentRetryAttempt = 0;
    return isCorrect;
  }

  /// Increment retry attempt and check if should continue
  bool incrementRetryAttempt(int maxAttempts) {
    _currentRetryAttempt++;
    
    if (kDebugMode) {
      print('📚 Retry attempt $_currentRetryAttempt/$maxAttempts');
    }
    
    return _currentRetryAttempt <= maxAttempts;
  }

  /// Reset retry attempt counter
  void resetRetryAttempt() {
    _currentRetryAttempt = 0;
  }

  /// Get current retry attempt
  int get currentRetryAttempt => _currentRetryAttempt;

  /// Get retry prompt for current attempt
  String getRetryPrompt(int attemptNumber) {
    switch (attemptNumber) {
      case 1:
        return "I didn't catch that. Please repeat your answer.";
      case 2:
        return "Could you speak a bit clearer? Try again.";
      case 3:
        return "Having trouble? You can use the touch screen instead.";
      default:
        return "Switching to manual mode.";
    }
  }

  /// Complete the lesson
  void _completeLesson() {
    _isActive = false;
    _actionController.add(LessonFlowAction.complete);
    
    if (kDebugMode) {
      print('📚 Lesson completed!');
    }
  }

  /// Notify progress change
  void _notifyProgress() {
    _progressController.add(_currentIndex);
  }

  /// Clamp index to valid range
  int _clampIndex(int index) {
    if (_contentList.isEmpty) return 0;
    return index.clamp(0, _contentList.length - 1);
  }

  /// Get progress percentage
  double getProgressPercentage() {
    if (_contentList.isEmpty) return 0.0;
    return (_currentIndex + 1) / _contentList.length;
  }

  /// Get progress description
  String getProgressDescription() {
    if (_contentList.isEmpty) return "No content";
    return "${_currentIndex + 1} of ${_contentList.length}";
  }

  /// Check if lesson can be started
  bool canStartLesson(List<LessonContent> contentList) {
    return contentList.isNotEmpty;
  }

  /// Get lesson statistics
  Map<String, dynamic> getLessonStats() {
    final stats = <String, dynamic>{
      'totalItems': _contentList.length,
      'currentIndex': _currentIndex,
      'isActive': _isActive,
      'progressPercentage': getProgressPercentage(),
      'isFirstItem': isFirstContent,
      'isLastItem': isLastContent,
      'retryAttempt': _currentRetryAttempt,
    };
    
    if (currentContent != null) {
      stats['currentContentType'] = currentContent.runtimeType.toString();
    }
    
    return stats;
  }

  /// Dispose and clean up resources
  void dispose() {
    _progressController.close();
    _actionController.close();
    _contentList.clear();
    _isActive = false;
  }
}

/// Actions that can occur in lesson flow
enum LessonFlowAction {
  next,
  previous,
  repeat,
  pause,
  resume,
  restart,
  complete,
}
