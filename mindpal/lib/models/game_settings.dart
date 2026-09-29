import 'dart:convert';

import 'difficulty.dart';

/// How the player wants games to behave.
///
/// One small record, saved under one key. These are accessibility choices, not
/// preferences to be buried: sound, motion and spoken instructions each make
/// the difference between a game being playable and not, for different people.
///
/// Every field has a safe default, and [fromMap] never throws, so a settings
/// blob written by an older version still opens.
class GameSettings {
  const GameSettings({
    this.soundOn = true,
    this.reducedMotion = false,
    this.spokenInstructions = false,
    this.difficulty = Difficulty.easy,
    this.packId,
    this.acceptDifficultySuggestions = true,
  });

  /// Feedback sounds and spoken praise. On by default, because the sound is
  /// part of knowing a tap registered.
  final bool soundOn;

  /// Cuts card flips and highlights to the shortest usable duration. For
  /// players who find movement distracting or nauseating — and it also makes
  /// the games noticeably faster on a slow phone.
  final bool reducedMotion;

  /// Reads the instructions aloud when a game opens.
  ///
  /// Off by default on purpose. A voice starting unasked is startling, and on a
  /// device with no installed voice it would simply be silence with no
  /// explanation. The Listen button is always there either way.
  final bool spokenInstructions;

  /// Remembered across launches, so a player who found Easy comfortable does
  /// not have to set it again every time.
  final Difficulty difficulty;

  /// The cultural pack last chosen. Null means the app's everyday pictures.
  final String? packId;

  /// Whether MindPal may OFFER a different level after several sessions. It
  /// only ever offers; it never changes the level by itself.
  final bool acceptDifficultySuggestions;

  static const GameSettings defaults = GameSettings();

  GameSettings copyWith({
    bool? soundOn,
    bool? reducedMotion,
    bool? spokenInstructions,
    Difficulty? difficulty,
    String? packId,
    bool clearPack = false,
    bool? acceptDifficultySuggestions,
  }) => GameSettings(
    soundOn: soundOn ?? this.soundOn,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    spokenInstructions: spokenInstructions ?? this.spokenInstructions,
    difficulty: difficulty ?? this.difficulty,
    packId: clearPack ? null : (packId ?? this.packId),
    acceptDifficultySuggestions:
        acceptDifficultySuggestions ?? this.acceptDifficultySuggestions,
  );

  Map<String, dynamic> toMap() => {
    'soundOn': soundOn,
    'reducedMotion': reducedMotion,
    'spokenInstructions': spokenInstructions,
    'difficulty': difficulty.name,
    'packId': packId,
    'acceptDifficultySuggestions': acceptDifficultySuggestions,
  };

  factory GameSettings.fromMap(Map<String, dynamic> map) => GameSettings(
    soundOn: map['soundOn'] as bool? ?? true,
    reducedMotion: map['reducedMotion'] as bool? ?? false,
    spokenInstructions: map['spokenInstructions'] as bool? ?? false,
    difficulty: Difficulty.fromName(map['difficulty'] as String?),
    packId: map['packId'] as String?,
    acceptDifficultySuggestions:
        map['acceptDifficultySuggestions'] as bool? ?? true,
  );

  String toJson() => jsonEncode(toMap());

  /// Returns the defaults for anything unreadable. Bad saved settings must
  /// never stop a game opening.
  factory GameSettings.fromJson(String source) {
    try {
      return GameSettings.fromMap(jsonDecode(source) as Map<String, dynamic>);
    } catch (_) {
      return defaults;
    }
  }
}
