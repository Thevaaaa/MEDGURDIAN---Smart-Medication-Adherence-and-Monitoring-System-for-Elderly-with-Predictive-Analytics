// Integration test — runs the REAL app on a phone / emulator.
//   flutter test integration_test/app_smoke_test.dart --dart-define=USE_FIREBASE_EMULATOR=true
// Needs: a device, the Firebase emulators running (see testing/01_firebase_test_environment.md) and a SIGNED-OUT app.
// It checks the start-up path and the form validation without sending anything to Firebase.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medguardianapp/main.dart' as app;

Future<bool> pumpUntil(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold start reaches the login screen with both sign-in options', (tester) async {
    await app.main();
    final found = await pumpUntil(tester, find.text('Continue with Google'));
    expect(found, isTrue, reason: 'Login screen not reached - is a user still signed in? Sign out first.');
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('empty login form is rejected locally', (tester) async {
    await app.main();
    expect(await pumpUntil(tester, find.text('Sign in')), isTrue);
    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Enter your email and password.'), findsOneWidget);
  });

  testWidgets('sign-up form validates before calling Firebase', (tester) async {
    await app.main();
    expect(await pumpUntil(tester, find.text('Create an account')), isTrue);
    await tester.tap(find.text('Create an account'));
    expect(await pumpUntil(tester, find.text('Create account')), isTrue);
    expect(find.text('Sign up with Google'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Please enter your full name.'), findsOneWidget);
  });
}
