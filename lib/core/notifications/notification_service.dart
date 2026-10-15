import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

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

  /// Attached to MaterialApp so we can show snackbars without a BuildContext.
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  NotificationService(this._messaging);

  Future<void> init() async {
    final settings = await _messaging.requestPermission();
    debugPrint('Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    debugPrint('FCM token: $token');

    _messaging.onTokenRefresh.listen((token) => debugPrint('FCM token refreshed: $token'));

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(notification.body ?? ''),
          ],
        ),
      ),
    );
  }
}
