import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/models/reminder.dart';
import 'package:mindpal/services/notification_service.dart';
import 'package:mindpal/services/reminder_service.dart';
import 'package:mindpal/storage/local_storage.dart';

/// Records every call so a test can assert what the OS would have been told.
class _RecordingNotifications implements NotificationService {
  final List<String> log = [];

  @override
  bool get isSupported => true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> canScheduleExactly() async => true;
  @override
  Future<void> schedule(Reminder reminder, {DateTime? after}) async {
    log.add(
      'schedule ${reminder.id}${after == null ? '' : ' after ${after.day}'}',
    );
  }

  @override
  Future<void> cancel(int reminderId) async => log.add('cancel $reminderId');
  @override
  Future<void> cancelAll() async => log.add('cancelAll');
  @override
  Stream<int> get tapped => const Stream.empty();
  @override
  Future<int?> launchReminderId() async => null;
  @override
  Future<void> showTestNotification() async => log.add('test');
  @override
  Future<int> pendingCount() async =>
      log.where((line) => line.startsWith('schedule')).length;
}

void main() {
  late InMemoryStorage storage;
  late _RecordingNotifications notifications;
  late ReminderService service;

  setUp(() async {
    storage = InMemoryStorage();
    await storage.init();
    notifications = _RecordingNotifications();
    service = ReminderService(storage, notifications);
  });

  Reminder draft({ReminderRepeat repeat = ReminderRepeat.once}) => Reminder(
    id: 0,
    title: 'Medicine',
    category: ReminderCategory.medicine,
    hour: 20,
    minute: 0,
    repeat: repeat,
    createdAt: DateTime(2026, 9, 22),
  );

  test('adding a reminder schedules one alarm with its own id', () async {
    final list = await service.add(const [], draft());
    expect(list.single.id, 1);
    expect(notifications.log, ['schedule 1']);
  });

  test('editing cancels the old alarm before scheduling the new one', () async {
    var list = await service.add(const [], draft());
    notifications.log.clear();

    list = await service.update(list, list.single.copyWith(hour: 21));

    expect(notifications.log, ['cancel 1', 'schedule 1']);
  });

  test('deleting cancels the alarm', () async {
    final list = await service.add(const [], draft());
    notifications.log.clear();

    await service.remove(list, 1);

    expect(notifications.log, ['cancel 1']);
  });

  test('completing a once-only reminder before it fires cancels it', () async {
    final list = await service.add(const [], draft());
    notifications.log.clear();

    await service.setCompleted(
      list,
      1,
      completed: true,
      day: DateTime(2026, 9, 22, 19),
    );

    expect(notifications.log, ['cancel 1']);
  });

  test('completing a daily reminder re-arms it from tomorrow', () async {
    final list = await service.add(
      const [],
      draft(repeat: ReminderRepeat.daily),
    );
    notifications.log.clear();

    await service.setCompleted(
      list,
      1,
      completed: true,
      day: DateTime(2026, 9, 22, 19),
    );

    expect(notifications.log, ['schedule 1 after 23']);
  });

  test('un-completing re-arms normally', () async {
    var list = await service.add(const [], draft());
    list = await service.setCompleted(
      list,
      1,
      completed: true,
      day: DateTime(2026, 9, 22),
    );
    notifications.log.clear();

    await service.setCompleted(
      list,
      1,
      completed: false,
      day: DateTime(2026, 9, 22),
    );

    expect(notifications.log, ['schedule 1']);
  });

  test('restart re-arms pending reminders once each, skips finished', () async {
    var list = await service.add(const [], draft());
    list = await service.add(list, draft(repeat: ReminderRepeat.daily));
    list = await service.add(list, draft());
    // Reminder 3 is done for good; it must not ring again after a restart.
    list = await service.setCompleted(
      list,
      3,
      completed: true,
      day: DateTime.now(),
    );
    notifications.log.clear();

    await service.rescheduleAll(list);

    expect(notifications.log.first, 'cancelAll');
    final scheduled = notifications.log
        .where((line) => line.startsWith('schedule'))
        .toList();
    expect(scheduled, hasLength(2));
    expect(scheduled.any((line) => line.startsWith('schedule 1')), isTrue);
    expect(scheduled.any((line) => line.startsWith('schedule 2')), isTrue);
    expect(scheduled.any((line) => line.startsWith('schedule 3')), isFalse);
  });

  test('nextOccurrenceAfter rolls to tomorrow once the time has passed', () {
    final reminder = draft();
    final before = DateTime(2026, 9, 22, 19, 30);
    final after = DateTime(2026, 9, 22, 20, 30);

    expect(reminder.nextOccurrenceAfter(before), DateTime(2026, 9, 22, 20));
    expect(reminder.nextOccurrenceAfter(after), DateTime(2026, 9, 23, 20));
  });
}
