import 'dart:convert';

import 'package:blog_app/core/notifications/local_notification_service.dart';
import 'package:blog_app/core/notifications/notification_type.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

/// Handles Firebase Cloud Messaging setup: permission, FCM token, foreground messages
/// and opening the right screen when the user taps a notification.
///
/// Messages must carry a `type` (see [NotificationType]) in their data payload,
/// plus the fields that type needs, e.g. `{"type": "post", "postId": "<id>"}`.
class NotificationService {
  static const _typeKey = 'type';

  final FirebaseMessaging _messaging;
  final LocalNotificationService _localNotifications;
  final GlobalKey<NavigatorState> _navigatorKey;

  NotificationService(this._messaging, this._localNotifications, this._navigatorKey);

  Future<void> init() async {
    final settings = await _messaging.requestPermission();
    debugPrint('Notification permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    await _messaging.setForegroundNotificationPresentationOptions(
      sound: true,
      badge: true,
      alert: true,
    );

    // Foreground (Android): tap on the local notification we showed.
    await _localNotifications.init(onTap: _onLocalNotificationTap);

    await _setupTapHandlers();

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

  Future<void> _setupTapHandlers() async {
    // Background: app was alive and the user tapped an FCM notification.
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(message.data));

    // Terminated: the FCM notification tap launched the app.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTap(initialMessage.data);
      return;
    }

    // Terminated: a local notification (shown while in foreground) launched the app.
    _onLocalNotificationTap(await _localNotifications.getLaunchPayload());
  }

  /// Local notifications carry the FCM data map as a JSON payload.
  void _onLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    _handleTap(Map<String, dynamic>.from(jsonDecode(payload) as Map));
  }

  void _handleTap(Map<String, dynamic> data) {
    final type = NotificationType.fromValue(data[_typeKey] as String?);
    debugPrint('Notification tapped: $type $data');

    switch (type) {
      case NotificationType.post:
        final postId = data['postId'] as String?;
        if (postId == null || postId.isEmpty) return;
        _navigate('/post-detail', arguments: postId);
      case null:
        return;
    }
  }

  /// init() runs before runApp, so the navigator may not exist yet. Wait for the first frame.
  void _navigate(String route, {Object? arguments}) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigate(route, arguments: arguments));
      return;
    }
    navigator.pushNamed(route, arguments: arguments);
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
      payload: jsonEncode(message.data),
    );
  }
}
