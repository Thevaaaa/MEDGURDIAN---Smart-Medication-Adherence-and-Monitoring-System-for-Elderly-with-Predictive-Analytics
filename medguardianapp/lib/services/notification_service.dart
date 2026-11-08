import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'fall_signal.dart';


@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Background FCM: ${message.messageId}');
}


class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();


  final ValueNotifier<String?> tapTarget = ValueNotifier<String?>(null);

  final ValueNotifier<AuthorizationStatus?> permission = ValueNotifier<AuthorizationStatus?>(null);
  final ValueNotifier<bool> tokenRegistered = ValueNotifier<bool>(false);

  static const AndroidNotificationChannel criticalChannel = AndroidNotificationChannel(
    'critical_alerts',
    'Critical alerts',
    description: 'SOS, falls and other emergencies',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel remindersChannel = AndroidNotificationChannel(
    'dose_reminders',
    'Reminders',
    description: 'Medication and appointment reminders',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel updatesChannel = AndroidNotificationChannel(
    'care_updates',
    'Care updates',
    description: 'Missed doses, symptoms and location updates',
    importance: Importance.high,
  );

  bool _initialized = false;
  String? _uid;
  String? _token;
  StreamSubscription<String>? _refreshSub;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) {
        _setTarget(r.payload);
        notificationActionBackgroundHandler(r);
      },
      // Registered defensively so the fall notification's action buttons are
      // handled the same way regardless of which plugin instance (this one,
      // or the background service's own) issued the notification.
      onDidReceiveBackgroundNotificationResponse: notificationActionBackgroundHandler,
    );

    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(criticalChannel);
      await android?.createNotificationChannel(remindersChannel);
      await android?.createNotificationChannel(updatesChannel);
    }

    await _fcm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _setTarget(m.data['target'] as String?));

    final initial = await _fcm.getInitialMessage();
    if (initial != null) _setTarget(initial.data['target'] as String?);

    // Local notification that launched the app from a terminated state.
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) _setTarget(launch?.notificationResponse?.payload);

    try {
      permission.value = (await _fcm.getNotificationSettings()).authorizationStatus;
    } catch (_) {}
  }

  void _setTarget(String? target) {
    if (target == null || target.isEmpty) return;
    tapTarget.value = target;
  }

  static String _channelName(String id) => id == 'critical_alerts' ? 'Critical alerts' : (id == 'dose_reminders' ? 'Reminders' : 'Care updates');

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // iOS shows foreground pushes itself (presentation options above).
    if (!Platform.isAndroid) return;
    final n = message.notification;
    if (n == null) return;
    await showLocal(
      id: message.hashCode,
      title: n.title ?? 'MedGuardian',
      body: n.body ?? '',
      channel: (message.data['channel'] as String?) ?? 'care_updates',
      payload: message.data['target'] as String?,
    );
  }

  /// Show a heads-up notification on this device.
  Future<void> showLocal({required int id, required String title, required String body, String channel = 'care_updates', String? payload}) {
    return _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          _channelName(channel),
          importance: channel == 'critical_alerts' ? Importance.max : Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: true),
      ),
      payload: payload,
    );
  }

  Future<void> cancelLocal(int id) => _local.cancel(id);

  /// Ask for permission, fetch the FCM token and register it for [uid].
  Future<void> registerForUser(String uid) async {
    _uid = uid;
    try {
      final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
      permission.value = settings.authorizationStatus;
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        tokenRegistered.value = false;
        debugPrint('🔕 Notification permission denied');
        return;
      }

      String? token;
      for (var attempt = 0; attempt < 4 && token == null; attempt++) {
        try {
          token = await _fcm.getToken();
        } catch (_) {
          // iOS: the APNs token may not be ready on the very first call.
        }
        if (token == null) await Future<void>.delayed(const Duration(seconds: 2));
      }
      if (token == null) {
        tokenRegistered.value = false;
        return;
      }

      _token = token;
      await _saveToken(uid, token);
      tokenRegistered.value = true;

      await _refreshSub?.cancel();
      _refreshSub = _fcm.onTokenRefresh.listen((t) async {
        final owner = _uid;
        if (owner == null) return;
        if (_token != null && _token != t) {
          try {
            await FirebaseFirestore.instance.collection('fcmTokens').doc(_token).delete();
          } catch (_) {}
        }
        _token = t;
        await _saveToken(owner, t);
      });
    } catch (e) {
      tokenRegistered.value = false;
      debugPrint('FCM registration failed: $e');
    }
  }

  /// Re-check the OS permission (e.g. after the user returns from Settings).
  Future<void> refreshPermission() async {
    try {
      final s = await _fcm.getNotificationSettings();
      permission.value = s.authorizationStatus;
      final ok = s.authorizationStatus == AuthorizationStatus.authorized || s.authorizationStatus == AuthorizationStatus.provisional;
      if (ok && !tokenRegistered.value && _uid != null) await registerForUser(_uid!);
      if (!ok) tokenRegistered.value = false;
    } catch (_) {}
  }

  Future<void> _saveToken(String uid, String token) {
    return FirebaseFirestore.instance.collection('fcmTokens').doc(token).set({
      'uid': uid,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Call BEFORE signing out (needs an authenticated session to write).
  Future<void> unregister(String uid) async {
    try {
      await _refreshSub?.cancel();
      _refreshSub = null;
      final token = _token ?? await _fcm.getToken();
      if (token != null) {
        try {
          await FirebaseFirestore.instance.collection('fcmTokens').doc(token).delete();
        } catch (e) {
          debugPrint('Token doc delete failed: $e');
        }
      }
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('FCM unregister failed: $e');
    } finally {
      _uid = null;
      _token = null;
      tokenRegistered.value = false;
    }
  }
}
