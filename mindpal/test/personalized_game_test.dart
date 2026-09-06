import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/games/personalized/personalized_game_session.dart';
import 'package:mindpal/models/difficulty.dart';
import 'package:mindpal/models/game_type.dart';
import 'package:mindpal/models/memory_note.dart';
import 'package:mindpal/models/person.dart';
import 'package:mindpal/models/place.dart';
import 'package:mindpal/models/quiz_question.dart';
import 'package:mindpal/services/memory_aid_service.dart';
import 'package:mindpal/services/personalized_game_service.dart';

final _when = DateTime(2026, 1, 1);

Person _person(int id, String name, String relationship) => Person(
  id: id,
  name: name,
  relationship: relationship,
  createdAt: _when,
);

Place _place(int id, String name, String description) =>
    Place(id: id, name: name, description: description, createdAt: _when);

MemoryNote _note(int id, String title, String content) => MemoryNote(
  id: id,
  title: title,
  content: content,
  createdAt: _when,
  updatedAt: _when,
);

/// A family with enough saved data for every question type.
final _rich = MemoryAidData(
  people: [
    _person(1, 'Rahul', 'Son'),
    _person(2, 'Ananya', 'Daughter'),
    _person(3, 'Priya', 'Friend'),
  ],
  places: [
    _place(1, 'Shillong', 'Family trip last summer'),
    _place(2, 'Civil Hospital', 'Where the doctor works'),
    _place(3, 'Home', 'Where I live with Ananya'),
  ],
  notes: [
    _note(1, 'Bank details', 'The passbook is in the brown cupboard'),
    _note(2, 'Gas booking', 'Call the agency before the cylinder runs out'),
    _note(3, 'Wifi', 'The password is written behind the router'),
  ],
);

PersonalizedGameSession _session(List<QuizQuestion> questions) =>
    PersonalizedGameSession(questions: questions, difficulty: Difficulty.easy);

void main() {
  const games = PersonalizedGameService();

  group('generation — enough data', () {
    test('produces questions from real saved data', () {
      final questions = games.generate(_rich, count: 5, random: Random(1));

      expect(questions, isNotEmpty);
      expect(questions.length, lessThanOrEqualTo(5));
    });

    test('asks person -> relationship', () {
      final all = games.generate(_rich, count: 50, random: Random(2));

      expect(all.any((q) => q.prompt == 'Who is Rahul?'), isTrue);
    });

    test('asks relationship -> person', () {
      final all = games.generate(_rich, count: 50, random: Random(2));

      expect(all.any((q) => q.prompt == 'Who is your daughter?'), isTrue);
    });

    test('asks about a place memory', () {
      final all = games.generate(_rich, count: 50, random: Random(2));

      expect(
        all.any((q) => q.prompt.contains('What memory is connected with')),
        isTrue,
      );
    });

    test('never asks a relationship two people share', () {
      // Two sons means "Who is your son?" has two right answers.
      final ambiguous = MemoryAidData(
        people: [
          _person(1, 'Rahul', 'Son'),
          _person(2, 'Arjun', 'Son'),
          _person(3, 'Ananya', 'Daughter'),
        ],
      );

      final all = games.generate(ambiguous, count: 50, random: Random(4));

      expect(all.any((q) => q.prompt == 'Who is your son?'), isFalse);
      expect(all.any((q) => q.prompt == 'Who is your daughter?'), isTrue);
    });
  });

  group('generation — safety', () {
    test('no questions at all from an empty vault', () {
      expect(games.generate(const MemoryAidData()), isEmpty);
      expect(games.canGenerate(const MemoryAidData()), isFalse);
    });

    test('too little data produces nothing rather than a padded quiz', () {
      final thin = MemoryAidData(
        people: [_person(1, 'Rahul', 'Son'), _person(2, 'Ananya', 'Daughter')],
      );

      expect(games.generate(thin, count: 5), isEmpty);
    });

    test('every option in every question is real saved data', () {
      // The core safety property of the whole feature.
      final realValues = {
        ..._rich.people.map((p) => p.name),
        ..._rich.people.map((p) => p.relationship),
        ..._rich.places.map((p) => p.name),
        ..._rich.places.map((p) => p.description),
        ..._rich.notes.map((n) => n.title),
      };

      for (final question in games.generate(_rich, count: 50, random: Random(6))) {
        for (final option in question.options) {
          expect(
            realValues,
            contains(option),
            reason: '"$option" was never entered by the user',
          );
        }
      }
    });

    test('the correct answer is always present and options are distinct', () {
      for (final question in games.generate(_rich, count: 50, random: Random(7))) {
        expect(question.options.length, PersonalizedGameService.optionCount);
        expect(question.options.contains(question.correctAnswer), isTrue);
        expect(question.options.toSet().length, question.options.length);
      }
    });

    test('long place descriptions are not used as answer buttons', () {
      final wordy = MemoryAidData(
        places: [
          _place(1, 'Shillong', 'A' * 200),
          _place(2, 'Home', 'B' * 200),
          _place(3, 'Hospital', 'C' * 200),
        ],
      );

      final all = games.generate(wordy, count: 50, random: Random(8));

      expect(
        all.any((q) => q.prompt.contains('What memory is connected with')),
        isFalse,
      );
    });
  });

  group('game flow', () {
    List<QuizQuestion> threeQuestions() =>
        games.generate(_rich, count: 3, random: Random(11));

    test('starts on question 1 with nothing answered', () {
      final session = _session(threeQuestions());

      expect(session.questionNumber, 1);
      expect(session.totalQuestions, 3);
      expect(session.isAnswered, isFalse);
      expect(session.isComplete, isFalse);
      expect(session.correctCount, 0);
    });

    test('a correct answer counts, a wrong one does not', () {
      final session = _session(threeQuestions());
      final question = session.currentQuestion;

      expect(session.answer(question.correctIndex), isTrue);
      expect(session.correctCount, 1);
      expect(session.wasCorrect, isTrue);

      session.next();
      final wrongIndex = (session.currentQuestion.correctIndex + 1) % 3;
      expect(session.answer(wrongIndex), isFalse);
      expect(session.correctCount, 1);
      expect(session.wasCorrect, isFalse);
    });

    test('answering twice does not change the score', () {
      final session = _session(threeQuestions());

      session.answer(session.currentQuestion.correctIndex);
      session.answer((session.currentQuestion.correctIndex + 1) % 3);

      expect(session.correctCount, 1);
    });

    test('next does nothing until the question is answered', () {
      final session = _session(threeQuestions());

      session.next();
      expect(session.questionNumber, 1);

      session.answer(0);
      session.next();
      expect(session.questionNumber, 2);
    });

    test('answering every question completes the game', () {
      final session = _session(threeQuestions());

      while (!session.isComplete) {
        session.answer(session.currentQuestion.correctIndex);
        if (!session.isLastQuestion) session.next();
      }

      expect(session.isComplete, isTrue);
      expect(session.correctCount, 3);
      expect(session.questionNumber, 3);
    });

    test('next on the last question does not run past the end', () {
      final session = _session(threeQuestions());

      while (!session.isLastQuestion) {
        session.answer(0);
        session.next();
      }
      session.answer(0);
      session.next();

      expect(session.questionNumber, 3);
    });
  });

  group('result', () {
    test('score is 100 per correct answer', () {
      final session = _session(games.generate(_rich, count: 3, random: Random(12)));

      session.answer(session.currentQuestion.correctIndex);
      session.next();
      session.answer((session.currentQuestion.correctIndex + 1) % 3);
      session.next();
      session.answer(session.currentQuestion.correctIndex);

      expect(session.correctCount, 2);
      expect(session.score, 200);
    });

    test('the result is tagged as the personalised game', () {
      final session = _session(games.generate(_rich, count: 3, random: Random(13)));

      while (!session.isComplete) {
        session.answer(session.currentQuestion.correctIndex);
        if (!session.isLastQuestion) session.next();
      }

      final result = session.toResult();
      expect(result.gameType, GameType.personalizedMemory);
      expect(result.difficulty, Difficulty.easy);
      expect(result.completed, isTrue);
      expect(result.score, 300);
      expect(result.mistakes, 0);
    });

    test('leaving early records an incomplete result, not a zero', () {
      final session = _session(games.generate(_rich, count: 3, random: Random(14)));

      session.answer(session.currentQuestion.correctIndex);

      final result = session.toResult();
      expect(result.completed, isFalse);
      expect(result.score, 100); // partial progress is still recorded
    });

    test('mistakes counts wrong answers, nothing more', () {
      final session = _session(games.generate(_rich, count: 3, random: Random(15)));

      session.answer((session.currentQuestion.correctIndex + 1) % 3);
      session.next();
      session.answer(session.currentQuestion.correctIndex);
      session.next();
      session.answer((session.currentQuestion.correctIndex + 1) % 3);

      expect(session.toResult().mistakes, 2);
    });
  });

  group('question count by difficulty', () {
    test('easy asks fewer questions than hard', () {
      final easy = games.generate(_rich, count: 3, random: Random(16));
      final hard = games.generate(_rich, count: 7, random: Random(16));

      expect(easy.length, 3);
      expect(hard.length, greaterThan(easy.length));
    });
  });
}
