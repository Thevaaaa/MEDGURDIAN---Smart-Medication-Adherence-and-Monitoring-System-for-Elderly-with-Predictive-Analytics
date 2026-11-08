import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'risk_predictor.dart';


class RiskApiService {
  RiskApiService._();

  static const String baseUrl = 'https://medguardian-risk-api-518397406148.asia-southeast1.run.app';
  /// LEGACY shared secret. A key compiled into an app can be extracted from the APK, so the API now
  /// also accepts the signed-in user's Firebase ID token (sent below). Once the API runs with
  /// AUTH_MODE=firebase, set this to '' — see testing/06_security_testing.md.
  static const String apiKey = '';

  static bool get enabled => baseUrl.isNotEmpty && !baseUrl.contains('YOUR-CLOUD-RUN-URL');

  static Future<RiskResult?> predict(Map<String, dynamic> payload) async {
    if (!enabled) return null;
    try {
      // The user's Firebase ID token proves WHO is calling; it expires after an hour and cannot be reused by strangers.
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final res = await http
          .post(
            Uri.parse('$baseUrl/predict_doses'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
              if (apiKey.isNotEmpty) 'x-api-key': apiKey,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20)); // allows for a Cloud Run cold start
      if (res.statusCode != 200) {
        debugPrint('Risk API ${res.statusCode}: ${res.body}');
        return null;
      }
      return RiskResult.fromApi(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Risk API unreachable: $e');
      return null;
    }
  }
}
