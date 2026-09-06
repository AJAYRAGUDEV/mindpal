import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/l10n/app_language.dart';
import 'package:mindpal/models/memory_note.dart';
import 'package:mindpal/models/person.dart';
import 'package:mindpal/models/place.dart';
import 'package:mindpal/services/ai_service.dart';
import 'package:mindpal/services/memory_aid_service.dart';
import 'package:mindpal/services/memory_assistant_service.dart';
import 'package:mindpal/services/personalized_game_service.dart';
import 'package:mindpal/services/voice_service.dart';

final _when = DateTime(2026, 1, 1);

Person _person(int id, String name, String relationship, {String phone = ''}) =>
    Person(
      id: id,
      name: name,
      relationship: relationship,
      phone: phone,
      createdAt: _when,
    );

Place _place(int id, String name, {String description = '', String address = ''}) =>
    Place(
      id: id,
      name: name,
      description: description,
      address: address,
      createdAt: _when,
    );

MemoryNote _note(int id, String title, String content) => MemoryNote(
  id: id,
  title: title,
  content: content,
  createdAt: _when,
  updatedAt: _when,
);

final _data = MemoryAidData(
  people: [
    _person(1, 'Rahul', 'Son', phone: '9876543210'),
    _person(2, 'Meena', 'Daughter'),
    _person(3, 'Dr Barua', 'Doctor'),
  ],
  places: [
    _place(1, 'Shillong', description: 'Family trip last summer'),
    _place(2, 'Civil Hospital', description: 'Where Dr Barua works', address: 'GS Road'),
    _place(3, 'Home', description: 'Where I live with Meena'),
  ],
  notes: [
    _note(1, 'Bank details', 'The passbook is in the brown cupboard'),
    _note(2, 'Gas booking', 'Call the agency before the cylinder runs out'),
    _note(3, 'Wifi', 'The password is written behind the router'),
  ],
);

void main() {
  group('MemoryAssistantService — answering', () {
    const assistant = MemoryAssistantService();

    test('answers "Who is Rahul?" from saved People', () {
      final answer = assistant.answerQuestion('Who is Rahul?', _data);

      expect(answer.found, isTrue);
      expect(answer.source, AnswerSource.person);
      expect(answer.text, contains('Rahul is your son'));
      expect(answer.text, contains('9876543210'));
    });

    test('answers "Where is Shillong?" from saved Places', () {
      final answer = assistant.answerQuestion('Where is Shillong?', _data);

      expect(answer.source, AnswerSource.place);
      expect(answer.text, contains('Family trip last summer'));
    });

    test('answers a note question from saved Notes', () {
      final answer = assistant.answerQuestion('Tell me about the bank', _data);

      expect(answer.source, AnswerSource.note);
      expect(answer.text, contains('brown cupboard'));
    });

    test('understands "who is my daughter"', () {
      final answer = assistant.answerQuestion('who is my daughter', _data);

      expect(answer.source, AnswerSource.person);
      expect(answer.text, contains('Meena'));
    });

    test('works without a question word — a bare name is a lookup', () {
      final answer = assistant.answerQuestion('Meena', _data);

      expect(answer.source, AnswerSource.person);
      expect(answer.text, contains('Meena is your daughter'));
    });

    test('ignores capital letters and punctuation', () {
      for (final question in ['WHO IS RAHUL', 'who is rahul?', '  Who is Rahul!  ']) {
        expect(
          assistant.answerQuestion(question, _data).source,
          AnswerSource.person,
          reason: question,
        );
      }
    });

    test('an exact name beats a passing mention in another record', () {
      // "Dr Barua" appears inside the Civil Hospital description too. The
      // person must win, because their name matches exactly.
      final answer = assistant.answerQuestion('Who is Dr Barua?', _data);

      expect(answer.source, AnswerSource.person);
      expect(answer.text, contains('is your doctor'));
    });
  });

  group('MemoryAssistantService — never inventing', () {
    const assistant = MemoryAssistantService();

    test('says it does not know rather than guessing', () {
      final answer = assistant.answerQuestion('Who is Priyanka?', _data);

      expect(answer.found, isFalse);
      expect(answer.source, AnswerSource.none);
      expect(answer.text, "I don't have that information yet.");
    });

    test('knows nothing at all when nothing is saved', () {
      final answer = assistant.answerQuestion(
        'Who is Rahul?',
        const MemoryAidData(),
      );

      expect(answer.found, isFalse);
    });

    test('every word of an answer comes from stored data or a fixed template', () {
      // The strongest guarantee this service offers: the person's own words
      // appear verbatim, and nothing else is added.
      final answer = assistant.answerQuestion('Where is Home?', _data);

      expect(answer.text, contains('Where I live with Meena'));
      // No invented extras such as a city, a country or a guessed address.
      expect(answer.text.toLowerCase(), isNot(contains('india')));
    });

    test('an empty question asks for one instead of answering', () {
      final answer = assistant.answerQuestion('   ', _data);

      expect(answer.found, isFalse);
      expect(answer.text, contains('Ask me about'));
    });
  });

  group('MemoryAssistantService — direct lookups', () {
    const assistant = MemoryAssistantService();

    test('findPerson, findPlace and findNote', () {
      expect(assistant.findPerson('rahul', _data.people)?.id, 1);
      expect(assistant.findPlace('shillong', _data.places)?.id, 1);
      expect(assistant.findNote('wifi', _data.notes)?.id, 3);
      expect(assistant.findPerson('nobody', _data.people), isNull);
    });
  });

  group('PersonalizedGameService', () {
    const games = PersonalizedGameService();

    test('builds questions from the user\'s own saved data', () {
      // count is large enough to take EVERY generated question. With a small
      // count this depended on the shuffle, so adding new question types in
      // Phase 3 quietly made it flaky.
      final questions = games.generate(_data, count: 100, random: Random(3));

      expect(questions, isNotEmpty);
      expect(
        questions.any((question) => question.prompt.contains('Rahul')),
        isTrue,
      );
    });

    test('the correct answer is always among the options', () {
      final questions = games.generate(_data, count: 10, random: Random(5));

      for (final question in questions) {
        expect(question.options.length, PersonalizedGameService.optionCount);
        expect(question.correctIndex, inInclusiveRange(0, 2));
        expect(question.options[question.correctIndex], question.correctAnswer);
      }
    });

    test('every wrong option is also real saved data, never invented', () {
      // This is the safety property: a wrong answer the user reads must be
      // something they themselves entered somewhere else.
      // "Who is Rahul?" is answered with a relationship, but Phase 3 added
      // "Who is your daughter?", which is answered with a NAME. Both are real
      // saved values, so the check is against everything the user typed.
      final realValues = {
        ..._data.people.map((person) => person.name),
        ..._data.people.map((person) => person.relationship),
      };

      final questions = games
          .generate(_data, count: 100, random: Random(9))
          .where((question) => question.prompt.startsWith('Who is'));

      expect(questions, isNotEmpty);
      for (final question in questions) {
        for (final option in question.options) {
          expect(
            realValues,
            contains(option),
            reason: '"$option" was never entered by the user',
          );
        }
      }
    });

    test('options within one question are all different', () {
      final questions = games.generate(_data, count: 10, random: Random(11));

      for (final question in questions) {
        expect(question.options.toSet().length, question.options.length);
      }
    });

    test('generates nothing when there is too little saved data', () {
      final thin = MemoryAidData(people: [_person(1, 'Rahul', 'Son')]);

      expect(games.generate(thin), isEmpty);
      expect(games.canGenerate(thin), isFalse);
      expect(games.canGenerate(_data), isTrue);
    });

    test('generates nothing at all from an empty vault', () {
      expect(games.generate(const MemoryAidData()), isEmpty);
    });

    test('isCorrect matches the correct index', () {
      final question = games.generate(_data, count: 1, random: Random(2)).single;

      expect(question.isCorrect(question.correctIndex), isTrue);
      expect(question.isCorrect((question.correctIndex + 1) % 3), isFalse);
    });
  });

  group('VoiceCommandParser', () {
    const parser = VoiceCommandParser();

    test('recognises the fixed command set', () {
      expect(parser.parse('Play a game'), VoiceCommand.playGame);
      expect(parser.parse('show my memories'), VoiceCommand.showMemories);
      expect(parser.parse('Read my reminders.'), VoiceCommand.readReminders);
      expect(parser.parse('next'), VoiceCommand.next);
      expect(parser.parse('Repeat!'), VoiceCommand.repeat);
      expect(parser.parse('go back'), VoiceCommand.goBack);
      expect(parser.parse('stop'), VoiceCommand.stop);
    });

    test('an exact short command is not swallowed by a longer phrase', () {
      expect(parser.parse('back'), VoiceCommand.goBack);
    });

    test('anything else is unknown rather than a wrong guess', () {
      expect(parser.parse('make me a sandwich'), VoiceCommand.unknown);
      expect(parser.parse(''), VoiceCommand.unknown);
    });
  });

  group('honesty of the service layer', () {
    test('speech and text-to-speech report themselves unavailable', () async {
      const speech = UnavailableSpeechToText();
      const tts = UnavailableTextToSpeech();

      expect(speech.isAvailable, isFalse);
      expect(tts.isAvailable, isFalse);
      expect(speech.unavailableReason, isNotEmpty);
      expect(await speech.listen(kEnglish), isNull);
    });

    test('the AI service does not claim to be generative', () {
      const ai = DeterministicAiService();

      expect(ai.isGenerative, isFalse);
      expect(ai.worksOffline, isTrue);
    });

    test('translate returns the text unchanged rather than guessing', () async {
      const ai = DeterministicAiService();

      final result = await ai.translate(
        text: 'Take your medicine',
        from: kEnglish,
        to: kEnglish,
      );
      expect(result, 'Take your medicine');
    });
  });
}
