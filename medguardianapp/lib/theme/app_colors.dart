import 'package:flutter/material.dart';

/// MedGuardian design tokens — a warm, high-trust palette built for both
/// elderly users (high contrast, calm) and caregivers (data-dense, modern).
class AppColors {
  AppColors._();

  // Brand
  static const Color primary        = Color(0xFF12706A); // deep guardian teal
  static const Color primaryDark    = Color(0xFF124442);
  static const Color primaryLight   = Color(0xFF5FA79E);
  static const Color accent         = Color(0xFFF2A65A); // warm amber accent
  static const Color accentSoft     = Color(0xFFFCE3C4);

  // Semantic
  static const Color success        = Color(0xFF3FA772);
  static const Color successSoft    = Color(0xFFDCF3E6);
  static const Color warning        = Color(0xFFE0A527);
  static const Color warningSoft    = Color(0xFFFBEFCF);
  static const Color danger         = Color(0xFFE0604F);
  static const Color dangerSoft     = Color(0xFFFAE0DB);
  static const Color info           = Color(0xFF3E7CB1);
  static const Color infoSoft       = Color(0xFFDDEBF7);

  // Neutrals
  static const Color background     = Color(0xFFF3F5F2);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceMuted   = Color(0xFFECEFEA);
  static const Color line           = Color(0xFFE3E8E2);
  static const Color textPrimary    = Color(0xFF1C2624);
  static const Color textSecondary  = Color(0xFF5C6B67);
  static const Color textFaint      = Color(0xFF8E9B96);

  // Risk scale
  static const Color riskLow        = Color(0xFF3FA772);
  static const Color riskModerate   = Color(0xFFE0A527);
  static const Color riskHigh       = Color(0xFFE0604F);

  static Color riskColor(double probability) {
    if (probability < 0.34) return riskLow;
    if (probability < 0.67) return riskModerate;
    return riskHigh;
  }

  // Aurora palette (hero headers, splash, auth)
  static const Color ink   = Color(0xFF071E1D);
  static const Color deep  = Color(0xFF0A2F2D);
  static const Color teal  = Color(0xFF12706A);
  static const Color mint  = Color(0xFF6FD3C0);
  static const Color coral = Color(0xFFFF8A73);

  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF071E1D), Color(0xFF0E4A46), Color(0xFF16867D)],
  );

  static const LinearGradient emergencyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3A0D0A), Color(0xFF7A1F17), Color(0xFFB8382B)],
  );

  /// Layered, colour-tinted shadow used by cards.
  static List<BoxShadow> softShadow([Color? tint]) => [
        BoxShadow(color: (tint ?? const Color(0xFF0B3B38)).withOpacity(0.10), blurRadius: 28, offset: const Offset(0, 12)),
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
      ];

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F6F6B), Color(0xFF16504D), Color(0xFF0D3634)],
  );

  static const LinearGradient sunGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF2A65A), Color(0xFFE0824A)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE97A63), Color(0xFFC24A3D)],
  );

  static LinearGradient cardTint(Color base) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base.withOpacity(0.16), base.withOpacity(0.04)],
      );
}
