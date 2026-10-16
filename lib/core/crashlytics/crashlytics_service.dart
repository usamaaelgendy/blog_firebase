import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Crashlytics so the rest of the app depends on this service,
/// not on `FirebaseCrashlytics.instance`.
class CrashlyticsService {
  final FirebaseCrashlytics _crashlytics;

  CrashlyticsService(this._crashlytics);

  /// Reports every uncaught error as fatal. Call once, right after Firebase is initialized.
  void init() {
    // Errors thrown inside the Flutter framework (build, layout, gestures).
    FlutterError.onError = _crashlytics.recordFlutterFatalError;

    // Uncaught async errors that the Flutter framework doesn't catch.
    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Records an error the app handled, so it is non-fatal by default.
  Future<void> recordError(Object error, StackTrace? stack, {String? reason, bool fatal = false}) {
    return _crashlytics.recordError(error, stack, reason: reason, fatal: fatal);
  }

  /// Forces a native crash to check the Crashlytics setup.
  void crash() => _crashlytics.crash();
}
