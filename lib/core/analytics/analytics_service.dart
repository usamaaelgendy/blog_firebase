import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Event names, kept in one place so every call logs the same spelling.
abstract class _AnalyticsEvents {
  static const postCreated = 'post_created';
  static const commentAdded = 'comment_added';
}

/// Parameter names shared by the events above.
abstract class _AnalyticsParams {
  static const postId = 'post_id';
  static const category = 'category';
}

/// Wraps Firebase Analytics so the rest of the app depends on this service,
/// not on `FirebaseAnalytics.instance`.
class AnalyticsService {
  final FirebaseAnalytics _analytics;

  AnalyticsService(this._analytics);

  /// Logs that the user published a new post.
  Future<void> logPostCreated({required String postId, String? category}) {
    return _log(_AnalyticsEvents.postCreated, {_AnalyticsParams.postId: postId, _AnalyticsParams.category: ?category});
  }

  /// Logs that the user added a comment to a post.
  Future<void> logCommentAdded({required String postId}) {
    return _log(_AnalyticsEvents.commentAdded, {_AnalyticsParams.postId: postId});
  }

  Future<void> _log(String name, Map<String, Object> parameters) async {
    await _analytics.logEvent(name: name, parameters: parameters);
    if (kDebugMode) {
      debugPrint('[Analytics] $name $parameters');
    }
  }
}
