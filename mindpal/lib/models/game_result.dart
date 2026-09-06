import 'dart:convert';

import 'difficulty.dart';
import 'game_type.dart';
import 'identifiable.dart';

/// What one finished (or abandoned) game produced.
///
/// All three games produce this same shape, which is why the history screen
/// and the Home dashboard only ever need to understand ONE model.
///
/// It follows exactly the same rules as UserProfile from Day 1: every field is
/// final, and `fromMap` gives every field a fallback so old saved data never
/// crashes the app.
class GameResult implements Identifiable {
  const GameResult({
    this.id = 0,
    required this.gameType,
    required this.difficulty,
    required this.score,
    required this.durationSeconds,
    required this.completed,
    required this.mistakes,
    required this.playedAt,
  });

  /// Assigned by JsonListStore when the result is saved to history.
  /// 0 means "not saved yet" — a result that has only just been played.
  @override
  final int id;

  final GameType gameType;
  final Difficulty difficulty;
  final int score;
  final int durationSeconds;

  /// False when the user left before finishing.
  final bool completed;
  final int mistakes;
  final DateTime playedAt;

  /// "1:05" or "42s"
  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// True when this game was played on the same calendar day as [day].
  ///
  /// We compare year/month/day rather than subtracting timestamps: a game at
  /// 11pm and a check at 1am are 2 hours apart but are different days.
  bool isOnSameDayAs(DateTime day) {
    return playedAt.year == day.year &&
        playedAt.month == day.month &&
        playedAt.day == day.day;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'gameType': gameType.name,
    'difficulty': difficulty.name,
    'score': score,
    'durationSeconds': durationSeconds,
    'completed': completed,
    'mistakes': mistakes,
    'playedAt': playedAt.toIso8601String(),
  };

  factory GameResult.fromMap(Map<String, dynamic> map) {
    return GameResult(
      id: (map['id'] as num?)?.toInt() ?? 0,
      gameType: GameType.fromName(map['gameType'] as String?),
      difficulty: Difficulty.fromName(map['difficulty'] as String?),
      score: (map['score'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      completed: map['completed'] as bool? ?? false,
      mistakes: (map['mistakes'] as num?)?.toInt() ?? 0,
      playedAt:
          DateTime.tryParse(map['playedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Returns a copy carrying a storage id.
  GameResult withId(int id) => GameResult(
    id: id,
    gameType: gameType,
    difficulty: difficulty,
    score: score,
    durationSeconds: durationSeconds,
    completed: completed,
    mistakes: mistakes,
    playedAt: playedAt,
  );

  String toJson() => jsonEncode(toMap());

  factory GameResult.fromJson(String source) =>
      GameResult.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
