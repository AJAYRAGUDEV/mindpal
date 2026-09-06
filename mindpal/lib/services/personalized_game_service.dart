import 'dart:math';

import '../models/quiz_question.dart';
import 'memory_aid_service.dart';

/// Builds personalised quiz questions from the user's own saved information.
///
/// No model, no API, no internet — just templates filled with stored data.
/// "Personalised" here is literal and honest: the questions are about this
/// user's actual family and places, which is what makes them worth doing.
///
/// The one rule that makes this safe: **every wrong option is also real data
/// from this user's own records.** If we invented plausible-sounding wrong
/// answers ("Brother", "Cousin") we would be putting words in the family's
/// mouth, and a user with memory difficulty could come away believing a
/// relationship that was never entered. Distractors are drawn from other
/// entries the user actually saved.
///
/// The consequence is a real limitation, stated plainly: a question needs at
/// least three saved entries of the same kind before it can be asked. With two
/// people saved, no person question is generated. That is correct behaviour,
/// not a bug to work around.
class PersonalizedGameService {
  const PersonalizedGameService();

  /// A question needs one right answer plus two distractors.
  static const int optionCount = 3;

  /// Builds up to [count] questions. Returns fewer — possibly none — when
  /// there is not enough saved data. The caller must handle an empty list.
  List<QuizQuestion> generate(
    MemoryAidData data, {
    int count = 5,
    Random? random,
  }) {
    final rng = random ?? Random();
    final questions = <QuizQuestion>[
      ..._personQuestions(data, rng),
      ..._relationshipQuestions(data, rng),
      ..._placeQuestions(data, rng),
      ..._placeMemoryQuestions(data, rng),
      ..._noteQuestions(data, rng),
    ]..shuffle(rng);

    return questions.take(count).toList();
  }

  /// True when there is enough data to build at least one question. The hub
  /// uses this to decide whether to offer the personalised game at all.
  bool canGenerate(MemoryAidData data) => generate(data, count: 1).isNotEmpty;

  // ------------------------------------------------------------------ people

  /// "Who is Rahul?" -> the answer is his relationship.
  ///
  /// Needs three people who each have a relationship filled in, and at least
  /// three DIFFERENT relationships — asking "Who is Rahul?" with options
  /// Son / Son / Daughter would be unanswerable.
  List<QuizQuestion> _personQuestions(MemoryAidData data, Random rng) {
    final withRelationship = data.people
        .where((person) =>
            person.name.trim().isNotEmpty &&
            person.relationship.trim().isNotEmpty)
        .toList();

    final relationships = withRelationship
        .map((person) => person.relationship.trim())
        .toSet()
        .toList();
    if (relationships.length < optionCount) return const [];

    final questions = <QuizQuestion>[];
    for (final person in withRelationship) {
      final built = _buildOptions(
        correct: person.relationship.trim(),
        pool: relationships,
        rng: rng,
      );
      if (built == null) continue;

      questions.add(
        QuizQuestion(
          prompt: 'Who is ${person.name.trim()}?',
          options: built.options,
          correctIndex: built.correctIndex,
          subject: QuizSubject.person,
          sourceId: person.id,
        ),
      );
    }
    return questions;
  }

  /// The reverse question: "Who is your daughter?" -> the answer is a name.
  ///
  /// A relationship is only usable if exactly ONE person has it. If two people
  /// are both saved as "Son", the question has two right answers and cannot be
  /// asked — so those relationships are skipped rather than guessed at.
  List<QuizQuestion> _relationshipQuestions(MemoryAidData data, Random rng) {
    final named = data.people
        .where((person) => person.name.trim().isNotEmpty)
        .toList();

    final names = named.map((person) => person.name.trim()).toSet().toList();
    if (names.length < optionCount) return const [];

    // Count how many people share each relationship.
    final counts = <String, int>{};
    for (final person in named) {
      final relationship = person.relationship.trim().toLowerCase();
      if (relationship.isEmpty) continue;
      counts[relationship] = (counts[relationship] ?? 0) + 1;
    }

    final questions = <QuizQuestion>[];
    for (final person in named) {
      final relationship = person.relationship.trim();
      if (relationship.isEmpty) continue;
      if (counts[relationship.toLowerCase()] != 1) continue; // ambiguous

      final built = _buildOptions(
        correct: person.name.trim(),
        pool: names,
        rng: rng,
      );
      if (built == null) continue;

      questions.add(
        QuizQuestion(
          prompt: 'Who is your ${relationship.toLowerCase()}?',
          options: built.options,
          correctIndex: built.correctIndex,
          subject: QuizSubject.person,
          sourceId: person.id,
        ),
      );
    }
    return questions;
  }

  // ------------------------------------------------------------------ places

  /// "Which place is this? ..." with the saved description -> the answer
  /// is the place's name.
  List<QuizQuestion> _placeQuestions(MemoryAidData data, Random rng) {
    final described = data.places
        .where((place) =>
            place.name.trim().isNotEmpty && place.description.trim().isNotEmpty)
        .toList();

    final names = data.places
        .map((place) => place.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    if (names.length < optionCount) return const [];

    final questions = <QuizQuestion>[];
    for (final place in described) {
      final built = _buildOptions(
        correct: place.name.trim(),
        pool: names,
        rng: rng,
      );
      if (built == null) continue;

      questions.add(
        QuizQuestion(
          prompt: 'Which place is this? "${place.description.trim()}"',
          options: built.options,
          correctIndex: built.correctIndex,
          subject: QuizSubject.place,
          sourceId: place.id,
        ),
      );
    }
    return questions;
  }

  /// "What memory is connected with Shillong?" -> the answer is the
  /// description the family wrote for it.
  ///
  /// Only SHORT descriptions are used. The options are answer buttons, and a
  /// paragraph does not fit on a button an elderly user can read at a glance —
  /// so a long description simply does not become a question.
  static const int _maxOptionLength = 45;

  List<QuizQuestion> _placeMemoryQuestions(MemoryAidData data, Random rng) {
    final shortDescriptions = data.places
        .map((place) => place.description.trim())
        .where((text) => text.isNotEmpty && text.length <= _maxOptionLength)
        .toSet()
        .toList();
    if (shortDescriptions.length < optionCount) return const [];

    final questions = <QuizQuestion>[];
    for (final place in data.places) {
      final description = place.description.trim();
      if (place.name.trim().isEmpty) continue;
      if (description.isEmpty || description.length > _maxOptionLength) continue;

      final built = _buildOptions(
        correct: description,
        pool: shortDescriptions,
        rng: rng,
      );
      if (built == null) continue;

      questions.add(
        QuizQuestion(
          prompt: 'What memory is connected with ${place.name.trim()}?',
          options: built.options,
          correctIndex: built.correctIndex,
          subject: QuizSubject.place,
          sourceId: place.id,
        ),
      );
    }
    return questions;
  }

  // ------------------------------------------------------------------- notes

  /// "Which note says this? ..." with the opening words -> the answer is
  /// the note's title.
  List<QuizQuestion> _noteQuestions(MemoryAidData data, Random rng) {
    final usable = data.notes
        .where((note) =>
            note.title.trim().isNotEmpty && note.content.trim().length >= 12)
        .toList();

    final titles = data.notes
        .map((note) => note.title.trim())
        .where((title) => title.isNotEmpty)
        .toSet()
        .toList();
    if (titles.length < optionCount) return const [];

    final questions = <QuizQuestion>[];
    for (final note in usable) {
      final built = _buildOptions(
        correct: note.title.trim(),
        pool: titles,
        rng: rng,
      );
      if (built == null) continue;

      questions.add(
        QuizQuestion(
          prompt: 'Which note says this? "${note.preview}"',
          options: built.options,
          correctIndex: built.correctIndex,
          subject: QuizSubject.note,
          sourceId: note.id,
        ),
      );
    }
    return questions;
  }

  // ----------------------------------------------------------------- helpers

  /// Picks the correct answer plus real distractors from [pool], shuffles
  /// them, and reports where the correct one ended up.
  ///
  /// Returns null when the pool cannot supply enough DIFFERENT wrong answers,
  /// which is how a question quietly declines to exist rather than being
  /// generated with invented options.
  _BuiltOptions? _buildOptions({
    required String correct,
    required List<String> pool,
    required Random rng,
  }) {
    final distractors = pool
        .where((value) => value.toLowerCase() != correct.toLowerCase())
        .toList()
      ..shuffle(rng);

    if (distractors.length < optionCount - 1) return null;

    final options = [correct, ...distractors.take(optionCount - 1)]
      ..shuffle(rng);

    return _BuiltOptions(options: options, correctIndex: options.indexOf(correct));
  }
}

class _BuiltOptions {
  const _BuiltOptions({required this.options, required this.correctIndex});

  final List<String> options;
  final int correctIndex;
}
