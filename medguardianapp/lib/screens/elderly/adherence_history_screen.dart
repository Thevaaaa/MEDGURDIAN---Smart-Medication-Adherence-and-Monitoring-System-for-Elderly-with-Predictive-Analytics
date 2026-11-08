import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/risk_details.dart';

class AdherenceHistoryScreen extends StatelessWidget {
  const AdherenceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final now = DateTime.now();
        final risk = data.risk;
        final rc = risk.hasData ? AppColors.riskColor(risk.probability) : AppColors.textFaint;

        double? dayRate(DateTime day) {
          final logs = data.doseLogs.where((d) => Fmt.isSameDay(d.scheduledTime, day) && d.status != DoseStatus.pending).toList();
          if (logs.isEmpty) return null;
          return logs.where((d) => d.status == DoseStatus.taken).length / logs.length;
        }

        final week = List.generate(7, (i) => dayRate(now.subtract(Duration(days: 6 - i))) ?? 0.02);
        final labels = List.generate(7, (i) => Fmt.weekdayShort(now.subtract(Duration(days: 6 - i))).substring(0, 2));
        final last21 = List.generate(21, (i) => dayRate(now.subtract(Duration(days: 20 - i))));

        final window = data.doseLogs.where((d) => d.scheduledTime.isAfter(now.subtract(const Duration(days: 30))) && d.status != DoseStatus.pending);
        final taken = window.where((d) => d.status == DoseStatus.taken).length;
        final missed = window.where((d) => d.status == DoseStatus.missed).length;

        var streak = 0;
        for (var i = 1; i <= 30; i++) {
          final r = dayRate(now.subtract(Duration(days: i)));
          if (r == null) break;
          if (r >= 0.999) {
            streak++;
          } else {
            break;
          }
        }

        final label = !risk.hasData ? 'Not enough data yet' : (risk.level == RiskLevel.low ? 'Low risk' : (risk.level == RiskLevel.moderate ? 'Moderate risk' : 'High risk'));

        return Scaffold(
          body: PageShell(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                HeroHeader(
                  child: Column(
                    children: [
                      const HeroBar(title: 'My progress', subtitle: 'How your routine is going'),
                      const SizedBox(height: 20),
                      RiskGauge(value: risk.probability, color: rc, size: 200, onDark: true, centerLabel: risk.percentLabel, subLabel: 'missed-dose risk'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(color: rc.withOpacity(0.25), borderRadius: BorderRadius.circular(20), border: Border.all(color: rc.withOpacity(0.6))),
                        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                PageBody(
                  children: staggered([
                    Row(children: [
                      Expanded(child: StatPill(icon: Icons.check_circle_rounded, label: 'Taken (30 days)', value: '$taken', color: AppColors.success)),
                      const SizedBox(width: 12),
                      Expanded(child: StatPill(icon: Icons.cancel_rounded, label: 'Missed', value: '$missed', color: AppColors.danger)),
                      const SizedBox(width: 12),
                      Expanded(child: StatPill(icon: Icons.local_fire_department_rounded, label: 'Day streak', value: '$streak', color: AppColors.accent)),
                    ]),
                    const SizedBox(height: 24),
                    SoftCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(risk.hasData ? 'Why this risk' : 'About this estimate', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ]),
                        const SizedBox(height: 12),
                        ...risk.factors.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Container(margin: const EdgeInsets.only(top: 6), width: 6, height: 6, decoration: BoxDecoration(color: rc, shape: BoxShape.circle)),
                                const SizedBox(width: 10),
                                Expanded(child: Text(f, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4))),
                              ]),
                            )),
                      ]),
                    ),
                    RiskDetails(risk: risk),
                    const SizedBox(height: 28),
                    const SectionHeader(title: 'This week', icon: Icons.bar_chart_rounded),
                    SoftCard(child: WeeklyBars(values: week, labels: labels)),
                    const SizedBox(height: 28),
                    const SectionHeader(title: 'Last 21 days', icon: Icons.grid_view_rounded),
                    SoftCard(
                      child: Column(children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(21, (i) {
                            final v = last21[i];
                            final c = v == null ? AppColors.surfaceMuted : (v >= 0.999 ? AppColors.success : (v > 0 ? AppColors.warning : AppColors.danger));
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: 350 + i * 40),
                              curve: Curves.easeOutBack,
                              builder: (context, t, child) => Transform.scale(scale: t.clamp(0.0, 1.2), child: child),
                              child: Container(width: 34, height: 34, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(11), boxShadow: v == null ? null : [BoxShadow(color: c.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))])),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _legend(AppColors.success, 'All taken'),
                          const SizedBox(width: 16),
                          _legend(AppColors.warning, 'Partial'),
                          const SizedBox(width: 16),
                          _legend(AppColors.danger, 'Missed'),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 11, height: 11, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ]);
}
