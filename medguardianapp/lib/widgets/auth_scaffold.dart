import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';

Widget chipIcon(IconData icon, Color color) {
  return Padding(
    padding: const EdgeInsets.all(11),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
      child: Icon(icon, color: color, size: 18),
    ),
  );
}

/// A drifting, translucent icon used purely as header decoration.
class _DecorIcon extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;
  final double size;
  final double opacity;
  final double amplitude;
  const _DecorIcon({required this.alignment, required this.icon, this.size = 26, this.opacity = 0.14, this.amplitude = 7});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Floating(
          amplitude: amplitude,
          child: Opacity(opacity: opacity, child: Icon(icon, color: Colors.white, size: size)),
        ),
      ),
    );
  }
}

/// Text field styled with a colour-chip leading icon and a smooth focus glow.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final Color iconColor;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? maxLength;
  final VoidCallback? onSubmitted;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.maxLength,
    this.onSubmitted,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: _focused ? [BoxShadow(color: widget.iconColor.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 6))] : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        textCapitalization: widget.textCapitalization,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        onSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          counterText: '',
          prefixIcon: chipIcon(widget.icon, widget.iconColor),
          suffixIcon: widget.suffix,
        ),
      ),
    );
  }
}

/// Lightweight visual strength meter for a password field — purely a UI cue,
/// not a policy: Firebase Auth still enforces the real 6-character minimum.
class PasswordStrengthBar extends StatelessWidget {
  final String password;
  const PasswordStrengthBar({super.key, required this.password});

  int get _score {
    if (password.isEmpty) return 0;
    var s = 0;
    if (password.length >= 6) s++;
    if (password.length >= 10) s++;
    if (RegExp(r'[0-9]').hasMatch(password) && RegExp(r'[A-Za-z]').hasMatch(password)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) s++;
    return s.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    const labels = ['Too short', 'Weak', 'Okay', 'Good', 'Strong'];
    const colors = [AppColors.danger, AppColors.danger, AppColors.warning, AppColors.success, AppColors.success];
    final score = _score;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        ...List.generate(4, (i) {
          final on = i < score;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == 3 ? 0 : 5),
              height: 5,
              decoration: BoxDecoration(color: on ? colors[score] : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(3)),
            ),
          );
        }),
        const SizedBox(width: 10),
        Text(labels[score], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: score == 0 ? AppColors.textFaint : colors[score])),
      ]),
    );
  }
}

/// Shared frame for sign-in / sign-up / link screens: animated aurora header
/// with drifting decorative icons and a soft-glow logo, and a rounded white
/// sheet that rises from below.
class AuthScaffold extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  final double headerHeight;
  final List<IconData> decorIcons;

  const AuthScaffold({
    super.key,
    this.eyebrow = '',
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.headerHeight = 284,
    this.decorIcons = const [Icons.favorite_rounded, Icons.medication_rounded, Icons.shield_rounded, Icons.event_available_rounded],
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: AuroraBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // The header has a fixed height, so cap the text scale here —
                // otherwise a large system font size overflows it.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.15,
                  child: SizedBox(
                  height: headerHeight,
                  child: Stack(
                    children: [
                      if (decorIcons.isNotEmpty) _DecorIcon(alignment: const Alignment(-0.86, -0.45), icon: decorIcons[0], size: 24, amplitude: 6),
                      if (decorIcons.length > 1) _DecorIcon(alignment: const Alignment(0.92, -0.7), icon: decorIcons[1], size: 30, amplitude: 8),
                      if (decorIcons.length > 2) _DecorIcon(alignment: const Alignment(0.8, 0.55), icon: decorIcons[2], size: 22, opacity: 0.12, amplitude: 5),
                      if (decorIcons.length > 3) _DecorIcon(alignment: const Alignment(-0.9, 0.75), icon: decorIcons[3], size: 26, opacity: 0.1, amplitude: 7),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 44,
                              child: Row(children: [
                                if (showBack)
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => Navigator.of(context).maybePop(),
                                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                  )
                                else
                                  const SizedBox(width: 4),
                                const Spacer(),
                              ]),
                            ),
                            const Spacer(),
                            FadeSlideIn(
                              child: SizedBox(
                                width: 76,
                                height: 76,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 76,
                                      height: 76,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(colors: [AppColors.mint.withOpacity(0.45), AppColors.mint.withOpacity(0)]),
                                      ),
                                    ),
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.32), Colors.white.withOpacity(0.1)]),
                                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 8))],
                                      ),
                                      child: const Icon(Icons.shield_moon_rounded, color: Colors.white, size: 29),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (eyebrow.isNotEmpty)
                              FadeSlideIn(
                                delayMs: 60,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                                  child: Text(eyebrow.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 1.1)),
                                ),
                              ),
                            if (eyebrow.isNotEmpty) const SizedBox(height: 10),
                            FadeSlideIn(delayMs: 90, child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8))),
                            const SizedBox(height: 4),
                            FadeSlideIn(delayMs: 160, child: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.3))),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                Expanded(
                  child: FadeSlideIn(
                    beginOffset: const Offset(0, 0.12),
                    duration: const Duration(milliseconds: 750),
                    delayMs: 120,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, -8))],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(24, 14, 24, MediaQuery.of(context).viewInsets.bottom + 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 22), decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3))),
                              ),
                              child,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error banner used by the auth forms.
class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: 0.96 + 0.04 * v, child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.danger.withOpacity(0.25))),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 19),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
      ),
    );
  }
}
