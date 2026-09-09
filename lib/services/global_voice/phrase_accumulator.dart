import 'dart:async';
import 'package:flutter/foundation.dart';

/// Handles multi-word phrase accumulation for voice commands.
/// 
/// Speech recognition often returns partial results, so this class
/// accumulates words over a short time window to form complete commands.
class PhraseAccumulator {
  String _accumulatedPhrase = '';
  Timer? _accumulationTimer;
  bool _isAccumulating = false;
  
  /// Default delay to wait for additional words before finalizing
  static const Duration defaultAccumulationDelay = Duration(milliseconds: 1200);
  
  /// Shorter delay for simple 1-2 word commands
  static const Duration quickAccumulationDelay = Duration(milliseconds: 600);
  
  /// Whether phrase accumulation is currently active
  bool get isAccumulating => _isAccumulating;
  
  /// The current accumulated phrase
  String get currentPhrase => _accumulatedPhrase;

  /// Add text to the accumulation buffer.
  /// 
  /// Returns true if this is new text that was added, false if duplicate.
  bool addText(String text) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return false;
    
    final newWords = trimmedText.split(' ');
    
    if (_isAccumulating) {
      final existingWords = _accumulatedPhrase.split(' ');
      
      // Check if this is actually new text (not a duplicate)
      final isNewText = !newWords.every(
        (word) => existingWords.contains(word.toLowerCase())
      );
      
      if (isNewText) {
        _accumulatedPhrase = '$_accumulatedPhrase $trimmedText'.trim();
        if (kDebugMode) {
          print('🔤 Accumulated phrase: "$_accumulatedPhrase"');
        }
        return true;
      }
      return false;
    } else {
      // Start new accumulation
      _accumulatedPhrase = trimmedText;
      _isAccumulating = true;
      
      if (kDebugMode) {
        print('🔤 Starting phrase accumulation: "$_accumulatedPhrase"');
      }
      return true;
    }
  }

  /// Start or restart the accumulation timer.
  /// 
  /// [onComplete] is called with the final phrase when the timer fires.
  /// [wordCount] is used to determine timeout duration (shorter for simple commands).
  void startTimer({
    required void Function(String finalPhrase) onComplete,
    int wordCount = 1,
  }) {
    _accumulationTimer?.cancel();
    
    // Use shorter timeout for simple commands
    final timeoutDuration = wordCount <= 2 
        ? quickAccumulationDelay 
        : defaultAccumulationDelay;
    
    _accumulationTimer = Timer(timeoutDuration, () {
      final phrase = _accumulatedPhrase;
      reset();
      onComplete(phrase);
    });
  }

  /// Reset the accumulator to initial state.
  void reset() {
    _accumulationTimer?.cancel();
    _accumulationTimer = null;
    _isAccumulating = false;
    _accumulatedPhrase = '';
  }

  /// Cancel any pending timer without resetting the phrase.
  void cancelTimer() {
    _accumulationTimer?.cancel();
    _accumulationTimer = null;
  }

  /// Dispose of resources.
  void dispose() {
    reset();
  }
}
