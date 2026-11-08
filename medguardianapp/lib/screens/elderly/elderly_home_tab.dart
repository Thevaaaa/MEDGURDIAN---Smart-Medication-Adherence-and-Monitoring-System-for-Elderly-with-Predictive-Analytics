import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import 'sos_screen.dart';
import 'log_symptom_screen.dart';
import 'adherence_history_screen.dart';
import 'health_tab.dart';

class ElderlyHomeTab extends StatefulWidget {
  const ElderlyHomeTab({super.key});

  @override
  State<ElderlyHomeTab> createState() => _ElderlyHomeTabState();
}

class _ElderlyHomeTabState extends State<ElderlyHomeTab> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Keeps the "next dose" lock and countdown fresh between data updates.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _relative(DateTime t) {
    final d = t.difference(DateTime.now());
    final mins = d.inMinutes.abs();
    final text = mins < 60 ? '$mins min' : '${(mins / 60).floor()} h ${mins % 60} min';
    return d.isNegative ? 'Overdue by $text' : 'In $text';
  }

  /// Today's doses grouped into Morning / Afternoon / Evening / Night.
  List<Widget> _schedule(AppData data, List<DoseLog> today) {
    final sorted = [...today]..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final out = <Widget>[];
    _DayPart? current;
    for (final d in sorted) {
      final med = data.medicationById(d.medicationId);
      if (med == null) continue;
      final p = _DayPart.of(d.scheduledTime.hour);
      if (p != current) {
        current = p;
        final inGroup = sorted.where((x) => _DayPart.of(x.scheduledTime.hour) == p).toList();
        out.add(_PeriodLabel(period: p, total: inGroup.length, done: inGroup.where((x) => x.status != DoseStatus.pending).length, first: out.isEmpty));
      }
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DoseTile(medication: med, dose: d, onTaken: () => data.updateDoseStatus(d.id, DoseStatus.taken), onMissed: () => data.updateDoseStatus(d.id, DoseStatus.missed)),
      ));
    }
    out.add(const Padding(
      padding: EdgeInsets.only(top: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.swipe_rounded, size: 14, color: AppColors.textFaint),
        SizedBox(width: 6),
        Text('Tip: swipe right for taken, left for missed', style: TextStyle(color: AppColors.textFaint, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    ));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final today = data.todayLogs();
        final pending = today.where((d) => d.status == DoseStatus.pending).length;
        final doneCount = today.length - pending;
        final next = data.nextDose;
        final nextMed = next == null ? null : data.medicationById(next.medicationId);
        final vital = data.latestVital;
        final name = (data.me?.name ?? data.elderly.name);
        final first = name.trim().isEmpty ? 'there' : name.trim().split(' ').first;

        // Confetti celebrates each dose marked *taken* (see DoseTile /
        // _NextDose) — never a missed one.

        return PageShell(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              HeroHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FadeSlideIn(child: Text(_greeting(), style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600))),
                              const SizedBox(height: 2),
                              FadeSlideIn(delayMs: 80, child: Text(first, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1))),
                              const SizedBox(height: 2),
                              FadeSlideIn(delayMs: 140, child: Text(Fmt.fullDate(DateTime.now()), style: const TextStyle(color: Colors.white54, fontSize: 12.5, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ),
                        FadeSlideIn(
                          delayMs: 100,
                          child: Pressable(
                            // Tapping your own picture opens your Profile.
                            onTap: () => NotificationService.instance.tapTarget.value = 'profile',
                            child: Stack(clipBehavior: Clip.none, children: [
                              InitialsAvatar(name: name, color: Colors.white, radius: 27, ring: true, photoUrl: data.elderly.photoUrl),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(color: AppColors.mint, shape: BoxShape.circle, border: Border.all(color: AppColors.deep, width: 2)),
                                  child: const Icon(Icons.person_rounded, size: 11, color: AppColors.deep),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      delayMs: 200,
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: _NextDose(next: next, med: nextMed, hasDoses: today.isNotEmpty, relative: next == null ? '' : _relative(next.scheduledTime), onTaken: () {
                            showConfetti(context);
                            data.updateDoseStatus(next!.id, DoseStatus.taken);
                          }, onMissed: () => data.updateDoseStatus(next!.id, DoseStatus.missed)),
                      ),
                    ),
                    if (today.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      FadeSlideIn(
                        delayMs: 300,
                        child: Row(
                          children: [
                            Text('$doneCount of ${today.length} doses today', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: today.isEmpty ? 0 : doneCount / today.length),
                                  duration: const Duration(milliseconds: 900),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 9, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(AppColors.mint)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PageBody(
                children: staggered([
                  _HeartCard(vital: vital),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatPill(
                          icon: (vital?.oxygenLow ?? false) ? Icons.warning_amber_rounded : Icons.air_rounded,
                          label: (vital?.oxygenLow ?? false) ? 'Oxygen is LOW' : 'Oxygen (SpO2)',
                          value: vital == null ? '—' : '${vital.oxygenLevel}%',
                          color: (vital?.oxygenLow ?? false) ? AppColors.danger : AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: StatPill(icon: Icons.verified_rounded, label: '2-week adherence', value: data.adherenceRate() == null ? '—' : '${(data.adherenceRate()! * 100).round()}%', color: AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _ScheduleHeader(today: today),
                  if (today.isEmpty)
                    const EmptyState(icon: Icons.medication_outlined, title: 'No medications yet', subtitle: 'Add your first one from the Medicine tab.')
                  else
                    ..._schedule(data, today),
                  const SizedBox(height: 26),
                  const SectionHeader(title: 'Quick actions', icon: Icons.bolt_rounded),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _ActionTile(icon: Icons.sos_rounded, title: 'Emergency', subtitle: 'Hold to call for help', gradient: AppColors.dangerGradient, onTap: () => Navigator.push(context, slideFadeRoute(const SosScreen()))),
                      _ActionTile(icon: Icons.sick_rounded, title: 'Log symptom', subtitle: 'How are you feeling?', gradient: AppColors.sunGradient, onTap: () => Navigator.push(context, slideFadeRoute(const LogSymptomScreen()))),
                      _ActionTile(icon: Icons.event_rounded, title: 'Appointments', subtitle: 'What is coming up', gradient: const LinearGradient(colors: [Color(0xFF3E7CB1), Color(0xFF2B5F8C)], begin: Alignment.topLeft, end: Alignment.bottomRight), onTap: () => Navigator.push(context, slideFadeRoute(const HealthTab(initialTab: 2)))),
                      _ActionTile(icon: Icons.insights_rounded, title: 'My progress', subtitle: 'History & risk insight', gradient: AppColors.heroGradient, onTap: () => Navigator.push(context, slideFadeRoute(const AdherenceHistoryScreen()))),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _InsightCard(data: data),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NextDose extends StatelessWidget {
  final DoseLog? next;
  final Medication? med;
  final bool hasDoses;
  final String relative;
  final VoidCallback onTaken;
  final VoidCallback onMissed;

  const _NextDose({required this.next, required this.med, required this.hasDoses, required this.relative, required this.onTaken, required this.onMissed});

  @override
  Widget build(BuildContext context) {
    if (next == null || med == null) {
      return Row(
        children: [
          hasDoses ? const DrawCheck(size: 54, color: AppColors.mint, strokeWidth: 4) : const Icon(Icons.medication_outlined, color: Colors.white70, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasDoses ? 'All done for today' : 'Nothing scheduled', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(hasDoses ? 'Every dose is recorded. Well done!' : 'Add a medication to start your reminders.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      );
    }
    final overdue = next!.scheduledTime.isBefore(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: overdue ? AppColors.coral.withOpacity(0.28) : Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(overdue ? Icons.priority_high_rounded : Icons.alarm_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(relative, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
          const Spacer(),
          Text(Fmt.time12(next!.scheduledTime), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          DoseCountdownRing(scheduledTime: next!.scheduledTime, done: false, taken: false, color: med!.color, icon: med!.icon, photoUrl: med!.photoUrl, size: 66, onDark: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(med!.name, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              Text(med!.dosage, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: !next!.isOpen
              // Strict time frame: no taking medicine early.
              ? Container(
                  key: const ValueKey('locked'),
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.22))),
                  child: Row(children: [
                    const Icon(Icons.lock_clock_rounded, color: AppColors.mint, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'You can take it from '),
                          TextSpan(text: Fmt.time12(next!.opensAt), style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                        ]),
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ]),
                )
              : Row(key: const ValueKey('open'), children: [
                  Expanded(
                    child: Pressable(
                      onTap: onMissed,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white54, width: 1.5)),
                        child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.close_rounded, color: Colors.white, size: 20), SizedBox(width: 6), Text('Missed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))])),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Pressable(
                      onTap: onTaken,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 6))]),
                        child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_rounded, color: AppColors.deep, size: 22), SizedBox(width: 6), Text("I've taken it", style: TextStyle(color: AppColors.deep, fontWeight: FontWeight.w800, fontSize: 16))])),
                      ),
                    ),
                  ),
                ]),
        ),
      ],
    );
  }
}

class _HeartCard extends StatelessWidget {
  final VitalReading? vital;
  const _HeartCard({required this.vital});

  @override
  Widget build(BuildContext context) {
    final abnormal = vital?.heartAbnormal ?? false;
    final color = abnormal ? AppColors.danger : AppColors.coral;
    return SoftCard(
      shadowTint: AppColors.danger,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Breathing(minScale: 0.9, maxScale: 1.15, duration: const Duration(milliseconds: 800), child: Icon(Icons.favorite_rounded, color: color, size: 20)),
                const SizedBox(width: 6),
                const Text('Heart rate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.textFaint)),
              ]),
              const SizedBox(height: 8),
              if (vital == null)
                const Text('—', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800))
              else
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  AnimatedNumber(end: vital!.heartRate.toDouble(), builder: (v) => v.round().toString(), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1)),
                  const SizedBox(width: 4),
                  const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('bpm', style: TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.w700, fontSize: 12))),
                ]),
              const SizedBox(height: 4),
              Text(vital == null ? 'No reading yet' : Fmt.timeAgo(vital!.time), style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(child: vital == null ? const SizedBox(height: 54) : EcgLine(bpm: vital!.heartRate, color: color)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 8))]),
        child: Stack(
          children: [
            Positioned(right: -14, bottom: -14, child: Icon(icon, size: 84, color: Colors.white.withOpacity(0.13))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: Colors.white, size: 22)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final AppData data;
  const _InsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final risk = data.risk;
    final c = risk.hasData ? AppColors.riskColor(risk.probability) : AppColors.textFaint;
    final label = risk.level == RiskLevel.low ? 'Low' : (risk.level == RiskLevel.moderate ? 'Moderate' : 'High');
    return SoftCard(
      shadowTint: c,
      onTap: () => Navigator.push(context, slideFadeRoute(const AdherenceHistoryScreen())),
      child: Row(
        children: [
          RiskGauge(value: risk.probability, color: c, size: 96, centerLabel: risk.percentLabel, subLabel: 'risk'),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Text('Adherence insight', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.textFaint)),
                ]),
                const SizedBox(height: 5),
                Text(risk.hasData ? '$label risk of a missed dose' : 'Still learning your routine', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c)),
                const SizedBox(height: 3),
                Text(risk.factors.first, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
        ],
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════
// Today's schedule
// ═════════════════════════════════════════════════════════════════════════

enum _DayPart {
  morning('Morning', Icons.wb_sunny_rounded, Color(0xFFE0A527)),
  afternoon('Afternoon', Icons.light_mode_rounded, Color(0xFFE0824A)),
  evening('Evening', Icons.wb_twilight_rounded, Color(0xFF9B6BC7)),
  night('Night', Icons.nightlight_round, Color(0xFF3E7CB1));

  final String label;
  final IconData icon;
  final Color color;
  const _DayPart(this.label, this.icon, this.color);

  static _DayPart of(int hour) {
    if (hour >= 5 && hour < 12) return _DayPart.morning;
    if (hour >= 12 && hour < 17) return _DayPart.afternoon;
    if (hour >= 17 && hour < 21) return _DayPart.evening;
    return _DayPart.night;
  }
}

/// Section title with a segmented progress strip — one segment per dose,
/// coloured by its status.
class _ScheduleHeader extends StatelessWidget {
  final List<DoseLog> today;
  const _ScheduleHeader({required this.today});

  @override
  Widget build(BuildContext context) {
    final sorted = [...today]..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final done = today.where((d) => d.status != DoseStatus.pending).length;
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TODAY', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
              SizedBox(height: 2),
              Text('Your schedule', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.textPrimary)),
            ]),
          ),
          if (today.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.09), borderRadius: BorderRadius.circular(20)),
              child: Text('$done / ${today.length} done', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
        ]),
        if (sorted.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 0; i < sorted.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('${sorted[i].id}-${sorted[i].status.name}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 380 + i * 70),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) {
                    final d = sorted[i];
                    final Color c = switch (d.status) {
                      DoseStatus.taken => AppColors.success,
                      DoseStatus.missed => AppColors.danger,
                      DoseStatus.skipped => AppColors.textFaint,
                      DoseStatus.pending => now.isAfter(d.scheduledTime) ? AppColors.danger.withOpacity(0.35) : AppColors.line,
                    };
                    return Container(
                      height: 6,
                      decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(6)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: v,
                        child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6))),
                      ),
                    );
                  },
                ),
              ),
            ],
          ]),
        ],
      ]),
    );
  }
}

class _PeriodLabel extends StatelessWidget {
  final _DayPart period;
  final int total;
  final int done;
  final bool first;
  const _PeriodLabel({required this.period, required this.total, required this.done, required this.first});

  @override
  Widget build(BuildContext context) {
    final complete = done == total;
    return Padding(
      padding: EdgeInsets.fromLTRB(2, first ? 4 : 10, 2, 10),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: period.color.withOpacity(0.14), borderRadius: BorderRadius.circular(9)),
          child: Icon(period.icon, size: 16, color: period.color),
        ),
        const SizedBox(width: 10),
        Text(period.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2, color: AppColors.textPrimary)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppColors.line)),
        const SizedBox(width: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: complete
              ? const Row(key: ValueKey('c'), mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success),
                  SizedBox(width: 4),
                  Text('Done', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 12)),
                ])
              : Text('$done of $total', key: const ValueKey('n'), style: const TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ]),
    );
  }
}
