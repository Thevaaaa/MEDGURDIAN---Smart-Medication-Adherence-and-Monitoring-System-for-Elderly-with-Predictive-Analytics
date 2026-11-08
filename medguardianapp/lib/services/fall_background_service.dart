import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fall_signal.dart';
import 'location_snapshot.dart';

class FallBackgroundService {
  FallBackgroundService._();
  static final FallBackgroundService instance = FallBackgroundService._();

  static const notificationChannelId = 'fall_service';
  static const _serviceNotifId = 9100;

  bool _configured = false;

  Future<void> configure() async {
    if (_configured) return;
    _configured = true;

    // Android 8+ crashes the app ("Bad notification for startForeground") if the
    // foreground-service notification channel does not exist yet, so create it first.
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            notificationChannelId,
            'Fall detection service',
            description: 'Keeps fall detection running in the background.',
            importance: Importance.low,
          ));
    } catch (e) {
      debugPrint('Could not create fall-service channel: $e');
    }

    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'MedGuardian is protecting you',
        initialNotificationContent: 'Fall detection is running in the background.',
        foregroundServiceNotificationId: _serviceNotifId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _iosBackground,
      ),
    );
  }

  Future<void> setEnabled(bool on) async {
    await configure();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kFallEnabledPref, on);
    final service = FlutterBackgroundService();
    if (on) {
      await _requestLaunchPermissions();
      if (!await service.isRunning()) await service.startService();
    } else {
      if (await service.isRunning()) service.invoke('stopService');
      await FallSignal.clear();
    }
  }

  Future<bool> get isRunning => FlutterBackgroundService().isRunning();

  /// Android 14+ only lets apps open a full-screen screen from the
  /// background (like an alarm clock) if the user allows it. Called
  /// dynamically so older flutter_local_notifications versions still compile.
  Future<void> _requestLaunchPermissions() async {
    try {
      final android = FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      await (android as dynamic).requestFullScreenIntentPermission();
    } catch (_) {
      // Not supported on this plugin / OS version — nothing to request.
    }
  }
}

const kFallEnabledPref = 'mg_fall_enabled';
const kAppForegroundAtPref = 'mg_app_fg_at';

@pragma('vm:entry-point')
bool _iosBackground(ServiceInstance service) => true;

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Already initialized (e.g. Android keeps the engine warm between runs).
  }

  final local = FlutterLocalNotificationsPlugin();
  await local.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: notificationActionBackgroundHandler,
    onDidReceiveBackgroundNotificationResponse: notificationActionBackgroundHandler,
  );

  // Honour the user's setting even when Android restarts the service on its
  // own (e.g. after a reboot).
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool(kFallEnabledPref) == false) {
      service.stopSelf();
      return;
    }
  } catch (_) {}

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(title: 'MedGuardian is protecting you', content: 'Fall detection is running in the background.');
  }

  const fallNotifId = 9101;
  const impactThreshold = 28.0; // m/s² — gravity alone is ~9.8
  const settleDelay = Duration(seconds: 1);
  const observeWindow = Duration(seconds: 4);
  const cooldown = Duration(minutes: 2);

  DateTime? impactAt;
  DateTime lastCandidate = DateTime.fromMillisecondsSinceEpoch(0);
  final postImpact = <double>[];
  Timer? countdownPoll;

  Future<void> escalate() async {
    countdownPoll?.cancel();
    countdownPoll = null;
    await local.cancel(fallNotifId);

    final state = await FallSignal.read();
    await FallSignal.clear();
    final uid = (state != null && state.uid.isNotEmpty) ? state.uid : FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('Fall escalation aborted: no signed-in user in background isolate');
      return;
    }

    LocationSnapshot? snap;
    try {
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)).timeout(const Duration(seconds: 8));
      snap = LocationSnapshot(lat: pos.latitude, lng: pos.longitude);
    } catch (e) {
      debugPrint('Background fall: could not get a location fix: $e');
    }

    var message = "MedGuardian's fall detector felt a hard impact followed by stillness, and nobody responded within 20 seconds.";
    if (snap != null) {
      try {
        message = '$message\n${await snap.describe()}';
      } catch (_) {}
    }

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid).collection('alerts').doc();
      await ref.set({
        'time': Timestamp.now(),
        'type': 'fallDetected',
        'severity': 'critical',
        'title': 'Possible fall detected',
        'message': message,
        'acknowledged': false,
        'lat': snap?.lat,
        'lng': snap?.lng,
      });
      debugPrint('Fall alert written for $uid');
    } catch (e) {
      debugPrint('Fall escalation Firestore write failed: $e');
    }
  }

  Future<void> startCountdown() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FallSignal.start(uid, const Duration(seconds: 20));

    // Open the countdown screen straight away — no notification to tap.
    //  * App on screen → the UI isolate gets the 'fall' event and pushes the
    //    full-screen countdown immediately.
    //  * App closed / phone locked → a full-screen intent (the same mechanism
    //    alarm clocks and incoming calls use) launches MedGuardian directly
    //    onto the countdown page.
    service.invoke('fall', {'deadline': DateTime.now().add(const Duration(seconds: 20)).millisecondsSinceEpoch});

    var appOnScreen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final seen = prefs.getInt(kAppForegroundAtPref);
      appOnScreen = seen != null && DateTime.now().millisecondsSinceEpoch - seen < 8000;
    } catch (_) {}

    if (!appOnScreen) {
      await local.show(
        fallNotifId,
        'Fall detected',
        'Opening MedGuardian — confirm you are OK within 20 seconds.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'critical_alerts',
            'Critical alerts',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
            timeoutAfter: 25000,
            visibility: NotificationVisibility.public,
          ),
        ),
        payload: 'fall',
      );
    }

    countdownPoll?.cancel();
    countdownPoll = Timer.periodic(const Duration(seconds: 1), (t) async {
      final state = await FallSignal.read();
      if (state == null) {
        t.cancel();
        countdownPoll = null;
        return;
      }
      if (state.status == 'ok') {
        t.cancel();
        countdownPoll = null;
        await local.cancel(fallNotifId);
        await FallSignal.clear();
        return;
      }
      if (state.status == 'help' || state.expired) {
        t.cancel();
        await escalate();
      }
    });
  }

  StreamSubscription<AccelerometerEvent>? sub;
  try {
    sub = accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final now = DateTime.now();

      if (impactAt == null) {
        if (mag > impactThreshold && now.difference(lastCandidate) > cooldown) {
          impactAt = now;
          postImpact.clear();
        }
        return;
      }

      final since = now.difference(impactAt!);
      if (since >= settleDelay) postImpact.add(mag);

      if (since >= observeWindow) {
        final samples = List<double>.from(postImpact);
        impactAt = null;
        postImpact.clear();
        if (samples.length < 5) return;
        final mean = samples.reduce((a, b) => a + b) / samples.length;
        final variance = samples.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / samples.length;
        final still = sqrt(variance) < 1.8 && mean > 7.5 && mean < 12.0;
        if (still) {
          lastCandidate = now;
          startCountdown();
        }
      }
    });
  } catch (e) {
    debugPrint('Background accelerometer stream unavailable: $e');
  }

  service.on('stopService').listen((event) {
    sub?.cancel();
    countdownPoll?.cancel();
    service.stopSelf();
  });
}
