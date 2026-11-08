// Unit tests for the validation and error-message logic in AuthService (no Firebase connection needed).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medguardianapp/services/auth_service.dart';

void main() {
  group('isValidPhone', () {
    for (final ok in ['+60 12-345 6789', '0123456789', '+60123456789', '(012) 345-6789', '+14155552671']) {
      test('accepts "$ok"', () => expect(AuthService.isValidPhone(ok), isTrue));
    }
    for (final bad in ['', '123', 'abcdefghij', '+60 12 345 abc', '12345678901234567890', '++6012345678']) {
      test('rejects "$bad"', () => expect(AuthService.isValidPhone(bad), isFalse));
    }
  });

  group('friendlyError', () {
    String msg(String code) => AuthService.friendlyError(FirebaseAuthException(code: code));
    test('wrong credentials all give one generic message (no account enumeration)', () {
      expect(msg('wrong-password'), 'Incorrect email or password.');
      expect(msg('user-not-found'), 'Incorrect email or password.');
      expect(msg('invalid-credential'), 'Incorrect email or password.');
    });
    test('common sign-up errors', () {
      expect(msg('email-already-in-use'), contains('already exists'));
      expect(msg('weak-password'), contains('6 characters'));
      expect(msg('invalid-email'), contains('email'));
    });
    test('network and throttling', () {
      expect(msg('network-request-failed'), contains('internet'));
      expect(msg('too-many-requests'), contains('Too many'));
    });
    test('Google account clash points to email sign-in', () {
      expect(msg('account-exists-with-different-credential'), contains('email and password'));
    });
    test('Google not configured gives an actionable hint', () {
      final m = AuthService.friendlyError(PlatformException(code: 'sign_in_failed', message: 'ApiException: 10'));
      expect(m, contains('not set up'));
    });
    test('Google network error', () {
      expect(AuthService.friendlyError(PlatformException(code: 'network_error')), contains('internet'));
    });
    test('permission-denied explains the rules must be deployed', () {
      final m = AuthService.friendlyError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
      expect(m, contains('security rules'));
    });
    test('a plain Exception shows its own message without the prefix', () {
      expect(AuthService.friendlyError(Exception('Please choose your date of birth.')), 'Please choose your date of birth.');
    });
  });
}
