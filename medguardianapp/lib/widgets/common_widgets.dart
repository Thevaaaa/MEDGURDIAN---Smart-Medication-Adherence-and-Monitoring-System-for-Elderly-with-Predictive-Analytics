import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_animations.dart';
import '../utils/formatters.dart';
import 'med_visuals.dart';


class PageShell extends StatelessWidget {
  final Widget child;
  const PageShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark),
      child: Stack(
        children: [
          child,
          Positioned(top: 0, left: 0, right: 0, height: MediaQuery.of(context).padding.top, child: const ColoredBox(color: AppColors.ink)),
        ],
      ),
    );
  }
}

/// Dark aurora header with rounded bottom corners.
class HeroHeader extends StatelessWidget {
  final Widget child;
  final double bottomRadius;
  final EdgeInsets padding;

  const HeroHeader({super.key, required this.child, this.bottomRadius = 36, this.padding = const EdgeInsets.fromLTRB(22, 14, 22, 26)});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
      child: AuroraBackground(
        child: Padding(padding: padding.copyWith(top: padding.top + top), child: child),
      ),
    );
  }
}

/// Content column that sits under a hero header.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final double top;
  const PageBody({super.key, required this.children, this.top = 22});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top, 20, 130),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Cards
// ═════════════════════════════════════════════════════════════════════════

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;
  final Color? shadowTint;

  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.gradient, this.color, this.onTap, this.radius = 24, this.shadowTint});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
        boxShadow: AppColors.softShadow(shadowTint),
      ),
      child: child,
    );
    return onTap == null ? content : Pressable(onTap: onTap, child: content);
  }
}

/// Frosted-glass card for use over dark / colourful backgrounds.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final VoidCallback? onTap;

  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.radius = 26, this.opacity = 0.13, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: child,
        ),
      ),
    );
    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.textPrimary))),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Tinted stat tile: icon badge, big value, small label.
class StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatPill({super.key, required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.softShadow(color),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.22), color.withOpacity(0.08)]), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 12),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.textPrimary))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textFaint)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
      child: Center(
        child: Column(
          children: [
            Floating(
              amplitude: 5,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary.withOpacity(0.14), AppColors.mint.withOpacity(0.10)]),
                ),
                child: Icon(icon, size: 32, color: AppColors.primary.withOpacity(0.75)),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textFaint, fontSize: 13, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double radius;
  final bool ring;
  final String? photoUrl;

  const InitialsAvatar({super.key, required this.name, required this.color, this.radius = 22, this.ring = false, this.photoUrl});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, min(2, parts.first.length)).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.30), color.withOpacity(0.12)]),
      ),
      child: (photoUrl == null || photoUrl!.isEmpty)
          ? Center(child: Text(_initials, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: radius * 0.66)))
          : ClipOval(
              child: Image.network(
                photoUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Center(child: Text(_initials, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: radius * 0.66))),
                errorBuilder: (context, error, stack) => Center(child: Text(_initials, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: radius * 0.66))),
              ),
            ),
    );
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.mint, AppColors.accent])),
      child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: avatar),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Buttons
// ═════════════════════════════════════════════════════════════════════════

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Gradient gradient;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.gradient = AppColors.heroGradient,
    this.height = 58,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Pressable(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onPressed == null ? 0.5 : 1,
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.32), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: loading
                  ? const SizedBox(key: ValueKey('l'), width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                  : Row(
                      key: const ValueKey('t'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[Icon(icon, color: Colors.white, size: 21), const SizedBox(width: 10)],
                        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated pill tab switcher bound to a [TabController].
class SegmentedTabs extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  final bool onDark;

  const SegmentedTabs({super.key, required this.controller, required this.labels, this.onDark = true});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final itemW = box.maxWidth / labels.length;
      return AnimatedBuilder(
        animation: controller.animation!,
        builder: (context, _) {
          final v = controller.animation!.value;
          return Container(
            height: 48,
            decoration: BoxDecoration(color: onDark ? Colors.white.withOpacity(0.13) : AppColors.surfaceMuted, borderRadius: BorderRadius.circular(24)),
            child: Stack(
              children: [
                Positioned(
                  left: v * itemW + 4,
                  top: 4,
                  bottom: 4,
                  width: itemW - 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: onDark ? Colors.white : AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                  ),
                ),
                Row(
                  children: List.generate(labels.length, (i) {
                    final t = (1 - (v - i).abs()).clamp(0.0, 1.0);
                    final selectedColor = onDark ? AppColors.deep : Colors.white;
                    final idleColor = onDark ? Colors.white.withOpacity(0.78) : AppColors.textSecondary;
                    return SizedBox(
                      width: itemW,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => controller.animateTo(i),
                        child: Center(child: Text(labels[i], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color.lerp(idleColor, selectedColor, t)))),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Data viz: risk gauge, adherence ring, weekly bars
// ═════════════════════════════════════════════════════════════════════════

class RiskGauge extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final Color color;
  final String centerLabel;
  final String subLabel;
  final bool onDark;

  const RiskGauge({super.key, required this.value, required this.centerLabel, required this.subLabel, this.size = 168, required this.color, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _GaugePainter(value: animated, color: color, onDark: onDark),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(centerLabel, style: TextStyle(fontSize: size * 0.21, fontWeight: FontWeight.w800, letterSpacing: -1, color: onDark ? Colors.white : AppColors.textPrimary)),
                Text(subLabel, style: TextStyle(fontSize: size * 0.075, fontWeight: FontWeight.w700, color: onDark ? Colors.white70 : AppColors.textFaint)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final bool onDark;
  _GaugePainter({required this.value, required this.color, required this.onDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 16;
    const start = -pi * 1.25;
    const sweep = pi * 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // tick marks
    for (int i = 0; i <= 30; i++) {
      final a = start + sweep * i / 30;
      final active = i / 30 <= value;
      final r1 = radius + 10;
      final r2 = radius + (i % 5 == 0 ? 3 : 6);
      canvas.drawLine(
        center + Offset(cos(a), sin(a)) * r1,
        center + Offset(cos(a), sin(a)) * r2,
        Paint()
          ..color = active ? color.withOpacity(0.9) : (onDark ? Colors.white24 : AppColors.line)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawArc(rect, start, sweep, false, Paint()
      ..color = onDark ? Colors.white.withOpacity(0.12) : AppColors.surfaceMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round);

    if (value > 0.001) {
      // glow
      canvas.drawArc(rect, start, sweep * value, false, Paint()
        ..color = color.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      canvas.drawArc(rect, start, sweep * value, false, Paint()
        ..shader = SweepGradient(startAngle: 0, endAngle: sweep, colors: [color.withOpacity(0.55), color], transform: const GradientRotation(start)).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round);

      final a = start + sweep * value;
      final dot = center + Offset(cos(a), sin(a)) * radius;
      canvas.drawCircle(dot, 9, Paint()..color = Colors.white);
      canvas.drawCircle(dot, 9, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.4);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value || old.color != color || old.onDark != onDark;
}

class AdherenceRing extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final bool onDark;
  final Widget? center;
  const AdherenceRing({super.key, required this.value, this.size = 92, this.onDark = false, this.center});

  @override
  Widget build(BuildContext context) {
    final color = value >= 0.8 ? AppColors.success : (value >= 0.5 ? AppColors.warning : AppColors.danger);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, color, onDark),
          child: Center(
            child: center ??
                Text('${(v * 100).round()}%', style: TextStyle(fontSize: size * 0.24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: onDark ? Colors.white : AppColors.textPrimary)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  final bool onDark;
  _RingPainter(this.v, this.color, this.onDark);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.115;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(rect, 0, 2 * pi, false, Paint()
      ..color = onDark ? Colors.white.withOpacity(0.14) : AppColors.surfaceMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    if (v > 0) {
      canvas.drawArc(rect, -pi / 2, 2 * pi * v, false, Paint()
        ..shader = SweepGradient(startAngle: -pi / 2, endAngle: 3 * pi / 2, colors: [color.withOpacity(0.5), color], transform: const GradientRotation(-pi / 2)).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v || old.color != color;
}

class WeeklyBars extends StatelessWidget {
  final List<double> values; // 0..1, oldest first
  final List<String> labels;
  const WeeklyBars({super.key, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final raw = values[i];
          final v = raw.clamp(0.04, 1.0);
          final color = raw >= 0.8 ? AppColors.success : (raw >= 0.5 ? AppColors.warning : AppColors.danger);
          final isToday = i == values.length - 1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(raw <= 0.03 ? '' : '${(raw * 100).round()}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textFaint)),
                  const SizedBox(height: 3),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: v),
                        duration: Duration(milliseconds: 750 + i * 90),
                        curve: Curves.easeOutBack,
                        builder: (context, val, _) => FractionallySizedBox(
                          heightFactor: val.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withOpacity(0.55)]),
                              boxShadow: isToday ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))] : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(labels[i], style: TextStyle(fontSize: 11, color: isToday ? AppColors.primary : AppColors.textFaint, fontWeight: isToday ? FontWeight.w800 : FontWeight.w700)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Alerts
// ═════════════════════════════════════════════════════════════════════════

Color severityColor(AlertSeverity s) {
  switch (s) {
    case AlertSeverity.info:
      return AppColors.info;
    case AlertSeverity.warning:
      return AppColors.warning;
    case AlertSeverity.critical:
      return AppColors.danger;
  }
}

class AlertTile extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback? onAck;

  /// Phone of the person the alert is about. For urgent alerts a "Call"
  /// button appears *before* Acknowledge — reach them first.
  final String? phone;
  final String? personName;

  const AlertTile({super.key, required this.alert, this.onAck, this.phone, this.personName});

  String get _severityLabel => switch (alert.severity) {
        AlertSeverity.critical => 'URGENT',
        AlertSeverity.warning => 'WARNING',
        AlertSeverity.info => 'INFO',
      };

  @override
  Widget build(BuildContext context) {
    final c = severityColor(alert.severity);
    final ack = alert.acknowledged;
    final urgent = !ack && alert.severity == AlertSeverity.critical;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: ack ? const Color(0xFFF9FAF8) : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ack ? AppColors.line : c.withOpacity(urgent ? 0.45 : 0.25), width: urgent ? 1.5 : 1),
        boxShadow: ack ? null : AppColors.softShadow(c),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          if (!ack)
            Positioned(
              right: -50,
              top: -70,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withOpacity(0.10), c.withOpacity(0)])),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: ack ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(c, Colors.white, 0.12)!, Color.lerp(c, Colors.black, 0.08)!]),
                    color: ack ? c.withOpacity(0.10) : null,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: ack ? null : [BoxShadow(color: c.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
                  ),
                  child: Icon(alert.icon, color: ack ? c : Colors.white, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(color: c.withOpacity(ack ? 0.08 : 0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(_severityLabel, style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
                        const Spacer(),
                        if (!ack) ...[LiveDot(color: c, size: 7), const SizedBox(width: 6)],
                        Text(Fmt.timeAgo(alert.time), style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 7),
                      Text(alert.title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, letterSpacing: -0.2, color: ack ? AppColors.textSecondary : AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Text(alert.message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                      if (alert.hasLocation || ack || onAck != null) const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        if (urgent && (phone ?? '').isNotEmpty)
                          Pressable(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              launchUrl(Uri(scheme: 'tel', path: phone));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF4CC38A), Color(0xFF2E9461)]),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.call_rounded, size: 15, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  (personName ?? '').trim().isEmpty ? 'Call now' : 'Call ${personName!.trim().split(' ').first}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ]),
                            ),
                          ),
                        if (!ack && onAck != null)
                          Pressable(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onAck!();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: urgent && (phone ?? '').isNotEmpty ? c.withOpacity(0.10) : c,
                                borderRadius: BorderRadius.circular(14),
                                border: urgent && (phone ?? '').isNotEmpty ? Border.all(color: c.withOpacity(0.35)) : null,
                                boxShadow: urgent && (phone ?? '').isNotEmpty ? null : [BoxShadow(color: c.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.check_rounded, size: 15, color: urgent && (phone ?? '').isNotEmpty ? c : Colors.white),
                                const SizedBox(width: 6),
                                Text('Acknowledge', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: urgent && (phone ?? '').isNotEmpty ? c : Colors.white)),
                              ]),
                            ),
                          ),
                        if (alert.hasLocation)
                          Pressable(
                            onTap: () => launchUrl(Uri.parse(alert.mapsUrl), mode: LaunchMode.externalApplication),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                              decoration: BoxDecoration(color: AppColors.info.withOpacity(0.09), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.info.withOpacity(0.2))),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.map_rounded, size: 15, color: AppColors.info),
                                SizedBox(width: 6),
                                Text('View on map', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.info)),
                              ]),
                            ),
                          ),
                        if (ack)
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 15),
                            SizedBox(width: 5),
                            Text('Acknowledged', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w800)),
                          ]),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );

    Widget result = urgent ? Breathing(minScale: 0.995, maxScale: 1.008, child: card) : card;
    if (!ack && onAck != null) {
      result = Dismissible(
        key: ValueKey('alert-${alert.id}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          HapticFeedback.mediumImpact();
          onAck!();
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.success.withOpacity(0.22), AppColors.success.withOpacity(0.04)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 6),
            Text('Acknowledge', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800)),
          ]),
        ),
        child: result,
      );
    }
    return result;
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Medication dose tile (buttons + swipe gestures)
// ═════════════════════════════════════════════════════════════════════════

/// A slim ring around a medication photo / icon that fills up as the dose
/// approaches (and passes) its scheduled time — purely a visual cue, not a
/// precise timer. Turns amber close to due, red once overdue, and green/red
/// once acted on.
class DoseCountdownRing extends StatelessWidget {
  final DateTime scheduledTime;
  final bool done;
  final bool taken;
  final Color color;
  final IconData icon;
  final double size;
  final bool onDark;
  final String photoUrl;

  const DoseCountdownRing({
    super.key,
    required this.scheduledTime,
    required this.done,
    required this.taken,
    required this.color,
    required this.icon,
    this.size = 56,
    this.onDark = false,
    this.photoUrl = '',
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdue = !done && now.isAfter(scheduledTime);

    double progress;
    Color ringColor;
    if (done) {
      progress = 1;
      ringColor = taken ? AppColors.success : AppColors.danger;
    } else {
      final windowStart = scheduledTime.subtract(const Duration(hours: 2));
      final totalSecs = scheduledTime.difference(windowStart).inSeconds;
      final elapsedSecs = now.difference(windowStart).inSeconds;
      progress = totalSecs <= 0 ? 0.0 : (elapsedSecs / totalSecs).clamp(0.0, 1.0);
      ringColor = overdue ? AppColors.danger : (onDark ? Colors.white : (progress > 0.85 ? AppColors.warning : color));
    }

    final trackColor = onDark ? Colors.white.withOpacity(0.18) : color.withOpacity(0.14);
    final inner = size - 12;

    Widget face;
    if (photoUrl.isNotEmpty) {
      face = MedThumb(color: color, icon: icon, photoUrl: photoUrl, size: inner, radius: inner / 2, shadow: false);
    } else if (onDark) {
      face = Container(
        width: inner,
        height: inner,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: inner * 0.5),
      );
    } else {
      face = MedThumb(color: color, icon: icon, size: inner, radius: inner / 2, shadow: !done);
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => CustomPaint(size: Size(size, size), painter: _DoseRingPainter(progress: v, trackColor: trackColor, color: ringColor)),
          ),
          AnimatedOpacity(duration: const Duration(milliseconds: 300), opacity: done ? 0.75 : 1, child: face),
          if (done)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.36,
                height: size * 0.36,
                decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle, border: Border.all(color: onDark ? AppColors.deep : Colors.white, width: 2)),
                child: Icon(taken ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: size * 0.22),
              ),
            ),
        ],
      ),
    );
  }
}

class _DoseRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color color;
  _DoseRingPainter({required this.progress, required this.trackColor, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    canvas.drawCircle(center, radius, Paint()..color = trackColor..style = PaintingStyle.stroke..strokeWidth = 3);
    if (progress > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DoseRingPainter old) => old.progress != progress || old.color != color;
}

/// Small "in 12m" / "Overdue 8m" pill shown next to a pending dose's time —
/// only surfaces within a 3-hour window so it doesn't clutter doses later in the day.
Widget? doseDueChip(DateTime scheduled) {
  final diff = scheduled.difference(DateTime.now());
  if (diff.inMinutes.abs() > 180) return null;
  final overdue = diff.isNegative;
  final mins = diff.abs().inMinutes;
  final hours = mins ~/ 60;
  final rem = mins % 60;
  final timeText = hours > 0 ? '${hours}h ${rem}m' : '${mins}m';
  final label = overdue ? 'Overdue $timeText' : (mins <= 1 ? 'Due now' : 'in $timeText');
  final c = overdue ? AppColors.danger : (mins <= 15 ? AppColors.warning : AppColors.info);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
    decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (overdue || mins <= 15) ...[LiveDot(color: c, size: 6), const SizedBox(width: 5)],
      Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
    ]),
  );
}

/// Today's-schedule dose card: photo ring, time, name and big, clear
/// Taken / Missed buttons. Swipe right for taken, left for missed.
class DoseTile extends StatefulWidget {
  final Medication medication;
  final DoseLog dose;
  final VoidCallback onTaken;
  final VoidCallback onMissed;

  const DoseTile({super.key, required this.medication, required this.dose, required this.onTaken, required this.onMissed});

  @override
  State<DoseTile> createState() => _DoseTileState();
}

class _DoseTileState extends State<DoseTile> {
  bool _justChanged = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Re-render every 20 s so the lock lifts and countdown chips stay current
    // without waiting for a data change.
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && widget.dose.status == DoseStatus.pending) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DoseTile old) {
    super.didUpdateWidget(old);
    if (old.dose.status != widget.dose.status && widget.dose.status != DoseStatus.pending) {
      setState(() => _justChanged = true);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _justChanged = false);
      });
    }
  }

  /// Records the dose — but only inside its window (15 min before → after).
  /// Taken doses get a burst of confetti; missed ones deliberately don't.
  void _act(bool taken) {
    if (!widget.dose.isOpen) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${widget.medication.name} can be taken from ${Fmt.time12(widget.dose.opensAt)} — 15 minutes before it is due.')));
      return;
    }
    if (taken) {
      HapticFeedback.mediumImpact();
      showConfetti(context);
      widget.onTaken();
    } else {
      HapticFeedback.lightImpact();
      widget.onMissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.medication;
    final dose = widget.dose;
    final done = dose.status != DoseStatus.pending;
    final locked = !done && !dose.isOpen;
    final taken = dose.status == DoseStatus.taken;
    final now = DateTime.now();
    final overdue = !done && now.isAfter(dose.scheduledTime);
    final soon = !done && !overdue && dose.scheduledTime.difference(now).inMinutes <= 15;
    final flashColor = taken ? AppColors.success : AppColors.danger;
    final chip = done ? null : doseDueChip(dose.scheduledTime);

    final Color accent = done ? (taken ? AppColors.success : AppColors.danger) : (overdue ? AppColors.danger : (soon ? AppColors.warning : m.color));

    final card = AnimatedScale(
      scale: _justChanged ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _justChanged ? Color.lerp(AppColors.surface, flashColor, 0.08) : (done ? const Color(0xFFF9FAF8) : AppColors.surface),
          borderRadius: BorderRadius.circular(24),
          boxShadow: done && !_justChanged ? null : AppColors.softShadow(_justChanged ? flashColor : accent),
          border: Border.all(
            color: _justChanged ? flashColor.withOpacity(0.5) : (done ? AppColors.line : (overdue ? AppColors.danger.withOpacity(0.35) : AppColors.line.withOpacity(0.7))),
            width: _justChanged || overdue ? 1.4 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            // Status accent bar.
            Positioned(
              left: 0,
              top: 14,
              bottom: 14,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 4,
                decoration: BoxDecoration(color: accent.withOpacity(done ? 0.5 : 1), borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Column(children: [
                Row(children: [
                  DoseCountdownRing(scheduledTime: dose.scheduledTime, done: done, taken: taken, color: m.color, icon: m.icon, photoUrl: m.photoUrl, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(
                          Fmt.time12(dose.scheduledTime),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2, color: done ? AppColors.textFaint : accent),
                        ),
                        if (chip != null) ...[const SizedBox(width: 8), Flexible(child: chip)],
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: -0.3,
                          color: done ? AppColors.textSecondary : AppColors.textPrimary,
                          decoration: taken ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.textFaint,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.instructions.isEmpty ? m.dosage : '${m.dosage} · ${m.instructions}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint),
                      ),
                    ]),
                  ),
                  if (done) ...[
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                      child: _StatusBadge(key: ValueKey(dose.status), status: dose.status),
                    ),
                  ],
                ]),
                AnimatedSize(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  child: done
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: locked
                                ? _LockedBar(key: const ValueKey('locked'), opensAt: dose.opensAt, color: m.color)
                                : Row(key: const ValueKey('open'), children: [
                                    Expanded(
                                      child: _DoseButton(label: 'Missed', icon: Icons.close_rounded, color: AppColors.danger, onTap: () => _act(false)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: _DoseButton(label: 'Taken', icon: Icons.check_rounded, color: AppColors.success, filled: true, onTap: () => _act(true)),
                                    ),
                                  ]),
                          ),
                        ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );

    // Locked doses can't be swiped either — the time frame is strict.
    if (done || locked) return card;
    return Dismissible(
      key: ValueKey('dose-${dose.id}'),
      confirmDismiss: (dir) async {
        _act(dir == DismissDirection.startToEnd);
        return false;
      },
      background: _swipeBg(true),
      secondaryBackground: _swipeBg(false),
      child: card,
    );
  }

  Widget _swipeBg(bool taken) {
    final c = taken ? AppColors.success : AppColors.danger;
    return Container(
      alignment: taken ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: taken ? Alignment.centerLeft : Alignment.centerRight,
          end: taken ? Alignment.centerRight : Alignment.centerLeft,
          colors: [c.withOpacity(0.22), c.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!taken) Text('Missed', style: TextStyle(color: c, fontWeight: FontWeight.w800)),
          if (!taken) const SizedBox(width: 6),
          Icon(taken ? Icons.check_circle_rounded : Icons.cancel_rounded, color: c),
          if (taken) const SizedBox(width: 6),
          if (taken) Text('Taken', style: TextStyle(color: c, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Shown instead of the Taken / Missed buttons until the dose window opens.
class _LockedBar extends StatelessWidget {
  final DateTime opensAt;
  final Color color;
  const _LockedBar({super.key, required this.opensAt, required this.color});

  @override
  Widget build(BuildContext context) {
    final diff = opensAt.difference(DateTime.now());
    final mins = diff.inMinutes + 1;
    final inText = mins >= 60 ? 'in ${mins ~/ 60}h ${mins % 60}m' : 'in $mins min';
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(Icons.lock_clock_rounded, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Opens at '),
              TextSpan(text: Fmt.time12(opensAt), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ),
        Text(inText, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    );
  }
}

class _DoseButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _DoseButton({required this.label, required this.icon, required this.color, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          gradient: filled ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, 0.12)!, Color.lerp(color, Colors.black, 0.1)!]) : null,
          color: filled ? null : color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(15),
          border: filled ? null : Border.all(color: color.withOpacity(0.22)),
          boxShadow: filled ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))] : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: filled ? Colors.white : color, size: 20),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: filled ? Colors.white : color, fontWeight: FontWeight.w800, fontSize: 14.5)),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DoseStatus status;
  const _StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final taken = status == DoseStatus.taken;
    final skipped = status == DoseStatus.skipped;
    final color = taken ? AppColors.success : (skipped ? AppColors.textFaint : AppColors.danger);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(color: color.withOpacity(0.11), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          taken ? DrawCheck(size: 16, color: color, strokeWidth: 2.6, withCircle: false, duration: const Duration(milliseconds: 500)) : Icon(skipped ? Icons.redo_rounded : Icons.close_rounded, color: color, size: 15),
          const SizedBox(width: 5),
          Text(taken ? 'Taken' : (skipped ? 'Skipped' : 'Missed'), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Hero top bar (title + optional back button) used inside HeroHeader
// ═════════════════════════════════════════════════════════════════════════

class HeroBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const HeroBar({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Row(
      children: [
        if (canPop) ...[
          Pressable(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.22))),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8))),
              if (subtitle != null) FadeSlideIn(delayMs: 70, child: Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 13.5))),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// Coloured severity dot / badge with a number (symptom severity 1–5).
Color severityScaleColor(int s) => s <= 2 ? AppColors.success : (s == 3 ? AppColors.warning : AppColors.danger);
