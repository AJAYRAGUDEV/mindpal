/// Layout constants used across the app.
///
/// Keeping these in one place means "make everything a bit bigger for
/// low-vision users" becomes a change to this file, not to twenty widgets.
class AppSizes {
  const AppSizes._();

  static const double pagePadding = 20;
  static const double cardPadding = 20;

  static const double gapSmall = 8;
  static const double gap = 16;
  static const double gapLarge = 28;

  static const double radius = 16;

  /// Accessibility guidance says 48dp minimum for a touch target.
  /// We use 64 because our users may have reduced fine motor control.
  static const double minTouchTarget = 64;
  static const double buttonHeight = 64;

  static const double iconMedium = 30;
  static const double iconLarge = 44;
}
