import '../models/models.dart';

RiskLevel _levelFrom(dynamic v) => switch (v) {
      'high' => RiskLevel.high,
      'moderate' => RiskLevel.moderate,
      _ => RiskLevel.low,
    };

/// Predicted chance of missing ONE upcoming dose.
class DoseRisk {
  final String medicationName;
  final DateTime scheduledAt;
  final String timeSlot;
  final int percent;
  final RiskLevel level;
  final List<String> reasons;

  const DoseRisk({
    required this.medicationName,
    required this.scheduledAt,
    required this.timeSlot,
    required this.percent,
    required this.level,
    required this.reasons,
  });

  factory DoseRisk.fromApi(Map<String, dynamic> j) => DoseRisk(
        medicationName: (j['medication_name'] ?? '') as String,
        scheduledAt: DateTime.tryParse((j['scheduled_at'] ?? '') as String) ?? DateTime.now(),
        timeSlot: (j['time_slot'] ?? '') as String,
        percent: ((j['percent'] ?? 0) as num).round(),
        level: _levelFrom(j['level']),
        reasons: List<String>.from((j['reasons'] as List?) ?? const []),
      );
}

/// A habit found in the user's own dose history.
class RiskInsight {
  final String kind;
  final String title;
  final String detail;
  const RiskInsight({required this.kind, required this.title, required this.detail});

  factory RiskInsight.fromApi(Map<String, dynamic> j) => RiskInsight(
        kind: (j['kind'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        detail: (j['detail'] ?? '') as String,
      );
}

/// Result of a missed-dose risk prediction.
class RiskResult {
  final double probability; // 0..1, likelihood the NEXT dose is missed
  final RiskLevel level;
  final List<String> factors;

  /// False until there is enough recorded history to estimate anything —
  /// the UI then shows "not enough data" instead of a made-up percentage.
  final bool hasData;

  /// 'local' = on-device formula, 'api' = trained model on the cloud API.
  final String source;

  /// Short caption such as "Logistic Regression · cloud API · 86% test accuracy".
  final String modelNote;

  /// Risk for each upcoming dose (next 24 hours) and plain-language habits
  /// found in the user's own history ("you often miss morning doses").
  final List<DoseRisk> doses;
  final List<RiskInsight> insights;

  const RiskResult({
    required this.probability,
    required this.level,
    required this.factors,
    this.hasData = true,
    this.source = 'local',
    this.modelNote = '',
    this.doses = const [],
    this.insights = const [],
  });

  /// Builds a result from the /predict_doses response of the risk API.
  factory RiskResult.fromApi(Map<String, dynamic> j) {
    final p = (j['probability'] as num).toDouble();
    final m = (j['model'] as Map?) ?? const {};
    final acc = m['accuracy'] is num ? ((m['accuracy'] as num) * 100).toStringAsFixed(0) : null;
    return RiskResult(
      probability: p,
      level: _levelFrom(j['level']),
      factors: List<String>.from((j['factors'] as List?) ?? const []),
      source: 'api',
      modelNote: '${m['name'] ?? 'Logistic Regression'} · cloud API${acc != null ? ' · $acc% test accuracy' : ''}',
      doses: ((j['doses'] as List?) ?? const []).map((e) => DoseRisk.fromApi(Map<String, dynamic>.from(e as Map))).toList(),
      insights: ((j['insights'] as List?) ?? const []).map((e) => RiskInsight.fromApi(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }

  /// Waiting for the API to answer.
  factory RiskResult.loading() => const RiskResult(
        probability: 0,
        level: RiskLevel.low,
        hasData: false,
        factors: ['Calculating risk…'],
      );

  /// The API could not be reached (no internet / server down).
  factory RiskResult.unavailable() => const RiskResult(
        probability: 0,
        level: RiskLevel.low,
        hasData: false,
        factors: ['Risk estimate is unavailable right now. Check your internet connection — it will retry automatically.'],
      );

  factory RiskResult.empty() => const RiskResult(
        probability: 0,
        level: RiskLevel.low,
        hasData: false,
        factors: ['Not enough history yet — MedGuardian needs a few days of recorded doses before it can estimate risk.'],
      );

  int get percent => (probability * 100).round();
  String get percentLabel => hasData ? '$percent%' : '—';
}

/// Builds the feature set that is sent to the risk API.
///
/// The risk itself is NOT calculated in the app: the trained logistic-regression
/// model runs on the cloud API (see /api in the project) and the app only
/// displays what it returns.
class RiskPredictor {
  RiskPredictor._();

  /// What is sent to the cloud API: the patient's profile, their last 30 days of
  /// taken / missed doses (medicine, scheduled time, minutes late) and the doses
  /// coming up in the next 24 hours. The API turns that into features itself,
  /// the same way the model was trained. Returns null while there is too little
  /// history to predict anything.
  static Map<String, dynamic>? apiPayload({
    required List<DoseLog> logs,
    required int medicationCount,
    required int age,
    required int conditionCount,
    required List<VitalReading> vitals,
    required List<AlertItem> alerts,
    required List<SymptomLog> symptoms,
  }) {
    final now = DateTime.now();
    final resolved = logs
        .where((d) =>
            d.scheduledTime.isAfter(now.subtract(const Duration(days: 30))) &&
            d.scheduledTime.isBefore(now) &&
            (d.status == DoseStatus.taken || d.status == DoseStatus.missed))
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    if (resolved.length < 3) return null;
    final recent = resolved.length > 600 ? resolved.sublist(resolved.length - 600) : resolved;

    final upcoming = logs
        .where((d) =>
            d.status == DoseStatus.pending &&
            d.scheduledTime.isAfter(now.subtract(const Duration(hours: 1))) &&
            d.scheduledTime.isBefore(now.add(const Duration(hours: 24))))
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    double delayOf(DoseLog d) {
      if (d.status != DoseStatus.taken || d.actionTime == null) return 0;
      final m = d.actionTime!.difference(d.scheduledTime).inMinutes;
      return m < 0 ? 0.0 : (m > 1440 ? 1440.0 : m.toDouble());
    }

    final recentVitals = vitals.where((v) => v.time.isAfter(now.subtract(const Duration(days: 7)))).toList();
    double avgOf(Iterable<num> xs, double fallback) {
      final l = xs.where((x) => x > 0).toList();
      return l.isEmpty ? fallback : l.reduce((a, b) => a + b) / l.length;
    }

    final recentSymptoms = symptoms.where((s) => s.time.isAfter(now.subtract(const Duration(days: 14)))).toList();
    final symptomSeverity = recentSymptoms.isEmpty ? 0.0 : recentSymptoms.map((s) => s.severity).reduce((a, b) => a + b) / recentSymptoms.length;

    return {
      'patient': {
        'age': age > 0 ? age : 72,
        'num_conditions': conditionCount,
        'medication_count': medicationCount,
        'avg_heart_rate': avgOf(recentVitals.map((v) => v.heartRate), 76).roundToDouble(),
        'avg_oxygen_pct': avgOf(recentVitals.map((v) => v.oxygenLevel), 97).roundToDouble(),
        'daily_steps': avgOf(recentVitals.map((v) => v.steps), 3000).roundToDouble(),
        'fall_events_30d': alerts.where((a) => a.type == AlertType.fallDetected && a.time.isAfter(now.subtract(const Duration(days: 30)))).length,
        'symptom_count_14d': recentSymptoms.length,
        'avg_symptom_severity': double.parse(symptomSeverity.toStringAsFixed(1)),
      },
      'history': [
        for (final d in recent)
          {
            'medication_id': d.medicationId,
            'medication_name': d.medName,
            'scheduled_at': d.scheduledTime.toIso8601String(),
            'status': d.status == DoseStatus.missed ? 'missed' : 'taken',
            'delay_min': delayOf(d),
          },
      ],
      'upcoming': [
        for (final d in upcoming.take(40))
          {
            'medication_id': d.medicationId,
            'medication_name': d.medName,
            'scheduled_at': d.scheduledTime.toIso8601String(),
          },
      ],
      // rounded down to the hour so the request only changes when something real changes
      'now': DateTime(now.year, now.month, now.day, now.hour).toIso8601String(),
    };
  }
}
