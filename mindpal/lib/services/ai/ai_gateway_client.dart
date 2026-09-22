import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../models/ai_models.dart';

/// Talks to the MindPal AI gateway over HTTPS.
///
/// It knows nothing about Gemini. The word "Gemini" does not appear in this
/// file, or anywhere else in the Flutter app, on purpose: the provider is the
/// backend's business, and swapping it must not touch the phone.
///
/// It also holds NO credentials. The base URL is supplied at build time and is
/// not a secret; the API key lives only in the server's environment.
class AiGatewayClient {
  AiGatewayClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  /// Supplied at build time through ApiConfig. Empty means "no backend
  /// configured", and the app stays fully offline on its local services.
  static String get configuredBaseUrl => ApiConfig.baseUrl;

  final String baseUrl;
  final http.Client _http;

  /// Long, on purpose. A free Render instance takes 30-50s to wake from
  /// sleep, and the gateway may try up to three models at 12s each. A 20s
  /// timeout here turned every cold start into a false "offline".
  static const Duration _timeout = Duration(seconds: 45);

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  /// Asks the gateway to phrase an answer from already-retrieved records.
  ///
  /// [context] must contain ONLY the records matched locally for this
  /// question. Never the whole database — see the privacy note in the README.
  Future<AiMemoryResponse> askMemoryQuestion({
    required String question,
    required String languageCode,
    required List<Map<String, dynamic>> context,
  }) async {
    final body = await _post({
      'task': 'memory_assistant',
      'language': languageCode,
      'context': context,
      'userInput': question,
    });
    return AiMemoryResponse.fromMap(body);
  }

  /// A question that is NOT about the user: a place, a fact, small talk.
  ///
  /// Note `context` is not a parameter. This call carries no personal data at
  /// all, and the gateway rejects the request if any is attached — so a bug
  /// here cannot become a privacy failure.
  ///
  /// [history] holds recent GENERAL turns only, so "what is it famous for?"
  /// resolves to the place just discussed. Personal-memory turns never appear.
  Future<AiMemoryResponse> askGeneralQuestion({
    required String question,
    required String languageCode,
    List<String> history = const [],
  }) async {
    final body = await _post({
      'task': 'general_knowledge',
      'language': languageCode,
      'context': const [],
      'userInput': question,
      'history': history,
    });
    return AiMemoryResponse.fromMap(body);
  }

  Future<List<AiGameQuestion>> generateQuestions({
    required String languageCode,
    required List<Map<String, dynamic>> context,
    required int count,
    required int optionCount,
  }) async {
    final body = await _post({
      'task': 'game_questions',
      'language': languageCode,
      'context': context,
      'count': count,
      'optionCount': optionCount,
    });

    final raw = body['questions'];
    if (raw is! List) throw const AiException(AiErrorCode.invalidResponse);

    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) AiGameQuestion.fromMap(item),
    ];
  }

  /// The one place network errors are turned into typed [AiException]s, so no
  /// caller ever has to handle a raw SocketException or a status code.
  Future<Map<String, dynamic>> _post(Map<String, dynamic> payload) async {
    if (!isConfigured) throw const AiException(AiErrorCode.notConfigured);

    http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/ai'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiException(AiErrorCode.timeout);
    } catch (error) {
      // No internet, gateway not running, DNS failure, CORS refusal — from the
      // app's point of view these are all "cannot reach it".
      // The error is logged WITHOUT the payload, which holds personal data.
      debugPrint('AI gateway unreachable: ${error.runtimeType}');
      throw const AiException(AiErrorCode.offline);
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException(AiErrorCode.invalidResponse);
    }

    if (response.statusCode != 200 || body['success'] != true) {
      // Status and code only. The body may echo nothing personal, but the
      // rule is simpler to keep if the log never carries response text.
      debugPrint(
        'AI gateway: HTTP ${response.statusCode} code=${body['code']} '
        'retryable=${body['retryable']}',
      );
      throw AiException(
        AiErrorCode.fromName(body['code'] as String?),
        body['error'] as String?,
      );
    }

    return body;
  }

  /// Whether the gateway is up and has a key. Used to decide whether to offer
  /// smart answers at all, rather than letting the user hit a failure.
  Future<bool> checkAvailable() async {
    if (!isConfigured) return false;
    try {
      final response = await _http
          .get(Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['geminiConfigured'] == true;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _http.close();
}
