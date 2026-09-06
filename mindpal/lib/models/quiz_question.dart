/// Where a generated question came from, so the UI can show the user that the
/// question is about their own saved information.
enum QuizSubject { person, place, note }

/// One multiple-choice question built from the user's saved data.
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.subject,
    required this.sourceId,
  });

  /// "Who is Rahul?"
  final String prompt;

  /// The choices shown, already shuffled. Always contains [correctIndex].
  final List<String> options;

  final int correctIndex;

  final QuizSubject subject;

  /// The id of the Person / Place / Note this came from, so a wrong answer can
  /// point the user back at the real entry.
  final int sourceId;

  String get correctAnswer => options[correctIndex];

  bool isCorrect(int chosenIndex) => chosenIndex == correctIndex;
}
