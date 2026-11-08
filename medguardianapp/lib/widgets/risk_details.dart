import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/risk_predictor.dart';
import '../theme/app_colors.dart';

Color _levelColor(RiskLevel l) => switch (l) {
      RiskLevel.high => AppColors.riskHigh,
      RiskLevel.moderate => AppColors.riskModerate,
      _ => AppColors.riskLow,
    };

String _clock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String _dayWord(DateTime d) {
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
  return diff == 0 ? 'Today' : (diff == 1 ? 'Tomorrow' : 'Soon');
}

/// Two cards under the risk gauge:
///  • "Your next doses" — the model's risk for each dose coming up
///  • "Your habits" — patterns found in the user's own dose history
/// Shows nothing until the API has answered.
class RiskDetails extends StatelessWidget {
  final RiskResult risk;
  const RiskDetails({super.key, required this.risk});

  @override
  Widget build(BuildContext context) {
    if (!risk.hasData || (risk.doses.isEmpty && risk.insights.isEmpty)) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (risk.doses.isNotEmpty) ...[
        const SizedBox(height: 16),
        _Card(
          icon: Icons.schedule_rounded,
          title: 'Your next doses',
          child: Column(children: [
            for (var i = 0; i < risk.doses.length && i < 8; i++) ...[
              if (i > 0) const Divider(height: 14, color: AppColors.line),
              _DoseRow(dose: risk.doses[i]),
            ],
          ]),
        ),
      ],
      if (risk.insights.isNotEmpty) ...[
        const SizedBox(height: 16),
        _Card(
          icon: Icons.insights_rounded,
          title: 'Your habits',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final i in risk.insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(_iconFor(i.kind), size: 18, color: i.kind == 'steady' || i.title.startsWith('Doing better') ? AppColors.success : AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(i.detail, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35)),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }

  static IconData _iconFor(String kind) => switch (kind) {
        'time_of_day' => Icons.wb_twilight_rounded,
        'medicine' => Icons.medication_rounded,
        'weekend' => Icons.weekend_rounded,
        'trend' => Icons.trending_up_rounded,
        'late' => Icons.timer_outlined,
        _ => Icons.check_circle_outline_rounded,
      };
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Card({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _DoseRow extends StatelessWidget {
  final DoseRisk dose;
  const _DoseRow({required this.dose});

  @override
  Widget build(BuildContext context) {
    final c = _levelColor(dose.level);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dose.medicationName.isEmpty ? 'Medication' : dose.medicationName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 2),
          Text('${_dayWord(dose.scheduledAt)} · ${_clock(dose.scheduledAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
          if (dose.reasons.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(dose.reasons.first, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
          ],
        ]),
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
        child: Text('${dose.percent}%', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    ]);
  }
}
