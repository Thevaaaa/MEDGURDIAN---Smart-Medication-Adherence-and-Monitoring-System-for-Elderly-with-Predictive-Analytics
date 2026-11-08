// Widget tests for the "Your next doses" and "Your habits" cards.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medguardianapp/models/models.dart';
import 'package:medguardianapp/services/risk_predictor.dart';
import 'package:medguardianapp/widgets/risk_details.dart';

Widget host(RiskResult r) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: RiskDetails(risk: r))));

RiskResult withData() => RiskResult(
      probability: 0.5,
      level: RiskLevel.moderate,
      factors: const ['x'],
      doses: [
        DoseRisk(medicationName: 'Metformin', scheduledAt: DateTime.now().add(const Duration(hours: 2)), timeSlot: 'morning', percent: 78, level: RiskLevel.high, reasons: const ['Morning doses are often missed']),
        DoseRisk(medicationName: 'Aspirin', scheduledAt: DateTime.now().add(const Duration(hours: 5)), timeSlot: 'evening', percent: 12, level: RiskLevel.low, reasons: const ['Aspirin is rarely missed']),
      ],
      insights: const [RiskInsight(kind: 'time_of_day', title: 'You often miss morning doses', detail: '79% of morning doses were missed.')],
    );

void main() {
  testWidgets('shows nothing while there is no data (loading / unavailable / empty)', (tester) async {
    for (final r in [RiskResult.loading(), RiskResult.unavailable(), RiskResult.empty()]) {
      await tester.pumpWidget(host(r));
      expect(find.text('Your next doses'), findsNothing);
      expect(find.text('Your habits'), findsNothing);
    }
  });

  testWidgets('lists each upcoming dose with its percentage and top reason', (tester) async {
    await tester.pumpWidget(host(withData()));
    expect(find.text('Your next doses'), findsOneWidget);
    expect(find.text('Metformin'), findsOneWidget);
    expect(find.text('78%'), findsOneWidget);
    expect(find.text('12%'), findsOneWidget);
    expect(find.text('Morning doses are often missed'), findsOneWidget);
  });

  testWidgets('shows habit insights with title and detail', (tester) async {
    await tester.pumpWidget(host(withData()));
    expect(find.text('Your habits'), findsOneWidget);
    expect(find.text('You often miss morning doses'), findsOneWidget);
    expect(find.text('79% of morning doses were missed.'), findsOneWidget);
  });

  testWidgets('the doses card is hidden when there are insights only', (tester) async {
    final r = RiskResult(probability: 0.2, level: RiskLevel.low, factors: const ['x'], insights: const [RiskInsight(kind: 'steady', title: 'Steady routine', detail: 'd')]);
    await tester.pumpWidget(host(r));
    expect(find.text('Your next doses'), findsNothing);
    expect(find.text('Steady routine'), findsOneWidget);
  });

  testWidgets('never shows more than 8 upcoming doses', (tester) async {
    final many = RiskResult(
      probability: 0.3,
      level: RiskLevel.low,
      factors: const ['x'],
      doses: [for (var i = 0; i < 12; i++) DoseRisk(medicationName: 'Med$i', scheduledAt: DateTime.now().add(Duration(hours: i + 1)), timeSlot: 'morning', percent: 10, level: RiskLevel.low, reasons: const [])],
    );
    await tester.pumpWidget(host(many));
    expect(find.textContaining('Med'), findsNWidgets(8));
  });
}
