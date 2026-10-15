/// Value of the `type` field in a notification's data payload.
/// Each type decides which screen opens when the user taps the notification.
///
/// To add a type: add a value here, then handle it in NotificationService._handleTap.
enum NotificationType {
  /// Data: `{"type": "post", "postId": "<id>"}`
  post('post');

  final String value;

  const NotificationType(this.value);

  static NotificationType? fromValue(String? value) => values.where((type) => type.value == value).firstOrNull;
}
