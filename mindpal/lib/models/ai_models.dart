/// Reads a field that SHOULD be a string, from data we do not control.
///
/// `map['x'] as String?` throws if the value is a number — and this map comes
/// from a language model, which is exactly where a stray number turns up. A
/// wrong type here must degrade to an empty field, never to a crash.
String _readString(Object? value) => value is String ? value.trim() : '';

/// Same idea for booleans. [fallback] is used when the value is missing or is
/// the wrong type.
bool _readBool(Object? value, {required bool fallback}) =>
    value is bool ? value : fallback;

/// Why an AI request failed. The app reacts differently to each.
enum AiErrorCode {
  /// The gateway has no key configured.
  notConfigured,
  offline,
  timeout,
  rateLimited,
  upstream,

  /// Reached the model, but what came back could not be trusted.
  invalidResponse,

  unknown;

  static AiErrorCode fromName(String? name) => switch (name) {
    'not_configured' => notConfigured,
    'timeout' => timeout,
    'rate_limited' => rateLimited,
    'upstream_error' => upstream,
    'invalid_response' => invalidResponse,
    'network_error' => offline,
    _ => unknown,
  };

  /// A plain sentence for an elderly user. Never a status code.
  String get message => switch (this) {
    AiErrorCode.notConfigured => 'The AI Assistant is not set up on this app.',
    AiErrorCode.offline =>
      'The AI Assistant could not be reached. Please check the internet '
          'connection and try again.',
    AiErrorCode.timeout =>
      'The AI Assistant took too long to answer. Please try again.',
    AiErrorCode.rateLimited =>
      'Too many questions just now. Please wait a minute and try again.',
    AiErrorCode.upstream ||
    AiErrorCode.invalidResponse ||
    AiErrorCode.unknown =>
      'The AI Assistant is temporarily unavailable. Please try again.',
  };

  /// Whether asking again in a moment could help. False only when the
  /// gateway itself is not set up, which no amount of retrying will change.
  bool get isRetryable => this != AiErrorCode.notConfigured;
}

class AiException implements Exception {
  const AiException(this.code, [this.detail]);

  final AiErrorCode code;
  final String? detail;

  String get message => code.message;

  @override
  String toString() => 'AiException(${code.name})';
}

/// A generated answer to a memory question.
class AiMemoryResponse {
  const AiMemoryResponse({
    required this.text,
    required this.hasEnoughInformation,
    required this.languageUsed,
    this.cached = false,
  });

  final String text;

  /// False when the model said the context was not enough. The app then shows
  /// its own "I don't have that information yet" rather than the model's
  /// phrasing of it.
  final bool hasEnoughInformation;

  /// The language code the model says it actually replied in. When this does
  /// not match what was asked for, the UI says so — see requirement 12.
  final String languageUsed;

  final bool cached;

  factory AiMemoryResponse.fromMap(Map<String, dynamic> map) =>
      AiMemoryResponse(
        text: _readString(map['text']),
        hasEnoughInformation: _readBool(
          map['hasEnoughInformation'],
          fallback: true,
        ),
        languageUsed: _readString(map['languageUsed']).isEmpty
            ? 'en'
            : _readString(map['languageUsed']),
        cached: _readBool(map['cached'], fallback: false),
      );
}

/// One question as the model produced it — BEFORE validation.
///
/// This type deliberately exists separately from QuizQuestion. Nothing of this
/// shape ever reaches the UI: it has to survive AiQuestionValidator and be
/// rebuilt as a QuizQuestion first. Keeping "what the model said" and "what we
/// are willing to show" as two different types makes it impossible to
/// accidentally display unverified content.
class AiGameQuestion {
  const AiGameQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.sourceMemory,
  });

  final String question;
  final List<String> options;
  final String correctAnswer;

  /// The name or title the question is about. Checked against the real
  /// database before the question is allowed through.
  final String sourceMemory;

  factory AiGameQuestion.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];

    return AiGameQuestion(
      question: _readString(map['question']),
      options: [
        if (rawOptions is List)
          for (final option in rawOptions)
            if (option is String) option.trim(),
      ],
      correctAnswer: _readString(map['correctAnswer']),
      sourceMemory: _readString(map['sourceMemory']),
    );
  }
}
