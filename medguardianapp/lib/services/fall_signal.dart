import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FallSignal {
  FallSignal._();

  static const _kDeadline = 'mg_fall_deadline_ms';
  static const _kStatus = 'mg_fall_status'; // pending | ok | help
  static const _kUid = 'mg_fall_uid';

  static Future<void> start(String uid, Duration countdown) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUid, uid);
    await p.setInt(_kDeadline, DateTime.now().add(countdown).millisecondsSinceEpoch);
    await p.setString(_kStatus, 'pending');
  }

  static Future<void> markOk() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kStatus, 'ok');
  }

  static Future<void> markGetHelp() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kStatus, 'help');
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kDeadline);
    await p.remove(_kStatus);
    await p.remove(_kUid);
  }

  static Future<FallState?> read() async {
    final p = await SharedPreferences.getInstance();
    // SharedPreferences caches values per isolate. The countdown is written by
    // the background-service isolate (and "I'm OK" by another), so without a
    // reload the UI isolate keeps seeing the stale/empty cache and never
    // finds the pending fall — which is why tapping the notification opened
    // the app without the countdown dialog.
    await p.reload();
    final deadlineMs = p.getInt(_kDeadline);
    if (deadlineMs == null) return null;
    return FallState(
      uid: p.getString(_kUid) ?? '',
      deadline: DateTime.fromMillisecondsSinceEpoch(deadlineMs),
      status: p.getString(_kStatus) ?? 'pending',
    );
  }
}

class FallState {
  final String uid;
  final DateTime deadline;
  final String status; // pending | ok | help
  const FallState({required this.uid, required this.deadline, required this.status});

  bool get expired => DateTime.now().isAfter(deadline);
  Duration get remaining {
    final d = deadline.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }
}

/// Handles a tap on the fall notification's "I'm OK" / "Get help now"
/// action buttons. Registered as the `onDidReceiveBackgroundNotificationResponse`
/// callback on every `FlutterLocalNotificationsPlugin.initialize()` call in
/// the app, so it fires the same way regardless of which plugin instance
/// (foreground app or background service) originally showed the notification,
/// and regardless of whether the app process is alive.
///
/// NOTE: this cross-isolate action-button path is the standard
/// flutter_local_notifications mechanism but has not been device-tested here.
/// Tapping the notification's body (rather than an action button) always
/// works as a fallback — it opens the app, which shows the same countdown
/// dialog with the true remaining time.
@pragma('vm:entry-point')
void notificationActionBackgroundHandler(NotificationResponse response) {
  if (response.actionId == 'im_ok') {
    FallSignal.markOk();
  } else if (response.actionId == 'get_help') {
    FallSignal.markGetHelp();
  }
}
