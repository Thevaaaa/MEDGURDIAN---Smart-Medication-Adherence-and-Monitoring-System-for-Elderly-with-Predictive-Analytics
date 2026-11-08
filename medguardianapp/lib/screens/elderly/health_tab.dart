import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../services/health_sync_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/health_charts.dart';
import 'log_symptom_screen.dart';
import 'add_appointment_screen.dart';

class HealthTab extends StatefulWidget {
  final int initialTab;
  const HealthTab({super.key, this.initialTab = 0});

  @override
  State<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<HealthTab> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Re-check once a minute so a manual reading visibly expires after an hour.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: PageShell(
            child: Column(
              children: [
                HeroHeader(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                  child: Column(
                    children: [
                      const HeroBar(title: 'Health', subtitle: 'Vitals, symptoms & appointments'),
                      const SizedBox(height: 18),
                      SegmentedTabs(controller: _tab, labels: const ['Vitals', 'Symptoms', 'Visits']),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [_VitalsView(data: data), _SymptomsView(data: data), _AppointmentsView(data: data)],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VitalsView extends StatelessWidget {
  final AppData data;
  const _VitalsView({required this.data});

  @override
  Widget build(BuildContext context) {
    final v = data.latestVital;
    final abnormal = v?.heartAbnormal ?? false;
    final color = abnormal ? AppColors.danger : AppColors.coral;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
      children: staggered([
        if (data.manualReadingExpired) ...[
          _ExpiredNotice(onEnter: () => _showVitalSheet(context)),
          const SizedBox(height: 12),
        ],
        SoftCard(
          shadowTint: color,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Breathing(minScale: 0.9, maxScale: 1.18, duration: const Duration(milliseconds: 800), child: Icon(Icons.favorite_rounded, color: color, size: 24)),
                const SizedBox(width: 8),
                const Text('Heart rate', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                const Spacer(),
                if (v != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: (abnormal ? AppColors.danger : AppColors.success).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Text(abnormal ? (v.heartRate < 50 ? 'Too low' : 'Too high') : 'Normal', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: abnormal ? AppColors.danger : AppColors.success)),
                  ),
              ]),
              const SizedBox(height: 10),
              if (v == null)
                const Text('No reading yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textFaint))
              else ...[
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  AnimatedNumber(end: v.heartRate.toDouble(), builder: (x) => x.round().toString(), style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: -2, height: 1)),
                  const SizedBox(width: 6),
                  const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('bpm', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textFaint))),
                  const Spacer(),
                  Flexible(child: Text('${v.sourceLabel} · ${Fmt.timeAgo(v.time)}${v.fromDevice ? '' : ' · valid ${v.manualMinutesLeft} min more'}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint))),
                ]),
                const SizedBox(height: 10),
                EcgLine(bpm: v.heartRate, color: color, height: 70),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _OxygenTile(v: v)),
          const SizedBox(width: 12),
          Expanded(child: StatPill(icon: Icons.directions_walk_rounded, label: 'Steps', value: v == null || v.steps == 0 ? '—' : '${v.steps}', color: AppColors.success)),
        ]),
        const SizedBox(height: 22),
        if (v != null && v.isAbnormal && data.dismissedWarningVitalId != v.id) ...[
          _VitalWarning(v: v, onDismiss: () => data.dismissVitalWarning(v.id)),
          const SizedBox(height: 14),
        ],
        const _HealthConnectPanel(),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _SyncButton()),
          const SizedBox(width: 10),
          Expanded(child: GradientButton(label: 'Enter manually', icon: Icons.edit_note_rounded, height: 54, onPressed: () => _showVitalSheet(context))),
        ]),
        Center(
          child: TextButton.icon(
            onPressed: () => _showConnectHelp(context),
            icon: const Icon(Icons.watch_rounded, size: 17),
            label: const Text('How to connect a phone or smartwatch', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 14),
        SectionHeader(title: 'Recent readings', icon: Icons.history_rounded, actionLabel: data.vitals.isEmpty ? null : 'Clear', onAction: () => _confirmClearReadings(context)),
        if (data.vitals.isEmpty)
          const EmptyState(icon: Icons.monitor_heart_outlined, title: 'No readings yet', subtitle: 'Record your first reading above.')
        else
          ...data.vitals.take(10).map((r) => _swipeToDelete(r, Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: r.isAbnormal ? AppColors.danger : AppColors.success)),
                    const SizedBox(width: 12),
                    Icon(Icons.favorite_rounded, color: r.heartAbnormal ? AppColors.danger : AppColors.coral, size: 16),
                    const SizedBox(width: 6),
                    Text('${r.heartRate} bpm', style: TextStyle(fontWeight: FontWeight.w800, color: r.heartAbnormal ? AppColors.danger : AppColors.textPrimary)),
                    const SizedBox(width: 16),
                    Icon(Icons.air_rounded, color: r.oxygenLow ? AppColors.danger : AppColors.info, size: 16),
                    const SizedBox(width: 6),
                    Text('${r.oxygenLevel}%', style: TextStyle(fontWeight: FontWeight.w800, color: r.oxygenLow ? AppColors.danger : AppColors.textPrimary)),
                    const Spacer(),
                    Icon(r.fromDevice ? Icons.watch_rounded : Icons.edit_note_rounded, size: 15, color: AppColors.textFaint),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(Fmt.timeAgo(r.time), style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint, fontWeight: FontWeight.w700)),
                        Text(r.sourceLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textFaint)),
                      ]),
                    ),
                  ]),
                ),
              ))),
      ]),
    );
  }
}

class _SymptomsView extends StatelessWidget {
  final AppData data;
  const _SymptomsView({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
      children: staggered([
        GradientButton(label: 'Log a symptom', icon: Icons.add_rounded, gradient: AppColors.sunGradient, onPressed: () => Navigator.push(context, slideFadeRoute(const LogSymptomScreen()))),
        const SizedBox(height: 26),
        const SectionHeader(title: 'History', icon: Icons.history_rounded),
        if (data.symptoms.isEmpty)
          const EmptyState(icon: Icons.sentiment_satisfied_alt_rounded, title: 'No symptoms logged', subtitle: "You're feeling good — keep it that way!")
        else
          ...data.symptoms.map((s) {
            final c = severityScaleColor(s.severity);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                shadowTint: c,
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [c, c.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
                    child: Center(child: Text('${s.severity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.symptom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      if (s.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(s.note, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5))),
                      const SizedBox(height: 3),
                      Text(Fmt.timeAgo(s.time), style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            );
          }),
      ]),
    );
  }
}

class _AppointmentsView extends StatelessWidget {
  final AppData data;
  const _AppointmentsView({required this.data});

  String _countdown(DateTime d) {
    final now = DateTime.now();
    final days = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  @override
  Widget build(BuildContext context) {
    final list = data.upcomingAppointments;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
      children: staggered([
        GradientButton(label: 'Add appointment', icon: Icons.add_rounded, gradient: const LinearGradient(colors: [Color(0xFF3E7CB1), Color(0xFF2B5F8C)]), onPressed: () => Navigator.push(context, slideFadeRoute(const AddAppointmentScreen()))),
        const SizedBox(height: 26),
        const SectionHeader(title: 'Upcoming', icon: Icons.event_rounded),
        if (list.isEmpty)
          const EmptyState(icon: Icons.event_available_rounded, title: 'Nothing scheduled', subtitle: 'Add your next medical appointment.')
        else ...[
          const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('Swipe left to remove an appointment.', style: TextStyle(color: AppColors.textFaint, fontSize: 12))),
          ...list.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Dismissible(
                  key: ValueKey('appt-${a.id}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    HapticFeedback.mediumImpact();
                    data.deleteAppointment(a.id);
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 26),
                    decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.14), borderRadius: BorderRadius.circular(24)),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                  child: SoftCard(
                    shadowTint: AppColors.info,
                    child: Row(children: [
                      Container(
                        width: 58,
                        height: 62,
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3E7CB1), Color(0xFF2B5F8C)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('${a.dateTime.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22, height: 1)),
                          const SizedBox(height: 2),
                          Text(Fmt.monthShort(a.dateTime).toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                        ]),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.place_outlined, size: 14, color: AppColors.textFaint),
                            const SizedBox(width: 3),
                            Expanded(child: Text(a.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5))),
                          ]),
                          const SizedBox(height: 6),
                          Row(children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(9)), child: Text(_countdown(a.dateTime), style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w800, fontSize: 11))),
                            const SizedBox(width: 8),
                            Text(Fmt.time12(a.dateTime), style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ),
              )),
        ],
      ]),
    );
  }
}

Future<void> _showVitalSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => const _VitalSheet(),
  );
}

/// Manual entry with inline validation — errors appear right under the
/// field (a SnackBar would be hidden behind the bottom sheet).
class _VitalSheet extends StatefulWidget {
  const _VitalSheet();

  @override
  State<_VitalSheet> createState() => _VitalSheetState();
}

class _VitalSheetState extends State<_VitalSheet> {
  final _hr = TextEditingController();
  final _spo2 = TextEditingController();
  final _steps = TextEditingController();
  String? _hrError;
  String? _spo2Error;
  String? _stepsError;
  bool _saving = false;
  int _shake = 0;

  @override
  void dispose() {
    _hr.dispose();
    _spo2.dispose();
    _steps.dispose();
    super.dispose();
  }

  String? _checkHr(String t) {
    if (t.trim().isEmpty) return 'Enter your heart rate';
    final v = int.tryParse(t.trim());
    if (v == null) return 'Numbers only, e.g. 72';
    if (v < 20 || v > 250) return 'Heart rate must be between 20 and 250 bpm';
    return null;
  }

  String? _checkSpo2(String t) {
    if (t.trim().isEmpty) return 'Enter your oxygen level';
    final v = int.tryParse(t.trim().replaceAll('%', ''));
    if (v == null) return 'Numbers only, e.g. 97';
    if (v < 50 || v > 100) return 'Oxygen must be between 50 and 100 %';
    return null;
  }

  String? _checkSteps(String t) {
    if (t.trim().isEmpty) return null;
    final v = int.tryParse(t.trim());
    if (v == null || v < 0 || v > 100000) return 'Enter a whole number of steps';
    return null;
  }

  Future<void> _save() async {
    setState(() {
      _hrError = _checkHr(_hr.text);
      _spo2Error = _checkSpo2(_spo2.text);
      _stepsError = _checkSteps(_steps.text);
    });
    if (_hrError != null || _spo2Error != null || _stepsError != null) {
      HapticFeedback.heavyImpact();
      setState(() => _shake++);
      return;
    }
    setState(() => _saving = true);
    try {
      await AppData.instance.addVital(
        heartRate: int.parse(_hr.text.trim()),
        oxygen: int.parse(_spo2.text.trim().replaceAll('%', '')),
        steps: int.tryParse(_steps.text.trim()) ?? 0,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _hrError = 'Could not save: $e';
      });
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    required String? error,
    required String suffix,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: Icon(icon, color: error == null ? color : AppColors.danger),
        errorText: error,
        errorMaxLines: 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 6, 24, MediaQuery.of(context).viewInsets.bottom + 26),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Record a reading', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 4),
            const Text('Copy the numbers from your monitor, oximeter or watch.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 18),
            TweenAnimationBuilder<double>(
              key: ValueKey(_shake),
              tween: Tween(begin: _shake == 0 ? 0 : 1, end: 0),
              duration: const Duration(milliseconds: 420),
              builder: (context, t, child) => Transform.translate(offset: Offset(sin(t * pi * 6) * 8 * t, 0), child: child),
              child: Column(children: [
                _field(
                  controller: _hr,
                  label: 'Heart rate',
                  hint: 'e.g. 72',
                  icon: Icons.favorite_rounded,
                  color: AppColors.coral,
                  error: _hrError,
                  suffix: 'bpm',
                  onChanged: (_) { if (_hrError != null) setState(() => _hrError = _checkHr(_hr.text)); },
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _spo2,
                  label: 'Oxygen level (SpO2)',
                  hint: 'e.g. 97',
                  icon: Icons.air_rounded,
                  color: AppColors.info,
                  error: _spo2Error,
                  suffix: '%',
                  onChanged: (_) { if (_spo2Error != null) setState(() => _spo2Error = _checkSpo2(_spo2.text)); },
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _steps,
                  label: 'Steps today (optional)',
                  hint: 'e.g. 3500',
                  icon: Icons.directions_walk_rounded,
                  color: AppColors.success,
                  error: _stepsError,
                  suffix: 'steps',
                  onChanged: (_) { if (_stepsError != null) setState(() => _stepsError = _checkSteps(_steps.text)); },
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(14)),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: AppColors.info, size: 17),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Normal ranges: heart rate 50–120 bpm at rest, oxygen 95–100 %. Readings outside these alert your caregivers.', style: TextStyle(color: AppColors.info, fontSize: 12, fontWeight: FontWeight.w600, height: 1.4)),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            GradientButton(label: 'Save reading', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// SpO2 tile that flags low oxygen on its own — not only via heart rate.
class _OxygenTile extends StatelessWidget {
  final VitalReading? v;
  const _OxygenTile({required this.v});

  @override
  Widget build(BuildContext context) {
    final low = v?.oxygenLow ?? false;
    final c = low ? AppColors.danger : AppColors.info;
    return SoftCard(
      shadowTint: c,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.air_rounded, color: c, size: 17),
          ),
          const Spacer(),
          if (v != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: (low ? AppColors.danger : AppColors.success).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(low ? (v!.oxygenCritical ? 'Very low' : 'Low') : 'Normal', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: low ? AppColors.danger : AppColors.success)),
            ),
        ]),
        const SizedBox(height: 10),
        Text(v == null ? '—' : '${v!.oxygenLevel}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: low ? AppColors.danger : AppColors.textPrimary)),
        const Text('Oxygen (SpO2)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _VitalWarning extends StatelessWidget {
  final VitalReading v;
  final VoidCallback? onDismiss;
  const _VitalWarning({required this.v, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.danger.withOpacity(0.14), AppColors.danger.withOpacity(0.04)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Your last reading shows ${v.problems.join(' and ')}. Your caregivers have been told. Rest and re-check — call for help if you feel unwell.',
            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13, height: 1.4),
          ),
        ),
        if (onDismiss != null)
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.close_rounded, size: 20, color: AppColors.danger)),
          ),
      ]),
    );
  }
}

/// Pulls the latest heart rate / SpO2 / steps from Health Connect or Apple
/// Health (i.e. from a paired watch, ring or oximeter) and saves them.
class _SyncButton extends StatefulWidget {
  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton> {
  bool _busy = false;

  Future<void> _sync() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final d = await HealthSyncService.instance.readLatest();
      final last = AppData.instance.latestVital;
      await AppData.instance.addVital(
        heartRate: d.heartRate ?? last?.heartRate ?? 0,
        oxygen: d.oxygen ?? last?.oxygenLevel ?? 0,
        steps: d.steps ?? 0,
        time: d.measuredAt,
        source: 'health_connect',
        sourceApp: d.sourceApp,
      );
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(SnackBar(content: Text('Synced from your device${d.heartRate != null ? ' · ${d.heartRate} bpm' : ''}${d.oxygen != null ? ' · ${d.oxygen}% SpO2' : ''}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'How to connect', onPressed: () => _showConnectHelp(context)),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: _busy ? null : _sync,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.4),
          boxShadow: AppColors.softShadow(AppColors.primary),
        ),
        child: Center(
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
              : const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.watch_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Sync device', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15)),
                ]),
        ),
      ),
    );
  }
}


/// Step-by-step guide for linking a phone or smartwatch to MedGuardian.
/// The watch never talks to MedGuardian directly: it syncs to its own app
/// (Samsung Health, Fitbit, Mi Fitness...), that app shares into Health
/// Connect / Apple Health, and MedGuardian reads from there.
void _showConnectHelp(BuildContext context) {
  final ios = Theme.of(context).platform == TargetPlatform.iOS;
  final steps = ios
      ? const [
          ('Open the Health app', 'Apple Watch readings are saved here automatically.'),
          ('Allow MedGuardian', 'Health app → Sharing → Apps → MedGuardian → turn on Heart Rate, Blood Oxygen and Steps.'),
          ('Tap Sync device', 'MedGuardian reads the newest readings and alerts caregivers if they are out of range.'),
        ]
      : const [
          ('Pair your watch with its app', 'e.g. Galaxy Watch → Samsung Health, Fitbit → Fitbit app, Xiaomi/Redmi band → Mi Fitness, Pixel/Wear OS → Fitbit or Google Fit.'),
          ('Turn on Health Connect in that app', 'Samsung Health: Settings → Health Connect → allow Heart rate, Oxygen saturation, Steps. Other apps have a similar "Health Connect" option.'),
          ('Allow MedGuardian in Health Connect', 'Tap Sync device here and allow Heart rate, Oxygen saturation and Steps. (Settings → Health Connect → App permissions → MedGuardian if you closed it.)'),
          ('Measure, then sync', 'Take a heart-rate / SpO2 reading on the watch, wait for it to sync to the phone app, then tap Sync device.'),
        ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.watch_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Text('Connect your phone & watch', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3))),
            ]),
            const SizedBox(height: 6),
            Text(ios ? 'Works with Apple Watch and any device that saves to Apple Health.' : 'Works with any watch or band whose app shares data to Health Connect.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 18),
            for (var i = 0; i < steps.length; i++)
              FadeSlideIn(
                delayMs: i * 70,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
                      child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(steps[i].$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text(steps[i].$2, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                      ]),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 4),
            GradientButton(label: 'Got it', icon: Icons.check_rounded, height: 52, onPressed: () => Navigator.pop(c)),
          ]),
        ),
      ),
    ),
  );
}


// ─────────────────────────────────────────────────────────────────────────
// Health Connect panel — live data from the user's watch / phone
// ─────────────────────────────────────────────────────────────────────────

enum _HcState { checking, notConnected, connected, empty }

/// Shows what Health Connect (Android) / Apple Health (iPhone) currently holds:
/// 24-hour heart-rate and oxygen trends and the last 7 days of steps. It
/// refreshes by itself when the tab opens, every 2 minutes, and when the user
/// comes back from the Health Connect permission screen. A new reading is also
/// saved to the account so caregivers see it, marked as coming from a device.
class _HealthConnectPanel extends StatefulWidget {
  const _HealthConnectPanel();

  @override
  State<_HealthConnectPanel> createState() => _HealthConnectPanelState();
}

class _HealthConnectPanelState extends State<_HealthConnectPanel> with WidgetsBindingObserver {
  _HcState _state = _HcState.checking;
  HealthHistory? _history;
  DateTime? _updatedAt;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  /// [prompt] = true shows the OS permission screen (user tapped Connect).
  Future<void> _load({bool prompt = false}) async {
    if (_busy) return;
    if (mounted) setState(() => _busy = true);
    try {
      final svc = HealthSyncService.instance;
      final ok = prompt ? await svc.requestAccess() : await svc.hasAccess();
      if (!ok) {
        if (mounted) setState(() => _state = _HcState.notConnected);
        return;
      }
      DeviceVitals? latest;
      try {
        latest = await svc.readLatest();
      } catch (_) {
        latest = null; // connected, but nothing recorded in the last 24 h
      }
      final history = await svc.readHistory();
      if (latest != null) await _autoSave(latest);
      if (!mounted) return;
      setState(() {
        _history = history;
        _updatedAt = DateTime.now();
        _state = (latest == null && history.isEmpty) ? _HcState.empty : _HcState.connected;
      });
    } catch (e) {
      debugPrint('Health Connect panel: $e');
      if (mounted && _state == _HcState.checking) setState(() => _state = _HcState.notConnected);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saves a newly measured reading once, so caregivers see it too.
  Future<void> _autoSave(DeviceVitals d) async {
    final data = AppData.instance;
    final at = d.measuredAt ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    if (at.millisecondsSinceEpoch <= (prefs.getInt(kVitalsClearedAtPref) ?? 0)) return; // user cleared these
    final already = data.vitals.any((v) =>
        v.fromDevice && (!at.isAfter(v.time) || DateTime.now().difference(v.time) < const Duration(minutes: 10)));
    if (already) return;
    final last = data.latestVital;
    await data.addVital(
      heartRate: d.heartRate ?? last?.heartRate ?? 0,
      oxygen: d.oxygen ?? last?.oxygenLevel ?? 0,
      steps: d.steps ?? 0,
      time: at,
      source: 'health_connect',
      sourceApp: d.sourceApp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = _state == _HcState.connected || _state == _HcState.empty;
    final subtitle = switch (_state) {
      _HcState.checking => 'Checking…',
      _HcState.notConnected => 'Not connected yet',
      _HcState.empty => 'Connected · no readings in the last 24 h',
      _HcState.connected => _updatedAt == null ? 'Connected' : 'Updated ${Fmt.timeAgo(_updatedAt!)}',
    };
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.watch_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('From your watch & phone', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textFaint, fontWeight: FontWeight.w600)),
            ]),
          ),
          if (connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.13), borderRadius: BorderRadius.circular(10)),
              child: const Text('Connected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.success)),
            ),
          const SizedBox(width: 4),
          if (_busy)
            const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)))
          else if (connected)
            IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary), tooltip: 'Refresh'),
        ]),
        const SizedBox(height: 14),
        if (_state == _HcState.checking)
          const SizedBox(height: 40)
        else if (_state == _HcState.notConnected) ...[
          const Text(
            'Connect Health Connect to see your heart-rate and oxygen trends and daily steps here. Your caregivers also get your newest readings automatically.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 14),
          GradientButton(label: 'Connect Health Connect', icon: Icons.link_rounded, height: 50, onPressed: () => _load(prompt: true)),
          Center(child: TextButton(onPressed: () => _showConnectHelp(context), child: const Text('How to connect a watch', style: TextStyle(fontWeight: FontWeight.w700)))),
        ] else if (_state == _HcState.empty) ...[
          const Text(
            'Nothing recorded yet. Take a heart-rate or SpO2 measurement on your watch, wait for its app to sync, then tap refresh.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
          ),
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => _showConnectHelp(context), child: const Text('How to connect a watch', style: TextStyle(fontWeight: FontWeight.w700)))),
        ] else
          ..._charts(_history!),
      ]),
    );
  }

  List<Widget> _charts(HealthHistory h) {
    final hr = h.heartRate.map((p) => p.value).toList();
    final ox = h.oxygen.map((p) => p.value).toList();
    String range(List<double> v) => v.isEmpty ? '' : '${v.reduce(min).round()}–${v.reduce(max).round()}';
    double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final stepsTotal = h.dailySteps.fold<int>(0, (a, b) => a + b);

    Widget title(IconData icon, Color c, String text, String trailing) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            const Spacer(),
            Text(trailing, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ]),
        );

    Widget empty(String msg) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(msg, style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
        );

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('Data from', style: TextStyle(fontSize: 12, color: AppColors.textFaint, fontWeight: FontWeight.w700)),
          if (h.sources.isEmpty)
            const _SourceChip(label: 'Health Connect')
          else
            for (final src in h.sources) _SourceChip(label: src),
        ]),
      ),
      title(Icons.favorite_rounded, AppColors.coral, 'Heart rate · last 24 h', hr.isEmpty ? '' : 'avg ${avg(hr).round()} · ${range(hr)} bpm'),
      if (hr.length >= 2) TrendLine(values: hr, color: AppColors.coral) else empty('Not enough heart-rate readings in the last 24 hours yet.'),
      const SizedBox(height: 18),
      title(Icons.air_rounded, AppColors.info, 'Oxygen · last 24 h', ox.isEmpty ? '' : 'avg ${avg(ox).round()}% · ${range(ox)}%'),
      if (ox.length >= 2) TrendLine(values: ox, color: AppColors.info, minY: 88, maxY: 100, height: 90) else empty('Not enough oxygen readings in the last 24 hours yet.'),
      const SizedBox(height: 18),
      title(Icons.directions_walk_rounded, AppColors.success, 'Steps · last 7 days', '$stepsTotal total'),
      MiniBars(
        values: h.dailySteps.map((e) => e.toDouble()).toList(),
        labels: [for (final d in h.days) letters[d.weekday - 1]],
        color: AppColors.success,
      ),
      const SizedBox(height: 6),
      const Text('Steps combine every app and your phone\'s own counter in Health Connect.', style: TextStyle(fontSize: 11, color: AppColors.textFaint)),
    ];
  }
}


class _SourceChip extends StatelessWidget {
  final String label;
  const _SourceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.watch_rounded, size: 12, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
      ]),
    );
  }
}

/// Shown when the newest reading was typed in by hand and is over an hour old.
class _ExpiredNotice extends StatelessWidget {
  final VoidCallback onEnter;
  const _ExpiredNotice({required this.onEnter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.timer_off_rounded, color: AppColors.warning),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Your manual reading has expired', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 3),
            const Text('Readings you type in are only valid for 1 hour. Measure again and enter a new one so your caregivers see correct data.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onEnter,
              child: const Text('Enter a new reading', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Swipe a reading to the left to delete it.
Widget _swipeToDelete(VitalReading r, Widget child) {
  return Dismissible(
    key: ValueKey(r.id),
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.16), borderRadius: BorderRadius.circular(24)),
      child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
    ),
    onDismissed: (_) => AppData.instance.deleteVital(r.id),
    child: child,
  );
}

Future<void> _confirmClearReadings(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Clear all readings?'),
      content: const Text('This deletes every saved heart-rate, oxygen and steps reading, for you and your caregivers. Data inside Health Connect is not touched.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await AppData.instance.clearVitals();
    messenger.showSnackBar(const SnackBar(content: Text('Readings cleared')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not clear: $e')));
  }
}
