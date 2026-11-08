import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import 'app_data.dart';
import 'notification_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _google = GoogleSignIn();

  /// True while an email sign-up is still writing the profile, so the auth gate
  /// does not mistake the half-created account for a Google user without a profile.
  bool creatingProfile = false;

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    required String phone,
    DateTime? birthDate,
  }) async {
    if (!isValidPhone(phone)) throw Exception('Please enter a valid phone number.');
    if (role == UserRole.elderly && birthDate == null) throw Exception('Please choose your date of birth.');
    creatingProfile = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user!.updateDisplayName(name.trim());
      await _writeProfile(uid: cred.user!.uid, name: name, email: email, role: role, phone: phone, birthDate: birthDate);
    } finally {
      creatingProfile = false;
    }
  }

  Future<void> _writeProfile({
    required String uid,
    required String name,
    required String email,
    required UserRole role,
    required String phone,
    DateTime? birthDate,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'role': role.name,
      'phone': phone.trim(),
      'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      'createdAt': FieldValue.serverTimestamp(),
    };

    String? code;
    if (role == UserRole.elderly) {
      final birth = birthDate!;
      code = await _uniqueLinkCode();
      data.addAll({
        'birthDate': Timestamp.fromDate(DateTime(birth.year, birth.month, birth.day)),
        'age': ageFromBirthDate(birth),
        'conditions': <String>[],
        'homeAddress': '',
        'linkCode': code,
        'safeRadiusM': 200,
        'shareLocation': true,
        'fallDetection': true,
      });
    } else {
      data['notifyPrefs'] = {'doseReminders': true, 'missedDose': true, 'health': true, 'geofence': true};
    }

    await _db.collection('users').doc(uid).set(data);
    if (code != null) {
      await _db.collection('linkCodes').doc(code).set({'elderlyId': uid, 'elderlyName': name.trim()});
    }
  }

  // ── Google sign-in ─────────────────────────────────────────────────

  /// Signs in (or signs up) with a Google account. Returns false if the user
  /// closed the Google chooser. A brand-new Google user has no profile yet —
  /// the auth gate then shows the "finish setting up" screen.
  Future<bool> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return false;
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(accessToken: auth.accessToken, idToken: auth.idToken);
    await _auth.signInWithCredential(credential);
    return true;
  }

  /// Whether the signed-in user already has a MedGuardian profile document.
  /// Returns true when unsure (e.g. offline) so a real user is never blocked.
  Future<bool> hasProfile(String uid) async {
    if (creatingProfile) return true;
    try {
      return (await _db.collection('users').doc(uid).get()).exists;
    } catch (_) {
      return true;
    }
  }

  /// Second step for a new Google user: role, phone and (elderly) date of birth.
  Future<void> completeGoogleProfile({
    required String name,
    required UserRole role,
    required String phone,
    DateTime? birthDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in.');
    if (!isValidPhone(phone)) throw Exception('Please enter a valid phone number.');
    if (role == UserRole.elderly && birthDate == null) throw Exception('Please choose your date of birth.');
    if (name.trim().isEmpty) throw Exception('Please enter your full name.');
    await user.updateDisplayName(name.trim());
    await _writeProfile(uid: user.uid, name: name, email: user.email ?? '', role: role, phone: phone, birthDate: birthDate);
  }

  /// True for accounts that sign in with Google and have no password.
  bool get usesGoogleOnly {
    final p = _auth.currentUser?.providerData.map((e) => e.providerId).toList() ?? const [];
    return p.contains('google.com') && !p.contains('password');
  }

  Future<String> _uniqueLinkCode() async {
    final rand = Random.secure();
    for (var i = 0; i < 8; i++) {
      final code = (100000 + rand.nextInt(900000)).toString();
      final snap = await _db.collection('linkCodes').doc(code).get();
      if (!snap.exists) return code;
    }
    throw Exception('Could not generate a unique link code — please try again.');
  }

  /// Permanently deletes the account. Re-authenticates with [password] first
  /// (Firebase requires a recent login); the `onUserDeleted` Cloud Function
  /// then removes all of the user's Firestore data.
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Not signed in.');
    if (usesGoogleOnly) {
      final account = await _google.signIn();
      if (account == null) throw Exception('Delete cancelled.');
      final auth = await account.authentication;
      await user.reauthenticateWithCredential(GoogleAuthProvider.credential(accessToken: auth.accessToken, idToken: auth.idToken));
    } else {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
    }
    await NotificationService.instance.unregister(user.uid);
    await user.delete();
    await AppData.instance.stop();
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await NotificationService.instance.unregister(uid);
    await AppData.instance.stop();
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Phone numbers are required for every account (caregivers are called
  /// from SOS / alerts). Accepts spaces, dashes and a leading +.
  static bool isValidPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(digits);
  }

  /// Human-readable message for Firebase auth / generic errors.
  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address does not look right.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'weak-password':
          return 'Please choose a password with at least 6 characters.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'requires-recent-login':
          return 'Please sign in again and retry.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'account-exists-with-different-credential':
          return 'An account with this email already exists. Sign in with your email and password instead.';
      }
      return e.message ?? 'Authentication failed.';
    }
    if (e is PlatformException) {
      final text = '${e.code} ${e.message}';
      if (text.contains('network_error')) return 'No internet connection. Please try again.';
      if (text.contains('ApiException: 10') || text.contains('12500') || text.contains('sign_in_failed')) {
        return 'Google sign-in is not set up for this build yet (add the SHA-1 key in Firebase and update google-services.json).';
      }
      return 'Google sign-in failed. Please try again.';
    }
    if (e is FirebaseException) {
      if (e.code == 'permission-denied' || e.code == 'unauthorized') {
        return 'The server refused this change (${e.plugin} permission denied). '
            'The Firebase security rules need to be deployed — run: firebase deploy --only firestore:rules,storage';
      }
      return e.message ?? 'Something went wrong (${e.code}).';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
