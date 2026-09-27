import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/services/companion/companion_intent.dart';

/// Reproduces the "I don't have information yet" fault before it is fixed.
///
/// The classifier's default is the user's vault, so any question whose
/// wording is not in one of its phrase lists is treated as personal, misses,
/// and gets the not-found answer — even when it is an ordinary question
/// anyone could answer.
void main() {
  const classifier = CompanionIntentClassifier();

  /// The screen's rule for rescuing a vault miss, mirroring
  /// _mayFallThroughToGeneral so the test measures the real behaviour.
  bool couldFallThrough(String question) =>
      !classifier.isAboutOwnLife(question);

  /// A question reaches general knowledge either by being classified that
  /// way, or by missing the vault and passing the fall-through rule.
  bool reachesGeneralKnowledge(String question) {
    final intent = classifier.classify(question);
    if (kGeneralIntents.contains(intent)) return true;
    if (intent != CompanionIntent.personalMemory) return false;
    return couldFallThrough(question);
  }

  group('ordinary questions must reach general knowledge', () {
    const shouldAnswer = [
      'What is the capital of India?',
      'Who invented the telephone?',
      'Tell me about the solar system.',
      'Why is exercise important?',
      'Tell me a short story.',
      'What day comes after Monday?',
      'How many days are in a year?',
      'What is the biggest animal?',
      'Sing me a song.',
      'What colour is the sky?',
    ];

    for (final question in shouldAnswer) {
      test('"$question"', () {
        expect(
          reachesGeneralKnowledge(question),
          isTrue,
          reason: 'classified as ${classifier.classify(question).name} and '
              'blocked from general knowledge, so the user is told '
              '"I don\'t have that information yet"',
        );
      });
    }
  });

  group('personal questions must stay with the vault', () {
    const shouldStayPersonal = [
      'Who is my daughter?',
      'Who is Ravi?',
      'Where did I go for my birthday?',
      'Show me my wedding memory.',
    ];

    for (final question in shouldStayPersonal) {
      test('"$question"', () {
        expect(
          classifier.classify(question),
          CompanionIntent.personalMemory,
          reason: 'a question about the user\'s own life must not be '
              'answered from general knowledge',
        );
      });
    }
  });

  group('health questions about oneself never reach a model', () {
    const boundary = [
      'Do I have dementia?',
      'Why am I forgetting things?',
      'Is my memory getting worse?',
    ];

    for (final question in boundary) {
      test('"$question"', () {
        expect(
          classifier.classify(question),
          CompanionIntent.medicalBoundary,
        );
      });
    }
  });
}
