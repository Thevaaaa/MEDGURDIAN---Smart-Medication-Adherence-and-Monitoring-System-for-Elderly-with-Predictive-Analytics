import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Smooth line chart with a soft gradient fill — used for the 24-hour heart-rate
/// and oxygen trends read from Health Connect.
class TrendLine extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  /// Optional fixed vertical range (e.g. 88–100 for oxygen). Auto-scaled when null.
  final double? minY;
  final double? maxY;

  const TrendLine({super.key, required this.values, required this.color, this.height = 110, this.minY, this.maxY});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(values.length),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _TrendPainter(values, color, minY, maxY, t)),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  final double? minY;
  final double? maxY;
  final double progress;
  _TrendPainter(this.v, this.color, this.minY, this.maxY, this.progress);

  @override
  void paint(Canvas canvas, Size s) {
    if (v.isEmpty) return;
    const padX = 8.0, padY = 12.0;
    var lo = minY ?? v.reduce(min);
    var hi = maxY ?? v.reduce(max);
    if (hi - lo < 1) {
      hi += 1;
      lo -= 1;
    } else if (minY == null || maxY == null) {
      final m = (hi - lo) * 0.18;
      if (minY == null) lo -= m;
      if (maxY == null) hi += m;
    }
    final w = s.width - padX * 2;
    final h = s.height - padY * 2;
    Offset pt(int i) {
      final x = padX + (v.length == 1 ? w / 2 : w * i / (v.length - 1));
      final y = padY + h * (1 - ((v[i] - lo) / (hi - lo)).clamp(0.0, 1.0)) * progress + h * (1 - progress);
      return Offset(x, y);
    }

    final grid = Paint()
      ..color = color.withOpacity(0.10)
      ..strokeWidth = 1;
    for (var g = 0; g < 3; g++) {
      final y = padY + h * g / 2;
      canvas.drawLine(Offset(0, y), Offset(s.width, y), grid);
    }

    if (v.length >= 2) {
      final path = Path()..moveTo(pt(0).dx, pt(0).dy);
      for (var i = 1; i < v.length; i++) {
        final p0 = pt(i - 1);
        final p1 = pt(i);
        path.quadraticBezierTo(p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      }
      path.lineTo(pt(v.length - 1).dx, pt(v.length - 1).dy);

      final fill = Path.from(path)
        ..lineTo(pt(v.length - 1).dx, s.height)
        ..lineTo(pt(0).dx, s.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withOpacity(0.28), color.withOpacity(0.0)],
          ).createShader(Offset.zero & s),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final last = pt(v.length - 1);
    canvas.drawCircle(last, 7, Paint()..color = color.withOpacity(0.18));
    canvas.drawCircle(last, 4.6, Paint()..color = Colors.white);
    canvas.drawCircle(
      last,
      4.6,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.v != v || old.color != color || old.progress != progress;
}

/// Animated bar chart (e.g. steps for the last 7 days). The last bar is highlighted.
class MiniBars extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;

  const MiniBars({super.key, required this.values, required this.labels, required this.color, this.height = 130});

  static String _short(double v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : '${v.round()}';

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1.0 : max(values.reduce(max), 1.0);
    const reserved = 40.0; // value label + day label
    final barMax = height - reserved;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_short(values[i]), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: i == values.length - 1 ? AppColors.textPrimary : AppColors.textFaint)),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: values[i] / maxV),
                    duration: Duration(milliseconds: 600 + i * 70),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, __) => Container(
                      height: 3 + (barMax - 3) * t,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: i == values.length - 1 ? color : color.withOpacity(0.32),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(i < labels.length ? labels[i] : '', style: TextStyle(fontSize: 11, fontWeight: i == values.length - 1 ? FontWeight.w800 : FontWeight.w600, color: AppColors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
