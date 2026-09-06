import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/models/memory_note.dart';
import 'package:mindpal/models/person.dart';
import 'package:mindpal/models/place.dart';
import 'package:mindpal/services/ai/answer_grounding_check.dart';
import 'package:mindpal/services/memory_aid_service.dart';
import 'package:mindpal/services/memory_assistant_service.dart';

final _when = DateTime(2026, 1, 1);

final _data = MemoryAidData(
  people: [
    Person(id: 1, name: 'Rahul', relationship: 'Son', createdAt: _when),
    Person(id: 2, name: 'Meena', relationship: 'Daughter', createdAt: _when),
    Person(id: 3, name: 'Priya', relationship: 'Friend', createdAt: _when),
  ],
  places: [
    Place(
      id: 1,
      name: 'Shillong',
      description: 'Family trip',
      createdAt: _when,
    ),
    Place(id: 2, name: 'Home', description: 'Where I live', createdAt: _when),
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

void main() {
  const grounding = AnswerGroundingCheck();
  const assistant = MemoryAssistantService();

  const rahulContext = [
    {'kind': 'person', 'name': 'Rahul', 'relationship': 'Son'},
  ];

  group('grounding check — accepting honest answers', () {
    test('an answer built only from the context passes', () {
      expect(
        grounding.isGrounded(
          answer: 'Rahul is your son.',
          context: rahulContext,
        ),
        isTrue,
      );
    });

    test('a capitalised first word is not treated as a name', () {
      // "Your" starts the sentence because of grammar, not because it is a
      // proper noun. Flagging it would reject every valid answer.
      expect(
        grounding.isGrounded(
          answer: 'Your son is Rahul.',
          context: rahulContext,
        ),
        isTrue,
      );
    });

    test('ordinary lowercase words are never flagged', () {
      expect(
        grounding.isGrounded(
          answer: 'He is your son and he lives nearby.',
          context: rahulContext,
        ),
        isTrue,
      );
    });
  });

  group('grounding check — rejecting invention', () {
    test('REJECTS a person who was never in the context', () {
      // The safety property. "Priya" exists in the vault but was NOT sent for
      // this question, so the model could not have known about her.
      final unsupported = grounding.unsupportedTokens(
        answer: 'Rahul is your son, and Priya is your niece.',
        context: rahulContext,
      );

      expect(unsupported, contains('Priya'));
    });

    test('REJECTS an invented year', () {
      expect(
        grounding.unsupportedTokens(
          answer: 'Rahul is your son, born in 1984.',
          context: rahulContext,
        ),
        contains('1984'),
      );
    });

    test('REJECTS an invented month', () {
      expect(
        grounding.unsupportedTokens(
          answer: 'You visited Shillong in August.',
          context: const [
            {'kind': 'place', 'name': 'Shillong', 'description': 'Family trip'},
          ],
        ),
        contains('august'),
      );
    });

    test('ACCEPTS a year that really was in the context', () {
      expect(
        grounding.isGrounded(
          answer: 'The trip was in 2026.',
          context: const [
            {'kind': 'place', 'name': 'Shillong', 'description': 'Trip in 2026'},
          ],
        ),
        isTrue,
      );
    });

    test('an empty context makes every proper noun unsupported', () {
      expect(
        grounding.unsupportedTokens(
          answer: 'Rahul is your son.',
          context: const [],
        ),
        isNotEmpty,
      );
    });
  });

  group('list questions', () {
    test('"What places have I saved?" lists the places', () {
      final answer = assistant.answerQuestion(
        'What places have I saved?',
        _data,
      );

      expect(answer.scope, AssistantScope.allPlaces);
      expect(answer.found, isTrue);
      expect(answer.text, contains('Shillong'));
      expect(answer.text, contains('Home'));
      expect(answer.recordCount, 2);
    });

    test('"Tell me about my family" lists the people', () {
      final answer = assistant.answerQuestion('Tell me about my family', _data);

      expect(answer.scope, AssistantScope.allPeople);
      expect(answer.text, contains('Rahul'));
      expect(answer.text, contains('Meena'));
      expect(answer.text, contains('Priya'));
    });

    test('"Show me all my memories" gives an overview count', () {
      final answer = assistant.answerQuestion('Show me all my memories', _data);

      expect(answer.scope, AssistantScope.overview);
      expect(answer.source, AnswerSource.collection);
      expect(answer.text, contains('3 people'));
      expect(answer.text, contains('2 places'));
      expect(answer.text, contains('1 note'));
    });

    test('a list question on an empty vault says so, and invents nothing', () {
      final answer = assistant.answerQuestion(
        'What places have I saved?',
        const MemoryAidData(),
      );

      expect(answer.found, isFalse);
      expect(answer.text, contains('not saved any places'));
    });

    test('single-record questions still work as before', () {
      final answer = assistant.answerQuestion('Who is Rahul?', _data);

      expect(answer.scope, AssistantScope.single);
      expect(answer.source, AnswerSource.person);
      expect(answer.text, contains('Rahul is your son'));
    });

    test('the names are joined readably, not comma-jammed', () {
      final answer = assistant.answerQuestion('my people', _data);

      expect(answer.text, contains('Rahul, Meena and Priya'));
    });

    test('one saved item uses the singular', () {
      final answer = assistant.answerQuestion(
        'what notes do I have',
        _data,
      );

      expect(answer.text, contains('1 note:'));
    });
  });
}
