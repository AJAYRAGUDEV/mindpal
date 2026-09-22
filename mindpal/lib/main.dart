import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'config/api_config.dart';
import 'services/ai/ai_gateway_client.dart';
import 'services/ai/gemini_ai_service.dart';
import 'services/ai_service.dart';
import 'services/game_history_service.dart';
import 'services/language_service.dart';
import 'services/memory_aid_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'services/reminder_service.dart';
import 'storage/local_storage.dart';
import 'storage/shared_prefs_storage.dart';

/// Entry point.
///
/// main() has exactly one job: build the app's dependencies, then run the app.
/// No UI code lives here — that is app.dart's job.
Future<void> main() async {
  // shared_preferences talks to Android over a platform channel, and channels
  // need the Flutter engine binding to exist first. Forgetting this line is
  // the most common startup crash in Flutter.
  WidgetsFlutterBinding.ensureInitialized();

  // Offline-first also means fault-tolerant: if the device's storage cannot
  // be opened, the app must still start. We fall back to memory-only storage
  // and tell the user their changes will not be kept.
  LocalStorage storage = SharedPrefsStorage();
  var storageHealthy = true;

  try {
    await storage.init();
  } catch (error, stackTrace) {
    debugPrint('Local storage failed to open: $error\n$stackTrace');
    storage = InMemoryStorage();
    await storage.init();
    storageHealthy = false;
  }

  // Notifications are optional: the reminder list works with or without them.
  // Today this is always the do-nothing version, which is what lets the app
  // run in Chrome. The real Android implementation is still to be built.
  final NotificationService notifications = NoopNotificationService();
  await notifications.init();

  // The AI gateway URL is supplied at build time and is NOT a secret — the
  // API key lives only in the gateway's own environment, never here:
  //   flutter run -d chrome --dart-define=AI_GATEWAY_URL=http://localhost:8787
  //
  // With no URL configured the app is entirely offline and uses the
  // deterministic services, which is the default.
  final gatewayUrl = ApiConfig.baseUrl;
  final AiService aiService = gatewayUrl.isEmpty
      ? const DeterministicAiService()
      : GeminiAiService(client: AiGatewayClient(baseUrl: gatewayUrl));

  // Wake the backend as soon as the app opens.
  //
  // Free hosting tiers put a service to sleep after a few idle minutes, and
  // the request that wakes it waits 30-60 seconds for the container to boot.
  // If that request is the user's first question, the app looks broken.
  //
  // So we send a cheap health check at launch instead. The user spends those
  // seconds reading the home screen, and by the time they open the companion
  // the service is already up.
  //
  // unawaited() on purpose: startup must not wait for this, and a failure is
  // not an error — it just means the app carries on offline, which it is
  // designed to do.
  if (aiService is GeminiAiService) {
    unawaited(
      aiService
          .checkAvailable()
          .then(
            (awake) => debugPrint(
              awake ? 'BACKEND: awake' : 'BACKEND: not reachable yet',
            ),
          )
          // checkAvailable already swallows its errors; this is belt and
          // braces so a startup failure can never surface to the user.
          .catchError((Object _) {}),
    );
  }

  // Printed on every launch, because "why is it always offline?" is otherwise
  // invisible: a missing --dart-define looks exactly like a dead server.
  if (gatewayUrl.isEmpty) {
    debugPrint('BACKEND: not configured. Smart answers are off; the app '
        'runs on its offline services.');
    debugPrint('  Local:      flutter run -d chrome '
        '--dart-define=API_BASE_URL=http://localhost:8787');
    debugPrint('  Production: flutter build web '
        '--dart-define=API_BASE_URL=https://your-api.onrender.com');
    debugPrint('  A --dart-define is read at BUILD time only.');
  } else {
    debugPrint('BACKEND: $gatewayUrl  (from ${ApiConfig.describeSource})');
  }

  // Read the saved language BEFORE the first frame, so the app opens straight
  // into the user's language rather than flashing English for a moment.
  final languageService = LanguageService(storage);
  final language = await languageService.loadSelected();

  runApp(
    MindPalApp(
      profileService: ProfileService(storage),
      reminderService: ReminderService(storage, notifications),
      memoryAidService: MemoryAidService(storage),
      gameHistoryService: GameHistoryService(storage),
      aiService: aiService,
      languageService: languageService,
      initialLanguage: language,
      storageHealthy: storageHealthy,
    ),
  );
}
