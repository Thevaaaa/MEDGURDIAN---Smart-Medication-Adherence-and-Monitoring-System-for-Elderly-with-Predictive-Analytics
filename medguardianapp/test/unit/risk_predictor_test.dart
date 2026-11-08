// Unit tests for RiskPredictor.apiPayload — the request the app sends to the risk API.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medguardianapp/models/models.dart';
import 'package:medguardianapp/services/risk_predictor.dart';

DoseLog dose(String id, DateTime t, DoseStatus s, {DateTime? action, String med = 'm1'}) =>
    DoseLog(id: id, medicationId: med, medName: 'Metformin', dosage: '500 mg', scheduledTime: t, status: s, actionTime: action);

Map<String, dynamic>? payload(List<DoseLog> logs, {int age = 74, List<VitalReading> vitals = const [], List<AlertItem> alerts = const [], List<SymptomLog> symptoms = const []}) =>
    RiskPredictor.apiPayload(logs: logs, medicationCount: 2, age: age, conditionCount: 1, vitals: vitals, alerts: alerts, symptoms: symptoms);

void main() {
  final now = DateTime.now();
  DateTime ago(Duration d) => now.subtract(d);

  List<DoseLog> threeResolved() => [
        dose('a', ago(const Duration(days: 3)), DoseStatus.taken, action: ago(const Duration(days: 3)).add(const Duration(minutes: 5))),
        dose('b', ago(const Duration(days: 2)), DoseStatus.missed),
        dose('c', ago(const Duration(days: 1)), DoseStatus.taken, action: ago(const Duration(days: 1))),
      ];

  group('when there is too little history', () {
    test('fewer than 3 resolved doses returns null (the UI then shows "not enough data")', () {
      expect(payload([dose('a', ago(const Duration(days: 1)), DoseStatus.taken), dose('b', ago(const Duration(days: 2)), DoseStatus.missed)]), isNull);
    });
    test('pending and skipped doses do not count as history', () {
      final logs = [
        dose('a', ago(const Duration(days: 1)), DoseStatus.taken),
        dose('b', ago(const Duration(days: 2)), DoseStatus.skipped),
        dose('c', ago(const Duration(days: 3)), DoseStatus.skipped),
        dose('d', now.add(const Duration(hours: 2)), DoseStatus.pending),
      ];
      expect(payload(logs), isNull);
    });
  });

  group('request shape', () {
    test('has exactly the four top-level keys the API expects', () {
      final p = payload(threeResolved())!;
      expect(p.keys.toSet(), {'patient', 'history', 'upcoming', 'now'});
    });
    test('patient block has exactly the nine fields the API validates', () {
      final p = payload(threeResolved())!['patient'] as Map<String, dynamic>;
      expect(p.keys.toSet(), {
        'age', 'num_conditions', 'medication_count', 'avg_heart_rate', 'avg_oxygen_pct',
        'daily_steps', 'fall_events_30d', 'symptom_count_14d', 'avg_symptom_severity',
      });
    });
    test('history items carry medicine, time, status and delay', () {
      final h = (payload(threeResolved())!['history'] as List).first as Map<String, dynamic>;
      expect(h.keys.toSet(), {'medication_id', 'medication_name', 'scheduled_at', 'status', 'delay_min'});
    });
    test('the payload can be JSON-encoded (no DateTime objects leak in)', () {
      expect(() => jsonEncode(payload(threeResolved())), returnsNormally);
    });
    test('"now" is rounded down to the hour so the request only changes when something real changes', () {
      final n = DateTime.parse(payload(threeResolved())!['now'] as String);
      expect(n.minute, 0);
      expect(n.second, 0);
    });
  });

  group('history', () {
    test('only taken and missed doses from the last 30 days, oldest first', () {
      final logs = [
        ...threeResolved().reversed,
        dose('old', ago(const Duration(days: 45)), DoseStatus.missed),
        dose('skip', ago(const Duration(days: 4)), DoseStatus.skipped),
      ];
      final h = payload(logs)!['history'] as List;
      expect(h.length, 3);
      final times = h.map((e) => DateTime.parse(e['scheduled_at'] as String)).toList();
      expect(times, orderedEquals([...times]..sort()));
      expect(h.map((e) => e['status']), containsAll(['taken', 'missed']));
    });
    test('minutes late: taken late = difference, taken early = 0, missed = 0', () {
      final t = ago(const Duration(days: 1));
      final logs = [
        dose('late', t, DoseStatus.taken, action: t.add(const Duration(minutes: 25))),
        dose('early', t.subtract(const Duration(hours: 5)), DoseStatus.taken, action: t.subtract(const Duration(hours: 5, minutes: 10))),
        dose('miss', t.subtract(const Duration(hours: 10)), DoseStatus.missed),
        dose('x', ago(const Duration(days: 2)), DoseStatus.taken),
      ];
      final h = payload(logs)!['history'] as List;
      final byTime = {for (final e in h) e['scheduled_at'] as String: (e['delay_min'] as num).toDouble()};
      expect(byTime[t.toIso8601String()], 25);
      expect(byTime[t.subtract(const Duration(hours: 5)).toIso8601String()], 0);
      expect(byTime[t.subtract(const Duration(hours: 10)).toIso8601String()], 0);
    });
    test('an absurd delay is capped at 1440 minutes', () {
      final t = ago(const Duration(days: 5));
      final logs = [dose('x', t, DoseStatus.taken, action: t.add(const Duration(days: 3))), ...threeResolved()];
      final h = payload(logs)!['history'] as List;
      expect(h.map((e) => (e['delay_min'] as num).toDouble()).reduce((a, b) => a > b ? a : b), 1440);
    });
  });

  group('upcoming doses', () {
    test('pending doses in the next 24 hours are scored; later ones are not', () {
      final logs = [
        ...threeResolved(),
        dose('soon', now.add(const Duration(hours: 3)), DoseStatus.pending),
        dose('tomorrow', now.add(const Duration(hours: 23)), DoseStatus.pending),
        dose('far', now.add(const Duration(hours: 30)), DoseStatus.pending),
      ];
      expect((payload(logs)!['upcoming'] as List).length, 2);
    });
    test('a dose up to one hour overdue is still scored; an older pending dose is not', () {
      final logs = [
        ...threeResolved(),
        dose('overdue30', ago(const Duration(minutes: 30)), DoseStatus.pending),
        dose('overdue90', ago(const Duration(minutes: 90)), DoseStatus.pending),
      ];
      expect((payload(logs)!['upcoming'] as List).length, 1);
    });
    test('never more than 40 upcoming doses are sent', () {
      final logs = [...threeResolved(), for (var i = 0; i < 60; i++) dose('p$i', now.add(Duration(minutes: 5 + i * 10)), DoseStatus.pending)];
      expect((payload(logs)!['upcoming'] as List).length, lessThanOrEqualTo(40));
    });
  });

  group('patient block', () {
    test('unknown age (0) falls back to 72', () {
      expect((payload(threeResolved(), age: 0)!['patient'] as Map)['age'], 72);
    });
    test('without vitals the neutral defaults are used (76 bpm, 97 %, 3000 steps)', () {
      final p = payload(threeResolved())!['patient'] as Map;
      expect([p['avg_heart_rate'], p['avg_oxygen_pct'], p['daily_steps']], [76, 97, 3000]);
    });
    test('recent vitals are averaged', () {
      final v = [
        VitalReading(id: '1', time: ago(const Duration(days: 1)), heartRate: 80, oxygenLevel: 96, steps: 2000),
        VitalReading(id: '2', time: ago(const Duration(days: 2)), heartRate: 90, oxygenLevel: 94, steps: 4000),
      ];
      final p = payload(threeResolved(), vitals: v)!['patient'] as Map;
      expect([p['avg_heart_rate'], p['avg_oxygen_pct'], p['daily_steps']], [85, 95, 3000]);
    });
    test('symptoms in the last 14 days are counted and their severity averaged', () {
      final s = [
        SymptomLog(id: '1', time: ago(const Duration(days: 1)), symptom: 'Dizzy', severity: 2),
        SymptomLog(id: '2', time: ago(const Duration(days: 3)), symptom: 'Nausea', severity: 4),
        SymptomLog(id: '3', time: ago(const Duration(days: 30)), symptom: 'Old', severity: 5),
      ];
      final p = payload(threeResolved(), symptoms: s)!['patient'] as Map;
      expect(p['symptom_count_14d'], 2);
      expect(p['avg_symptom_severity'], 3.0);
    });
    test('only recent fall alerts count', () {
      final a = [
        AlertItem(id: '1', time: ago(const Duration(days: 5)), type: AlertType.fallDetected, severity: AlertSeverity.critical, title: 't', message: 'm'),
        AlertItem(id: '2', time: ago(const Duration(days: 60)), type: AlertType.fallDetected, severity: AlertSeverity.critical, title: 't', message: 'm'),
        AlertItem(id: '3', time: ago(const Duration(days: 1)), type: AlertType.sos, severity: AlertSeverity.critical, title: 't', message: 'm'),
      ];
      expect((payload(threeResolved(), alerts: a)!['patient'] as Map)['fall_events_30d'], 1);
    });
  });
}
