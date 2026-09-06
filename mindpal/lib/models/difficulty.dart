/// How hard a game should be.
///
/// This is an "enhanced enum": a plain enum that is allowed to carry data and
/// methods. It saves us writing a separate class just to hold three labels.
enum Difficulty {
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const Difficulty(this.label);

  /// Shown on buttons and cards.
  final String label;

  /// Reading a difficulty back from saved JSON.
  ///
  /// We store `name` ("easy") rather than the index (0). If we ever reorder
  /// the enum values, saved data still reads correctly — storing the index
  /// would silently turn every old "hard" score into "easy".
  static Difficulty fromName(String? name) {
    return Difficulty.values.firstWhere(
      (difficulty) => difficulty.name == name,
      orElse: () => Difficulty.easy,
    );
  }
}
