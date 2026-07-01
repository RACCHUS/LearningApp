import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';

/// Represents the result of a completed study session
class SessionResult {
  final SessionMode mode;
  final int correct;
  final int total;
  final List<MissedTerm> missedTerms;
  final List<MissedQuestion> missedQuestions;

  const SessionResult({
    required this.mode,
    required this.correct,
    required this.total,
    this.missedTerms = const [],
    this.missedQuestions = const [],
  });

  double get accuracy => total > 0 ? correct / total : 0.0;
  int get missed => total - correct;
  bool get hasMissedItems => missedTerms.isNotEmpty || missedQuestions.isNotEmpty;
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
