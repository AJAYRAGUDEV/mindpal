import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

/// One reminder as the caregiver server describes it.
class RemoteReminder {
  const RemoteReminder({
    required this.id,
    required this.rev,
    required this.title,
    required this.notes,
    required this.hour,
    required this.minute,
    required this.repeat,
    required this.category,
    required this.deleted,
  });

  final int id;

  /// The server's monotonic revision. The device keeps the highest it has
  /// seen and asks for everything above it.
  final int rev;

  final String title;
  final String notes;
  final int hour;
  final int minute;
  final String repeat;
  final String category;

  /// A soft delete. The row still arrives so a device that has been offline
  /// learns the reminder is gone; without it the alarm would ring forever.
  final bool deleted;

  factory RemoteReminder.fromMap(Map<String, dynamic> map) => RemoteReminder(
    id: (map['id'] as num?)?.toInt() ?? 0,
    rev: (map['rev'] as num?)?.toInt() ?? 0,
    title: map['title'] as String? ?? '',
    notes: map['notes'] as String? ?? '',
    hour: (map['hour'] as num?)?.toInt() ?? 9,
    minute: (map['minute'] as num?)?.toInt() ?? 0,
    repeat: map['repeat'] as String? ?? 'once',
    category: map['category'] as String? ?? 'other',
    deleted: map['deleted'] == true,
  );
}

/// What one sync returned.
class SyncResult {
  const SyncResult({required this.reminders, required this.highestRev});

  final List<RemoteReminder> reminders;
  final int highestRev;
}

class CareException implements Exception {
  const CareException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to the caregiver server on the patient's behalf.
///
/// AUTHENTICATION. There is no account and no password here: a patient does
/// not log in. The device holds a key the SERVER generated for it, and that
/// key is the credential.
///
/// The key is never in the APK. Every install that pairs calls
/// [registerDevice] once and receives its own key, so two phones running the
/// same build have different credentials and one cannot read the other's
/// reminders. A key baked into the binary would be extractable from any copy
/// of the app and would unlock every patient at once.
class CareClient {
  CareClient({http.Client? httpClient, String? baseUrl})
    : _http = httpClient ?? http.Client(),
      _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final http.Client _http;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 30);

  bool get isConfigured => _baseUrl.isNotEmpty;

  /// Claims a device identity. Called once, when the user first chooses to
  /// share with a caregiver. Returns the key to store.
  Future<String> registerDevice(String displayName) async {
    final body = await _send(
      'POST',
      '/api/care/device/register',
      body: {'displayName': displayName},
    );
    final key = body['deviceKey'] as String?;
    if (key == null || key.isEmpty) {
      throw const CareException('The server did not return a device key.');
    }
    return key;
  }

  /// Asks for a short code the patient reads out to their caregiver.
  Future<({String code, DateTime expiresAt})> requestLinkCode(
    String deviceKey,
  ) async {
    final body = await _send(
      'POST',
      '/api/care/device/link-code',
      body: {'deviceKey': deviceKey},
    );
    final code = body['code'] as String? ?? '';
    final expires =
        DateTime.tryParse(body['expiresAt'] as String? ?? '') ??
        DateTime.now().add(const Duration(minutes: 15));
    if (code.isEmpty) {
      throw const CareException('The server did not return a code.');
    }
    return (code: code, expiresAt: expires);
  }

  /// Everything that changed above [sinceRev].
  Future<SyncResult> sync({
    required String deviceKey,
    required int sinceRev,
  }) async {
    final body = await _send(
      'GET',
      '/api/care/device/sync?since=$sinceRev',
      deviceKey: deviceKey,
    );

    final raw = body['reminders'];
    final reminders = <RemoteReminder>[
      if (raw is List)
        for (final item in raw)
          if (item is Map<String, dynamic>) RemoteReminder.fromMap(item),
    ];

    var highest = sinceRev;
    for (final reminder in reminders) {
      if (reminder.rev > highest) highest = reminder.rev;
    }
    return SyncResult(reminders: reminders, highestRev: highest);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? deviceKey,
  }) async {
    if (!isConfigured) {
      throw const CareException('No server is configured in this build.');
    }

    final uri = Uri.parse('$_baseUrl$path');
    final headers = {
      if (body != null) 'Content-Type': 'application/json',
      'x-device-key': ?deviceKey,
    };

    http.Response response;
    try {
      final request = method == 'GET'
          ? _http.get(uri, headers: headers)
          : _http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      response = await request.timeout(_timeout);
    } on TimeoutException {
      throw const CareException('The server took too long to answer.');
    } catch (error) {
      // Offline is the normal case, not an error worth alarming about. The
      // payload is never logged: it can carry the device key.
      debugPrint('CARE: unreachable (${error.runtimeType})');
      throw const CareException('Could not reach the server.');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const CareException('The server sent something unreadable.');
    }

    if (response.statusCode >= 400) {
      // 401 here means the device key is no longer recognised — the server
      // was reset, or the patient was removed. The caller clears the pairing.
      debugPrint('CARE: HTTP ${response.statusCode}');
      throw CareException(
        decoded['error'] as String? ?? 'The server refused that request.',
      );
    }
    return decoded;
  }

  void dispose() => _http.close();
}
