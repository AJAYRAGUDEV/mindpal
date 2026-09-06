import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/models/reminder.dart';
import 'package:mindpal/services/notification_service.dart';
import 'package:mindpal/services/reminder_service.dart';
import 'package:mindpal/storage/local_storage.dart';

Reminder _draft({
  String title = 'Drink water',
  int hour = 10,
  int minute = 0,
  ReminderRepeat repeat = ReminderRepeat.daily,
  ReminderCategory category = ReminderCategory.dailyActivity,
  String notes = '',
}) => Reminder(
  id: 0, // the service assigns the real id
  title: title,
  category: category,
  hour: hour,
  minute: minute,
  repeat: repeat,
  notes: notes,
  createdAt: DateTime(2026, 1, 1),
);

Future<(ReminderService, InMemoryStorage)> _newService() async {
  final storage = InMemoryStorage();
  await storage.init();
  return (
    ReminderService(storage, NoopNotificationService()),
    storage,
  );
}

void main() {
  group('Reminder model', () {
    test('formats the time in 12-hour clock', () {
      expect(_draft(hour: 0, minute: 0).formattedTime, '12:00 AM');
      expect(_draft(hour: 9, minute: 5).formattedTime, '9:05 AM');
      expect(_draft(hour: 12, minute: 0).formattedTime, '12:00 PM');
      expect(_draft(hour: 16, minute: 30).formattedTime, '4:30 PM');
      expect(_draft(hour: 23, minute: 59).formattedTime, '11:59 PM');
    });

    test('a daily reminder completed today is pending again tomorrow', () {
      final today = DateTime(2026, 8, 29, 12);
      final tomorrow = DateTime(2026, 8, 30, 12);

      final done = _draft(repeat: ReminderRepeat.daily).markCompletedOn(today);

      expect(done.isCompletedOn(today), isTrue);
      expect(done.isCompletedOn(tomorrow), isFalse); // the whole point
    });

    test('a once reminder stays completed forever', () {
      final today = DateTime(2026, 8, 29, 12);
      final nextYear = DateTime(2027, 3, 3, 12);

      final done = _draft(repeat: ReminderRepeat.once).markCompletedOn(today);

      expect(done.isCompletedOn(today), isTrue);
      expect(done.isCompletedOn(nextYear), isTrue);
    });

    test('missed means the time passed and it was not completed', () {
      final reminder = _draft(hour: 10, minute: 0);

      expect(reminder.isMissedAt(DateTime(2026, 8, 29, 9)), isFalse); // early
      expect(reminder.isMissedAt(DateTime(2026, 8, 29, 11)), isTrue); // late
      expect(
        reminder
            .markCompletedOn(DateTime(2026, 8, 29))
            .isMissedAt(DateTime(2026, 8, 29, 11)),
        isFalse, // late but done
      );
    });

    test('next occurrence rolls over to tomorrow once the time has gone', () {
      final reminder = _draft(hour: 10, minute: 0);

      expect(
        reminder.nextOccurrenceAfter(DateTime(2026, 8, 29, 8)),
        DateTime(2026, 8, 29, 10),
      );
      expect(
        reminder.nextOccurrenceAfter(DateTime(2026, 8, 29, 15)),
        DateTime(2026, 8, 30, 10),
      );
    });

    test('survives a round trip through JSON', () {
      final original = _draft(
        title: 'Take medicine',
        category: ReminderCategory.medicine,
        hour: 20,
        minute: 15,
        notes: 'After dinner',
      ).markCompletedOn(DateTime(2026, 8, 29));

      final restored = Reminder.fromMap(original.toMap());

      expect(restored.title, 'Take medicine');
      expect(restored.category, ReminderCategory.medicine);
      expect(restored.hour, 20);
      expect(restored.minute, 15);
      expect(restored.notes, 'After dinner');
      expect(restored.completedOn, '2026-08-29');
    });

    test('a map missing fields falls back to defaults instead of crashing', () {
      final restored = Reminder.fromMap({'title': 'Only a title'});

      expect(restored.title, 'Only a title');
      expect(restored.category, ReminderCategory.other);
      expect(restored.repeat, ReminderRepeat.once);
      expect(restored.completedOn, isNull);
    });
  });

  group('ReminderService', () {
    test('gives each reminder a unique id starting at 1', () async {
      final (service, _) = await _newService();

      var list = await service.add(const [], _draft(title: 'One'));
      list = await service.add(list, _draft(title: 'Two', hour: 11));
      list = await service.add(list, _draft(title: 'Three', hour: 12));

      expect(list.map((r) => r.id).toList(), [1, 2, 3]);
    });

    test('reminders persist and come back in time order', () async {
      final (service, storage) = await _newService();

      var list = await service.add(const [], _draft(title: 'Evening', hour: 20));
      list = await service.add(list, _draft(title: 'Morning', hour: 7));

      // A brand-new service reading the SAME storage — this is what happens
      // when the app is closed and reopened.
      final reopened = ReminderService(storage, NoopNotificationService());
      final loaded = await reopened.loadAll();

      expect(loaded.length, 2);
      expect(loaded.first.title, 'Morning'); // 7am before 8pm
      expect(loaded.last.title, 'Evening');
    });

    test('deleting one reminder leaves the others alone', () async {
      final (service, _) = await _newService();

      var list = await service.add(const [], _draft(title: 'A', hour: 8));
      list = await service.add(list, _draft(title: 'B', hour: 9));
      list = await service.add(list, _draft(title: 'C', hour: 10));

      list = await service.remove(list, 2);

      expect(list.map((r) => r.title).toList(), ['A', 'C']);
    });

    test('editing keeps the id, so the notification id never changes', () async {
      final (service, _) = await _newService();

      var list = await service.add(const [], _draft(title: 'Walk', hour: 10));
      final original = list.single;

      list = await service.update(list, original.copyWith(hour: 11));

      expect(list.single.id, original.id); // same alarm slot, rescheduled
      expect(list.single.hour, 11);
    });

    test('completing counts towards today only', () async {
      final today = DateTime(2026, 8, 29, 12);
      final (service, _) = await _newService();

      var list = await service.add(const [], _draft(title: 'A', hour: 8));
      list = await service.add(list, _draft(title: 'B', hour: 9));

      expect(service.completedCount(list, today), 0);

      list = await service.setCompleted(list, 1, completed: true, day: today);
      expect(service.completedCount(list, today), 1);

      // Un-ticking works too, for a mis-tap.
      list = await service.setCompleted(list, 1, completed: false, day: today);
      expect(service.completedCount(list, today), 0);
    });

    test('nextUpcoming skips completed and already-passed reminders', () async {
      final now = DateTime(2026, 8, 29, 10, 30);
      final (service, _) = await _newService();

      var list = await service.add(const [], _draft(title: 'Past', hour: 8));
      list = await service.add(list, _draft(title: 'Soon', hour: 12));
      list = await service.add(list, _draft(title: 'Later', hour: 16));

      expect(service.nextUpcoming(list, now)?.title, 'Soon');

      list = await service.setCompleted(list, 2, completed: true, day: now);
      expect(service.nextUpcoming(list, now)?.title, 'Later');
    });

    test('corrupt stored data gives an empty list, not a crash', () async {
      final storage = InMemoryStorage();
      await storage.init();
      await storage.writeString('reminders_v1', 'this is not json');

      final service = ReminderService(storage, NoopNotificationService());

      expect(await service.loadAll(), isEmpty);
    });
  });
}
