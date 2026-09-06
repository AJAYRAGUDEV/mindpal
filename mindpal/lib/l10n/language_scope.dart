import 'package:flutter/material.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// Makes the current language's strings available to every screen.
///
/// This is an **InheritedWidget** — the Flutter mechanism for handing data
/// *down* the widget tree without passing it through every constructor in
/// between. Until now this app has passed everything explicitly (profile,
/// reminders, services), which is clear and easy to follow. Strings are the
/// case where that stops working: literally every widget needs them, and
/// threading a parameter through forty constructors would be absurd.
///
/// How it works:
///   * LanguageScope sits high in the tree, above MaterialApp.
///   * Any widget below calls `LanguageScope.of(context)`.
///   * Flutter walks UP from that context to find the nearest LanguageScope.
///   * Because `of` uses dependOnInheritedWidgetOfExactType, that widget is
///     automatically rebuilt whenever the language changes.
///
/// That last point is the important one: changing the language rebuilds every
/// screen that reads a string, with no listeners to wire up by hand.
class LanguageScope extends InheritedWidget {
  const LanguageScope({
    super.key,
    required this.strings,
    required this.onLanguageChanged,
    required super.child,
  });

  final AppStrings strings;

  /// Called when the user picks a language. The app rebuilds with it.
  final ValueChanged<AppLanguage> onLanguageChanged;

  /// The strings for the current language.
  ///
  /// Throws a clear error rather than returning null if it is used outside a
  /// LanguageScope, which can only happen if someone forgets to wrap the app.
  static AppStrings of(BuildContext context) => _scopeOf(context).strings;

  /// The whole scope, for the language screen, which needs to change it.
  static LanguageScope scopeOf(BuildContext context) => _scopeOf(context);

  static LanguageScope _scopeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    assert(scope != null, 'No LanguageScope found above this widget.');
    return scope!;
  }

  /// Flutter asks this to decide whether widgets that depend on us need to
  /// rebuild. Comparing the language code means a rebuild happens exactly when
  /// the language actually changed, and never otherwise.
  @override
  bool updateShouldNotify(LanguageScope oldWidget) =>
      oldWidget.strings.language.code != strings.language.code;
}
