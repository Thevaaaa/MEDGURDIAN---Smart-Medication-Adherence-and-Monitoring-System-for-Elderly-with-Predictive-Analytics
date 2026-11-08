import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';


class FallDetectionService {
  FallDetectionService._();
  static final FallDetectionService instance = FallDetectionService._();

  static const double impactThreshold = 28.0; // m/s²
  static const Duration settleDelay = Duration(seconds: 1);
  static const Duration observeWindow = Duration(seconds: 4);
  static const Duration cooldown = Duration(minutes: 2);

  /// Wired up by ElderlyShell to show the countdown dialog.
  VoidCallback? onCandidate;

  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime? _impactAt;
  DateTime _lastCandidate = DateTime.fromMillisecondsSinceEpoch(0);
  final List<double> _post = [];

  bool get running => _sub != null;

  void setEnabled(bool enabled) {
    if (enabled) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    if (_sub != null) return;
    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen(
        _onEvent,
        onError: (Object e) => debugPrint('Accelerometer unavailable: $e'),
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Fall detection could not start: $e');
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _impactAt = null;
    _post.clear();
  }

  void _onEvent(AccelerometerEvent e) {
    final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final now = DateTime.now();

    if (_impactAt == null) {
      if (mag > impactThreshold && now.difference(_lastCandidate) > cooldown) {
        _impactAt = now;
        _post.clear();
      }
      return;
    }

    final since = now.difference(_impactAt!);
    if (since >= settleDelay) _post.add(mag);

    if (since >= observeWindow) {
      final ok = _isStill(_post);
      _impactAt = null;
      _post.clear();
      if (ok) {
        _lastCandidate = now;
        onCandidate?.call();
      }
    }
  }

  bool _isStill(List<double> samples) {
    if (samples.length < 5) return false;
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance = samples.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / samples.length;
    return sqrt(variance) < 1.8 && mean > 7.5 && mean < 12.0;
  }
}
