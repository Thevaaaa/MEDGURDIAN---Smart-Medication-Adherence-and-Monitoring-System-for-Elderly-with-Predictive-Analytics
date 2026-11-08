import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/med_visuals.dart';
import '../auth/link_person_screen.dart';
import 'dependent_detail_screen.dart';

class CaregiverHomeTab extends StatelessWidget {
  const CaregiverHomeTab({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        if (data.dependents.isEmpty) return const _NoDependents();

        final el = data.elderly;
        final adherence = data.adherenceRate();
        final riskColor = data.risk.hasData ? AppColors.riskColor(data.risk.probability) : AppColors.textFaint;
        final nextAppt = data.upcomingAppointments.isNotEmpty ? data.upcomingAppointments.first : null;
        final vital = data.latestVital;
        final today = [...data.todayLogs()]..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
        final unread = data.alerts.where((a) => !a.acknowledged).toList();
        final urgent = unread.where((a) => a.severity == AlertSeverity.critical).length;
        final badVital = data.recentAbnormalVital;
        final overdue = data.overdueToday.length;
        final concern = urgent > 0 || badVital != null;
        void openAlerts() => NotificationService.instance.tapTarget.value = 'alerts';
        final riskLabel = !data.risk.hasData ? 'Still learning' : (data.risk.level == RiskLevel.low ? 'Low' : (data.risk.level == RiskLevel.moderate ? 'Moderate' : 'High'));
        final loc = data.currentLocation;
        final me = data.me?.name.trim() ?? '';
        final myFirst = me.isEmpty ? '' : me.split(' ').first;

        void openDetail() => Navigator.push(context, slideFadeRoute(const DependentDetailScreen()));

        return PageShell(
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            children: [
              HeroHeader(
                bottomRadius: 40,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          FadeSlideIn(
                            child: Text(
                              (myFirst.isEmpty ? _greeting() : '${_greeting()}, $myFirst').toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.mint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const FadeSlideIn(
                            delayMs: 60,
                            child: Text('Care dashboard', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                          ),
                        ]),
                      ),
                      FadeSlideIn(
                        delayMs: 80,
                        child: Row(children: [
                          _GlassCircle(icon: Icons.person_add_alt_1_rounded, onTap: () => Navigator.push(context, slideFadeRoute(const LinkPersonScreen()))),
                          const SizedBox(width: 10),
                          // Your own picture — tap for your Profile.
                          Pressable(
                            onTap: () => NotificationService.instance.tapTarget.value = 'profile',
                            child: InitialsAvatar(name: data.me?.name ?? 'Me', color: Colors.white, radius: 21, ring: true, photoUrl: data.me?.photoUrl),
                          ),
                        ]),
                      ),
                    ]),
                    if (data.dependents.length > 1) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: data.dependents.map((d) {
                            final selected = d.uid == data.activeElderlyId;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Pressable(
                                onTap: () => data.selectDependent(d.uid),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
                                  decoration: BoxDecoration(
                                    color: selected ? Colors.white : Colors.white.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: selected ? Colors.white : Colors.white.withOpacity(0.18)),
                                    boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))] : null,
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    InitialsAvatar(name: d.name, color: selected ? d.color : Colors.white, radius: 16, photoUrl: d.photoUrl),
                                    const SizedBox(width: 8),
                                    Text(d.name.isEmpty ? 'Person' : d.name.split(' ').first, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: selected ? AppColors.deep : Colors.white)),
                                  ]),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FadeSlideIn(
                      delayMs: 140,
                      child: GlassCard(
                        onTap: openDetail,
                        radius: 28,
                        opacity: 0.10,
                        padding: const EdgeInsets.all(18),
                        child: Column(children: [
                          Row(children: [
                            Stack(clipBehavior: Clip.none, children: [
                              InitialsAvatar(name: el.name, color: Colors.white, radius: 27, ring: true, photoUrl: el.photoUrl),
                              Positioned(
                                right: 1,
                                bottom: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: const BoxDecoration(color: AppColors.deep, shape: BoxShape.circle),
                                  child: LiveDot(color: concern ? AppColors.coral : AppColors.mint, size: 10),
                                ),
                              ),
                            ]),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(el.name.isEmpty ? '…' : el.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                                const SizedBox(height: 2),
                                Text(
                                  [if (el.age > 0) '${el.age} yrs', if (el.conditions.isNotEmpty) el.conditions.join(', ')].join(' · ').ifEmpty('View care details'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withOpacity(0.68), fontSize: 12.5),
                                ),
                              ]),
                            ),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                            ),
                          ]),
                          const SizedBox(height: 14),
                          _StatusBanner(urgent: urgent, unread: unread.length, vital: badVital, overdue: overdue, onTap: openAlerts),
                          const SizedBox(height: 18),
                          Row(children: [
                            Expanded(
                              child: Column(children: [
                                RiskGauge(value: data.risk.probability, color: riskColor, size: 128, onDark: true, centerLabel: data.risk.percentLabel, subLabel: 'risk'),
                                const SizedBox(height: 2),
                                Text(data.risk.hasData ? '$riskLabel miss risk' : 'Risk · learning', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                                Text('Risk prediction', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
                              ]),
                            ),
                            Container(width: 1, height: 120, color: Colors.white.withOpacity(0.14)),
                            Expanded(
                              child: Column(children: [
                                AdherenceRing(value: adherence ?? 0, size: 98, onDark: true, center: adherence == null ? const Text('—', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)) : null),
                                const SizedBox(height: 12),
                                const Text('Adherence', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                                Text('Last 2 weeks', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
                              ]),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              PageBody(
                top: 22,
                children: staggered([
                  Row(children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.call_rounded,
                        label: 'Call',
                        color: AppColors.success,
                        enabled: el.phone.isNotEmpty,
                        onTap: () => launchUrl(Uri(scheme: 'tel', path: el.phone)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.map_rounded,
                        label: 'Map',
                        color: AppColors.info,
                        enabled: loc != null,
                        onTap: () => launchUrl(Uri.parse(loc!.mapsUrl), mode: LaunchMode.externalApplication),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickAction(icon: Icons.insights_rounded, label: 'Details', color: AppColors.primary, onTap: openDetail)),
                  ]),
                  const SizedBox(height: 26),
                  _TodayDoses(data: data, today: today),
                  const SizedBox(height: 26),
                  const _Title('Vitals'),
                  _VitalsCard(vital: vital),
                  if (loc != null) ...[
                    const SizedBox(height: 26),
                    const _Title('Last known location'),
                    _LocationCard(loc: loc),
                  ],
                  const SizedBox(height: 26),
                  const _Title('Next appointment'),
                  if (nextAppt == null)
                    const _QuietCard(icon: Icons.event_available_rounded, text: 'No upcoming appointments right now.')
                  else
                    _ApptCard(appt: nextAppt),
                  const SizedBox(height: 26),
                  _Title('Recent alerts', trailing: unread.isEmpty ? null : '${unread.length} new'),
                  if (data.alerts.isEmpty)
                    const _QuietCard(icon: Icons.notifications_none_rounded, text: 'All quiet — no alerts recently.')
                  else
                    ...data.alerts.take(3).map((a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: AlertTile(alert: a, phone: el.phone, personName: el.name, onAck: () => data.acknowledgeAlert(a.id)))),
                ], stepMs: 60),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

// ═════════════════════════════════════════════════════════════════════════
// Hero pieces
// ═════════════════════════════════════════════════════════════════════════

class _GlassCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassCircle({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2))),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// One-line health summary under the person's name. It only says
/// "Everything looks good" when there are no urgent/unread alerts, no
/// out-of-range vitals and no overdue doses. Tapping it (when there is
/// something to see) jumps straight to the Alerts tab.
class _StatusBanner extends StatelessWidget {
  final int urgent;
  final int unread;
  final VitalReading? vital;
  final int overdue;
  final VoidCallback onTap;
  const _StatusBanner({required this.urgent, required this.unread, required this.vital, required this.overdue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    late final Color c;
    late final IconData icon;
    late final String text;
    if (urgent > 0) {
      c = AppColors.coral;
      icon = Icons.priority_high_rounded;
      text = '$urgent urgent ${urgent == 1 ? 'alert needs' : 'alerts need'} attention';
    } else if (vital != null) {
      c = AppColors.coral;
      icon = Icons.monitor_heart_rounded;
      text = 'Vitals out of range: ${vital!.problems.join(', ')}';
    } else if (overdue > 0) {
      c = AppColors.accent;
      icon = Icons.medication_liquid_rounded;
      text = '$overdue ${overdue == 1 ? 'dose is' : 'doses are'} overdue today';
    } else if (unread > 0) {
      c = AppColors.accent;
      icon = Icons.notifications_active_rounded;
      text = '$unread unread ${unread == 1 ? 'alert' : 'alerts'}';
    } else {
      c = AppColors.mint;
      icon = Icons.verified_user_rounded;
      text = 'Everything looks good';
    }
    final actionable = urgent > 0 || vital != null || overdue > 0 || unread > 0;
    final banner = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.withOpacity(0.16), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(0.35))),
      child: Row(children: [
        urgent > 0 || vital != null ? Breathing(minScale: 0.85, maxScale: 1.15, duration: const Duration(milliseconds: 700), child: Icon(icon, color: c, size: 17)) : Icon(icon, color: c, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
        if (actionable) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11.5)),
              Icon(Icons.chevron_right_rounded, color: Colors.white, size: 15),
            ]),
          ),
        ],
      ]),
    );
    return actionable ? Pressable(onTap: onTap, child: banner) : banner;
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Body pieces
// ═════════════════════════════════════════════════════════════════════════

class _Title extends StatelessWidget {
  final String text;
  final String? trailing;
  const _Title(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.textPrimary))),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
            child: Text(trailing!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
      ]),
    );
  }
}

BoxDecoration _panel([Color? tint]) => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.line.withOpacity(0.7)),
      boxShadow: AppColors.softShadow(tint),
    );

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: _panel(color),
          child: Column(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, 0.12)!, color]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: color.withOpacity(0.32), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
          ]),
        ),
      ),
    );
  }
}

/// Horizontal strip of today's doses with photo, time and status.
class _TodayDoses extends StatelessWidget {
  final AppData data;
  final List<DoseLog> today;
  const _TodayDoses({required this.data, required this.today});

  @override
  Widget build(BuildContext context) {
    final taken = today.where((d) => d.status == DoseStatus.taken).length;
    final missed = today.where((d) => d.status == DoseStatus.missed).length;
    return Container(
      decoration: _panel(AppColors.primary),
      padding: const EdgeInsets.fromLTRB(18, 16, 0, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("TODAY'S MEDICINES", style: TextStyle(color: AppColors.primary, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
                SizedBox(height: 2),
                Text('Dose tracker', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
              ]),
            ),
            if (today.isNotEmpty)
              AnimatedNumber(
                end: taken.toDouble(),
                builder: (v) => '${v.round()}/${today.length}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: AppColors.textPrimary),
              ),
          ]),
        ),
        if (today.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Row(children: [
              _Dot(color: AppColors.success, label: '$taken taken'),
              const SizedBox(width: 12),
              _Dot(color: AppColors.danger, label: '$missed missed'),
              const SizedBox(width: 12),
              _Dot(color: AppColors.line, label: '${today.length - taken - missed} to go'),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        if (today.isEmpty)
          const Padding(
            padding: EdgeInsets.only(right: 18),
            child: Text('No doses scheduled today.', style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(right: 18),
              itemCount: today.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final d = today[i];
                final med = data.medicationById(d.medicationId);
                return _DoseChip(dose: d, med: med);
              },
            ),
          ),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _DoseChip extends StatelessWidget {
  final DoseLog dose;
  final Medication? med;
  const _DoseChip({required this.dose, required this.med});

  @override
  Widget build(BuildContext context) {
    final overdue = dose.status == DoseStatus.pending && DateTime.now().isAfter(dose.scheduledTime);
    final (Color c, IconData icon, String label) = switch (dose.status) {
      DoseStatus.taken => (AppColors.success, Icons.check_rounded, 'Taken'),
      DoseStatus.missed => (AppColors.danger, Icons.close_rounded, 'Missed'),
      DoseStatus.skipped => (AppColors.textFaint, Icons.redo_rounded, 'Skipped'),
      DoseStatus.pending => overdue ? (AppColors.warning, Icons.schedule_rounded, 'Due') : (AppColors.info, Icons.schedule_rounded, 'Upcoming'),
    };
    final color = med?.color ?? AppColors.primary;
    return Container(
      width: 108,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dose.status == DoseStatus.pending ? AppColors.background : c.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dose.status == DoseStatus.pending ? AppColors.line : c.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(clipBehavior: Clip.none, children: [
            MedThumb(color: color, icon: med?.icon ?? Icons.medication_rounded, photoUrl: med?.photoUrl ?? '', size: 40, radius: 13, shadow: false),
            Positioned(
              right: -5,
              bottom: -5,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: Icon(icon, size: 11, color: Colors.white),
              ),
            ),
          ]),
        ]),
        const Spacer(),
        Text(Fmt.time12(dose.scheduledTime), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, letterSpacing: -0.2, color: AppColors.textPrimary)),
        Text(dose.medName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11)),
      ]),
    );
  }
}

class _VitalsCard extends StatelessWidget {
  final VitalReading? vital;
  const _VitalsCard({required this.vital});

  @override
  Widget build(BuildContext context) {
    final v = vital;
    final abnormal = v?.isAbnormal ?? false;
    final hc = (v?.heartAbnormal ?? false) ? AppColors.danger : AppColors.coral;
    return Container(
      decoration: _panel(hc),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: hc.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Breathing(minScale: 0.88, maxScale: 1.12, duration: const Duration(milliseconds: 800), child: Icon(Icons.favorite_rounded, color: hc, size: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Heart rate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              Text(v == null ? 'No reading yet' : 'Updated ${Fmt.timeAgo(v.time)}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
            ]),
          ),
          if (abnormal) const MedTag(label: 'Abnormal', color: AppColors.danger, icon: Icons.warning_amber_rounded, solid: true),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (v == null)
            const Text('—', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800))
          else ...[
            AnimatedNumber(end: v.heartRate.toDouble(), builder: (x) => x.round().toString(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.4, height: 1)),
            const SizedBox(width: 4),
            const Padding(padding: EdgeInsets.only(bottom: 5), child: Text('bpm', style: TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.w700, fontSize: 13))),
          ],
          const SizedBox(width: 16),
          Expanded(child: v == null ? const SizedBox(height: 54) : EcgLine(bpm: v.heartRate, color: hc)),
        ]),
        if (v != null) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _MiniStat(
                icon: v.oxygenLow ? Icons.warning_amber_rounded : Icons.air_rounded,
                color: v.oxygenLow ? AppColors.danger : AppColors.info,
                value: '${v.oxygenLevel}%',
                label: v.oxygenLow ? 'Low O₂' : 'Oxygen',
                alert: v.oxygenLow,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _MiniStat(icon: Icons.directions_walk_rounded, color: AppColors.success, value: '${v.steps}', label: 'Steps')),
          ]),
          if (abnormal) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
              child: Text('Out of range: ${v.problems.join(', ')}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ],
        ],
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool alert;
  final String value;
  final String label;
  const _MiniStat({required this.icon, required this.color, required this.value, required this.label, this.alert = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: alert ? AppColors.danger.withOpacity(0.08) : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: alert ? Border.all(color: AppColors.danger.withOpacity(0.3)) : null,
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: alert ? AppColors.danger : AppColors.textPrimary)),
        const SizedBox(width: 5),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: alert ? AppColors.danger : AppColors.textFaint, fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final LocationPoint loc;
  const _LocationCard({required this.loc});

  @override
  Widget build(BuildContext context) {
    final inside = loc.inside;
    final Color c = inside == null ? AppColors.info : (inside ? AppColors.success : AppColors.warning);
    return Pressable(
      onTap: () => launchUrl(Uri.parse(loc.mapsUrl), mode: LaunchMode.externalApplication),
      child: Container(
        decoration: _panel(c),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.withOpacity(0.22), c.withOpacity(0.08)]),
              borderRadius: BorderRadius.circular(17),
            ),
            child: PulseRings(color: c, size: 52, rings: 1, child: Icon(Icons.location_on_rounded, color: c, size: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loc.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.3)),
              const SizedBox(height: 4),
              Row(children: [
                if (inside != null) ...[MedTag(label: inside ? 'Home' : 'Away', color: c), const SizedBox(width: 8)],
                Text(Fmt.timeAgo(loc.time), style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
              ]),
            ]),
          ),
          const Icon(Icons.open_in_new_rounded, color: AppColors.textFaint, size: 19),
        ]),
      ),
    );
  }
}

class _ApptCard extends StatelessWidget {
  final Appointment appt;
  const _ApptCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final days = DateTime(appt.dateTime.year, appt.dateTime.month, appt.dateTime.day).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
    final when = days <= 0 ? 'Today' : (days == 1 ? 'Tomorrow' : 'In $days days');
    return Container(
      decoration: _panel(AppColors.info),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 58,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4A8BC2), Color(0xFF2B5F8C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.info.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(Fmt.monthShort(appt.dateTime).toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
            Text('${appt.dateTime.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 23, height: 1.1)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MedTag(label: when, color: AppColors.info),
            const SizedBox(height: 6),
            Text(appt.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 2),
            Text('${Fmt.time12(appt.dateTime)} · ${appt.location}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

class _QuietCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _QuietCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.6), borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.line)),
      child: Row(children: [
        Icon(icon, color: AppColors.textFaint),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5))),
      ]),
    );
  }
}

class _NoDependents extends StatelessWidget {
  const _NoDependents();

  @override
  Widget build(BuildContext context) {
    return PageShell(
      child: AuroraBackground(
        child: SizedBox.expand(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Floating(
                    child: PulseRings(
                      color: AppColors.mint,
                      size: 190,
                      rings: 3,
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.14), border: Border.all(color: Colors.white38)),
                        child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const FadeSlideIn(child: Text('Link the person you care for', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6))),
                  const SizedBox(height: 12),
                  const FadeSlideIn(delayMs: 100, child: Text('Ask them for the 6-digit code in their MedGuardian profile. Once linked you will see their medication, health and location — and get alerts instantly.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 14.5))),
                  const SizedBox(height: 32),
                  FadeSlideIn(
                    delayMs: 200,
                    child: Pressable(
                      onTap: () => Navigator.push(context, slideFadeRoute(const LinkPersonScreen())),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10))]),
                        child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.link_rounded, color: AppColors.deep), SizedBox(width: 10), Text('Enter link code', style: TextStyle(color: AppColors.deep, fontWeight: FontWeight.w800, fontSize: 16.5))])),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
