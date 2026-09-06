/// What kind of question the user asked.
enum CompanionIntent {
  /// About the user's own saved People, Places or Notes.
  personalMemory,

  /// General education: "What is dementia?", "Why do people forget?"
  memoryEducation,

  /// The user is asking about their OWN health: "Do I have dementia?",
  /// "Why am I forgetting things?"
  ///
  /// These never reach a language model. See [MemoryEducation.safeAnswerFor].
  medicalBoundary,

  /// "What are my reminders today?"
  reminder,

  /// "Let's play a game."
  game,

  /// "Tell me about Shillong." — a place the user may or may not have saved.
  placeInformation,

  /// "What is the largest ocean?" — ordinary facts.
  generalKnowledge,

  /// "Hello", "How are you?", "Tell me something interesting."
  casualConversation,

  /// "I'm bored", "I don't know what to do." — wants a suggestion, not a fact.
  careSupport,
}

/// The intents whose answers come from general knowledge rather than the
/// user's vault. They share one Gemini path and one system instruction, and
/// none of them is ever given personal data.
const Set<CompanionIntent> kGeneralIntents = {
  CompanionIntent.placeInformation,
  CompanionIntent.generalKnowledge,
  CompanionIntent.casualConversation,
  CompanionIntent.careSupport,
};

/// Decides which of the app's abilities a question needs.
///
/// Plain Dart, no network, fully testable — and deliberately so, because one
/// of its jobs is a safety decision. A question about the user's own health
/// must be recognised BEFORE anything is sent anywhere, so the classification
/// cannot depend on a service being reachable.
///
/// Order matters. The medical check runs first, because "Do I have dementia?"
/// also contains the word "dementia" and would otherwise look educational.
class CompanionIntentClassifier {
  const CompanionIntentClassifier();

  /// Words that name a condition or a worry about one.
  static const List<String> _conditionWords = [
    'dementia',
    'alzheimer',
    'alzheimers',
    'memory loss',
    'losing my memory',
    'memory problem',
    'memory problems',
    'cognitive decline',
    'brain disease',
  ];

  /// Phrases where the user is asking about THEMSELVES.
  static const List<String> _aboutMyself = [
    'do i have',
    'have i got',
    'am i getting',
    'am i developing',
    'am i losing',
    'is my memory',
    'my memory getting',
    'my memory worse',
    'my memory problems',
    'whats wrong with me',
    'what is wrong with me',
    'diagnose me',
    'diagnose my',
    'do you think i',
    'am i normal',
    'why am i forgetting',
    'why do i forget',
    'why cant i remember',
    'why can i not remember',
    'am i ok',
  ];

  static const List<String> _educationWords = [
    'what is memory',
    'what is short term memory',
    'what is long term memory',
    'why do we forget',
    'why do people forget',
    'what is dementia',
    'what is alzheimer',
    'types of dementia',
    'what causes memory',
    'what can affect memory',
    'normal ageing',
    'normal aging',
    'when should someone',
    'when to see a doctor',
    'how does sleep',
    'why is sleep',
    'exercise my memory',
    'exercise my brain',
    'stay mentally active',
    'improve my memory',
    'memory exercises',
    'brain health',
  ];

  static const List<String> _reminderWords = [
    'my reminders',
    'reminders today',
    'what reminders',
    'remind me',
    'my medicine time',
  ];

  /// Openings that mean "tell me about the world", not "look in my vault".
  static const List<String> _generalOpenings = [
    'what is the',
    'what are the',
    'who was',
    'who invented',
    'who wrote',
    'why does',
    'why do we',
    'how does',
    'how do',
    'what causes',
    'tell me a fact',
    'tell me something interesting',
    'fun fact',
    'interesting fact',
    'what is photosynthesis',
    'largest',
    'smallest',
    'capital of',
    'prime minister',
    'president of',
  ];

  /// Words that mean the question is about a place.
  static const List<String> _placeOpenings = [
    'tell me about',
    'where is',
    'what is famous in',
    'famous for',
    'what to see in',
    'capital of',
  ];

  static const List<String> _greetings = [
    'hello',
    'hi',
    'hey',
    'good morning',
    'good afternoon',
    'good evening',
    'how are you',
    'who are you',
    'what can you do',
    'thank you',
    'thanks',
    'lets talk',
    'tell me a story',
  ];

  static const List<String> _careWords = [
    'im bored',
    'i am bored',
    'im lonely',
    'i am lonely',
    'nothing to do',
    'what can i do',
    'what should i do',
    'im sad',
    'i feel',
    'cheer me up',
  ];

  static const List<String> _gameWords = [
    'play a game',
    'play game',
    'lets play',
    'memory game',
    'start a game',
    'an activity',
  ];

  CompanionIntent classify(String question) {
    final text = _normalise(question);
    if (text.isEmpty) return CompanionIntent.personalMemory;

    // 1. SAFETY FIRST. Anything where the user is asking about their own
    //    health is answered from a fixed template and never sent to a model.
    if (_isAboutOwnHealth(text)) return CompanionIntent.medicalBoundary;

    // 2. App actions, which are unambiguous phrases.
    if (_containsAny(text, _reminderWords)) return CompanionIntent.reminder;
    if (_containsAny(text, _gameWords)) return CompanionIntent.game;

    // 3. Memory education, before general knowledge: "what is dementia" is
    //    both, and the curated answer is the better one.
    if (_containsAny(text, _educationWords)) return CompanionIntent.memoryEducation;

    // A bare condition word with no "my" attached is a general question:
    // "dementia" or "tell me about alzheimers".
    if (_containsAny(text, _conditionWords) && !_mentionsSelf(text)) {
      return CompanionIntent.memoryEducation;
    }

    // 4. Wanting company or a suggestion rather than a fact.
    if (_containsAny(text, _careWords)) return CompanionIntent.careSupport;

    // 5. Greetings and small talk. Matched on the WHOLE message so that
    //    "hi" is a greeting but "who is Hilda" is not.
    if (_greetings.contains(text) || _startsWithAny(text, _greetings)) {
      return CompanionIntent.casualConversation;
    }

    // 6. A question shaped like a request for general facts.
    if (_containsAny(text, _generalOpenings)) {
      return _looksLikeAPlace(text)
          ? CompanionIntent.placeInformation
          : CompanionIntent.generalKnowledge;
    }

    // 7. "Tell me about X" is ambiguous: X may be a saved person OR a city.
    //    Personal wins, because the vault is checked first and costs nothing.
    //    When the vault has no match the caller re-routes to general
    //    knowledge, so nothing is lost by trying the cheap option first.
    if (_containsAny(text, _placeOpenings)) {
      return CompanionIntent.personalMemory;
    }

    // 8. Default: the user's own vault. A miss there is answered honestly,
    //    which makes this a safe default for anything unrecognised.
    return CompanionIntent.personalMemory;
  }

  /// True when the phrasing points at a place rather than a general fact.
  bool _looksLikeAPlace(String text) =>
      text.contains('where is') ||
      text.contains('capital of') ||
      text.contains('famous in') ||
      text.contains('famous for');

  bool _startsWithAny(String text, List<String> phrases) =>
      phrases.any((phrase) => text.startsWith('$phrase '));

  /// True when the question is about the user's own health or memory ability.
  bool _isAboutOwnHealth(String text) {
    if (_containsAny(text, _aboutMyself)) return true;

    // "Tell me about my memory problems" — self-reference plus a condition.
    return _mentionsSelf(text) && _containsAny(text, _conditionWords);
  }

  bool _mentionsSelf(String text) {
    const markers = [' i ', ' my ', ' me ', ' im ', ' i am '];
    final padded = ' $text ';
    return markers.any(padded.contains);
  }

  bool _containsAny(String text, List<String> phrases) =>
      phrases.any(text.contains);

  /// Lowercase, apostrophes DELETED (not replaced by a space), other
  /// punctuation turned into spaces, whitespace collapsed.
  ///
  /// Deleting the apostrophe rather than spacing it is what makes
  /// "alzheimer's" match "alzheimers" and "what's wrong" match "whats wrong".
  /// Every phrase list below is therefore written without apostrophes.
  String _normalise(String question) => question
      .toLowerCase()
      .replaceAll("'", '')
      .replaceAll(String.fromCharCode(0x2019), '') // curly apostrophe
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
