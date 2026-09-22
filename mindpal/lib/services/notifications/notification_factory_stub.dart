import '../notification_service.dart';

/// Web (and anything else without dart:io): reminders are saved and shown in
/// the app, but the browser cannot schedule a notification for a future time
/// while the page is closed, so nothing rings. The UI says so.
NotificationService createPlatformNotificationService() =>
    NoopNotificationService();
