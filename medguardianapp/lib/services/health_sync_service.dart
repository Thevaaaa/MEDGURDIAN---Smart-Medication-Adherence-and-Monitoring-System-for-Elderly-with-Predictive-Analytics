import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Latest readings pulled from the phone's health store.
class DeviceVitals {
  final int? heartRate; // bpm
  final int? oxygen; // %
  final int? steps; // today
  final DateTime? measuredAt;

  /// App that recorded the heart-rate / oxygen reading, e.g. "Samsung Health".
  final String sourceApp;
  const DeviceVitals({this.heartRate, this.oxygen, this.steps, this.measuredAt, this.sourceApp = ''});

  bool get isEmpty => heartRate == null && oxygen == null && steps == null;
}

class HealthPoint {
  final DateTime time;
  final double value;
  const HealthPoint(this.time, this.value);
}

/// Last 24 h of heart rate / SpO2 (averaged per hour) and the last 7 days of steps.
class HealthHistory {
  final List<HealthPoint> heartRate;
  final List<HealthPoint> oxygen;
  final List<DateTime> days; // oldest -> today
  final List<int> dailySteps;

  /// Apps / devices that supplied the readings, e.g. ["Samsung Health"].
  final List<String> sources;
  const HealthHistory({this.heartRate = const [], this.oxygen = const [], this.days = const [], this.dailySteps = const [], this.sources = const []});

  bool get isEmpty => heartRate.isEmpty && oxygen.isEmpty && dailySteps.every((s) => s == 0);
}

/// Reads heart rate, blood-oxygen (SpO2) and steps from the device's health
/// platform — **Health Connect** on Android and **Apple Health** on iOS.
/// Any watch, ring, band or oximeter that syncs to those (Samsung Health,
/// Fitbit, Garmin, Mi Fitness, Apple Watch, Withings…) is therefore
/// supported without pairing it to MedGuardian directly.
class HealthSyncService {
  HealthSyncService._();
  static final HealthSyncService instance = HealthSyncService._();

  final Health _health = Health();
  bool _configured = false;

  static const _types = [HealthDataType.HEART_RATE, HealthDataType.BLOOD_OXYGEN, HealthDataType.STEPS];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Android only: Health Connect must be installed / up to date. On Android
  /// 14+ it is built into the phone; on Android 13 and below it is a Play
  /// Store app. Opens the Play Store and throws a readable message if needed.
  Future<void> _ensureHealthConnect() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final status = await _health.getHealthConnectSdkStatus();
    if (status == HealthConnectSdkStatus.sdkAvailable) return;
    try {
      await _health.installHealthConnect();
    } catch (_) {}
    throw Exception(status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired
        ? 'Health Connect needs an update. Update it in the Play Store, then tap Sync device again.'
        : 'Health Connect is not installed. Install it from the Play Store, then tap Sync device again.');
  }

  /// Asks for read access (shows the OS permission screen the first time).
  Future<bool> requestAccess() async {
    await _configure();
    await _ensureHealthConnect();
    final perms = _types.map((_) => HealthDataAccess.READ).toList();
    try {
      final has = await _health.hasPermissions(_types, permissions: perms) ?? false;
      if (has) return true;
      return await _health.requestAuthorization(_types, permissions: perms);
    } catch (e) {
      debugPrint('Health permission failed: $e');
      return false;
    }
  }

  /// Device-friendly name of the health hub, for messages.
  String get hubName => defaultTargetPlatform == TargetPlatform.iOS ? 'Apple Health' : 'Health Connect';

  /// Most recent heart rate + SpO2 from the last 24 h, and today's steps.
  /// Throws a readable message if access is refused or nothing is available.
  Future<DeviceVitals> readLatest() async {
    if (!await requestAccess()) {
      throw Exception('MedGuardian needs permission to read heart rate, oxygen and steps. '
          'On Android, install or open Health Connect and allow MedGuardian; on iPhone, allow it in the Health app.');
    }
    final now = DateTime.now();
    // Watches sync in batches, so look back a few days and use the newest.
    final since = now.subtract(const Duration(days: 3));

    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.HEART_RATE, HealthDataType.BLOOD_OXYGEN],
      startTime: since,
      endTime: now,
    );

    HealthDataPoint? latestOf(HealthDataType t) {
      final list = points.where((p) => p.type == t).toList()..sort((a, b) => b.dateTo.compareTo(a.dateTo));
      return list.isEmpty ? null : list.first;
    }

    double? numOf(HealthDataPoint? p) {
      final v = p?.value;
      return v is NumericHealthValue ? v.numericValue.toDouble() : null;
    }

    final hrPoint = latestOf(HealthDataType.HEART_RATE);
    final oxPoint = latestOf(HealthDataType.BLOOD_OXYGEN);
    final hr = numOf(hrPoint);
    var ox = numOf(oxPoint);
    // Apple Health reports SpO2 as a fraction (0.97); Health Connect as a percent.
    if (ox != null && ox <= 1.0) ox = ox * 100;

    int? steps;
    try {
      steps = await _health.getTotalStepsInInterval(DateTime(now.year, now.month, now.day), now);
    } catch (_) {}

    final when = [hrPoint?.dateTo, oxPoint?.dateTo].whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

    final apps = <String>{
      for (final p in [hrPoint, oxPoint])
        if (p != null) friendlyApp(p.sourceName.isNotEmpty ? p.sourceName : p.sourceId),
    };
    final result = DeviceVitals(heartRate: hr?.round(), oxygen: ox?.round(), steps: steps, measuredAt: when, sourceApp: apps.join(' + '));
    if (result.isEmpty) {
      throw Exception('No heart-rate or oxygen readings from the last 3 days were found. '
          'Make sure your watch or oximeter is syncing to ${defaultTargetPlatform == TargetPlatform.iOS ? 'Apple Health' : 'Health Connect'}.');
    }
    return result;
  }

  static const Map<String, String> _apps = {
    'com.sec.android.app.shealth': 'Samsung Health',
    'com.samsung.android.wear.shealth': 'Samsung Health',
    'com.google.android.apps.fitness': 'Google Fit',
    'com.google.android.apps.healthdata': 'Health Connect',
    'com.google.android.wearable.app': 'Wear OS',
    'com.fitbit.FitbitMobile': 'Fitbit',
    'com.garmin.android.apps.connectmobile': 'Garmin Connect',
    'com.xiaomi.wearable': 'Mi Fitness',
    'com.mi.health': 'Mi Fitness',
    'com.huawei.health': 'Huawei Health',
    'com.heytap.health': 'HeyTap Health',
    'com.oppo.health': 'HeyTap Health',
    'com.withings.wiscale2': 'Withings',
    'com.ouraring.oura': 'Oura',
    'com.huami.watch.hmwatchmanager': 'Zepp',
    'com.MTechX.medguardianapp': 'MedGuardian',
  };

  /// Turns an Android package name (or an iPhone source name) into something readable.
  static String friendlyApp(String raw) {
    if (raw.isEmpty) return 'Health Connect';
    final known = _apps[raw];
    if (known != null) return known;
    if (!raw.contains('.')) return raw; // iPhone: already a name such as "Apple Watch"
    final last = raw.split('.').last;
    return last.isEmpty ? raw : last[0].toUpperCase() + last.substring(1);
  }

  /// True when the user has already allowed MedGuardian in Health Connect / Apple
  /// Health. Never shows a permission screen.
  Future<bool> hasAccess() async {
    try {
      await _configure();
      final perms = _types.map((_) => HealthDataAccess.READ).toList();
      return await _health.hasPermissions(_types, permissions: perms) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Hourly heart-rate / SpO2 for the last 24 h plus steps for the last 7 days,
  /// used for the trend charts. Missing data simply yields empty lists.
  Future<HealthHistory> readHistory() async {
    await _configure();
    final now = DateTime.now();

    var points = <HealthDataPoint>[];
    try {
      points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.HEART_RATE, HealthDataType.BLOOD_OXYGEN],
        startTime: now.subtract(const Duration(hours: 24)),
        endTime: now,
      );
    } catch (e) {
      debugPrint('Health history failed: $e');
    }

    List<HealthPoint> hourly(HealthDataType type) {
      final buckets = <DateTime, List<double>>{};
      for (final p in points.where((p) => p.type == type)) {
        final v = p.value;
        if (v is! NumericHealthValue) continue;
        var x = v.numericValue.toDouble();
        if (type == HealthDataType.BLOOD_OXYGEN && x <= 1.0) x *= 100;
        final key = DateTime(p.dateTo.year, p.dateTo.month, p.dateTo.day, p.dateTo.hour);
        (buckets[key] ??= []).add(x);
      }
      final keys = buckets.keys.toList()..sort();
      return [
        for (final k in keys) HealthPoint(k, buckets[k]!.reduce((a, b) => a + b) / buckets[k]!.length),
      ];
    }

    final days = <DateTime>[];
    final steps = <int>[];
    for (var i = 6; i >= 0; i--) {
      final start = DateTime(now.year, now.month, now.day - i);
      final end = i == 0 ? now : start.add(const Duration(days: 1));
      int total = 0;
      try {
        total = await _health.getTotalStepsInInterval(start, end) ?? 0;
      } catch (_) {}
      days.add(start);
      steps.add(total);
    }

    final sources = <String>{
      for (final p in points) friendlyApp(p.sourceName.isNotEmpty ? p.sourceName : p.sourceId),
    }.toList()
      ..sort();

    return HealthHistory(
      sources: sources,
      heartRate: hourly(HealthDataType.HEART_RATE),
      oxygen: hourly(HealthDataType.BLOOD_OXYGEN),
      days: days,
      dailySteps: steps,
    );
  }
}
