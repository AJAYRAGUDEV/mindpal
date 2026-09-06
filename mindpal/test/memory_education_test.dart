import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/services/companion/companion_intent.dart';
import 'package:mindpal/services/companion/memory_education.dart';

void main() {
  const classifier = CompanionIntentClassifier();
  const education = MemoryEducation();

  group('intent — personal vs general', () {
    test('a question about a saved person is personal', () {
      expect(classifier.classify('Who is Rahul?'), CompanionIntent.personalMemory);
      expect(
        classifier.classify('What places have I saved?'),
        CompanionIntent.personalMemory,
      );
    });

    test('a question about memory in general is education', () {
      for (final question in [
        'What is memory loss?',
        'What is dementia?',
        'Why do people forget?',
        "What is Alzheimer's?",
        'What is short-term memory?',
        'Are dementia and normal ageing the same?',
        'Why is sleep important?',
      ]) {
        expect(
          classifier.classify(question),
          CompanionIntent.memoryEducation,
          reason: question,
        );
      }
    });

    test('app actions are recognised', () {
      expect(
        classifier.classify('What are my reminders today?'),
        CompanionIntent.reminder,
      );
      expect(classifier.classify("Let's play a game"), CompanionIntent.game);
    });
  });

  group('intent — the medical boundary', () {
    // The safety-critical group. Every one of these must be routed AWAY from
    // any generative path.

    test('asking for a diagnosis is a medical boundary, not education', () {
      for (final question in [
        'Do I have dementia?',
        'Am I developing Alzheimers?',
        "Am I developing Alzheimer's?",
        'Do I have memory loss?',
        'Is my memory getting worse?',
        'Tell me about my memory problems',
        'What is wrong with me?',
        'Can you diagnose me?',
        'Am I losing my memory?',
      ]) {
        expect(
          classifier.classify(question),
          CompanionIntent.medicalBoundary,
          reason: question,
        );
      }
    });

    test('symptom worries are also a boundary, not a personal lookup', () {
      for (final question in [
        'Why am I forgetting things?',
        'Why do I forget names?',
        "Why can't I remember where I put things?",
      ]) {
        expect(
          classifier.classify(question),
          CompanionIntent.medicalBoundary,
          reason: question,
        );
      }
    });

    test('"what is dementia" and "do I have dementia" are DIFFERENT', () {
      // Both contain the word dementia. Only one is a request for a
      // diagnosis, and the classifier must not confuse them.
      expect(
        classifier.classify('What is dementia?'),
        CompanionIntent.memoryEducation,
      );
      expect(
        classifier.classify('Do I have dementia?'),
        CompanionIntent.medicalBoundary,
      );
    });

    test('apostrophes and capitals do not change the result', () {
      expect(
        classifier.classify("DO I HAVE ALZHEIMER'S?"),
        CompanionIntent.medicalBoundary,
      );
      expect(
        classifier.classify("what's wrong with me"),
        CompanionIntent.medicalBoundary,
      );
    });

    test('wanting to exercise memory is education, not a health worry', () {
      // Contains "my", but is not a question about having a condition.
      expect(
        classifier.classify('How can I exercise my memory?'),
        CompanionIntent.memoryEducation,
      );
      expect(
        classifier.classify('How can I stay mentally active?'),
        CompanionIntent.memoryEducation,
      );
    });
  });

  group('safe answers never diagnose', () {
    test('a diagnosis request is declined and redirected', () {
      final answer = education.safeAnswerFor('Do I have dementia?');

      expect(answer, contains('not able to assess'));
      expect(answer.toLowerCase(), contains('doctor'));
    });

    test('a symptom worry gets general causes, not a verdict', () {
      final answer = education.safeAnswerFor('Why am I forgetting things?');

      expect(answer.toLowerCase(), contains('many everyday causes'));
      expect(answer.toLowerCase(), contains('doctor'));
    });

    test('no safe answer ever states that the user HAS a condition', () {
      const forbidden = [
        'you have dementia',
        'you have alzheimer',
        'you are developing',
        'your memory score',
        'you are showing signs',
        'diagnosis is',
      ];

      for (final question in [
        'Do I have dementia?',
        'Am I developing Alzheimers?',
        'Why am I forgetting things?',
        'Is my memory getting worse?',
      ]) {
        final answer = education.safeAnswerFor(question).toLowerCase();
        for (final phrase in forbidden) {
          expect(
            answer.contains(phrase),
            isFalse,
            reason: '"$question" produced "$phrase"',
          );
        }
      }
    });
  });

  group('curated educational content', () {
    test('covers every category from the plan', () {
      for (final category in EducationCategory.values) {
        expect(
          education.topicsIn(category),
          isNotEmpty,
          reason: category.label,
        );
      }
    });

    test('finds an answer for the common questions', () {
      expect(education.offlineAnswerFor('What is memory loss?'), isNotNull);
      expect(education.offlineAnswerFor('What is dementia?'), isNotNull);
      expect(education.offlineAnswerFor('Why do we forget things?'), isNotNull);
      expect(education.offlineAnswerFor("What is Alzheimer's?"), isNotNull);
      expect(education.offlineAnswerFor('Why is sleep important?'), isNotNull);
    });

    test('returns null rather than a wrong answer for something unrelated', () {
      expect(education.offlineAnswerFor('What is the capital of France?'),
          isNull);
      expect(education.offlineAnswerFor(''), isNull);
    });

    test('every health topic points at a professional', () {
      final healthTopics = [
        ...education.topicsIn(EducationCategory.memoryLoss),
        ...education.topicsIn(EducationCategory.dementia),
      ];

      for (final topic in healthTopics) {
        final answer = topic.answer.toLowerCase();
        expect(
          answer.contains('doctor') ||
              answer.contains('healthcare professional') ||
              answer.contains('checked urgently'),
          isTrue,
          reason: '"${topic.question}" does not point anywhere',
        );
      }
    });

    test('no curated answer claims to prevent or cure anything', () {
      const forbidden = ['prevent dementia', 'cure', 'will stop you', 'treats'];

      for (final topic in MemoryEducation.topics) {
        final answer = topic.answer.toLowerCase();
        for (final phrase in forbidden) {
          expect(
            answer.contains(phrase),
            isFalse,
            reason: '"${topic.question}" contains "$phrase"',
          );
        }
      }
    });

    test('the activity answer states plainly that it is not a treatment', () {
      final topic = education.offlineAnswerFor('How can I stay mentally active?');

      expect(topic, isNotNull);
      expect(topic!.answer.toLowerCase(), contains('not a treatment'));
    });
  });

  group('intent — general knowledge, places and conversation', () {
    // The group that fixes "everything falls through to the vault".

    test('an explicit general question goes straight to general knowledge', () {
      expect(
        classifier.classify('What is the capital of India?'),
        CompanionIntent.placeInformation,
      );
    });

    test('an open place question checks the vault first, by design', () {
      // "Where is Assam?" might be about a place the user saved, and the vault
      // is free and instant. The companion screen falls through to general
      // knowledge when the vault has no match, so nothing is lost — see
      // _mayFallThroughToGeneral in ai_companion_screen.dart.
      for (final question in ['Where is Assam?', 'What is famous in Meghalaya?']) {
        expect(
          classifier.classify(question),
          CompanionIntent.personalMemory,
          reason: question,
        );
      }
    });

    test('ordinary facts are general knowledge', () {
      for (final question in [
        'What is the largest ocean?',
        'What is photosynthesis?',
        'Who was Mahatma Gandhi?',
        'Why does it rain?',
        'Tell me something interesting',
      ]) {
        expect(
          classifier.classify(question),
          CompanionIntent.generalKnowledge,
          reason: question,
        );
      }
    });

    test('greetings are conversation', () {
      for (final greeting in [
        'Hello',
        'Good morning',
        'How are you?',
        'Who are you?',
      ]) {
        expect(
          classifier.classify(greeting),
          CompanionIntent.casualConversation,
          reason: greeting,
        );
      }
    });

    test('"I am bored" asks for a suggestion, not a fact', () {
      expect(classifier.classify('I am bored'), CompanionIntent.careSupport);
      expect(classifier.classify("I'm bored"), CompanionIntent.careSupport);
      expect(
        classifier.classify('What can I do today?'),
        CompanionIntent.careSupport,
      );
    });

    test('a greeting word inside a name does not become a greeting', () {
      // "hi" starts "Who is Hilda" only as a substring; matching on the whole
      // message stops that becoming small talk.
      expect(
        classifier.classify('Who is Hilda?'),
        CompanionIntent.personalMemory,
      );
    });

    test('"Tell me about X" still checks the vault first', () {
      // Cheap and instant. The screen falls through to general knowledge only
      // when the vault has no match.
      expect(
        classifier.classify('Tell me about Shillong'),
        CompanionIntent.personalMemory,
      );
    });

    test('health questions still win over general knowledge', () {
      // "What is dementia" matches a general opening too. The education and
      // safety branches must keep priority.
      expect(
        classifier.classify('What is dementia?'),
        CompanionIntent.memoryEducation,
      );
      expect(
        classifier.classify('Do I have dementia?'),
        CompanionIntent.medicalBoundary,
      );
    });

    test('general intents are exactly the four non-vault ones', () {
      expect(kGeneralIntents, {
        CompanionIntent.placeInformation,
        CompanionIntent.generalKnowledge,
        CompanionIntent.casualConversation,
        CompanionIntent.careSupport,
      });
    });
  });
}
