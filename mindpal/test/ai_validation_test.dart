import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/l10n/app_language.dart';
import 'package:mindpal/models/ai_models.dart';
import 'package:mindpal/models/memory_note.dart';
import 'package:mindpal/models/person.dart';
import 'package:mindpal/models/place.dart';
import 'package:mindpal/services/ai/ai_question_validator.dart';
import 'package:mindpal/services/ai_service.dart';
import 'package:mindpal/services/memory_aid_service.dart';
import 'package:mindpal/services/memory_assistant_service.dart';

final _when = DateTime(2026, 1, 1);

final _data = MemoryAidData(
  people: [
    Person(id: 1, name: 'Rahul', relationship: 'Son', createdAt: _when),
    Person(id: 2, name: 'Ananya', relationship: 'Daughter', createdAt: _when),
    Person(id: 3, name: 'Priya', relationship: 'Friend', createdAt: _when),
  ],
  places: [
    Place(
      id: 1,
      name: 'Shillong',
      description: 'Family trip',
      createdAt: _when,
    ),
  ],
  notes: [
    MemoryNote(
      id: 1,
      title: 'Bank details',
      content: 'In the brown cupboard',
      createdAt: _when,
      updatedAt: _when,
    ),
  ],
);

AiGameQuestion _q({
  String question = 'Who is Rahul?',
  List<String> options = const ['Son', 'Daughter', 'Friend'],
  String correct = 'Son',
  String source = 'Rahul',
}) => AiGameQuestion(
  question: question,
  options: options,
  correctAnswer: correct,
  sourceMemory: source,
);

void main() {
  const validator = AiQuestionValidator();

  group('AI question validation — accepting good output', () {
    test('a fully grounded question is accepted', () {
      final kept = validator.keepValid([_q()], _data);

      expect(kept.length, 1);
      expect(kept.single.prompt, 'Who is Rahul?');
      expect(kept.single.correctAnswer, 'Son');
      expect(kept.single.sourceId, 1);
    });

    test('the correct index is found wherever the answer sits', () {
      final kept = validator.keepValid(
        [_q(options: ['Friend', 'Daughter', 'Son'], correct: 'Son')],
        _data,
      );

      expect(kept.single.correctIndex, 2);
    });

    test('whitespace and capitalisation differences are tolerated', () {
      // "  son " and "Son" are the same answer; rejecting that would throw
      // away good questions for no safety gain.
      final kept = validator.keepValid(
        [_q(options: ['  Son ', 'Daughter', 'Friend'], correct: 'son')],
        _data,
      );

      expect(kept.length, 1);
    });
  });

  group('AI question validation — rejecting unsafe output', () {
    test('REJECTS an invented distractor', () {
      // Nobody in this family is saved as a Brother. This is the single most
      // important test in the AI integration.
      final kept = validator.keepValid(
        [_q(options: ['Son', 'Brother', 'Cousin'])],
        _data,
      );

      expect(kept, isEmpty);
    });

    test('rejects a question whose correct answer is not an option', () {
      final kept = validator.keepValid(
        [_q(options: ['Daughter', 'Friend', 'Shillong'], correct: 'Son')],
        _data,
      );

      expect(kept, isEmpty);
    });

    test('rejects the wrong number of options', () {
      expect(validator.keepValid([_q(options: ['Son', 'Daughter'])], _data), isEmpty);
      expect(
        validator.keepValid(
          [_q(options: ['Son', 'Daughter', 'Friend', 'Rahul'])],
          _data,
        ),
        isEmpty,
      );
    });

    test('rejects duplicate options', () {
      final kept = validator.keepValid(
        [_q(options: ['Son', 'son', 'Friend'])],
        _data,
      );

      expect(kept, isEmpty);
    });

    test('rejects a blank option or a blank question', () {
      expect(
        validator.keepValid([_q(options: ['Son', '', 'Friend'])], _data),
        isEmpty,
      );
      expect(validator.keepValid([_q(question: '  ')], _data), isEmpty);
    });

    test('rejects a source memory that does not exist', () {
      final kept = validator.keepValid([_q(source: 'Vikram')], _data);

      expect(kept, isEmpty);
    });

    test('rejects everything when the vault is empty', () {
      expect(validator.keepValid([_q()], const MemoryAidData()), isEmpty);
    });

    test('keeps the good questions and drops the bad ones', () {
      final kept = validator.keepValid([
        _q(),
        _q(options: ['Son', 'Brother', 'Uncle']), // invented
        _q(question: 'Who is Ananya?', correct: 'Daughter', source: 'Ananya'),
      ], _data);

      expect(kept.length, 2);
      expect(kept.map((q) => q.sourceId), [1, 2]);
    });

    test('place and note names are also valid subjects and options', () {
      final kept = validator.keepValid([
        _q(
          question: 'What memory is connected with Shillong?',
          options: ['Family trip', 'Son', 'Bank details'],
          correct: 'Family trip',
          source: 'Shillong',
        ),
      ], _data);

      expect(kept.single.sourceId, 1);
    });
  });

  group('AI error handling', () {
    test('every error code has a plain message, never a status code', () {
      for (final code in AiErrorCode.values) {
        expect(code.message, isNotEmpty);
        expect(code.message, isNot(contains('50')));
        expect(code.message, isNot(contains('Exception')));
      }
    });

    test('backend error codes map to app codes', () {
      expect(AiErrorCode.fromName('rate_limited'), AiErrorCode.rateLimited);
      expect(AiErrorCode.fromName('not_configured'), AiErrorCode.notConfigured);
      expect(AiErrorCode.fromName('network_error'), AiErrorCode.offline);
      expect(AiErrorCode.fromName('something new'), AiErrorCode.unknown);
      expect(AiErrorCode.fromName(null), AiErrorCode.unknown);
    });
  });

  group('response parsing', () {
    test('reads a well-formed memory response', () {
      final response = AiMemoryResponse.fromMap(const {
        'text': 'Rahul is your son.',
        'hasEnoughInformation': true,
        'languageUsed': 'en',
        'cached': false,
      });

      expect(response.text, 'Rahul is your son.');
      expect(response.hasEnoughInformation, isTrue);
    });

    test('a malformed question map becomes empty fields, not a crash', () {
      final question = AiGameQuestion.fromMap(const {'question': 42});

      expect(question.question, isEmpty);
      expect(question.options, isEmpty);
    });

    test('non-string options are dropped rather than coerced', () {
      final question = AiGameQuestion.fromMap(const {
        'question': 'Who is Rahul?',
        'options': ['Son', 7, null, 'Friend'],
        'correctAnswer': 'Son',
        'sourceMemory': 'Rahul',
      });

      expect(question.options, ['Son', 'Friend']);
    });
  });

  group('offline fallback', () {
    test('the deterministic service still answers with no network', () async {
      const ai = DeterministicAiService();

      final answer = await ai.answerMemoryQuestion(
        question: 'Who is Rahul?',
        data: _data,
        language: kEnglish,
      );

      expect(answer.source, AnswerSource.person);
      expect(answer.text, contains('Rahul is your son'));
    });

    test('the deterministic service never claims to be generative', () {
      const ai = DeterministicAiService();

      expect(ai.isGenerative, isFalse);
      expect(ai.worksOffline, isTrue);
    });

    test('an unknown person still gets the honest answer offline', () async {
      const ai = DeterministicAiService();

      final answer = await ai.answerMemoryQuestion(
        question: 'Who is Vikram?',
        data: _data,
        language: kEnglish,
      );

      expect(answer.found, isFalse);
      expect(answer.text, "I don't have that information yet.");
    });
  });
}
