// MedGuardian widget smoke tests (replaces the default Flutter "counter" template test, which never applied to this app).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medguardianapp/screens/auth/signup_screen.dart';

void main() {
  testWidgets('RoleCard shows its label and reacts to taps (used on sign-up and "finish setting up")', (tester) async {
    var selected = 'elderly';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => Row(children: [
            Expanded(child: RoleCard(icon: Icons.elderly_rounded, label: 'Using it myself', selected: selected == 'elderly', onTap: () => setState(() => selected = 'elderly'))),
            Expanded(child: RoleCard(icon: Icons.volunteer_activism_rounded, label: 'A caregiver', selected: selected == 'caregiver', onTap: () => setState(() => selected = 'caregiver'))),
          ]),
        ),
      ),
    ));
    expect(find.text('Using it myself'), findsOneWidget);
    expect(find.text('A caregiver'), findsOneWidget);
    await tester.tap(find.text('A caregiver'));
    await tester.pumpAndSettle();
    expect(selected, 'caregiver');
  });
}
