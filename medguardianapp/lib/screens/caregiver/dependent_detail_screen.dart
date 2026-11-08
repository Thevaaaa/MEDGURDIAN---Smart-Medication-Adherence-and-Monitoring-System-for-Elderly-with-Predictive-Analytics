import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/med_visuals.dart';
import '../../widgets/risk_details.dart';

class DependentDetailScreen extends StatefulWidget {
  const DependentDetailScreen({super.key});

  @override
  State<DependentDetailScreen> createState() => _DependentDetailScreenState();
}

class _DependentDetailScreenState extends State<DependentDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final el = data.elderly;
        final adherence = data.adherenceRate();
        return Scaffold(
          backgroundColor: AppColors.background,
          body: PageShell(
            child: Column(
              children: [
                HeroHeader(
                  bottomRadius: 36,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  child: Column(children: [
                    Row(children: [
                      _HeroButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.maybePop(context)),
                      const Spacer(),
                      if (el.phone.isNotEmpty) ...[
                        _HeroButton(icon: Icons.sms_rounded, onTap: () => launchUrl(Uri(scheme: 'sms', path: el.phone))),
                        const SizedBox(width: 10),
                        Pressable(
                          onTap: () => launchUrl(Uri(scheme: 'tel', path: el.phone)),
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(21),
                              boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 5))],
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.call_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text('Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                            ]),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      FadeSlideIn(child: InitialsAvatar(name: el.name, color: Colors.white, radius: 30, ring: true, photoUrl: el.photoUrl)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          FadeSlideIn(
                            delayMs: 60,
                            child: Text(el.name.isEmpty ? 'Details' : el.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
                          ),
                          const SizedBox(height: 4),
                          FadeSlideIn(
                            delayMs: 110,
                            child: Wrap(spacing: 6, runSpacing: 6, children: [
                              if (el.age > 0) _HeroTag('${el.age} yrs'),
                              for (final c in el.conditions.take(3)) _HeroTag(c),
                              if (el.age == 0 && el.conditions.isEmpty) _HeroTag('Care details'),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delayMs: 160,
                      child: Row(children: [
                        _HeroStat(label: 'Adherence', value: adherence == null ? '—' : '${(adherence * 100).round()}%'),
                        _HeroDivider(),
                        _HeroStat(label: 'Medicines', value: '${data.medications.length}'),
                        _HeroDivider(),
                        _HeroStat(label: 'Miss risk', value: data.risk.hasData ? data.risk.percentLabel : '—'),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    SegmentedTabs(controller: _tab, labels: const ['Doses', 'Meds', 'Health', 'Visits']),
                  ]),
                ),
                Expanded(
                  child: TabBarView(controller: _tab, children: [_AdherenceTab(data: data), _MedsTab(data: data), _HealthTab(data: data), _ApptTab(data: data)]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Hero pieces
// ═════════════════════════════════════════════════════════════════════════

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeroButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2))),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  final String text;
  const _HeroTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.16))),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 1),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 28, color: Colors.white.withOpacity(0.14));
}

// ═════════════════════════════════════════════════════════════════════════
// Shared body pieces
// ═════════════════════════════════════════════════════════════════════════

BoxDecoration _panel([Color? tint]) => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.line.withOpacity(0.7)),
      boxShadow: AppColors.softShadow(tint),
    );

class _Title extends StatelessWidget {
  final String text;
  final String? trailing;
  const _Title(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.textPrimary))),
        if (trailing != null) Text(trailing!, style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Quiet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Quiet({required this.icon, required this.title, this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.6), borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.line)),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: AppColors.textFaint, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Doses tab
// ═════════════════════════════════════════════════════════════════════════

class _AdherenceTab extends StatelessWidget {
  final AppData data;
  const _AdherenceTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final week = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final logs = data.doseLogs.where((d) => Fmt.isSameDay(d.scheduledTime, day) && d.status != DoseStatus.pending);
      if (logs.isEmpty) return 0.02;
      return logs.where((d) => d.status == DoseStatus.taken).length / logs.length;
    });
    final labels = List.generate(7, (i) => Fmt.weekdayShort(now.subtract(Duration(days: 6 - i))).substring(0, 2));
    final missed = data.doseLogs.where((d) => d.status == DoseStatus.missed).toList()..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    final today = [...data.todayLogs()]..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final rc = data.risk.hasData ? AppColors.riskColor(data.risk.probability) : AppColors.textFaint;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 60),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: staggered([
        _Title('Today', trailing: today.isEmpty ? null : '${today.where((d) => d.status == DoseStatus.taken).length} of ${today.length} taken'),
        if (today.isEmpty)
          const _Quiet(icon: Icons.medication_outlined, title: 'No doses today')
        else
          Container(
            decoration: _panel(AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              for (var i = 0; i < today.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 70, color: AppColors.line),
                _TodayRow(dose: today[i], med: data.medicationById(today[i].medicationId)),
              ],
            ]),
          ),
        const SizedBox(height: 26),
        const _Title('Missed-dose risk'),
        Container(
          decoration: _panel(rc),
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            RiskGauge(value: data.risk.probability, color: rc, size: 118, centerLabel: data.risk.percentLabel, subLabel: 'risk'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.primary),
                  ),
                  const SizedBox(width: 7),
                  const Text('Key factors', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                ]),
                const SizedBox(height: 10),
                if (data.risk.factors.isEmpty)
                  const Text('Not enough history yet.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))
                else
                  ...data.risk.factors.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(margin: const EdgeInsets.only(top: 5), width: 6, height: 6, decoration: BoxDecoration(color: rc, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35))),
                        ]),
                      )),
              ]),
            ),
          ]),
        ),
        RiskDetails(risk: data.risk),
        const SizedBox(height: 26),
        const _Title('This week'),
        Container(decoration: _panel(), padding: const EdgeInsets.all(18), child: WeeklyBars(values: week, labels: labels)),
        const SizedBox(height: 26),
        _Title('Recent missed doses', trailing: missed.isEmpty ? null : '${missed.length}'),
        if (missed.isEmpty)
          const _Quiet(icon: Icons.check_circle_outline_rounded, title: 'No missed doses', subtitle: 'Adherence has been perfect recently.')
        else
          Container(
            decoration: _panel(AppColors.danger),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              for (var i = 0; i < missed.length && i < 6; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 64, color: AppColors.line),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.close_rounded, color: AppColors.danger, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(missed[i].medName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                    Text(Fmt.dateTime(missed[i].scheduledTime), style: const TextStyle(fontSize: 12, color: AppColors.textFaint, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),
          ),
      ], stepMs: 55),
    );
  }
}

class _TodayRow extends StatelessWidget {
  final DoseLog dose;
  final Medication? med;
  const _TodayRow({required this.dose, required this.med});

  @override
  Widget build(BuildContext context) {
    final overdue = dose.status == DoseStatus.pending && DateTime.now().isAfter(dose.scheduledTime);
    final (Color c, String label) = switch (dose.status) {
      DoseStatus.taken => (AppColors.success, 'Taken'),
      DoseStatus.missed => (AppColors.danger, 'Missed'),
      DoseStatus.skipped => (AppColors.textFaint, 'Skipped'),
      DoseStatus.pending => overdue ? (AppColors.warning, 'Due') : (AppColors.info, 'Upcoming'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        MedThumb(color: med?.color ?? AppColors.primary, icon: med?.icon ?? Icons.medication_rounded, photoUrl: med?.photoUrl ?? '', size: 42, radius: 14, shadow: false),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dose.medName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            Text('${Fmt.time12(dose.scheduledTime)} · ${dose.dosage}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ]),
        ),
        MedTag(label: label, color: c),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Medicines tab (read-only for caregivers)
// ═════════════════════════════════════════════════════════════════════════

class _MedsTab extends StatelessWidget {
  final AppData data;
  const _MedsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final meds = data.medications;
    final low = meds.where((m) => m.stock <= 8).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 60),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: staggered([
        if (low.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.warning.withOpacity(0.16), AppColors.warning.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.inventory_2_rounded, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${low.map((m) => m.name).join(', ')} ${low.length == 1 ? 'is' : 'are'} running low — a refill may be needed soon.',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.35),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 22),
        ],
        _Title('Medicine cabinet', trailing: '${meds.length}'),
        if (meds.isEmpty)
          const _Quiet(icon: Icons.medication_outlined, title: 'No medicines yet', subtitle: 'They will appear here once added on their phone.')
        else
          ...meds.map((m) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _MedRow(med: m))),
      ], stepMs: 55),
    );
  }
}

class _MedRow extends StatelessWidget {
  final Medication med;
  const _MedRow({required this.med});

  @override
  Widget build(BuildContext context) {
    final low = med.stock <= 8;
    final days = daysOfSupply(med);
    return Container(
      decoration: _panel(med.color),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          MedThumb.of(med, size: 58, radius: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(med.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, letterSpacing: -0.3)),
              Text(med.dosage, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
              if (med.instructions.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.tips_and_updates_rounded, size: 13, color: med.color),
                  const SizedBox(width: 4),
                  Expanded(child: Text(med.instructions, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textFaint, fontSize: 12))),
                ]),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in med.times) MedTag(label: t.label, color: med.color, icon: Icons.access_time_filled_rounded),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: StockBar(stock: med.stock, color: low ? AppColors.warning : med.color)),
          const SizedBox(width: 12),
          Text(
            days == null ? '${med.stock} left' : '${med.stock} left · ~$days d',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: low ? AppColors.warning : AppColors.textFaint),
          ),
        ]),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Health tab
// ═════════════════════════════════════════════════════════════════════════

class _HealthTab extends StatelessWidget {
  final AppData data;
  const _HealthTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final v = data.latestVital;
    final abnormal = v?.isAbnormal ?? false;
    final color = (v?.heartAbnormal ?? false) ? AppColors.danger : AppColors.coral;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 60),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: staggered([
        if (v != null) ...[
          Container(
            decoration: _panel(color),
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Breathing(minScale: 0.88, maxScale: 1.15, duration: const Duration(milliseconds: 800), child: Icon(Icons.favorite_rounded, color: color, size: 20)),
                ),
                const SizedBox(width: 12),
                AnimatedNumber(end: v.heartRate.toDouble(), builder: (x) => x.round().toString(), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1)),
                const SizedBox(width: 5),
                const Text('bpm', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textFaint)),
                const Spacer(),
                if (abnormal) const MedTag(label: 'Abnormal', color: AppColors.danger, solid: true),
              ]),
              const SizedBox(height: 10),
              EcgLine(bpm: v.heartRate, color: color, height: 62),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Metric(icon: v.oxygenLow ? Icons.warning_amber_rounded : Icons.air_rounded, color: v.oxygenLow ? AppColors.danger : AppColors.info, value: '${v.oxygenLevel}%', label: v.oxygenLow ? 'Low SpO2' : 'SpO2')),
                const SizedBox(width: 10),
                Expanded(child: _Metric(icon: Icons.directions_walk_rounded, color: AppColors.success, value: '${v.steps}', label: 'Steps')),
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
            ]),
          ),
          const SizedBox(height: 26),
        ],
        const _Title('Recent vitals'),
        if (data.vitals.isEmpty)
          const _Quiet(icon: Icons.monitor_heart_outlined, title: 'No readings yet')
        else
          Container(
            decoration: _panel(),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              for (var i = 0; i < data.vitals.length && i < 8; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 18, endIndent: 18, color: AppColors.line),
                _VitalRow(r: data.vitals[i]),
              ],
            ]),
          ),
        const SizedBox(height: 26),
        const _Title('Symptoms reported'),
        if (data.symptoms.isEmpty)
          const _Quiet(icon: Icons.sentiment_satisfied_alt_rounded, title: 'None reported')
        else
          ...data.symptoms.map((s) {
            final c = severityScaleColor(s.severity);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: _panel(c),
                padding: const EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(c, Colors.white, 0.12)!, c]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: c.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${s.severity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, height: 1)),
                      const Text('/5', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 9.5)),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(s.symptom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                        Text(Fmt.timeAgo(s.time), style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ]),
                      if (s.note.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(s.note, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.35)),
                      ],
                    ]),
                  ),
                ]),
              ),
            );
          }),
      ], stepMs: 55),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _Metric({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.textFaint, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _VitalRow extends StatelessWidget {
  final VitalReading r;
  const _VitalRow({required this.r});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: r.isAbnormal ? AppColors.danger : AppColors.success)),
        const SizedBox(width: 14),
        const Icon(Icons.favorite_rounded, color: AppColors.coral, size: 16),
        const SizedBox(width: 6),
        Text('${r.heartRate}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
        const Text(' bpm', style: TextStyle(color: AppColors.textFaint, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 18),
        const Icon(Icons.air_rounded, color: AppColors.info, size: 16),
        const SizedBox(width: 6),
        Text('${r.oxygenLevel}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
        const Spacer(),
        Text(Fmt.timeAgo(r.time), style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Visits tab
// ═════════════════════════════════════════════════════════════════════════

class _ApptTab extends StatelessWidget {
  final AppData data;
  const _ApptTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final list = data.upcomingAppointments;
    final today = DateTime.now();
    final day0 = DateTime(today.year, today.month, today.day);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 60),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: staggered([
        _Title('Upcoming appointments', trailing: list.isEmpty ? null : '${list.length}'),
        if (list.isEmpty)
          const _Quiet(icon: Icons.event_available_rounded, title: 'Nothing scheduled', subtitle: 'New appointments will show up here.')
        else
          ...list.map((a) {
            final days = DateTime(a.dateTime.year, a.dateTime.month, a.dateTime.day).difference(day0).inDays;
            final when = days <= 0 ? 'Today' : (days == 1 ? 'Tomorrow' : 'In $days days');
            final soon = days <= 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
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
                      Text(Fmt.monthShort(a.dateTime).toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      Text('${a.dateTime.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 23, height: 1.1)),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      MedTag(label: when, color: soon ? AppColors.warning : AppColors.info, solid: soon),
                      const SizedBox(height: 6),
                      Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textFaint),
                        const SizedBox(width: 4),
                        Text(Fmt.time12(a.dateTime), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        if (a.location.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.place_rounded, size: 13, color: AppColors.textFaint),
                          const SizedBox(width: 3),
                          Expanded(child: Text(a.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5))),
                        ],
                      ]),
                    ]),
                  ),
                ]),
              ),
            );
          }),
      ], stepMs: 55),
    );
  }
}
