import 'package:flutter/material.dart';
import 'services/app_data.dart';
import 'theme/app_theme.dart';
import 'utils/nav.dart';
import 'screens/splash_screen.dart';

class MedGuardianApp extends StatelessWidget {
  const MedGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'MedGuardian',
          navigatorKey: rootNavigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            // Large text is an elderly-only setting — caregiver screens always use the
            // normal size, even when testing both roles on one phone.
            final scale = AppData.instance.largeTextActive ? 1.25 : 1.0;
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
