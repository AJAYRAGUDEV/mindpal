// A real end-to-end run: caregiver website -> Express -> database ->
// this Flutter sync client -> the notification service.
//
// Run it explicitly against a running server:
//
//   flutter test test/care_live_e2e.dart
//
// The filename has no `_test` suffix, so `flutter test` with no arguments
// skips it — it needs a server, and a suite that fails when the server is
// merely not running is a suite people learn to ignore.
//
// It pairs a throwaway device, drives the caregiver HTTP API exactly as the
// website does, and asserts the patient side ends up in the right state with
// the right alarms scheduled. What it does NOT prove is that an Android
// phone rings: nothing here touches a device.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mindpal/models/reminder.dart';
import 'package:mindpal/services/care/care_client.dart';
import 'package:mindpal/services/care/care_sync_service.dart';
import 'package:mindpal/services/notification_service.dart';
import 'package:mindpal/services/reminder_service.dart';
import 'package:mindpal/storage/local_storage.dart';

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

int passed = 0;
int failed = 0;

void check(String label, Object? got, Object? want) {
  final ok = '$got' == '$want';
  if (ok) {
    passed++;
  } else {
    failed++;
  }
  stdout.writeln('${ok ? "PASS" : "FAIL"} ${label.padRight(52)} '
      'got $got want $want');
}

void main() {
  test('caregiver website to Flutter, end to end', run,
      timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> run() async {
  final base = (Platform.environment['CARE_BASE_URL'] ?? 'http://localhost:8787')
      .replaceAll(RegExp(r'/+$'), '');
  stdout.writeln('Server: $base');

  // A server that is not running is a skip, not a failure: a suite that
  // fails merely because nothing is listening is one people learn to
  // ignore.
  try {
    final probe = await http
        .get(Uri.parse('$base/api/health'))
        .timeout(const Duration(seconds: 5));
    if (probe.statusCode != 200) throw Exception('unhealthy');
  } catch (_) {
    markTestSkipped('No server at $base. Run: cd server && npm start');
    return;
  }

  final web = http.Client();

  Future<Map<String, dynamic>> api(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    final uri = Uri.parse('$base$path');
    final headers = {
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final response = method == 'GET'
        ? await web.get(uri, headers: headers)
        : method == 'DELETE'
        ? await web.delete(uri, headers: headers)
        : method == 'PUT'
        ? await web.put(uri, headers: headers, body: jsonEncode(body))
        : await web.post(uri, headers: headers, body: jsonEncode(body));
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'status': response.statusCode};
    }
  }

  // ---------------------------------------------------- the patient's side
  final storage = InMemoryStorage();
  await storage.init();
  final notifications = _RecordingNotifications();
  final reminders = ReminderService(storage, notifications);
  final sync = CareSyncService(
    storage,
    reminders,
    client: CareClient(baseUrl: base),
  );
  var local = <Reminder>[];

  Future<SyncReport> pull() => sync.sync(
    local,
    force: true,
    onChanged: (updated) => local = updated,
  );

  stdout.writeln('=== 1. the phone claims a device identity ===');
  final deviceKey = await sync.ensureDevice('E2E Patient');
  check('the server issued a key', deviceKey.isNotEmpty, true);
  check('it is not a value shipped in the app', deviceKey.length > 20, true);

  stdout.writeln('\n=== 2. the patient asks for a code ===');
  final codeResult = await sync.requestLinkCode('E2E Patient');
  check('a six-character code', codeResult.code.length, 6);

  stdout.writeln('\n=== 3. a caregiver signs in and redeems it ===');
  final login = await api('POST', '/api/care/login', body: {
    'email': 'meena@example.com',
    'password': 'mindpal-demo-2026',
  });
  final token = login['token'] as String?;
  check('signed in', token != null, true);

  final linked = await api('POST', '/api/care/link',
      body: {'code': codeResult.code, 'relationship': 'Daughter'},
      token: token);
  final patientId = linked['patientId'];
  check('linked to the new patient', patientId != null, true);

  stdout.writeln('\n=== 4. a new link grants nothing ===');
  final blocked = await api(
    'POST',
    '/api/care/patients/$patientId/reminders',
    body: {'title': 'Should be refused', 'hour': 9, 'minute': 0},
    token: token,
  );
  check('adding a reminder is refused', blocked['error'] != null, true);

  stdout.writeln('\n=== 5. the PATIENT grants permission from their phone ===');
  final caregiverId = (login['caregiver'] as Map)['id'] as int;

  // Through the same calls the Flutter screen makes, so this covers the
  // client code and not only the endpoint.
  var links = await sync.listLinks();
  check('the phone sees the new helper', links.length, 1);
  check('and knows their name', links.first.caregiverName, 'Meena Das');
  check('who has been granted nothing',
      links.first.has('can_view_reminders'), false);

  await sync.setPermissions(
    caregiverId: caregiverId,
    permissions: {'can_view_reminders': true, 'can_edit_reminders': true},
  );

  links = await sync.listLinks();
  check('now allowed to view', links.first.has('can_view_reminders'), true);
  check('now allowed to edit', links.first.has('can_edit_reminders'), true);
  check('but still not memories', links.first.has('can_view_vault'), false);

  stdout.writeln('\n=== 6. caregiver creates a reminder ===');
  final created = await api(
    'POST',
    '/api/care/patients/$patientId/reminders',
    body: {
      'title': 'Take your evening medicine',
      'hour': 20,
      'minute': 0,
      'repeat': 'daily',
      'category': 'medicine',
    },
    token: token,
  );
  final remoteId = (created['reminder'] as Map?)?['id'];
  check('created on the server', remoteId != null, true);

  stdout.writeln('\n=== 7. the phone syncs ===');
  notifications.log.clear();
  var report = await pull();
  check('one reminder added', report.added, 1);
  check('it is on the phone', local.length, 1);
  check('the title arrived', local.first.title, 'Take your evening medicine');
  check('it is daily', local.first.repeat, ReminderRepeat.daily);
  check('an alarm was scheduled', notifications.log, ['schedule ${local.first.id}']);
  final localId = local.first.id;

  stdout.writeln('\n=== 8. syncing again changes nothing (no duplicates) ===');
  notifications.log.clear();
  report = await pull();
  check('nothing added', report.added, 0);
  check('still one reminder', local.length, 1);
  check('no alarm touched', notifications.log.isEmpty, true);

  stdout.writeln('\n=== 9. caregiver edits the time ===');
  await api(
    'PUT',
    '/api/care/patients/$patientId/reminders/$remoteId',
    body: {'hour': 21, 'minute': 30},
    token: token,
  );
  notifications.log.clear();
  report = await pull();
  check('one updated', report.updated, 1);
  check('still one reminder', local.length, 1);
  check('the new time arrived', '${local.first.hour}:${local.first.minute}', '21:30');
  check('same alarm id, cancelled then rescheduled', notifications.log,
      ['cancel $localId', 'schedule $localId']);

  stdout.writeln('\n=== 10. the patient adds one of their own ===');
  local = await reminders.add(
    local,
    Reminder(
      id: 0,
      title: 'My own walk',
      category: ReminderCategory.dailyActivity,
      hour: 7,
      minute: 0,
      repeat: ReminderRepeat.daily,
      createdAt: DateTime.now(),
    ),
  );
  check('two reminders now', local.length, 2);

  stdout.writeln('\n=== 11. caregiver deletes theirs ===');
  await api('DELETE', '/api/care/patients/$patientId/reminders/$remoteId',
      token: token);
  notifications.log.clear();
  report = await pull();
  check('one removed', report.removed, 1);
  check("the patient's own survives", local.length, 1);
  check('and it is the right one', local.first.title, 'My own walk');
  check('its alarm was cancelled', notifications.log, ['cancel $localId']);

  stdout.writeln('\n=== 12. permission withdrawn from the phone ===');
  await sync.setPermissions(
    caregiverId: caregiverId,
    permissions: {'can_edit_reminders': false},
  );
  final refused = await api(
    'POST',
    '/api/care/patients/$patientId/reminders',
    body: {'title': 'Should fail now', 'hour': 9, 'minute': 0},
    token: token,
  );
  check('the caregiver can no longer add', refused['error'] != null, true);

  stdout.writeln('\n=== 13. unpairing clears caregiver reminders ===');
  // Re-grant, add one, then unpair.
  await sync.setPermissions(
    caregiverId: caregiverId,
    permissions: {'can_edit_reminders': true},
  );
  await api('POST', '/api/care/patients/$patientId/reminders',
      body: {'title': 'Temporary', 'hour': 12, 'minute': 0}, token: token);
  await pull();
  check('three reminders before unpairing', local.length, 2);

  local = await sync.unpair(local);
  check("only the patient's own remains", local.length, 1);
  check('and it is theirs', local.first.title, 'My own walk');
  check('no longer paired', sync.isPaired, false);

  web.close();
  sync.dispose();

  stdout.writeln('\n$passed passed, $failed failed');
  expect(failed, 0, reason: '$failed end-to-end checks failed');
}
