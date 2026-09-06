/// Remembers just enough of the conversation to resolve "he", "she", "it".
///
/// "Who is Rahul?" then "Where does he live?" — the second question is
/// meaningless on its own. This rewrites it to "Where does Rahul live?" BEFORE
/// any retrieval happens.
///
/// Deliberately tiny, and deliberately NOT the model's job:
///   * it is deterministic, so the same follow-up always resolves the same way
///   * it works offline
///   * it means the chat history is never sent to Gemini. Only the resolved
///     question and the record it matched are sent, which keeps the privacy
///     promise intact as the conversation grows.
///
/// It holds ONE subject — the last thing successfully found. Real pronoun
/// resolution needs far more than that, but for "ask about a person, then ask
/// a follow-up" it is right almost always, and when it is wrong the answer is
/// "I don't have that information yet" rather than something invented.
class ConversationContext {
  /// The subject of the most recent successful answer, e.g. "Rahul".
  String? lastSubject;

  static const Set<String> _pronouns = {
    'he',
    'him',
    'his',
    'she',
    'her',
    'hers',
    'it',
    'its',
    'they',
    'them',
    'their',
    'that',
    'this',
  };

  /// Records what the last answer was about. Pass null to forget.
  void remember(String? subject) {
    final trimmed = subject?.trim();
    lastSubject = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  void clear() => lastSubject = null;

  /// True when [question] leans on something said earlier.
  bool needsContext(String question) {
    final words = _words(question);
    return words.any(_pronouns.contains);
  }

  /// Replaces pronouns with the remembered subject.
  ///
  /// Returns the question unchanged when there is nothing to substitute — so
  /// a follow-up asked before any successful answer stays vague, gets no
  /// match, and is answered honestly rather than guessed at.
  String resolve(String question) {
    final subject = lastSubject;
    if (subject == null || subject.isEmpty) return question;
    if (!needsContext(question)) return question;

    // replaceAllMapped walks the words and leaves everything between them —
    // spaces, punctuation — exactly as it was.
    //
    // An earlier version split on r'(\s+)' and rebuilt the string. Dart's
    // String.split does not return capture groups the way JavaScript's does,
    // so every space was silently discarded and the question arrived at
    // retrieval as "WheredoesRahullive?".
    var replaced = false;

    return question.replaceAllMapped(RegExp(r'[A-Za-z]+'), (match) {
      final word = match[0]!;

      // Only the FIRST pronoun is replaced. "Where does he keep his keys"
      // becoming "Where does Rahul keep Rahul keys" is worse than leaving the
      // second one alone.
      if (!replaced && _pronouns.contains(word.toLowerCase())) {
        replaced = true;
        return subject;
      }
      return word;
    });
  }

  List<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .where((word) => word.isNotEmpty)
      .toList();
}
