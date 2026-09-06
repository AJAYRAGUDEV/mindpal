import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/games/odd_one_out/odd_one_out_game.dart';
import 'package:mindpal/games/odd_one_out/odd_one_out_item.dart';
import 'package:mindpal/models/difficulty.dart';
import 'package:mindpal/models/game_type.dart';

OddOneOutGame _newGame(Difficulty difficulty, [int seed = 1]) => OddOneOutGame(
  config: OddOneOutConfig.forDifficulty(difficulty),
  random: Random(seed),
);

void main() {
  group('board construction', () {
    test('each difficulty puts the right number of tiles on screen', () {
      expect(_newGame(Difficulty.easy).items.length, 4);
      expect(_newGame(Difficulty.medium).items.length, 6);
      expect(_newGame(Difficulty.hard).items.length, 9);
    });

    test('exactly ONE item is from a different category', () {
      // Run many seeds: this is the rule the whole game rests on, and a
      // single sample would prove nothing about randomised generation.
      for (var seed = 0; seed < 200; seed++) {
        for (final difficulty in Difficulty.values) {
          final game = _newGame(difficulty, seed);

          final counts = <ItemCategory, int>{};
          for (final item in game.items) {
            counts[item.category] = (counts[item.category] ?? 0) + 1;
          }

          expect(
            counts.length,
            2,
            reason: 'seed $seed ${difficulty.name}: expected exactly two '
                'categories on the board',
          );
          expect(
            counts.values.where((count) => count == 1).length,
            1,
            reason: 'seed $seed ${difficulty.name}: exactly one odd item',
          );
        }
      }
    });

    test('oddIndex really points at the odd item, after shuffling', () {
      for (var seed = 0; seed < 200; seed++) {
        final game = _newGame(Difficulty.hard, seed);
        final odd = game.items[game.oddIndex];

        final sameCategory = game.items
            .where((item) => item.category == odd.category)
            .length;

        expect(sameCategory, 1, reason: 'seed $seed');
      }
    });

    test('no picture is repeated on the board', () {
      for (var seed = 0; seed < 100; seed++) {
        final game = _newGame(Difficulty.hard, seed);
        final labels = game.items.map((item) => item.label).toList();

        expect(labels.toSet().length, labels.length, reason: 'seed $seed');
      }
    });

    test('the two categories on a board are always different', () {
      for (var seed = 0; seed < 200; seed++) {
        final game = _newGame(Difficulty.medium, seed);
        expect(game.oddCategory, isNot(game.majorityCategory));
      }
    });

    test('every item pool has enough pictures for the hardest board', () {
      for (final category in ItemCategory.values) {
        expect(itemsInCategory(category).length, greaterThanOrEqualTo(8));
      }
    });
  });

  group('playing', () {
    test('tapping the odd item is correct', () {
      final game = _newGame(Difficulty.easy);

      expect(game.answer(game.oddIndex), isTrue);
      expect(game.correctCount, 1);
      expect(game.mistakes, 0);
      expect(game.wasCorrect, isTrue);
    });

    test('tapping any other item is a mistake, not a failure', () {
      final game = _newGame(Difficulty.easy);
      final wrongIndex = (game.oddIndex + 1) % game.items.length;

      expect(game.answer(wrongIndex), isFalse);
      expect(game.correctCount, 0);
      expect(game.mistakes, 1);
    });

    test('a second tap in the same round changes nothing', () {
      final game = _newGame(Difficulty.easy);

      game.answer(game.oddIndex);
      game.answer((game.oddIndex + 1) % game.items.length);

      expect(game.correctCount, 1);
      expect(game.mistakes, 0);
    });

    test('next does nothing until the round is answered', () {
      final game = _newGame(Difficulty.easy);

      game.next();
      expect(game.round, 1);

      game.answer(game.oddIndex);
      game.next();
      expect(game.round, 2);
    });

    test('a new round deals a new board and clears the selection', () {
      final game = _newGame(Difficulty.easy);

      game.answer(game.oddIndex);
      game.next();

      expect(game.isAnswered, isFalse);
      expect(game.selectedIndex, isNull);
      expect(game.items.length, 4);
    });
  });

  group('finishing', () {
    test('answering every round completes the game', () {
      final game = _newGame(Difficulty.easy);

      while (!game.isComplete) {
        game.answer(game.oddIndex);
        if (!game.isLastRound) game.next();
      }

      expect(game.isComplete, isTrue);
      expect(game.round, game.config.rounds);
      expect(game.correctCount, game.config.rounds);
    });

    test('next on the last round does not run past the end', () {
      final game = _newGame(Difficulty.easy);

      while (!game.isLastRound) {
        game.answer(game.oddIndex);
        game.next();
      }
      game.answer(game.oddIndex);
      game.next();

      expect(game.round, game.config.rounds);
    });

    test('score is 100 per correct answer', () {
      final game = _newGame(Difficulty.medium);

      game.answer(game.oddIndex);
      game.next();
      game.answer((game.oddIndex + 1) % game.items.length); // wrong
      game.next();
      game.answer(game.oddIndex);

      expect(game.correctCount, 2);
      expect(game.score, 200);
      expect(game.mistakes, 1);
    });

    test('the result is tagged as Odd-One-Out for the history', () {
      final game = _newGame(Difficulty.hard);

      while (!game.isComplete) {
        game.answer(game.oddIndex);
        if (!game.isLastRound) game.next();
      }

      final result = game.toResult();
      expect(result.gameType, GameType.oddOneOut);
      expect(result.difficulty, Difficulty.hard);
      expect(result.completed, isTrue);
      expect(result.score, 500);
    });

    test('leaving early records partial progress, not a zero', () {
      final game = _newGame(Difficulty.easy);
      game.answer(game.oddIndex);

      final result = game.toResult();
      expect(result.completed, isFalse);
      expect(result.score, 100);
    });
  });
}
