import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mindpal/models/reminder.dart';
import 'package:mindpal/services/care/care_client.dart';
import 'package:mindpal/services/care/care_sync_service.dart';
import 'package:mindpal/services/notification_service.dart';
import 'package:mindpal/services/reminder_service.dart';
import 'package:mindpal/storage/local_storage.dart';

/// Records what the OS would have been told, so the tests can assert that a
/// sync scheduled exactly the alarms it should and no more.
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
  Future<void> schedule(Reminder reminder, {DateTime? after}) async =>
      log.add('schedule ${reminder.id}');
  @override
  Future<void> cancel(int reminderId) async => log.add('cancel $reminderId');
  @override
  Future<void> cancelAll() async => log.add('cancelAll');
  @override
  Stream<int> get tapped => const Stream.empty();
  @override
  Future<int?> launchReminderId() async => null;
  @override
  Future<void> showTestNotification() async {}
  @override
  Future<int> pendingCount() async => 0;
}

/// Serves canned sync responses without a network.
class _FakeServer extends http.BaseClient {
  _FakeServer();

  /// Queued responses, one per sync call.
  final List<String> responses = [];
  final List<String> requestedPaths = [];

  /// Every request body sent, so a test can assert what left the device.
  final List<String> sentBodies = [];

  String deviceKeySeen = '';

  /// Makes the next request fail, for the "never reaches the player" test.
  bool failNext = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path + (request.url.query.isEmpty ? '' : '?${request.url.query}'));
    deviceKeySeen = request.headers['x-device-key'] ?? '';
    if (request is http.Request) sentBodies.add(request.body);
    if (failNext) {
      failNext = false;
      return _json('{"error":"Something went wrong."}', 500);
    }

    if (request.url.path.endsWith('/device/register')) {
      return _json('{"patientId":1,"deviceKey":"server-issued-key"}');
    }
    if (request.url.path.endsWith('/link-code')) {
      return _json('{"code":"ABC234","expiresAt":"2030-01-01T00:00:00.000Z"}');
    }
    final body = responses.isEmpty ? '{"reminders":[]}' : responses.removeAt(0);
    return _json(body);
  }

  http.StreamedResponse _json(String body, [int status = 200]) =>
      http.StreamedResponse(
        Stream.value(body.codeUnits),
        status,
        headers: {'content-type': 'application/json'},
      );
}

String remoteReminder({
  required int id,
  required int rev,
  String title = 'Take medicine',
  int hour = 20,
  int minute = 0,
  String repeat = 'daily',
  bool deleted = false,
}) =>
    '{"id":$id,"rev":$rev,"title":"$title","notes":"","hour":$hour,'
    '"minute":$minute,"repeat":"$repeat","category":"medicine",'
    '"deleted":$deleted}';

void main() {
  late InMemoryStorage storage;
  late _RecordingNotifications notifications;
  late ReminderService reminders;
  late _FakeServer server;
  late CareSyncService sync;
  late List<Reminder> list;

  setUp(() async {
    storage = InMemoryStorage();
    await storage.init();
    notifications = _RecordingNotifications();
    reminders = ReminderService(storage, notifications);
    server = _FakeServer();
    sync = CareSyncService(
      storage,
      reminders,
      client: CareClient(
        httpClient: server,
        baseUrl: 'https://example.test',
      ),
    );
    list = [];
  });

  Future<SyncReport> runSync({bool force = true}) => sync.sync(
    list,
    force: force,
    onChanged: (updated) => list = updated,
  );

  group('pairing', () {
    test('the device key comes from the server, never from the app', () async {
      expect(sync.isPaired, isFalse);

      final key = await sync.ensureDevice('Bimala');

      expect(key, 'server-issued-key');
      expect(sync.isPaired, isTrue);
      // The key is stored, and it is the one the server chose.
      expect(storage.readString('care_device_key_v1'), 'server-issued-key');
    });

    test('pairing twice keeps the first key', () async {
      final first = await sync.ensureDevice('Bimala');
      final second = await sync.ensureDevice('Bimala');
      expect(second, first);
    });

    test('a link code is fetched for the paired device', () async {
      final result = await sync.requestLinkCode('Bimala');
      expect(result.code, 'ABC234');
    });

    test('syncing without pairing does nothing', () async {
      final report = await runSync();
      expect(report.skipped, isTrue);
      expect(notifications.log, isEmpty);
    });
  });

  group('applying changes', () {
    setUp(() async => sync.ensureDevice('Bimala'));

    test('a new remote reminder is added and scheduled once', () async {
      server.responses.add('{"reminders":[${remoteReminder(id: 10, rev: 1)}]}');

      final report = await runSync();

      expect(report.added, 1);
      expect(list, hasLength(1));
      expect(list.single.title, 'Take medicine');
      expect(list.single.repeat, ReminderRepeat.daily);
      // Exactly one alarm, for the id the store assigned.
      expect(notifications.log, ['schedule ${list.single.id}']);
    });

    test('the device key travels in the header', () async {
      server.responses.add('{"reminders":[]}');
      await runSync();
      expect(server.deviceKeySeen, 'server-issued-key');
    });

    test('syncing again with no changes schedules nothing', () async {
      server.responses.add('{"reminders":[${remoteReminder(id: 10, rev: 1)}]}');
      await runSync();
      notifications.log.clear();

      server.responses.add('{"reminders":[]}');
      final report = await runSync();

      expect(report.total, 0);
      expect(notifications.log, isEmpty, reason: 'no alarm should be touched');
      expect(list, hasLength(1));
    });

    test('THE DUPLICATE TEST: re-sending the same reminder does not duplicate',
        () async {
      server.responses.add('{"reminders":[${remoteReminder(id: 10, rev: 1)}]}');
      await runSync();
      final firstId = list.single.id;
      notifications.log.clear();

      // The server resends the same reminder at a higher revision, which is
      // what an edit looks like. Before the remote-id map existed this added
      // a second reminder and a second alarm.
      server.responses.add(
        '{"reminders":[${remoteReminder(id: 10, rev: 2, title: 'Take medicine now')}]}',
      );
      final report = await runSync();

      expect(list, hasLength(1), reason: 'still one reminder, not two');
      expect(list.single.id, firstId, reason: 'same local id, so same alarm id');
      expect(list.single.title, 'Take medicine now');
      expect(report.updated, 1);
      expect(report.added, 0);
      // Cancel THEN schedule, on the same id: never two alarms at once.
      expect(notifications.log, ['cancel $firstId', 'schedule $firstId']);
    });

    test('a changed time cancels the old alarm before the new one', () async {
      server.responses.add('{"reminders":[${remoteReminder(id: 10, rev: 1, hour: 8)}]}');
      await runSync();
      final id = list.single.id;
      notifications.log.clear();

      server.responses.add('{"reminders":[${remoteReminder(id: 10, rev: 2, hour: 21)}]}');
      await runSync();

      expect(list.single.hour, 21);
      expect(notifications.log, ['cancel $id', 'schedule $id']);
    });

    test('a deletion removes the reminder and cancels its alarm', () async {
      server.responses.add('{"reminders":[${remoteReminder(id: 10, rev: 1)}]}');
      await runSync();
      final id = list.single.id;
      notifications.log.clear();

      server.responses.add(
        '{"reminders":[${remoteReminder(id: 10, rev: 2, deleted: true)}]}',
      );
      final report = await runSync();

      expect(list, isEmpty);
      expect(report.removed, 1);
      expect(notifications.log, ['cancel $id']);
    });

    test('a deletion for something never seen is ignored quietly', () async {
      server.responses.add(
        '{"reminders":[${remoteReminder(id: 99, rev: 5, deleted: true)}]}',
      );
      final report = await runSync();

      expect(report.removed, 0);
      expect(notifications.log, isEmpty);
    });

    test("the patient's own reminders are never touched", () async {
      list = await reminders.add(
        list,
        Reminder(
          id: 0,
          title: 'My own reminder',
          category: ReminderCategory.personal,
          hour: 7,
          minute: 0,
          repeat: ReminderRepeat.daily,
          createdAt: DateTime.now(),
        ),
      );
      notifications.log.clear();

      // The caregiver adds one, then deletes it. The patient's own must
      // survive both.
      server.responses.add('{"reminders":[${remoteReminder(id: 10, rev: 1)}]}');
      await runSync();
      server.responses.add(
        '{"reminders":[${remoteReminder(id: 10, rev: 2, deleted: true)}]}',
      );
      await runSync();

      expect(list, hasLength(1));
      expect(list.single.title, 'My own reminder');
    });

    test('completion survives a caregiver edit', () async {
      server.responses.add('{"reminders":[${remoteReminder(id: 10, rev: 1)}]}');
      await runSync();

      final today = DateTime.now();
      list = await reminders.setCompleted(
        list,
        list.single.id,
        completed: true,
        day: today,
      );
      expect(list.single.isCompletedOn(today), isTrue);

      server.responses.add(
        '{"reminders":[${remoteReminder(id: 10, rev: 2, title: 'Reworded')}]}',
      );
      await runSync();

      expect(list.single.title, 'Reworded');
      expect(
        list.single.isCompletedOn(today),
        isTrue,
        reason: 'ticking off this morning is the patient\'s fact, not the '
            'caregiver\'s to undo by editing the wording',
      );
    });
  });

  group('offline and rate limiting', () {
    setUp(() async => sync.ensureDevice('Bimala'));

    test('the cursor only advances on success', () async {
      server.responses.add('{"reminders":[${remoteReminder(id: 10, rev: 7)}]}');
      await runSync();
      expect(storage.readString('care_last_rev_v1'), '7');
    });

    test('a second sync asks only for what is newer', () async {
      server.responses.add('{"reminders":[${remoteReminder(id: 10, rev: 7)}]}');
      await runSync();
      server.requestedPaths.clear();

      server.responses.add('{"reminders":[]}');
      await runSync();

      expect(server.requestedPaths.single, contains('since=7'));
    });

    test('repeated resumes do not hammer the server', () async {
      server.responses.add('{"reminders":[]}');
      await runSync(force: true);
      server.requestedPaths.clear();

      // Three resumes in quick succession, none forced.
      for (var i = 0; i < 3; i += 1) {
        final report = await runSync(force: false);
        expect(report.skipped, isTrue);
      }
      expect(server.requestedPaths, isEmpty);
    });
  });

  group('unpairing', () {
    test('removes caregiver reminders and their alarms, keeps the rest',
        () async {
      await sync.ensureDevice('Bimala');
      list = await reminders.add(
        list,
        Reminder(
          id: 0,
          title: 'Mine',
          category: ReminderCategory.personal,
          hour: 7,
          minute: 0,
          repeat: ReminderRepeat.once,
          createdAt: DateTime.now(),
        ),
      );
      server.responses.add('{"reminders":[${remoteReminder(id: 10, rev: 1)}]}');
      await runSync();
      expect(list, hasLength(2));
      notifications.log.clear();

      list = await sync.unpair(list);

      expect(list, hasLength(1));
      expect(list.single.title, 'Mine');
      expect(sync.isPaired, isFalse);
      expect(notifications.log.where((l) => l.startsWith('cancel')), hasLength(1));
    });
  });

  group('reporting a game to the caregiver server', () {
    test('an unpaired phone reports nothing at all', () async {
      await sync.reportGameActivity(
        gameLabel: 'Cultural Memory Match',
        difficultyLabel: 'Easy',
        completed: true,
        correct: 4,
        mistakes: 1,
      );

      // No pairing means no caregiver, so there is nobody to tell.
      expect(server.requestedPaths, isEmpty);
    });

    test('a paired phone sends the game, the level and the counts', () async {
      await sync.ensureDevice('Test patient');
      server.requestedPaths.clear();
      server.sentBodies.clear();

      await sync.reportGameActivity(
        gameLabel: 'Cultural Memory Match',
        difficultyLabel: 'Easy',
        packTitle: 'Assam: Bihu and everyday things',
        completed: true,
        correct: 4,
        mistakes: 1,
      );

      expect(server.requestedPaths.single, endsWith('/device/activity'));
      final body = server.sentBodies.single;
      expect(body, contains('Cultural Memory Match'));
      expect(body, contains('Easy'));
      expect(body, contains('Assam'));
      expect(body, contains('4 right'));
      expect(body, contains('1 missed'));
      expect(body, contains('"kind":"game"'));
    });

    test('an unfinished game is reported as started, not finished', () async {
      await sync.ensureDevice('Test patient');
      server.sentBodies.clear();

      await sync.reportGameActivity(
        gameLabel: 'Story Order',
        difficultyLabel: 'Medium',
        completed: false,
        correct: 1,
        mistakes: 3,
      );

      expect(server.sentBodies.single, contains('Started Story Order'));
      expect(server.sentBodies.single, isNot(contains('Finished')));
    });

    test('nothing private goes with it', () async {
      // The family board is built from private photos. What is reported must
      // say only that it was played — never a photo caption, a memory title, a
      // person's name, or a media reference.
      await sync.ensureDevice('Test patient');
      server.sentBodies.clear();

      await sync.reportGameActivity(
        gameLabel: 'Family Photo Match',
        difficultyLabel: 'Easy',
        completed: true,
        correct: 3,
        mistakes: 0,
      );

      final body = server.sentBodies.single;
      expect(body, contains('Family Photo Match'));
      for (final forbidden in ['photoRef', 'videoRef', 'vault_', 'imageRef']) {
        expect(body, isNot(contains(forbidden)), reason: forbidden);
      }
      // The whole summary is one predictable sentence, with no free text from
      // the user's own data anywhere in it.
      expect(
        body,
        contains('Finished Family Photo Match on Easy. 3 right, 0 missed.'),
      );
    });

    test('a server error never reaches the player', () async {
      await sync.ensureDevice('Test patient');
      server.failNext = true;

      // A game that was played and enjoyed must not produce an error because a
      // courtesy report could not be filed.
      await expectLater(
        sync.reportGameActivity(
          gameLabel: 'Cultural Odd-One-Out',
          difficultyLabel: 'Easy',
          completed: true,
          correct: 5,
          mistakes: 0,
        ),
        completes,
      );
    });
  });
}