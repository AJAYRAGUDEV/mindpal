/// Checks that a generated ANSWER only mentions things present in the context
/// it was given.
///
/// The games already had this (AiQuestionValidator). The memory assistant did
/// not: its generated sentence went straight to the screen. The system prompt
/// says "never invent a name" — this is what makes that checkable rather than
/// merely requested.
///
/// WHAT IT CATCHES, honestly:
///   * invented proper nouns  — "Rahul is your son, and Priya is your niece"
///     when Priya was never in the context
///   * invented years         — "the trip in 2019" when no year was supplied
///   * invented months        — "in August" when no month was supplied
///
/// WHAT IT DOES NOT CATCH: a wrong claim built only from words that ARE in the
/// context ("Rahul is your daughter" when the context says son). That needs
/// semantic checking, which a token check cannot do. The low temperature and
/// the tiny single-record context make that unlikely, but "unlikely" is not
/// "impossible" and it should be described that way to a judge.
///
/// A failed check is not an error shown to the user — the app quietly uses its
/// own deterministic answer instead.
class AnswerGroundingCheck {
  const AnswerGroundingCheck();

  /// Words that may legitimately appear capitalised mid-sentence without
  /// coming from the user's data. Kept deliberately short: every entry here
  /// is a small hole in the check.
  /// Words a grounded answer may contain even though the context never
  /// mentioned them: pronouns, articles, and the handful of nouns the answer
  /// templates themselves use.
  ///
  /// This list matters more than it looks. The first word of a sentence is no
  /// longer exempt from the proper-noun check (that exemption hid every
  /// invented name, because answers open with the subject), so ordinary
  /// sentence-openers have to be named here instead. A pronoun can never be an
  /// invented person, so whitelisting them costs no safety.
  static const Set<String> _benign = {
    // pronouns and demonstratives
    'i', 'you', 'your', 'yours',
    'he', 'him', 'his',
    'she', 'her', 'hers',
    'it', 'its',
    'they', 'them', 'their',
    'we', 'us', 'our',
    'this', 'that', 'these', 'those',
    'there', 'here',
    // articles and connectives
    'a', 'an', 'the', 'and', 'or', 'but', 'so',
    // short replies the templates use
    'yes', 'no', 'ok', 'okay', 'sorry', 'please',
    // nouns the answer templates supply themselves
    'phone', 'number', 'address', 'note', 'notes',
  };

  static const List<String> _months = [
    'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
  ];

  static final RegExp _sentenceBreak = RegExp(r'(?<=[.!?])\s+');
  static final RegExp _year = RegExp(r'\b(?:19|20)\d{2}\b');
  static final RegExp _wordChars = RegExp(r'[^A-Za-z0-9ঀ-৿ऀ-ॿ]');

  /// Returns the tokens in [answer] that are NOT supported by [context].
  /// Empty list means the answer is grounded.
  List<String> unsupportedTokens({
    required String answer,
    required List<Map<String, dynamic>> context,
  }) {
    final allowed = _allowedWords(context);
    final unsupported = <String>[];

    // 1. Proper nouns: a capitalised word that is not starting a sentence.
    for (final sentence in answer.split(_sentenceBreak)) {
      final words = sentence.trim().split(RegExp(r'\s+'));
      for (var index = 0; index < words.length; index++) {
        final raw = words[index].replaceAll(_wordChars, '');
        if (raw.isEmpty) continue;

        // The first word of a sentence USED to be skipped here, on the
        // reasoning that grammar capitalises it. That was a hole big enough
        // to drive the whole feature through: a generated answer opens with
        // the subject ("Rahul is your son."), so the one token worth checking
        // was the one exempted.
        //
        // Ordinary sentence-openers are handled by the _benign list below
        // instead, which is the narrower and correct filter.
        final first = raw[0];
        if (first != first.toUpperCase() || first == first.toLowerCase()) {
          continue; // not a capitalised Latin word
        }

        final lower = raw.toLowerCase();
        if (_benign.contains(lower) || allowed.contains(lower)) continue;
        unsupported.add(raw);
      }
    }

    // 2. Years the context never mentioned.
    for (final match in _year.allMatches(answer)) {
      final year = match.group(0)!;
      if (!allowed.contains(year)) unsupported.add(year);
    }

    // 3. Months the context never mentioned.
    final lowerAnswer = answer.toLowerCase();
    for (final month in _months) {
      if (lowerAnswer.contains(month) && !allowed.contains(month)) {
        unsupported.add(month);
      }
    }

    return unsupported;
  }

  bool isGrounded({
    required String answer,
    required List<Map<String, dynamic>> context,
  }) => unsupportedTokens(answer: answer, context: context).isEmpty;

  /// Every word the model is allowed to use, taken from the context values.
  Set<String> _allowedWords(List<Map<String, dynamic>> context) {
    final words = <String>{};
    for (final record in context) {
      for (final value in record.values) {
        if (value == null) continue;
        for (final word in value.toString().toLowerCase().split(RegExp(r'\s+'))) {
          final cleaned = word.replaceAll(_wordChars, '');
          if (cleaned.isNotEmpty) words.add(cleaned);
        }
      }
    }
    return words;
  }
}
