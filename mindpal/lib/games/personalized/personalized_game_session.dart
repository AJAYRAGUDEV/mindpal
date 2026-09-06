import '../../models/difficulty.dart';
import '../../models/game_result.dart';
import '../../models/game_type.dart';
import '../../models/quiz_question.dart';

/// One playthrough of the personalised game.
///
/// Plain Dart, no Flutter import — the same rule as MemoryMatchGame and
/// SequenceRecallGame. The screen draws; this class decides.
///
/// It does NOT generate the questions. It is handed a finished list by
/// PersonalizedGameService, which is what lets a future AI generator replace
/// that service without this class or the screen changing at all.
class PersonalizedGameSession {
  PersonalizedGameSession({
    required this.questions,
    required this.difficulty,
  }) : assert(questions.isNotEmpty, 'A session needs at least one question');

  final List<QuizQuestion> questions;
  final Difficulty difficulty;

  int _currentIndex = 0;
  int _correctCount = 0;

  /// Which option the player tapped for the current question, or null while
  /// they are still deciding.
  int? _selectedIndex;

  DateTime? _startedAt;
  DateTime? _finishedAt;

  int get currentIndex => _currentIndex;
  int get questionNumber => _currentIndex + 1;
  int get totalQuestions => questions.length;
  int get correctCount => _correctCount;

  QuizQuestion get currentQuestion => questions[_currentIndex];

  int? get selectedIndex => _selectedIndex;
  bool get isAnswered => _selectedIndex != null;
  bool get isLastQuestion => _currentIndex == questions.length - 1;
  bool get isComplete => _finishedAt != null;

  /// True only when the answered question was right.
  bool get wasCorrect =>
      isAnswered && currentQuestion.isCorrect(_selectedIndex!);

  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    return (_finishedAt ?? DateTime.now()).difference(start);
  }

  /// Records the player's choice. Returns whether it was correct.
  ///
  /// Answering twice does nothing — the screen locks the buttons after the
  /// first tap, and this makes that guarantee real rather than a UI detail.
  bool answer(int optionIndex) {
    if (isAnswered || isComplete) return wasCorrect;

    _startedAt ??= DateTime.now();
    _selectedIndex = optionIndex;

    final correct = currentQuestion.isCorrect(optionIndex);
    if (correct) _correctCount++;

    // The last answer ends the game, so the result is available immediately.
    if (isLastQuestion) _finishedAt = DateTime.now();

    return correct;
  }

  /// Moves to the next question. Does nothing on the last one.
  void next() {
    if (!isAnswered || isLastQuestion) return;
    _currentIndex++;
    _selectedIndex = null;
  }

  /// 100 points per correct answer, and nothing else.
  ///
  /// Deliberately simpler than Memory Match's formula: no time penalty and no
  /// difficulty bonus. This game is about recalling your own family and places,
  /// and there is no good reason to make a person who thinks slowly about their
  /// daughter's name score lower than one who answers fast.
  int get score => _correctCount * 100;

  GameResult toResult() => GameResult(
    gameType: GameType.personalizedMemory,
    difficulty: difficulty,
    score: score,
    durationSeconds: elapsed.inSeconds,
    completed: isComplete,
    // "Mistakes" is the shared GameResult field; here it means questions
    // answered incorrectly. Nothing reads it as anything more than that.
    mistakes: (isComplete ? questions.length : _currentIndex) - _correctCount,
    playedAt: DateTime.now(),
  );
}
