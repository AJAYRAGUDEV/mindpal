import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/games/memory_match/memory_card.dart';
import 'package:mindpal/games/memory_match/memory_match_config.dart';
import 'package:mindpal/games/memory_match/memory_match_game.dart';
import 'package:mindpal/models/difficulty.dart';

/// These tests build NO widgets. Because the game rules live in a plain Dart
/// class, we can test every rule in milliseconds without a phone, an emulator,
/// or a single pixel being drawn. That is the practical payoff of keeping
/// logic out of the UI.

MemoryMatchGame _newGame(Difficulty difficulty) => MemoryMatchGame(
  config: MemoryMatchConfig.forDifficulty(difficulty),
  random: Random(1), // fixed seed = the same board every run
);

/// The other card carrying the same picture.
MemoryCard _partnerOf(MemoryMatchGame game, MemoryCard card) => game.cards
    .firstWhere((c) => c.id != card.id && c.symbol.label == card.symbol.label);

void main() {
  group('dealing', () {
    test('easy deals 8 cards with every picture exactly twice', () {
      final game = _newGame(Difficulty.easy);

      expect(game.cards.length, 8);

      final counts = <String, int>{};
      for (final card in game.cards) {
        counts[card.symbol.label] = (counts[card.symbol.label] ?? 0) + 1;
      }
      expect(counts.length, 4); // 4 distinct pictures
      expect(counts.values.every((count) => count == 2), isTrue);
    });

    test('every card starts face down', () {
      final game = _newGame(Difficulty.easy);
      expect(game.cards.every((card) => card.isHidden), isTrue);
      expect(game.hasStarted, isFalse);
    });
  });

  group('matching', () {
    test('a correct pair stays face up and counts as a match', () {
      final game = _newGame(Difficulty.easy);
      final first = game.cards.first;
      final partner = _partnerOf(game, first);

      expect(game.tap(first), TapResult.firstCardRevealed);
      expect(game.tap(partner), TapResult.matched);

      expect(first.isMatched, isTrue);
      expect(partner.isMatched, isTrue);
      expect(game.matches, 1);
      expect(game.mistakes, 0);
      expect(game.moves, 1);
      expect(game.isWaitingToHide, isFalse); // board is playable again
    });

    test('a wrong pair counts a mistake and locks the board', () {
      final game = _newGame(Difficulty.easy);
      final first = game.cards.first;
      final wrong = game.cards.firstWhere(
        (card) => card.symbol.label != first.symbol.label,
      );

      game.tap(first);
      expect(game.tap(wrong), TapResult.mismatched);

      expect(game.mistakes, 1);
      expect(game.isWaitingToHide, isTrue);

      // Further taps are refused while the wrong pair is on show.
      final third = game.cards.firstWhere((c) => c.isHidden);
      expect(game.tap(third), TapResult.ignored);

      game.hideMismatch();
      expect(first.isFaceUp, isFalse);
      expect(wrong.isFaceUp, isFalse);
      expect(game.isWaitingToHide, isFalse);
    });

    test('tapping the same card twice does nothing', () {
      final game = _newGame(Difficulty.easy);
      final card = game.cards.first;

      game.tap(card);
      expect(game.tap(card), TapResult.ignored);
      expect(game.moves, 0);
    });
  });

  group('finishing and scoring', () {
    test('matching every pair completes the game', () {
      final game = _newGame(Difficulty.easy);

      while (!game.isComplete) {
        final next = game.cards.firstWhere((card) => !card.isMatched);
        game.tap(next);
        game.tap(_partnerOf(game, next));
      }

      expect(game.isComplete, isTrue);
      expect(game.matches, 4);
      expect(game.mistakes, 0);
      // 4 pairs x 100, minus almost no time, plus 0 easy bonus.
      expect(game.score, greaterThan(300));
    });

    test('score is zero before anything is matched', () {
      expect(_newGame(Difficulty.easy).score, 0);
    });

    test('score never goes below zero, however many mistakes', () {
      final game = _newGame(Difficulty.easy);

      // One real match, then a pile of wrong guesses.
      final first = game.cards.first;
      game.tap(first);
      game.tap(_partnerOf(game, first));

      for (var i = 0; i < 20; i++) {
        final a = game.cards.firstWhere((card) => !card.isMatched);
        final b = game.cards.firstWhere(
          (card) => !card.isMatched && card.symbol.label != a.symbol.label,
        );
        game.tap(a);
        game.tap(b);
        game.hideMismatch();
      }

      expect(game.mistakes, 20);
      expect(game.score, 0);
    });

    test('harder difficulties award a bonus', () {
      expect(MemoryMatchConfig.forDifficulty(Difficulty.easy).difficultyBonus, 0);
      expect(
        MemoryMatchConfig.forDifficulty(Difficulty.hard).difficultyBonus,
        greaterThan(
          MemoryMatchConfig.forDifficulty(Difficulty.medium).difficultyBonus,
        ),
      );
    });
  });

  test('result carries the game type and difficulty', () {
    final game = _newGame(Difficulty.medium);
    final first = game.cards.first;
    game.tap(first);
    game.tap(_partnerOf(game, first));

    final result = game.toResult();
    expect(result.difficulty, Difficulty.medium);
    expect(result.completed, isFalse); // only 1 of 6 pairs found
    expect(result.mistakes, 0);
  });
}
