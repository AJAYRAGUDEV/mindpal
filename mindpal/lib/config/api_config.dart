/// Where the backend lives.
///
/// The URL is injected at BUILD time, never hard-coded and never a secret:
///
///   flutter build web --dart-define=API_BASE_URL=https://your-api.onrender.com
///
/// The Gemini API key is NOT here and must never be. It lives only in the
/// backend's environment. Anything compiled into Flutter Web ends up in
/// main.dart.js, which anyone can read with View Source — a key placed here
/// would be a published key.
///
/// With nothing configured the app runs entirely offline on its deterministic
/// services, which is the correct default rather than a broken state.
class ApiConfig {
  const ApiConfig._();

  /// The preferred name.
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// The name used before this config existed. Still honoured so older build
  /// commands and scripts keep working.
  static const String _legacyGatewayUrl = String.fromEnvironment(
    'AI_GATEWAY_URL',
    defaultValue: '',
  );

  /// The backend base URL, with no trailing slash.
  static String get baseUrl {
    final chosen = _apiBaseUrl.trim().isNotEmpty
        ? _apiBaseUrl
        : _legacyGatewayUrl;
    return chosen.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static bool get isConfigured => baseUrl.isNotEmpty;

  /// Which define supplied the value — used only in the startup log, so that
  /// "why is it offline?" is answerable in one glance at the console.
  static String get describeSource {
    if (_apiBaseUrl.trim().isNotEmpty) return 'API_BASE_URL';
    if (_legacyGatewayUrl.trim().isNotEmpty) return 'AI_GATEWAY_URL (legacy)';
    return 'not set';
  }
}
