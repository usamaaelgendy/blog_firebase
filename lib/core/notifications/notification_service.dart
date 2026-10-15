import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handles Firebase Cloud Messaging setup: permission + FCM token.
class NotificationService {
  final FirebaseMessaging _messaging;

  NotificationService(this._messaging);

  Future<void> init() async {
    final settings = await _messaging.requestPermission();
    debugPrint('Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    debugPrint('FCM token: $token');

    _messaging.onTokenRefresh.listen((token) => debugPrint('FCM token refreshed: $token'));
  }
}
