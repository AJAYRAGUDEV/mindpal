/// One error type for the whole app.
///
/// Services catch low-level problems (disk full, corrupt data, a failed
/// platform channel) and re-throw them as an AppException whose [message] is
/// plain enough to show directly to an elderly user.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// Shown to the user. Keep it short and non-technical.
  final String message;

  /// The original error, kept for debugging. Never shown in the UI.
  final Object? cause;

  @override
  String toString() =>
      'AppException: $message${cause == null ? '' : ' (cause: $cause)'}';
}
