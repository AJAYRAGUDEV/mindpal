import '../../models/ai_models.dart';
import '../../models/quiz_question.dart';
import '../memory_aid_service.dart';

/// Checks generated questions against the real database before any of them
/// can reach the screen.
///
/// This class is the single most important piece of the AI integration, and it
/// is worth being blunt about why: a prompt is a request, not a guarantee. The
/// system instruction tells the model never to invent a relationship. This
/// class is what makes that true.
///
/// A question is only allowed through if EVERY option is a value the user
/// actually typed into this app. If the model returns "Brother" for a family
/// where nobody is saved as a brother, the whole question is discarded — not
/// repaired, not partially used. The deterministic generator fills the gap.
///
/// Note that it never trusts the context that was SENT either; it re-checks
/// against the live data. A bug in the retrieval step must not become a wrong
/// fact shown to someone with memory difficulty.
class AiQuestionValidator {
  const AiQuestionValidator({this.optionCount = 3});

  final int optionCount;

  /// Returns only the questions that are fully grounded in [data].
  List<QuizQuestion> keepValid(
    List<AiGameQuestion> generated,
    MemoryAidData data,
  ) {
    final allowed = _allowedValues(data);
    final subjects = _subjects(data);

    final safe = <QuizQuestion>[];
    for (final question in generated) {
      final result = _validateOne(question, allowed, subjects);
      if (result != null) safe.add(result);
    }
    return safe;
  }

  /// Validates one question. Returns null when it must be discarded.
  ///
  /// Private because its signature mentions an internal type. The rules are
  /// tested through [keepValid], one test per rule.
  QuizQuestion? _validateOne(
    AiGameQuestion question,
    Set<String> allowedValues,
    Map<String, _Subject> subjects,
  ) {
    // 1. The question text must exist.
    if (question.question.trim().isEmpty) return null;

    // 2. Exactly the number of options we asked for.
    if (question.options.length != optionCount) return null;

    // 3. No blanks.
    if (question.options.any((option) => option.trim().isEmpty)) return null;

    // 4. All options different (case-insensitively — "Son" and "son" would
    //    look like two choices but read as one).
    final lowered = question.options.map(_normalise).toList();
    if (lowered.toSet().length != lowered.length) return null;

    // 5. The correct answer must be one of the options.
    final correctIndex = lowered.indexOf(_normalise(question.correctAnswer));
    if (correctIndex < 0) return null;

    // 6. THE GROUNDING RULE. Every option must be something the user saved.
    //    This is what stops invented distractors.
    for (final option in question.options) {
      if (!allowedValues.contains(_normalise(option))) return null;
    }

    // 7. The subject must be a real record, so a wrong answer can be traced
    //    back to something the family actually entered.
    final subject = subjects[_normalise(question.sourceMemory)];
    if (subject == null) return null;

    return QuizQuestion(
      prompt: question.question.trim(),
      options: question.options,
      correctIndex: correctIndex,
      subject: subject.kind,
      sourceId: subject.id,
    );
  }

  /// Every value a generated option is allowed to be: exactly the text the
  /// user typed into People, Places and Notes, and nothing else.
  Set<String> _allowedValues(MemoryAidData data) => {
    for (final person in data.people) ...[
      _normalise(person.name),
      if (person.relationship.trim().isNotEmpty)
        _normalise(person.relationship),
    ],
    for (final place in data.places) ...[
      _normalise(place.name),
      if (place.description.trim().isNotEmpty) _normalise(place.description),
    ],
    for (final note in data.notes) _normalise(note.title),
  }..remove('');

  /// Maps a subject name back to the record it came from.
  Map<String, _Subject> _subjects(MemoryAidData data) => {
    for (final person in data.people)
      _normalise(person.name): _Subject(QuizSubject.person, person.id),
    for (final place in data.places)
      _normalise(place.name): _Subject(QuizSubject.place, place.id),
    for (final note in data.notes)
      _normalise(note.title): _Subject(QuizSubject.note, note.id),
  }..remove('');

  /// Compare on lowercase, collapsed whitespace — a model may return "  Son "
  /// where the user typed "Son", and that is the same answer.
  String _normalise(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _Subject {
  const _Subject(this.kind, this.id);

  final QuizSubject kind;
  final int id;
}
