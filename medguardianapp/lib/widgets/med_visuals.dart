import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';

/// Medicine "face": the pack photo when there is one, otherwise a glossy
/// gradient tile with the medicine's icon. Optional local [bytes] win over
/// [photoUrl] so pickers can preview an image before it's uploaded.
class MedThumb extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String photoUrl;
  final Uint8List? bytes;
  final double size;
  final double? radius;
  final bool shadow;

  const MedThumb({
    super.key,
    required this.color,
    required this.icon,
    this.photoUrl = '',
    this.bytes,
    this.size = 56,
    this.radius,
    this.shadow = true,
  });

  factory MedThumb.of(Medication m, {Key? key, double size = 56, double? radius, bool shadow = true}) =>
      MedThumb(key: key, color: m.color, icon: m.icon, photoUrl: m.photoUrl, size: size, radius: radius, shadow: shadow);

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? size * 0.32);
    final fallback = _IconFace(color: color, icon: icon, size: size);
    Widget face;
    if (bytes != null) {
      face = Image.memory(bytes!, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (photoUrl.isNotEmpty) {
      face = Image.network(
        photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, sync) => sync
            ? child
            : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 350), curve: Curves.easeOut, child: child),
        loadingBuilder: (context, child, progress) => progress == null ? child : Stack(fit: StackFit.expand, children: [fallback, child]),
        errorBuilder: (context, error, stack) => fallback,
      );
    } else {
      face = fallback;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow ? [BoxShadow(color: color.withOpacity(0.32), blurRadius: size * 0.28, offset: Offset(0, size * 0.11))] : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(fit: StackFit.expand, children: [
          face,
          // Inner hairline for a crisp, "printed" edge on photos.
          DecoratedBox(decoration: BoxDecoration(borderRadius: r, border: Border.all(color: Colors.white.withOpacity(0.22), width: 1))),
        ]),
      ),
    );
  }
}

class _IconFace extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;
  const _IconFace({required this.color, required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, 0.15)!, Color.lerp(color, Colors.black, 0.18)!]),
      ),
      child: Stack(children: [
        // Soft glossy highlight in the top-left corner.
        Positioned(
          left: -size * 0.3,
          top: -size * 0.45,
          child: Container(
            width: size * 1.1,
            height: size * 0.9,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withOpacity(0.28), Colors.white.withOpacity(0)])),
          ),
        ),
        Center(child: Icon(icon, color: Colors.white, size: size * 0.5)),
      ]),
    );
  }
}

/// Small rounded label used on medicine cards ("Low stock", "3× daily"…).
class MedTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;
  const MedTag({super.key, required this.label, required this.color, this.icon, this.solid = false});

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: solid ? color : color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.1)),
      ]),
    );
  }
}

/// Animated, rounded stock bar with a soft glow on the filled part.
class StockBar extends StatelessWidget {
  final int stock;
  final Color color;
  final double height;
  final int full;
  const StockBar({super.key, required this.stock, required this.color, this.height = 7, this.full = 30});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (stock / full).clamp(0.03, 1.0)),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Container(
        height: height,
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(height)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.25)!, color]),
              borderRadius: BorderRadius.circular(height),
              boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whole days of supply left given how many doses are taken per day.
int? daysOfSupply(Medication m) => m.times.isEmpty ? null : (m.stock / m.times.length).floor();
