// Unit tests for parsing the API response into RiskResult / DoseRisk / RiskInsight.
// The JSON below is a REAL response captured from the API (see testing/evidence/sample_response.json).
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medguardianapp/models/models.dart';
import 'package:medguardianapp/services/risk_predictor.dart';

const sample = '''
{"probability":0.4954,"percent":50,"level":"moderate",
 "factors":["Med MED1 at this time of day is often missed","Weekend doses are missed more often"],
 "doses":[
  {"medication_id":"MED1","medication_name":"Med MED1","scheduled_at":"2026-11-01T08:00:00","time_slot":"morning","probability":0.7814,"percent":78,"level":"high","reasons":["Med MED1 at this time of day is often missed"]},
  {"medication_id":"MED1","medication_name":"Med MED1","scheduled_at":"2026-11-01T20:00:00","time_slot":"evening","probability":0.2094,"percent":21,"level":"low","reasons":["Adherence has been steady"]}],
 "insights":[{"kind":"time_of_day","title":"You often miss morning doses","detail":"79% of morning doses were missed, against 50% overall."}],
 "history_doses":28,
 "model":{"name":"Logistic Regression","accuracy":0.796,"data":"synthetic"}}
''';

void main() {
  test('parses the overall risk', () {
    final r = RiskResult.fromApi(jsonDecode(sample) as Map<String, dynamic>);
    expect(r.hasData, isTrue);
    expect(r.probability, closeTo(0.4954, 1e-9));
    expect(r.percent, 50);
    expect(r.level, RiskLevel.moderate);
    expect(r.source, 'api');
    expect(r.factors.length, 2);
  });

  test('parses per-dose risk', () {
    final r = RiskResult.fromApi(jsonDecode(sample) as Map<String, dynamic>);
    expect(r.doses.length, 2);
    expect(r.doses.first.medicationName, 'Med MED1');
    expect(r.doses.first.percent, 78);
    expect(r.doses.first.level, RiskLevel.high);
    expect(r.doses.last.level, RiskLevel.low);
    expect(r.doses.first.scheduledAt, DateTime.parse('2026-11-01T08:00:00'));
  });

  test('parses habit insights', () {
    final r = RiskResult.fromApi(jsonDecode(sample) as Map<String, dynamic>);
    expect(r.insights.single.kind, 'time_of_day');
    expect(r.insights.single.title, contains('morning'));
  });

  test('an unknown level string falls back to low instead of crashing', () {
    final r = RiskResult.fromApi({'probability': 0.1, 'level': 'banana'});
    expect(r.level, RiskLevel.low);
    expect(r.doses, isEmpty);
    expect(r.insights, isEmpty);
  });

  test('an integer probability is accepted (JSON has no int/double distinction)', () {
    expect(RiskResult.fromApi({'probability': 1, 'level': 'high'}).probability, 1.0);
  });

  group('non-API states never show a made-up percentage', () {
    test('loading', () {
      final r = RiskResult.loading();
      expect(r.hasData, isFalse);
      expect(r.percentLabel, '—');
    });
    test('unavailable', () {
      final r = RiskResult.unavailable();
      expect(r.hasData, isFalse);
      expect(r.percentLabel, '—');
      expect(r.factors.first, contains('unavailable'));
    });
    test('empty (not enough history)', () {
      final r = RiskResult.empty();
      expect(r.hasData, isFalse);
      expect(r.factors.first, contains('Not enough history'));
    });
  });
}
