import 'dart:io';

import '../notification_service.dart';
import 'android_notification_service.dart';

/// Android gets the real thing. Desktop builds (used only by `flutter test`
/// on this machine) get the no-op, since nothing there is wired up.
NotificationService createPlatformNotificationService() =>
    Platform.isAndroid ? AndroidNotificationService() : NoopNotificationService();
