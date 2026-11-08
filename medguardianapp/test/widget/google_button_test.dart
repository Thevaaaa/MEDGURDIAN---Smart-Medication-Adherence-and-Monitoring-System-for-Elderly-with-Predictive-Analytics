// Widget tests for the "Continue with Google" button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medguardianapp/widgets/google_button.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('shows the default and a custom label', (tester) async {
    await tester.pumpWidget(host(GoogleButton(onPressed: () {})));
    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.pumpWidget(host(GoogleButton(label: 'Sign up with Google', onPressed: () {})));
    expect(find.text('Sign up with Google'), findsOneWidget);
  });

  testWidgets('calls onPressed when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(GoogleButton(onPressed: () => taps++)));
    await tester.tap(find.byType(GoogleButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('while loading it shows a spinner and ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(GoogleButton(loading: true, onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    await tester.tap(find.byType(GoogleButton));
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 0);
  });

  testWidgets('when disabled (onPressed null) taps do nothing', (tester) async {
    await tester.pumpWidget(host(const GoogleButton(onPressed: null)));
    await tester.tap(find.byType(GoogleButton));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
