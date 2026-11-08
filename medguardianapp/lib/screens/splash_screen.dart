import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_animations.dart';
import 'auth/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  static const _title = 'MedGuardian';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) Navigator.of(context).pushReplacement(slideFadeRoute(const AuthGate()));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoScale = CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.45, curve: Curves.elasticOut));
    final logoFade = CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.2, curve: Curves.easeOut));
    final tagFade = CurvedAnimation(parent: _c, curve: const Interval(0.62, 0.85, curve: Curves.easeOut));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: AuroraBackground(
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: logoFade,
                  child: ScaleTransition(
                    scale: logoScale,
                    child: PulseRings(
                      color: AppColors.mint,
                      size: 190,
                      rings: 3,
                      child: Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.28), Colors.white.withOpacity(0.08)]),
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                          boxShadow: [BoxShadow(color: AppColors.mint.withOpacity(0.35), blurRadius: 40, spreadRadius: 2)],
                        ),
                        child: const Icon(Icons.shield_moon_rounded, color: Colors.white, size: 56),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                // Letter-by-letter reveal
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_title.length, (i) {
                      final start = 0.30 + i * 0.035;
                      final t = ((_c.value - start) / 0.16).clamp(0.0, 1.0);
                      final e = Curves.easeOutCubic.transform(t);
                      return Opacity(
                        opacity: e,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - e)),
                          child: Text(_title[i], style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: tagFade,
                  child: const Text('Care that never misses a beat', style: TextStyle(color: Colors.white70, fontSize: 14.5, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                ),
                const SizedBox(height: 54),
                FadeTransition(
                  opacity: tagFade,
                  child: Shimmer(
                    child: Container(width: 120, height: 5, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
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
