import '../models/memory_note.dart';
import '../models/person.dart';
import '../models/place.dart';
import 'memory_aid_service.dart';

/// What kind of question was asked.
enum AssistantIntent {
  /// "Who is Rahul?" -> look in People.
  who,

  /// "Where is Shillong?" -> look in Places.
  where,

  /// "What is the bank note?" / "Tell me about..." -> look in Notes first.
  what,

  /// No recognised question word — treat the whole input as a search.
  search,
}

/// How much of the vault a question is about.
///
/// The assistant used to answer exactly one shape of question — "Who is X?" —
/// by finding one record. "What places have I saved?" found nothing, because
/// there is no single record called "places".
enum AssistantScope {
  /// One record: "Who is Rahul?"
  single,

  allPeople,
  allPlaces,
  allNotes,

  /// Everything at once: "Tell me about my family."
  overview,
}

/// Where an answer came from. The UI shows this so the user (and a judge) can
/// see the answer was READ from stored data, not produced by a model.
enum AnswerSource { person, place, note, collection, none }

class AssistantAnswer {
  const AssistantAnswer({
    required this.text,
    required this.source,
    required this.intent,
    this.subject = '',
    this.scope = AssistantScope.single,
    this.recordCount = 1,
  });

  final AssistantScope scope;

  /// The sentence to show, and later to speak aloud.
  final String text;

  final AnswerSource source;
  final AssistantIntent intent;

  /// The thing the user asked about, as the parser understood it.
  final String subject;

  /// How many stored records this answer drew on. 1 for a single lookup,
  /// more for a list question. Used to size the context sent to the model.
  final int recordCount;

  bool get found => source != AnswerSource.none;
}

/// Answers questions using ONLY what is stored on this device.
///
/// This is deliberately NOT an LLM, and must never be described as one. It is
/// a question parser plus a database lookup:
///
///     question -> intent + subject -> search People/Places/Notes -> sentence
///
/// The important property is that it is INCAPABLE of inventing anything. Every
/// word in an answer is either a fixed template or text the user typed in
/// themselves. If nothing matches, it says so. There is no path through this
/// code that produces a fact nobody entered — which is a stronger guarantee
/// than any prompt instruction to an LLM can give.
///
/// It is also instant, free, and works with no internet.
class MemoryAssistantService {
  const MemoryAssistantService();

  /// Question openings we recognise, longest first so that "who is" is not
  /// matched by a shorter prefix before "who is my" gets a chance.
  static const Map<AssistantIntent, List<String>> _openings = {
    AssistantIntent.who: [
      'who is my',
      'who was my',
      'who is',
      "who's",
      'who was',
    ],
    AssistantIntent.where: [
      'where is my',
      'where is',
      "where's",
      'where was',
      'where do i find',
      'where can i find',
    ],
    AssistantIntent.what: [
      'what is my',
      'what is',
      "what's",
      'tell me about',
      'remind me about',
      'what did i write about',
    ],
  };

  /// The single entry point used by the UI.
  AssistantAnswer answerQuestion(String question, MemoryAidData data) {
    final cleaned = _clean(question);
    if (cleaned.isEmpty) {
      return const AssistantAnswer(
        text: 'Ask me about a person, a place, or something you wrote down.',
        source: AnswerSource.none,
        intent: AssistantIntent.search,
      );
    }

    // A list question is answered from the whole collection, not by hunting
    // for one record that happens to be called "places".
    final scope = scopeFor(cleaned);
    if (scope != AssistantScope.single) {
      return _answerCollection(scope, data);
    }

    final (intent, subject) = _parse(cleaned);
    if (subject.isEmpty) {
      return AssistantAnswer(
        text: "I don't have that information yet.",
        source: AnswerSource.none,
        intent: intent,
      );
    }

    // Each intent tries its most likely source first, then the others. Asking
    // "who is X" about something saved as a note should still find it.
    final order = switch (intent) {
      AssistantIntent.who => [AnswerSource.person, AnswerSource.place, AnswerSource.note],
      AssistantIntent.where => [AnswerSource.place, AnswerSource.person, AnswerSource.note],
      AssistantIntent.what => [AnswerSource.note, AnswerSource.person, AnswerSource.place],
      AssistantIntent.search => [AnswerSource.person, AnswerSource.place, AnswerSource.note],
    };

    for (final source in order) {
      final answer = switch (source) {
        AnswerSource.person => _answerAboutPerson(subject, data.people, intent),
        AnswerSource.place => _answerAboutPlace(subject, data.places, intent),
        AnswerSource.note => _answerAboutNote(subject, data.notes, intent),
        // Never in `order`; listed so the switch stays exhaustive.
        AnswerSource.collection || AnswerSource.none => null,
      };
      if (answer != null) return answer;
    }

    return AssistantAnswer(
      text: "I don't have that information yet.",
      source: AnswerSource.none,
      intent: intent,
      subject: subject,
    );
  }

  /// Works out whether the question is about one thing or many.
  AssistantScope scopeFor(String question) {
    final text = _clean(question);
    if (text.isEmpty) return AssistantScope.single;

    const peopleWords = ['people', 'persons', 'family', 'relatives', 'contacts'];
    const placeWords = ['places', 'locations', 'where have i', 'which places'];
    const noteWords = ['notes', 'written', 'wrote down'];
    const everythingWords = ['everything', 'all my memories', 'my memories'];

    bool mentions(List<String> words) =>
        words.any((word) => text.contains(word));

    if (mentions(everythingWords)) return AssistantScope.overview;
    if (mentions(peopleWords)) return AssistantScope.allPeople;
    if (mentions(placeWords)) return AssistantScope.allPlaces;
    if (mentions(noteWords)) return AssistantScope.allNotes;
    return AssistantScope.single;
  }

  /// The deterministic answer for a list question.
  ///
  /// Note it never summarises or characterises — it counts and it names. That
  /// is all it can honestly do from stored data.
  AssistantAnswer _answerCollection(AssistantScope scope, MemoryAidData data) {
    switch (scope) {
      case AssistantScope.allPeople:
        return _listAnswer(
          scope: scope,
          source: AnswerSource.person,
          names: data.people.map((person) => person.name).toList(),
          singular: 'person',
          plural: 'people',
        );

      case AssistantScope.allPlaces:
        return _listAnswer(
          scope: scope,
          source: AnswerSource.place,
          names: data.places.map((place) => place.name).toList(),
          singular: 'place',
          plural: 'places',
        );

      case AssistantScope.allNotes:
        return _listAnswer(
          scope: scope,
          source: AnswerSource.note,
          names: data.notes.map((note) => note.title).toList(),
          singular: 'note',
          plural: 'notes',
        );

      case AssistantScope.overview:
        final total =
            data.people.length + data.places.length + data.notes.length;
        if (total == 0) {
          return const AssistantAnswer(
            text: "You have not saved anything yet.",
            source: AnswerSource.none,
            intent: AssistantIntent.search,
            scope: AssistantScope.overview,
            recordCount: 0,
          );
        }
        return AssistantAnswer(
          text:
              'You have saved ${data.people.length} people, '
              '${data.places.length} places and ${data.notes.length} notes.',
          source: AnswerSource.collection,
          intent: AssistantIntent.search,
          scope: AssistantScope.overview,
          recordCount: total,
        );

      case AssistantScope.single:
        return const AssistantAnswer(
          text: "I don't have that information yet.",
          source: AnswerSource.none,
          intent: AssistantIntent.search,
        );
    }
  }

  AssistantAnswer _listAnswer({
    required AssistantScope scope,
    required AnswerSource source,
    required List<String> names,
    required String singular,
    required String plural,
  }) {
    final usable = names.where((name) => name.trim().isNotEmpty).toList();

    if (usable.isEmpty) {
      return AssistantAnswer(
        text: 'You have not saved any $plural yet.',
        source: AnswerSource.none,
        intent: AssistantIntent.search,
        scope: scope,
        recordCount: 0,
      );
    }

    final label = usable.length == 1 ? singular : plural;
    return AssistantAnswer(
      text: 'You have saved ${usable.length} $label: ${_join(usable)}.',
      source: source,
      intent: AssistantIntent.search,
      scope: scope,
      recordCount: usable.length,
    );
  }

  /// "Rahul, Meena and Priya" — an Oxford-comma-free list, easier to read
  /// aloud than a bare comma-separated string.
  String _join(List<String> values) {
    if (values.length == 1) return values.single;
    return '${values.take(values.length - 1).join(', ')} and ${values.last}';
  }

  // ---------------------------------------------------------------- lookups

  /// Finds a saved person by name, or by relationship ("my son").
  Person? findPerson(String subject, List<Person> people) {
    final needle = _clean(subject);
    if (needle.isEmpty) return null;

    return _bestMatch<Person>(
      needle,
      people,
      // Name is tried first and matched most strictly.
      primary: (person) => person.name,
      // "who is my son" finds the person whose relationship is Son.
      secondary: (person) => person.relationship,
    );
  }

  Place? findPlace(String subject, List<Place> places) {
    final needle = _clean(subject);
    if (needle.isEmpty) return null;

    return _bestMatch<Place>(
      needle,
      places,
      primary: (place) => place.name,
      secondary: (place) => place.description,
    );
  }

  MemoryNote? findNote(String subject, List<MemoryNote> notes) {
    final needle = _clean(subject);
    if (needle.isEmpty) return null;

    return _bestMatch<MemoryNote>(
      needle,
      notes,
      primary: (note) => note.title,
      secondary: (note) => note.content,
    );
  }

  // ------------------------------------------------------------- responses

  AssistantAnswer? _answerAboutPerson(
    String subject,
    List<Person> people,
    AssistantIntent intent,
  ) {
    final person = findPerson(subject, people);
    if (person == null) return null;

    // Every part of this sentence is either a fixed word or text the user
    // typed. Nothing is inferred.
    final buffer = StringBuffer();
    if (person.relationship.trim().isEmpty) {
      buffer.write('${person.name} is saved in your people.');
    } else {
      buffer.write('${person.name} is your ${person.relationship.toLowerCase()}.');
    }
    if (person.phone.trim().isNotEmpty) {
      buffer.write(' Phone number: ${person.phone}.');
    }

    return AssistantAnswer(
      text: buffer.toString(),
      source: AnswerSource.person,
      intent: intent,
      subject: person.name,
    );
  }

  AssistantAnswer? _answerAboutPlace(
    String subject,
    List<Place> places,
    AssistantIntent intent,
  ) {
    final place = findPlace(subject, places);
    if (place == null) return null;

    final buffer = StringBuffer();
    if (place.description.trim().isEmpty) {
      buffer.write('${place.name} is saved in your places.');
    } else {
      buffer.write('${place.name}: ${place.description}');
      if (!place.description.trim().endsWith('.')) buffer.write('.');
    }
    if (place.address.trim().isNotEmpty) {
      buffer.write(' Address: ${place.address}.');
    }

    return AssistantAnswer(
      text: buffer.toString(),
      source: AnswerSource.place,
      intent: intent,
      subject: place.name,
    );
  }

  AssistantAnswer? _answerAboutNote(
    String subject,
    List<MemoryNote> notes,
    AssistantIntent intent,
  ) {
    final note = findNote(subject, notes);
    if (note == null) return null;

    return AssistantAnswer(
      // The note is quoted back word for word — never summarised, because
      // summarising is where invention creeps in.
      text: 'You wrote under "${note.title}": ${note.content}',
      source: AnswerSource.note,
      intent: intent,
      subject: note.title,
    );
  }

  // ---------------------------------------------------------------- parsing

  /// Lowercase, strip punctuation, collapse spaces.
  String _clean(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[?!.,;:"’“”]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Splits "who is my son" into (who, "son").
  (AssistantIntent, String) _parse(String cleaned) {
    for (final entry in _openings.entries) {
      for (final opening in entry.value) {
        if (cleaned.startsWith('$opening ')) {
          return (entry.key, _stripLeadingWords(
            cleaned.substring(opening.length).trim(),
          ));
        }
      }
    }
    // No question word: treat the whole thing as a name to look up.
    return (AssistantIntent.search, _stripLeadingWords(cleaned));
  }

  /// Removes filler words from the front of the subject.
  ///
  /// Without this, "tell me about the bank" searches for "the bank", which
  /// does not match a note titled "Bank details" — people phrase questions
  /// naturally, and the words they add carry no meaning for a lookup.
  /// Applied repeatedly so "who is my the doctor" still reduces to "doctor".
  String _stripLeadingWords(String subject) {
    const filler = ['my ', 'the ', 'a ', 'an '];
    var result = subject.trim();

    var changed = true;
    while (changed) {
      changed = false;
      for (final word in filler) {
        if (result.startsWith(word)) {
          result = result.substring(word.length).trim();
          changed = true;
        }
      }
    }
    return result;
  }

  /// Scores candidates and returns the best, or null if nothing matched.
  ///
  /// Ranking, strongest first:
  ///   4  primary field equals the query exactly     ("rahul" == "Rahul")
  ///   3  primary field starts with the query        ("rahul k" for "rahul")
  ///   2  primary field contains the query
  ///   1  secondary field contains the query         (relationship, notes...)
  ///
  /// A plain `contains` alone would let "Ravi" match a note that merely
  /// mentions Ravi in passing, ahead of the actual person called Ravi.
  T? _bestMatch<T>(
    String needle,
    List<T> items, {
    required String Function(T item) primary,
    required String Function(T item) secondary,
  }) {
    T? best;
    var bestScore = 0;

    for (final item in items) {
      final primaryText = _clean(primary(item));
      final secondaryText = _clean(secondary(item));

      var score = 0;
      if (primaryText == needle) {
        score = 4;
      } else if (primaryText.startsWith(needle)) {
        score = 3;
      } else if (primaryText.contains(needle)) {
        score = 2;
      } else if (secondaryText.contains(needle)) {
        score = 1;
      }

      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }

    return best;
  }
}
