import 'package:blog_app/core/notifications/local_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Runs in its own isolate when a message arrives while the app is in the
/// background or terminated. Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}

/// Handles Firebase Cloud Messaging setup: permission, FCM token and foreground messages.
class NotificationService {
  final FirebaseMessaging _messaging;
  final LocalNotificationService _localNotifications;

  NotificationService(this._messaging, this._localNotifications);

  Future<void> init() async {
    final settings = await _messaging.requestPermission();
    debugPrint('Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    await _messaging.setForegroundNotificationPresentationOptions(
      sound: true,
      badge: true,
      alert: true,
    );

    await _localNotifications.init();

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await _waitForApnsToken();
      debugPrint('APNs token: $apnsToken');
      if (apnsToken == null) return;
    }

    final token = await _messaging.getToken();
    debugPrint('FCM token: $token');

    _messaging.onTokenRefresh.listen(
      (token) => debugPrint('FCM token refreshed: $token'),
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  /// On iOS, getToken() throws until the APNs token is registered, which can take a moment after launch.
  Future<String?> _waitForApnsToken({int attempts = 5}) async {
    for (var i = 0; i < attempts; i++) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null) return apnsToken;
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  /// FCM doesn't display notifications while the app is in the foreground, so we show them ourselves.
  void _onForegroundMessage(RemoteMessage message) {
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
    );
  }
}
