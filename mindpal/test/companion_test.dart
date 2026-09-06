import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/models/chat_message.dart';
import 'package:mindpal/models/difficulty.dart';
import 'package:mindpal/models/game_result.dart';
import 'package:mindpal/models/game_type.dart';
import 'package:mindpal/models/memory_note.dart';
import 'package:mindpal/models/person.dart';
import 'package:mindpal/models/place.dart';
import 'package:mindpal/models/reminder.dart';
import 'package:mindpal/services/ai_suggestion_service.dart';
import 'package:mindpal/services/conversation_context.dart';
import 'package:mindpal/services/memory_aid_service.dart';
import 'package:mindpal/services/memory_assistant_service.dart';

final _when = DateTime(2026, 1, 1);
final _now = DateTime(2026, 8, 30, 10);

Person _person(int id, String name, String relationship) => Person(
  id: id,
  name: name,
  relationship: relationship,
  createdAt: _when,
);

Reminder _reminder(int id, {int hour = 18, String? completedOn}) => Reminder(
  id: id,
  title: 'Call Rahul',
  category: ReminderCategory.personal,
  hour: hour,
  minute: 0,
  repeat: ReminderRepeat.daily,
  completedOn: completedOn,
  createdAt: _when,
);

GameResult _played({bool completed = true, DateTime? at}) => GameResult(
  id: 1,
  gameType: GameType.memoryMatch,
  difficulty: Difficulty.easy,
  score: 400,
  durationSeconds: 60,
  completed: completed,
  mistakes: 0,
  playedAt: at ?? _now,
);

final _vault = MemoryAidData(
  people: [_person(1, 'Rahul', 'Son'), _person(2, 'Meena', 'Daughter')],
  places: [
    Place(id: 1, name: 'Shillong', description: 'Family trip', createdAt: _when),
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
  const suggestions = AiSuggestionService();

  group('suggestions — never offer what cannot be answered', () {
    test('an empty vault offers setup, not questions about nobody', () {
      final chips = suggestions.suggestionsFor(
        data: const MemoryAidData(),
        reminders: const [],
        history: const [],
        now: _now,
      );

      // The critical rule: no chip may name a person who does not exist.
      expect(chips.any((chip) => chip.action == SuggestionAction.ask), isFalse);
      expect(
        chips.any((chip) => chip.action == SuggestionAction.openMemoryAid),
        isTrue,
      );
    });

    test('a saved person is named in the chip', () {
      final chips = suggestions.suggestionsFor(
        data: _vault,
        reminders: const [],
        history: const [],
        now: _now,
      );

      expect(chips.any((chip) => chip.label == 'Who is Rahul?'), isTrue);
    });

    test('places are only offered when places exist', () {
      final withoutPlaces = MemoryAidData(people: _vault.people);
      final chips = suggestions.suggestionsFor(
        data: withoutPlaces,
        reminders: const [],
        history: const [],
        now: _now,
      );

      expect(
        chips.any((chip) => chip.label.contains('places')),
        isFalse,
      );
    });

    test('reminders are offered only when something is still pending', () {
      bool offersReminders(List<Reminder> reminders) => suggestions
          .suggestionsFor(
            data: _vault,
            reminders: reminders,
            history: const [],
            now: _now,
          )
          .any((chip) => chip.action == SuggestionAction.openReminders);

      expect(offersReminders([_reminder(1)]), isTrue);
      expect(offersReminders([_reminder(1, completedOn: '2026-08-30')]), isFalse);
      expect(offersReminders(const []), isFalse);
    });

    test('a game is suggested only when none was finished today', () {
      List<AiSuggestion> chipsWith(List<GameResult> history) =>
          suggestions.suggestionsFor(
            data: _vault,
            reminders: const [],
            history: history,
            now: _now,
          );

      expect(
        chipsWith(const []).any((c) => c.label.contains('play a memory game')),
        isTrue,
      );

      // Already played: it should not nag, it should acknowledge.
      final after = chipsWith([_played()]);
      expect(after.any((c) => c.label.contains('play a memory game')), isFalse);
      expect(after.any((c) => c.label.contains("today's activity")), isTrue);
    });

    test('an unfinished game does not count as an activity', () {
      final chips = suggestions.suggestionsFor(
        data: _vault,
        reminders: const [],
        history: [_played(completed: false)],
        now: _now,
      );

      expect(chips.any((c) => c.label.contains('play a memory game')), isTrue);
    });

    test('never more than four chips', () {
      final chips = suggestions.suggestionsFor(
        data: _vault,
        reminders: [_reminder(1)],
        history: const [],
        now: _now,
      );

      expect(chips.length, lessThanOrEqualTo(AiSuggestionService.maxSuggestions));
    });

    test('the dashboard gets one suggestion, or none', () {
      expect(
        suggestions.dashboardSuggestion(
          data: _vault,
          reminders: const [],
          history: const [],
          now: _now,
        ),
        isNotNull,
      );
    });
  });

  group('conversation context', () {
    test('resolves "he" to the last subject', () {
      final context = ConversationContext()..remember('Rahul');

      expect(context.resolve('Where does he live?'), 'Where does Rahul live?');
    });

    test('resolves she, it and they too', () {
      final context = ConversationContext()..remember('Meena');

      expect(context.resolve('What is her phone number?'),
          contains('Meena'));
      expect(context.resolve('Tell me about it'), contains('Meena'));
    });

    test('leaves a question with no pronoun alone', () {
      final context = ConversationContext()..remember('Rahul');

      expect(context.resolve('Who is Meena?'), 'Who is Meena?');
    });

    test('a follow-up with nothing remembered stays vague', () {
      // It must NOT guess a subject. An unresolved question finds nothing and
      // gets an honest "I don't have that information yet".
      final context = ConversationContext();

      expect(context.resolve('Where does he live?'), 'Where does he live?');
    });

    test('only the first pronoun is replaced', () {
      final context = ConversationContext()..remember('Rahul');

      final resolved = context.resolve('Where does he keep his keys?');
      expect(resolved, contains('Rahul'));
      expect(resolved, contains('his')); // second pronoun untouched
    });

    test('clearing forgets the subject', () {
      final context = ConversationContext()..remember('Rahul');
      context.clear();

      expect(context.resolve('Who is he?'), 'Who is he?');
    });

    test('remembering an empty subject is the same as forgetting', () {
      final context = ConversationContext()
        ..remember('Rahul')
        ..remember('');

      expect(context.lastSubject, isNull);
    });
  });

  group('follow-up buttons', () {
    test('a found answer offers another question and a game', () {
      const answer = AssistantAnswer(
        text: 'Rahul is your son.',
        source: AnswerSource.person,
        intent: AssistantIntent.who,
        subject: 'Rahul',
      );

      expect(followUpsFor(answer), contains(ChatFollowUp.askAnother));
      expect(followUpsFor(answer), contains(ChatFollowUp.playGame));
    });

    test('a miss points the user at adding the missing information', () {
      const answer = AssistantAnswer(
        text: "I don't have that information yet.",
        source: AnswerSource.none,
        intent: AssistantIntent.who,
      );

      expect(followUpsFor(answer), contains(ChatFollowUp.openMemoryAid));
    });
  });

  group('chat messages', () {
    test('a user message carries no source or delivery label', () {
      const message = ChatMessage.user('Who is Rahul?');

      expect(message.isFromUser, isTrue);
      expect(message.source, AnswerSource.none);
      expect(message.delivery, isNull);
    });
  });
}
