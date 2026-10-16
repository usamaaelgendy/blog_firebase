import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Performance so the rest of the app depends on this service,
/// not on `FirebasePerformance.instance`.
class PerformanceService {
  final FirebasePerformance _performance;

  PerformanceService(this._performance);

  /// Measures how long [action] takes as a custom trace named [name] and returns its result.
  /// [attributes] split the trace in the console (e.g. by category), up to 5 per trace.
  Future<T> measure<T>(String name, Future<T> Function() action, {Map<String, String>? attributes}) async {
    final trace = _performance.newTrace(name);
    attributes?.forEach(trace.putAttribute);

    final stopwatch = Stopwatch()..start();
    await trace.start();
    try {
      final result = await action();
      trace.putAttribute('status', 'success');
      return result;
    } catch (_) {
      trace.putAttribute('status', 'error');
      rethrow;
    } finally {
      await trace.stop();
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('[Performance] $name ${attributes ?? ''} took ${stopwatch.elapsedMilliseconds}ms');
      }
    }
  }
}
