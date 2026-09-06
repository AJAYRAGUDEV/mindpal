import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The three cognitive games.
///
/// Each value carries its own name, description, icon and colour, so the game
/// hub can build its cards by simply looping over `GameType.values`. Adding a
/// fourth game later means adding one entry here.
///
/// A note on purity: strictly speaking a "model" should not know about icons
/// and colours (that is UI). Splitting them would mean two files and a lookup
/// table to keep in sync. For an MVP this size, one file is easier to reason
/// about — a deliberate trade, not an oversight.
enum GameType {
  memoryMatch(
    label: 'Memory Match',
    description: 'Match the pairs and exercise your memory.',
    icon: Icons.grid_view_rounded,
    color: AppColors.activity,
  ),
  sequenceRecall(
    label: 'Sequence Recall',
    description: 'Remember the sequence and repeat it.',
    icon: Icons.timeline_rounded,
    color: AppColors.memory,
  ),
  oddOneOut(
    label: 'Odd-One-Out',
    description: "Find the item that doesn't belong.",
    icon: Icons.search_rounded,
    color: AppColors.reminder,
  ),
  personalizedMemory(
    label: 'Memory Moment',
    description: 'Questions made from your own saved memories.',
    icon: Icons.favorite_rounded,
    color: AppColors.primary,
  );

  const GameType({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;

  /// See the note in [Difficulty.fromName] — we store the name, not the index.
  static GameType fromName(String? name) {
    return GameType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => GameType.memoryMatch,
    );
  }
}
