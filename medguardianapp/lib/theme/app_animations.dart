import 'dart:math';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Motion toolkit for MedGuardian. Everything is pure Flutter (no packages).
/// ─────────────────────────────────────────────────────────────────────────

/// Fades + slides a child in on mount (staggered entrances).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Offset beginOffset;
  final Duration duration;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.beginOffset = const Offset(0, 0.08),
    this.duration = const Duration(milliseconds: 560),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
  }
}

List<Widget> staggered(List<Widget> children, {int stepMs = 70, int startMs = 0}) {
  return [for (int i = 0; i < children.length; i++) FadeSlideIn(delayMs: startMs + i * stepMs, child: children[i])];
}

/// Tactile press-scale wrapper.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleTo;

  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scaleTo = 0.96});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  double _scale = 1;
  void _set(double v) => setState(() => _scale = v);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(widget.scaleTo),
      onTapCancel: () => _set(1),
      onTapUp: (_) => _set(1),
      child: AnimatedScale(scale: _scale, duration: const Duration(milliseconds: 120), curve: Curves.easeOut, child: widget.child),
    );
  }
}

/// Expanding, fading concentric rings behind a child.
class PulseRings extends StatefulWidget {
  final Color color;
  final double size;
  final Widget child;
  final bool active;
  final int rings;

  const PulseRings({super.key, required this.child, this.color = Colors.red, this.size = 160, this.active = true, this.rings = 2});

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: List.generate(widget.rings, (i) {
                  final t = (_c.value + i / widget.rings) % 1.0;
                  return Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0) * 0.4,
                    child: Container(
                      width: widget.size * (0.5 + t * 0.5),
                      height: widget.size * (0.5 + t * 0.5),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color, width: 2), color: widget.color.withOpacity(0.15)),
                    ),
                  );
                }),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

/// Small breathing "live" dot.
class LiveDot extends StatefulWidget {
  final Color color;
  final double size;
  const LiveDot({super.key, this.color = Colors.green, this.size = 8});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [BoxShadow(color: widget.color.withOpacity(0.55 * _c.value + 0.15), blurRadius: 6 + 6 * _c.value, spreadRadius: 1 + _c.value)],
        ),
      ),
    );
  }
}

/// Gentle scale "breathing" loop.
class Breathing extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;
  const Breathing({super.key, required this.child, this.minScale = 0.97, this.maxScale = 1.04, this.duration = const Duration(milliseconds: 1600)});

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(scale: widget.minScale + (widget.maxScale - widget.minScale) * Curves.easeInOut.transform(_c.value), child: child),
      child: widget.child,
    );
  }
}

/// Gentle vertical bobbing loop.
class Floating extends StatefulWidget {
  final Widget child;
  final double amplitude;
  const Floating({super.key, required this.child, this.amplitude = 6});

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(offset: Offset(0, -widget.amplitude * Curves.easeInOut.transform(_c.value)), child: child),
      child: widget.child,
    );
  }
}

/// Premium page transition: fade + rise + slight scale.
Route<T> slideFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(curved),
          child: ScaleTransition(scale: Tween<double>(begin: 0.985, end: 1).animate(curved), child: child),
        ),
      );
    },
  );
}

/// Count-up number.
class AnimatedNumber extends StatelessWidget {
  final double begin;
  final double end;
  final Duration duration;
  final String Function(double) builder;
  final TextStyle? style;

  const AnimatedNumber({super.key, this.begin = 0, required this.end, this.duration = const Duration(milliseconds: 1000), required this.builder, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(builder(value), style: style),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Aurora background — slowly drifting gradient blobs
// ═════════════════════════════════════════════════════════════════════════

class AuroraBackground extends StatefulWidget {
  final Widget child;
  final Gradient base;
  final List<Color> blobs;

  const AuroraBackground({
    super.key,
    required this.child,
    this.base = AppColors.auroraGradient,
    this.blobs = const [AppColors.mint, AppColors.accent, Color(0xFF3E7CB1)],
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: widget.base),
      child: Stack(
        children: [
          Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _AuroraPainter(_c, widget.blobs)))),
          widget.child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> t;
  final List<Color> colors;
  _AuroraPainter(this.t, this.colors) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final a = t.value * 2 * pi;
    final centers = [
      Offset(size.width * (0.15 + 0.10 * sin(a)), size.height * (0.10 + 0.12 * cos(a))),
      Offset(size.width * (0.90 + 0.06 * cos(a + 1)), size.height * (0.30 + 0.14 * sin(a + 2))),
      Offset(size.width * (0.55 + 0.14 * sin(a + 3)), size.height * (0.95 + 0.06 * cos(a + 1))),
    ];
    final radii = [size.shortestSide * 0.85, size.shortestSide * 0.70, size.shortestSide * 0.80];
    final opacities = [0.34, 0.22, 0.26];
    for (var i = 0; i < 3; i++) {
      final color = colors[i % colors.length].withOpacity(opacities[i]);
      final paint = Paint()
        ..shader = RadialGradient(colors: [color, color.withOpacity(0)]).createShader(Rect.fromCircle(center: centers[i], radius: radii[i]));
      canvas.drawCircle(centers[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => false;
}

// ═════════════════════════════════════════════════════════════════════════
// Shimmer
// ═════════════════════════════════════════════════════════════════════════

class Shimmer extends StatefulWidget {
  final Widget child;
  final Color base;
  final Color highlight;
  const Shimmer({super.key, required this.child, this.base = const Color(0x33FFFFFF), this.highlight = const Color(0xCCFFFFFF)});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final dx = -1.5 + 3.0 * _c.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(dx - 1, 0),
            end: Alignment(dx + 1, 0),
            colors: [widget.base, widget.highlight, widget.base],
            stops: const [0.25, 0.5, 0.75],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Drawn check-mark (circle draws, then the tick)
// ═════════════════════════════════════════════════════════════════════════

class DrawCheck extends StatefulWidget {
  final double size;
  final Color color;
  final double strokeWidth;
  final bool withCircle;
  final Duration duration;

  const DrawCheck({super.key, this.size = 72, this.color = AppColors.success, this.strokeWidth = 5, this.withCircle = true, this.duration = const Duration(milliseconds: 900)});

  @override
  State<DrawCheck> createState() => _DrawCheckState();
}

class _DrawCheckState extends State<DrawCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _CheckPainter(_c.value, widget.color, widget.strokeWidth, widget.withCircle)),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double t;
  final Color color;
  final double stroke;
  final bool circle;
  _CheckPainter(this.t, this.color, this.stroke, this.circle);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (circle) {
      final ct = Curves.easeOutCubic.transform((t / 0.6).clamp(0.0, 1.0));
      canvas.drawArc(Rect.fromLTWH(stroke, stroke, size.width - stroke * 2, size.height - stroke * 2), -pi / 2, 2 * pi * ct, false, paint..color = color.withOpacity(0.35));
      paint.color = color;
    }

    final tt = Curves.easeOutCubic.transform(((t - (circle ? 0.45 : 0)) / (circle ? 0.55 : 1)).clamp(0.0, 1.0));
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.45, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.34);
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * tt), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.t != t;
}

// ═════════════════════════════════════════════════════════════════════════
// Confetti burst (one-shot overlay)
// ═════════════════════════════════════════════════════════════════════════

void showConfetti(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _ConfettiOverlay(onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _ConfettiOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiOverlay({required this.onDone});

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
    ..forward().whenComplete(widget.onDone);
  final _rand = Random(7);
  late final List<_Particle> _ps = List.generate(70, (_) => _Particle(_rand));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_ps, _c.value)),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double spin;
  final double size;
  final Color color;
  _Particle(Random r)
      : angle = -pi / 2 + (r.nextDouble() - 0.5) * 1.5,
        speed = 380 + r.nextDouble() * 520,
        spin = (r.nextDouble() - 0.5) * 14,
        size = 6 + r.nextDouble() * 7,
        color = const [AppColors.mint, AppColors.accent, AppColors.coral, Color(0xFF7FB2FF), Colors.white, AppColors.success][r.nextInt(6)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> ps;
  final double t;
  _ConfettiPainter(this.ps, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    final secs = t * 2.2;
    for (final p in ps) {
      final dx = cos(p.angle) * p.speed * secs;
      final dy = sin(p.angle) * p.speed * secs + 0.5 * 900 * secs * secs;
      final pos = origin + Offset(dx, dy);
      final opacity = (1 - Curves.easeIn.transform(((t - 0.6) / 0.4).clamp(0.0, 1.0)));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * secs);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), const Radius.circular(2)),
        Paint()..color = p.color.withOpacity(opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

// ═════════════════════════════════════════════════════════════════════════
// ECG heartbeat line
// ═════════════════════════════════════════════════════════════════════════

class EcgLine extends StatefulWidget {
  final int bpm;
  final Color color;
  final double height;
  const EcgLine({super.key, required this.bpm, this.color = AppColors.danger, this.height = 54});

  @override
  State<EcgLine> createState() => _EcgLineState();
}

class _EcgLineState extends State<EcgLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cps = (widget.bpm.clamp(30, 200)) / 60.0; // beats per second
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(child: CustomPaint(painter: _EcgPainter(_c, widget.color, cps))),
    );
  }
}

class _EcgPainter extends CustomPainter {
  final Animation<double> t;
  final Color color;
  final double cps;
  _EcgPainter(this.t, this.color, this.cps) : super(repaint: t);

  // One PQRST cycle, p in [0,1) → y in [-1,1] (up is negative on canvas).
  double _y(double p) {
    double bump(double c, double w, double h) => h * exp(-pow((p - c) / w, 2).toDouble());
    return bump(0.14, 0.035, 0.18) - bump(0.27, 0.010, 0.20) + bump(0.30, 0.012, 1.0) - bump(0.335, 0.012, 0.32) + bump(0.58, 0.05, 0.28);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const cycles = 2.0; // visible beats
    final phase = t.value * cps; // scroll speed follows the heart rate
    final path = Path();
    final mid = size.height * 0.58;
    for (double x = 0; x <= size.width; x += 2) {
      final p = ((x / size.width) * cycles - phase) % 1.0;
      final y = mid - _y(p < 0 ? p + 1 : p) * size.height * 0.5;
      x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(colors: [color.withOpacity(0), color, color]).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _EcgPainter old) => old.color != color || old.cps != cps;
}
