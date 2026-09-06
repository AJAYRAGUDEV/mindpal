import '../l10n/app_language.dart';
import '../models/quiz_question.dart';
import '../services/memory_aid_service.dart';
import 'memory_assistant_service.dart';
import 'personalized_game_service.dart';

/// The seam where a real AI model would plug in one day.
///
/// INTERFACE ONLY — no model, no API key, no network call exists in this
/// project. The one implementation below, [DeterministicAiService], is built
/// from ordinary rules and database lookups.
///
/// It is named "Deterministic", not "Local AI" and not "LocalLLM", because it
/// is neither. Calling rule-based code an AI is exactly the kind of claim this
/// project has decided not to make. The capability matrix therefore still
/// reports AI as `notAvailable` for every language, and a unit test enforces
/// that.
///
/// What a real implementation would have to solve, none of which is done:
///   * which provider, whose API key, who pays;
///   * what leaves the device (see the privacy note on generateQuestion);
///   * behaviour with no internet;
///   * per-language quality, which differs enormously and must be measured,
///     not assumed, for the smaller NER languages.
abstract class AiService {
  /// True when this implementation can produce genuinely generated text, as
  /// opposed to filling in templates. Currently false everywhere.
  bool get isGenerative;

  /// Whether this implementation can work with no internet.
  bool get worksOffline;

  /// Makes a quiz question from the user's saved information.
  ///
  /// PRIVACY: a networked implementation must send only the few fields needed
  /// for one question — never the whole memory database. The deterministic
  /// implementation sends nothing at all, because nothing leaves the device.
  Future<List<QuizQuestion>> generateQuestions({
    required MemoryAidData data,
    required AppLanguage language,
    int count,
  });

  /// Answers a question about the user's own saved information.
  Future<AssistantAnswer> answerMemoryQuestion({
    required String question,
    required MemoryAidData data,
    required AppLanguage language,
  });

  /// Answers a question that is NOT about the user's saved information.
  ///
  /// Returns null when there is no generative path available — the caller then
  /// says so plainly rather than pretending an offline answer came from a
  /// model.
  Future<String?> answerGeneralQuestion({
    required String question,
    required AppLanguage language,
    List<String> history = const [],
  });

  /// Translates text. Not implemented; the deterministic version returns the
  /// text unchanged rather than guessing.
  Future<String> translate({
    required String text,
    required AppLanguage from,
    required AppLanguage to,
  });
}

/// The rules-based implementation. Instant, free, offline, and incapable of
/// inventing a fact.
class DeterministicAiService implements AiService {
  const DeterministicAiService({
    this.assistant = const MemoryAssistantService(),
    this.games = const PersonalizedGameService(),
  });

  final MemoryAssistantService assistant;
  final PersonalizedGameService games;

  /// False, and it must stay false until a real model is integrated.
  @override
  bool get isGenerative => false;

  @override
  bool get worksOffline => true;

  @override
  Future<List<QuizQuestion>> generateQuestions({
    required MemoryAidData data,
    required AppLanguage language,
    int count = 5,
  }) async => games.generate(data, count: count);

  @override
  Future<AssistantAnswer> answerMemoryQuestion({
    required String question,
    required MemoryAidData data,
    required AppLanguage language,
  }) async => assistant.answerQuestion(question, data);

  /// Null, always. The offline implementation has no general knowledge and
  /// must not invent any.
  @override
  Future<String?> answerGeneralQuestion({
    required String question,
    required AppLanguage language,
    List<String> history = const [],
  }) async => null;

  /// Returns the input untouched. Translating by rule would produce nonsense,
  /// and silently returning wrong text is worse than returning none.
  @override
  Future<String> translate({
    required String text,
    required AppLanguage from,
    required AppLanguage to,
  }) async => text;
}
