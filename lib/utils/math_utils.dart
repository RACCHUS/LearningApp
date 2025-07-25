class MathUtils {
  static bool isAnswerCorrect(String userAnswer, String correctAnswer) {
    return userAnswer.trim().toLowerCase() == correctAnswer.trim().toLowerCase();
  }
}
