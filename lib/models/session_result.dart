import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';

/// Represents the result of a completed study session
class SessionResult {
  final SessionMode mode;
  final int correct;
  final int total;
  final List<MissedTerm> missedTerms;
  final List<MissedQuestion> missedQuestions;

  /// How long the session took, if tracked.
  final Duration? duration;

  const SessionResult({
    required this.mode,
    required this.correct,
    required this.total,
    this.missedTerms = const [],
    this.missedQuestions = const [],
    this.duration,
  });

  double get accuracy => total > 0 ? correct / total : 0.0;
  int get missed => total - correct;
  bool get hasMissedItems => missedTerms.isNotEmpty || missedQuestions.isNotEmpty;

  /// Session length formatted as `m:ss` (e.g. `4:07`), or null if untracked.
  String? get formattedDuration {
    final d = duration;
    if (d == null) return null;
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

enum SessionMode { flashcards, mcq, lesson, mixed }

/// A term the user marked as "don't know"
class MissedTerm {
  final Term term;
  const MissedTerm({required this.term});
}

/// A question the user got wrong, with their selected answer
class MissedQuestion {
  final Question question;
  final int selectedAnswer;
  const MissedQuestion({required this.question, required this.selectedAnswer});
}
