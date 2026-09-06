import 'package:flutter/foundation.dart';

import '../../l10n/app_language.dart';
import '../../models/ai_models.dart';
import '../../models/quiz_question.dart';
import '../ai_service.dart';
import '../memory_aid_service.dart';
import '../memory_assistant_service.dart';
import '../personalized_game_service.dart';
import 'ai_gateway_client.dart';
import 'answer_grounding_check.dart';
import 'ai_question_validator.dart';

/// The generative implementation of [AiService].
///
/// It is named for the provider only because that is what it is configured
/// against today; nothing above it knows. The UI depends on [AiService].
///
/// The shape of every method here is the same:
///
///     retrieve locally  ->  if nothing found, stop (no network call)
///                       ->  send only what was found
///                       ->  validate what comes back
///                       ->  on any doubt, use the deterministic result
///
/// The deterministic service is not a sad fallback: it is the correctness
/// baseline. Generated output has to earn its place by passing validation.
class GeminiAiService implements AiService {
  GeminiAiService({
    required this.client,
    this.fallback = const DeterministicAiService(),
    this.assistant = const MemoryAssistantService(),
    this.games = const PersonalizedGameService(),
    this.validator = const AiQuestionValidator(),
    this.grounding = const AnswerGroundingCheck(),
  });

  final AiGatewayClient client;
  final DeterministicAiService fallback;
  final MemoryAssistantService assistant;
  final PersonalizedGameService games;
  final AiQuestionValidator validator;

  /// Checks a generated ANSWER against the context it was given, the same way
  /// [validator] checks generated questions.
  final AnswerGroundingCheck grounding;

  @override
  bool get isGenerative => client.isConfigured;

  /// False, and this is the honest answer: without a network the generative
  /// path cannot run. The app still works, but through [fallback].
  @override
  bool get worksOffline => false;

  /// The last request's outcome, so the UI can say whether an answer was
  /// generated or came from the offline logic. Never inferred — recorded.
  AiDelivery lastDelivery = AiDelivery.deterministic;

  Future<bool> checkAvailable() => client.checkAvailable();

  // ------------------------------------------------------- memory assistant

  @override
  Future<AssistantAnswer> answerMemoryQuestion({
    required String question,
    required MemoryAidData data,
    required AppLanguage language,
  }) async {
    // STEP 1 — local retrieval decides whether there IS an answer.
    //
    // This ordering is the core safety property. The model is only ever asked
    // to phrase a record we already matched on this device. It is never asked
    // "who is Rahul?" with an empty context and left to guess, because if we
    // found nothing we never call it at all.
    final local = assistant.answerQuestion(question, data);

    if (!local.found) {
      lastDelivery = AiDelivery.deterministic;
      return local; // "I don't have that information yet." No network, no cost.
    }

    if (!client.isConfigured) {
      lastDelivery = AiDelivery.deterministic;
      return local;
    }

    // STEP 2 — send ONLY the matched record.
    final context = _contextFor(local, data);
    if (context.isEmpty) {
      lastDelivery = AiDelivery.deterministic;
      return local;
    }

    try {
      final response = await client.askMemoryQuestion(
        question: question,
        languageCode: language.code,
        context: context,
      );

      // The model itself says it did not have enough to go on: trust that
      // over its own prose, and use ours.
      if (!response.hasEnoughInformation || response.text.isEmpty) {
        lastDelivery = AiDelivery.deterministic;
        return local;
      }

      // THE POST-CHECK. The system prompt asks the model not to invent a
      // name; this is what verifies it did not. An answer that mentions a
      // person, year or month the context never contained is discarded and
      // the offline answer is shown instead — the user is never told, because
      // the offline answer is correct and there is nothing for them to do.
      final unsupported = grounding.unsupportedTokens(
        answer: response.text,
        context: context,
      );
      if (unsupported.isNotEmpty) {
        debugPrint(
          'Rejected a generated answer: it mentioned '
          '${unsupported.length} thing(s) that were not in the context.',
        );
        lastDelivery = AiDelivery.deterministic;
        return local;
      }

      lastDelivery = response.languageUsed == language.code
          ? AiDelivery.generated
          : AiDelivery.generatedInEnglishFallback;

      // The SOURCE stays the locally matched one. The model changed the
      // wording, not the fact, and the UI keeps showing where it came from.
      return AssistantAnswer(
        text: response.text,
        source: local.source,
        intent: local.intent,
        subject: local.subject,
        scope: local.scope,
        recordCount: local.recordCount,
      );
    } on AiException catch (error) {
      debugPrint('Smart answer unavailable (${error.code.name}); using '
          'the offline assistant.');
      lastDelivery = AiDelivery.deterministic;
      return local;
    }
  }

  /// Builds the smallest possible context: the one record that matched.
  ///
  /// For "Who is Rahul?" this is Rahul and nobody else — not the rest of the
  /// family, not unrelated notes, not the activity history.
  List<Map<String, dynamic>> _contextFor(
    AssistantAnswer local,
    MemoryAidData data,
  ) {
    // A list question is decided by SCOPE, not by source: "what places have
    // I saved" has source `place` but is not about one place.
    if (local.scope != AssistantScope.single) {
      return _collectionContext(data);
    }

    switch (local.source) {
      case AnswerSource.person:
        final person = assistant.findPerson(local.subject, data.people);
        if (person == null) return const [];
        return [
          {
            'kind': 'person',
            'name': person.name,
            if (person.relationship.trim().isNotEmpty)
              'relationship': person.relationship,
            // The phone number is deliberately NOT sent. It is not needed to
            // phrase "Rahul is your son", and unnecessary personal data should
            // not leave the device.
          },
        ];

      case AnswerSource.place:
        final place = assistant.findPlace(local.subject, data.places);
        if (place == null) return const [];
        return [
          {
            'kind': 'place',
            'name': place.name,
            if (place.description.trim().isNotEmpty)
              'description': place.description,
          },
        ];

      case AnswerSource.note:
        final note = assistant.findNote(local.subject, data.notes);
        if (note == null) return const [];
        return [
          {'kind': 'note', 'title': note.title, 'content': note.content},
        ];

      case AnswerSource.collection:
        return _collectionContext(data);

      case AnswerSource.none:
        return const [];
    }
  }

  /// Names only, hard-capped.
  ///
  /// Enough for the model to phrase "you have saved Rahul, Meena and Priya",
  /// and nothing more — relationships, phone numbers, addresses and note
  /// bodies all stay on the device. The cap matches the gateway's own limit,
  /// which refuses anything larger.
  List<Map<String, dynamic>> _collectionContext(MemoryAidData data) {
    const maxRecords = 8;

    final context = <Map<String, dynamic>>[
      for (final person in data.people) {'kind': 'person', 'name': person.name},
      for (final place in data.places) {'kind': 'place', 'name': place.name},
      for (final note in data.notes) {'kind': 'note', 'title': note.title},
    ];

    return context.take(maxRecords).toList();
  }

  // ------------------------------------------------------ general knowledge

  /// Places, facts, small talk.
  ///
  /// Deliberately NOT grounded against the vault. An answer about Shillong
  /// legitimately mentions Meghalaya, which the user never typed, so the
  /// grounding check that protects personal answers would reject every correct
  /// answer here. The protection on this path is different and stronger: the
  /// request carries no personal data at all, so there is nothing to leak and
  /// nothing personal to get wrong.
  @override
  Future<String?> answerGeneralQuestion({
    required String question,
    required AppLanguage language,
    List<String> history = const [],
  }) async {
    if (!client.isConfigured) {
      lastDelivery = AiDelivery.deterministic;
      return null; // offline: the caller says so honestly
    }

    try {
      final response = await client.askGeneralQuestion(
        question: question,
        languageCode: language.code,
        history: history,
      );

      if (response.text.isEmpty) {
        lastDelivery = AiDelivery.deterministic;
        return null;
      }

      lastDelivery = response.languageUsed == language.code
          ? AiDelivery.generated
          : AiDelivery.generatedInEnglishFallback;
      return response.text;
    } on AiException catch (error) {
      debugPrint('General answer unavailable (${error.code.name}).');
      lastDelivery = AiDelivery.deterministic;
      return null;
    }
  }

  // ------------------------------------------------------ personalised games

  @override
  Future<List<QuizQuestion>> generateQuestions({
    required MemoryAidData data,
    required AppLanguage language,
    int count = 5,
  }) async {
    // The deterministic set is built first. It is both the fallback and the
    // proof that there is enough data to ask anything at all.
    final deterministic = games.generate(data, count: count);

    if (!client.isConfigured || deterministic.isEmpty) {
      lastDelivery = AiDelivery.deterministic;
      return deterministic;
    }

    try {
      final generated = await client.generateQuestions(
        languageCode: language.code,
        context: _gameContext(data),
        count: count,
        optionCount: PersonalizedGameService.optionCount,
      );

      // Everything the model produced is checked against the live database.
      // Anything unproven is dropped, not repaired.
      final validated = validator.keepValid(generated, data);

      if (validated.isEmpty) {
        lastDelivery = AiDelivery.deterministic;
        return deterministic;
      }

      lastDelivery = AiDelivery.generated;

      if (validated.length >= count) return validated.take(count).toList();

      // Some passed, some did not: top up from the deterministic set rather
      // than showing a shorter game.
      return [
        ...validated,
        ...deterministic.take(count - validated.length),
      ];
    } on AiException catch (error) {
      debugPrint('Smart questions unavailable (${error.code.name}); using '
          'the offline generator.');
      lastDelivery = AiDelivery.deterministic;
      return deterministic;
    }
  }

  /// A capped, minimal snapshot for question generation.
  ///
  /// Only the fields a question could use, and only a few records. Phone
  /// numbers, addresses and note bodies are excluded — a quiz never needs
  /// them, and the gateway refuses more than eight records anyway.
  List<Map<String, dynamic>> _gameContext(MemoryAidData data) {
    const perKind = 3;

    return [
      for (final person in data.people.take(perKind))
        {
          'kind': 'person',
          'name': person.name,
          'relationship': person.relationship,
        },
      for (final place in data.places.take(perKind))
        {
          'kind': 'place',
          'name': place.name,
          'description': place.description,
        },
      for (final note in data.notes.take(2))
        {'kind': 'note', 'title': note.title},
    ];
  }

  /// Not implemented. Returning the text unchanged is honest; returning a
  /// guess would not be.
  @override
  Future<String> translate({
    required String text,
    required AppLanguage from,
    required AppLanguage to,
  }) => fallback.translate(text: text, from: from, to: to);
}

/// How the last answer was actually produced.
enum AiDelivery {
  /// Produced on this device by the rule-based services.
  deterministic,

  /// Generated by the AI gateway, in the requested language.
  generated,

  /// Generated, but the model replied in English instead of the language the
  /// user chose. The UI must say so rather than implying it succeeded.
  generatedInEnglishFallback,
}
