import '../notification_service.dart';
import 'notification_factory_stub.dart'
    if (dart.library.io) 'notification_factory_io.dart'
    as platform;

/// The notification service for the platform this build targets.
///
/// Resolved at COMPILE time by conditional import, the same way the Memory
/// Vault picks its media store: the web bundle never contains the Android
/// implementation or the plugins it depends on, and the Android build never
/// contains web code. Whatever comes back must still be `init()`ed, and must
/// never throw from it.
NotificationService createNotificationService() =>
    platform.createPlatformNotificationService();
