import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Generic wrapper around flutter_local_notifications.
/// Knows nothing about FCM, so any feature can use it to show a notification.
class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin;

  static const _defaultChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications.',
    importance: Importance.high,
  );

  LocalNotificationService(this._plugin);

  /// [onTap] is called with the notification's payload when the user taps it.
  Future<void> init({void Function(String? payload)? onTap}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested elsewhere (e.g. by FirebaseMessaging).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: onTap == null ? null : (response) => onTap(response.payload),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_defaultChannel);
  }

  /// Payload of the notification that launched the app from a terminated state, if any.
  /// onDidReceiveNotificationResponse is not called in that case.
  Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    AndroidNotificationChannel channel = _defaultChannel,
  }) {
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Future<void> cancelAll() => _plugin.cancelAll();
}
