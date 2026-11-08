import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/fall_background_service.dart';
import 'services/notification_service.dart';

/// MedGuardian — Firebase edition.
///
/// Auth, Firestore, FCM push (sent by Cloud Functions), real fall
/// detection (accelerometer) and GPS/geofencing. See SETUP.md.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // TEST ENVIRONMENT ONLY: flutter run --dart-define=USE_FIREBASE_EMULATOR=true [--dart-define=EMULATOR_HOST=192.168.x.x]
  // sends Auth and Firestore to the local Firebase Emulator Suite instead of the real project.
  // (10.0.2.2 is the Android emulator's address for the PC; use the PC's LAN IP for a real phone.)
  const useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
  if (useEmulator) {
    const host = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await NotificationService.instance.initialize();
  await FallBackgroundService.instance.configure();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFF6F4EE),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  runApp(const MedGuardianApp());
}
