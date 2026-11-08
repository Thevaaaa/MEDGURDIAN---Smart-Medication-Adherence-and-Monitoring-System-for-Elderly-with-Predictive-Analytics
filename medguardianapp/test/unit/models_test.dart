// Unit tests for the pure logic inside the data models.
import 'package:flutter_test/flutter_test.dart';
import 'package:medguardianapp/models/models.dart';

void main() {
  group('ageFromBirthDate', () {
    test('birthday not reached yet this year', () {
      expect(ageFromBirthDate(DateTime(1950, 6, 15), DateTime(2026, 6, 14)), 75);
    });
    test('on the birthday', () {
      expect(ageFromBirthDate(DateTime(1950, 6, 15), DateTime(2026, 6, 15)), 76);
    });
    test('day after the birthday', () {
      expect(ageFromBirthDate(DateTime(1950, 6, 15), DateTime(2026, 6, 16)), 76);
    });
  });

  group('dose timing rules', () {
    test('a dose opens 15 minutes before its time', () {
      final d = DoseLog(id: 'x', medicationId: 'm', medName: 'A', dosage: '1', scheduledTime: DateTime(2026, 1, 1, 8, 0));
      expect(d.opensAt, DateTime(2026, 1, 1, 7, 45));
      expect(kDoseEarlyWindow, const Duration(minutes: 15));
      expect(kDoseMissAfter, const Duration(hours: 1));
    });
    test('a dose later today is still locked, a dose in the past is open', () {
      final future = DoseLog(id: 'f', medicationId: 'm', medName: 'A', dosage: '1', scheduledTime: DateTime.now().add(const Duration(hours: 3)));
      final past = DoseLog(id: 'p', medicationId: 'm', medName: 'A', dosage: '1', scheduledTime: DateTime.now().subtract(const Duration(minutes: 5)));
      expect(future.isOpen, isFalse);
      expect(past.isOpen, isTrue);
    });
  });

  group('VitalReading', () {
    VitalReading v({int hr = 72, int ox = 97, Duration age = const Duration(minutes: 5), String source = 'manual', String app = ''}) =>
        VitalReading(id: 'v', time: DateTime.now().subtract(age), heartRate: hr, oxygenLevel: ox, steps: 0, source: source, sourceApp: app);

    test('a manual reading expires after one hour', () {
      expect(v(age: const Duration(minutes: 50)).isManualStale, isFalse);
      expect(v(age: const Duration(minutes: 61)).isManualStale, isTrue);
    });
    test('a device reading never expires as "manual"', () {
      expect(v(age: const Duration(days: 2), source: 'health_connect').isManualStale, isFalse);
    });
    test('minutes left is clamped between 0 and 999', () {
      expect(v(age: const Duration(minutes: 20)).manualMinutesLeft, inInclusiveRange(39, 40));
      expect(v(age: const Duration(hours: 5)).manualMinutesLeft, 0);
    });
    test('source label names the app', () {
      expect(v(source: 'health_connect', app: 'Samsung Health').sourceLabel, 'Samsung Health · Health Connect');
      expect(v(source: 'health_connect').sourceLabel, 'Health Connect');
      expect(v().sourceLabel, 'Entered manually');
    });
    test('heart-rate thresholds', () {
      expect(v(hr: 49).heartAbnormal, isTrue);
      expect(v(hr: 50).heartAbnormal, isFalse);
      expect(v(hr: 120).heartAbnormal, isFalse);
      expect(v(hr: 121).heartAbnormal, isTrue);
      expect(v(hr: 0).heartAbnormal, isFalse, reason: '0 means "not measured"');
    });
    test('oxygen thresholds', () {
      expect(v(ox: 95).oxygenLow, isFalse);
      expect(v(ox: 94).oxygenLow, isTrue);
      expect(v(ox: 92).oxygenCritical, isFalse);
      expect(v(ox: 91).oxygenCritical, isTrue);
    });
    test('critical = heart rate <40 or >140, or oxygen <92', () {
      expect(v(hr: 39).isCritical, isTrue);
      expect(v(hr: 141).isCritical, isTrue);
      expect(v(hr: 100, ox: 91).isCritical, isTrue);
      expect(v(hr: 100, ox: 96).isCritical, isFalse);
    });
    test('problems are listed in plain language', () {
      expect(v(hr: 130, ox: 90).problems, ['high heart rate (130 bpm)', 'low oxygen (90%)']);
    });
  });
}
