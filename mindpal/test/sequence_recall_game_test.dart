import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/games/sequence_recall/sequence_recall_config.dart';
import 'package:mindpal/games/sequence_recall/sequence_recall_game.dart';
import 'package:mindpal/models/difficulty.dart';

SequenceRecallGame _newGame(Difficulty difficulty) => SequenceRecallGame(
  config: SequenceRecallConfig.forDifficulty(difficulty),
  random: Random(7),
);

/// Plays the current sequence back perfectly.
void _playRoundCorrectly(SequenceRecallGame game) {
  final sequence = List<int>.from(game.sequence);
  for (final pad in sequence) {
    game.submitTap(pad);
  }
}

/// Taps a pad that is definitely wrong for the current position.
void _tapWrongPad(SequenceRecallGame game) {
  final expected = game.expectedPad;
  final wrong = (expected + 1) % game.config.padCount;
  game.submitTap(wrong);
}

void main() {
  group('sequence generation', () {
    test('round 1 uses the difficulty start length', () {
      expect(_newGame(Difficulty.easy).sequence.length, 3);
      expect(_newGame(Difficulty.medium).sequence.length, 4);
      expect(_newGame(Difficulty.hard).sequence.length, 5);
    });

    test('never lights the same pad twice in a row', () {
      // Repeat many times: this is a randomised rule, so one sample is not
      // evidence. Two identical highlights in a row would be unplayable.
      for (var seed = 0; seed < 200; seed++) {
        final game = SequenceRecallGame(
          config: SequenceRecallConfig.forDifficulty(Difficulty.hard),
          random: Random(seed),
        );
        for (var i = 1; i < game.sequence.length; i++) {
          expect(
            game.sequence[i],
            isNot(game.sequence[i - 1]),
            reason: 'seed $seed produced a repeat at position $i',
          );
        }
      }
    });

    test('every pad index is within range', () {
      final game = _newGame(Difficulty.easy);
      expect(
        game.sequence.every((pad) => pad >= 0 && pad < game.config.padCount),
        isTrue,
      );
    });
  });

  group('playing a round', () {
    test('correct taps advance progress, last one completes the round', () {
      final game = _newGame(Difficulty.easy);
      final sequence = List<int>.from(game.sequence);

      expect(game.submitTap(sequence[0]), SequenceTapResult.correct);
      expect(game.progress, 1);
      expect(game.submitTap(sequence[1]), SequenceTapResult.correct);
      expect(game.submitTap(sequence[2]), SequenceTapResult.roundComplete);

      expect(game.roundsCompleted, 1);
      expect(game.mistakes, 0);
    });

    test('a wrong tap costs one try', () {
      final game = _newGame(Difficulty.easy);
      final triesBefore = game.triesRemaining;

      expect(_tapWrongPadResult(game), SequenceTapResult.wrong);

      expect(game.mistakes, 1);
      expect(game.triesRemaining, triesBefore - 1);
      expect(game.isOver, isFalse);
    });

    test('the sequence grows by one each round', () {
      final game = _newGame(Difficulty.easy);
      expect(game.sequence.length, 3);

      _playRoundCorrectly(game);
      game.advanceRound();
      game.startRound();
      expect(game.sequence.length, 4);

      _playRoundCorrectly(game);
      game.advanceRound();
      game.startRound();
      expect(game.sequence.length, 5);

      expect(game.roundsCompleted, 2);
      expect(game.longestSequence, 4);
    });

    test('a retry keeps the same length but a fresh sequence', () {
      final game = _newGame(Difficulty.medium);
      final before = List<int>.from(game.sequence);

      _tapWrongPad(game);
      game.startRound(); // retry, no advanceRound

      expect(game.sequence.length, before.length);
      expect(game.progress, 0);
    });
  });

  group('ending and scoring', () {
    test('the game ends after three wrong answers', () {
      final game = _newGame(Difficulty.easy);

      _tapWrongPad(game);
      game.startRound();
      _tapWrongPad(game);
      game.startRound();
      expect(game.isOver, isFalse);

      _tapWrongPad(game);
      expect(game.isOver, isTrue);
      expect(game.triesRemaining, 0);
    });

    test('score is zero until a whole round is passed', () {
      final game = _newGame(Difficulty.easy);
      expect(game.score, 0);

      final sequence = List<int>.from(game.sequence);
      game.submitTap(sequence[0]); // partial round earns nothing
      expect(game.score, 0);
    });

    test('each passed round banks length x 30', () {
      final game = _newGame(Difficulty.easy);

      _playRoundCorrectly(game); // 3 pads -> 90
      expect(game.score, 90);

      game.advanceRound();
      game.startRound();
      _playRoundCorrectly(game); // 4 pads -> 120, total 210
      expect(game.score, 210);
    });

    test('mistakes subtract, difficulty adds, never below zero', () {
      final easy = _newGame(Difficulty.easy);
      _playRoundCorrectly(easy);
      expect(easy.score, 90); // no bonus on easy

      final hard = _newGame(Difficulty.hard);
      _playRoundCorrectly(hard); // 5 pads -> 150, +100 bonus
      expect(hard.score, 250);

      hard.advanceRound();
      hard.startRound();
      _tapWrongPad(hard); // -20
      expect(hard.score, 230);
    });

    test('result reports completed only after a full round', () {
      final unfinished = _newGame(Difficulty.easy);
      expect(unfinished.toResult().completed, isFalse);

      final played = _newGame(Difficulty.easy);
      _playRoundCorrectly(played);
      expect(played.toResult().completed, isTrue);
    });
  });
}

/// Small helper so the "wrong tap" test can assert on the returned value.
SequenceTapResult _tapWrongPadResult(SequenceRecallGame game) {
  final expected = game.expectedPad;
  final wrong = (expected + 1) % game.config.padCount;
  return game.submitTap(wrong);
}
