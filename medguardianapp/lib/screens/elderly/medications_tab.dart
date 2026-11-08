import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/med_visuals.dart';
import 'add_edit_medication_screen.dart';
import 'medication_detail_screen.dart';

class MedicationsTab extends StatelessWidget {
  const MedicationsTab({super.key});

  void _add(BuildContext context) => Navigator.push(context, slideFadeRoute(const AddEditMedicationScreen()));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final meds = data.medications;
        final today = data.todayLogs();
        final pendingToday = today.where((d) => d.status == DoseStatus.pending).toList()..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
        final takenToday = today.where((d) => d.status == DoseStatus.taken).length;
        final lowStock = meds.where((m) => m.stock <= 8).length;
        final progress = today.isEmpty ? 0.0 : takenToday / today.length;
        final next = pendingToday.isEmpty ? null : pendingToday.first;

        return PageShell(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: meds.isEmpty
                ? null
                : FadeSlideIn(
                    delayMs: 450,
                    beginOffset: const Offset(0, 0.6),
                    child: _AddFab(onTap: () => _add(context)),
                  ),
            body: ListView(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              children: [
                HeroHeader(
                  bottomRadius: 40,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeSlideIn(
                        child: Text(Fmt.fullDate(DateTime.now()).toUpperCase(), style: const TextStyle(color: AppColors.mint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
                      ),
                      const SizedBox(height: 4),
                      const FadeSlideIn(
                        delayMs: 50,
                        child: Text('Your medicines', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.9)),
                      ),
                      const SizedBox(height: 20),
                      FadeSlideIn(
                        delayMs: 120,
                        child: _TodayCard(progress: progress, taken: takenToday, total: today.length, next: next, nextMed: next == null ? null : data.medicationById(next.medicationId)),
                      ),
                      const SizedBox(height: 12),
                      FadeSlideIn(
                        delayMs: 190,
                        child: Row(children: [
                          _HeroStat(
                            value: meds.length,
                            label: 'In cabinet',
                            icon: Icons.medication_rounded,
                            title: 'Medicines in your cabinet',
                            explain: 'How many different medicines you have added to MedGuardian. Each one has its own reminder times.',
                          ),
                          const SizedBox(width: 10),
                          _HeroStat(
                            value: pendingToday.length,
                            label: 'Left today',
                            icon: Icons.schedule_rounded,
                            title: 'Doses still to take today',
                            explain: 'Doses scheduled for today that are not recorded yet. Each one unlocks 15 minutes before its time.',
                          ),
                          const SizedBox(width: 10),
                          _HeroStat(
                            value: lowStock,
                            label: 'Running low',
                            icon: Icons.inventory_2_rounded,
                            warn: lowStock > 0,
                            title: 'Medicines running low',
                            explain: 'Medicines with 8 or fewer tablets left. Refill these soon so you never run out.',
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
                PageBody(
                  top: 26,
                  children: staggered([
                    if (pendingToday.isNotEmpty) ...[
                      _Header(title: 'Still to take today', count: pendingToday.length),
                      ...pendingToday.map((d) {
                        final med = data.medicationById(d.medicationId);
                        if (med == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DoseTile(medication: med, dose: d, onTaken: () => data.updateDoseStatus(d.id, DoseStatus.taken), onMissed: () => data.updateDoseStatus(d.id, DoseStatus.missed)),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                    _Header(title: 'Medicine cabinet', count: meds.length),
                    if (meds.isEmpty) _EmptyCabinet(onAdd: () => _add(context)),
                    if (meds.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 10),
                        child: Row(children: [
                          Icon(Icons.swipe_left_rounded, size: 14, color: AppColors.textFaint),
                          SizedBox(width: 6),
                          Text('Swipe a medicine left to delete it', style: TextStyle(color: AppColors.textFaint, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    if (meds.isNotEmpty)
                      ...meds.map((m) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _SwipeToDelete(medication: m, child: _MedCard(medication: m)))),
                  ], stepMs: 60),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Hero pieces ────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  final double progress;
  final int taken;
  final int total;
  final DoseLog? next;
  final Medication? nextMed;
  const _TodayCard({required this.progress, required this.taken, required this.total, required this.next, required this.nextMed});

  String _inLabel(DateTime t) {
    final diff = t.difference(DateTime.now());
    if (diff.isNegative) return 'due now';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m == 0 ? 'in ${h}h' : 'in ${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final allDone = total > 0 && next == null;
    final String headline = total == 0 ? 'No doses today' : (allDone ? 'All done for today' : '$taken of $total taken');
    return GlassCard(
      radius: 26,
      opacity: 0.10,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        AdherenceRing(
          value: total == 0 ? 0 : progress,
          size: 84,
          onDark: true,
          center: allDone
              ? const Icon(Icons.check_rounded, color: AppColors.mint, size: 34)
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedNumber(end: taken.toDouble(), builder: (v) => v.round().toString(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1)),
                  Text('of $total', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("TODAY'S PROGRESS", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(headline, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 10),
            if (next != null && nextMed != null)
              Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.14))),
                child: Row(children: [
                  MedThumb.of(nextMed!, size: 30, shadow: false),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(nextMed!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 6),
                  Text(_inLabel(next!.scheduledTime), style: const TextStyle(color: AppColors.mint, fontWeight: FontWeight.w800, fontSize: 12)),
                ]),
              )
            else
              Text(
                total == 0 ? 'Add a medicine to start your daily plan.' : 'Great work — every dose is logged.',
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12.5, height: 1.35),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final bool warn;
  final String title;
  final String explain;
  const _HeroStat({required this.value, required this.label, required this.icon, required this.title, required this.explain, this.warn = false});

  void _showInfo(BuildContext context) {
    final accent = warn ? AppColors.accent : AppColors.primary;
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3))),
              Text('$value', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: accent)),
            ]),
            const SizedBox(height: 14),
            Text(explain, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.45)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = warn ? AppColors.accent : AppColors.mint;
    return Expanded(
      child: GlassCard(
        radius: 20,
        opacity: 0.08,
        onTap: () => _showInfo(context),
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: accent.withOpacity(0.18), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 15, color: accent),
            ),
            const Spacer(),
            Icon(Icons.info_outline_rounded, size: 14, color: Colors.white.withOpacity(0.45)),
          ]),
          const SizedBox(height: 10),
          AnimatedNumber(
            end: value.toDouble(),
            builder: (v) => v.round().toString(),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.05, fontFeatures: [ui.FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.2)),
        ]),
      ),
    );
  }
}

class _AddFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 22, 14),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [BoxShadow(color: AppColors.primaryDark.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 12))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(gradient: AppColors.sunGradient, shape: BoxShape.circle),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Add medicine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.1)),
        ]),
      ),
    );
  }
}

// ── Body pieces ────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final int count;
  const _Header({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(children: [
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ]),
    );
  }
}

class _MedCard extends StatelessWidget {
  final Medication medication;
  const _MedCard({required this.medication});

  @override
  Widget build(BuildContext context) {
    final m = medication;
    final low = m.stock <= 8;
    final days = daysOfSupply(m);
    final stockColor = low ? AppColors.warning : m.color;
    return Pressable(
      scaleTo: 0.975,
      onTap: () => Navigator.push(context, slideFadeRoute(MedicationDetailScreen(medicationId: m.id))),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.line.withOpacity(0.7)),
          boxShadow: AppColors.softShadow(m.color),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(children: [
            // Colour wash in the corner keyed to the medicine's colour.
            Positioned(
              right: -40,
              top: -60,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [m.color.withOpacity(0.13), m.color.withOpacity(0)])),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Hero(tag: 'med-icon-${m.id}', child: MedThumb.of(m, size: 64, radius: 20)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.4, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(m.dosage, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        MedTag(label: '${m.times.length}× daily', color: m.color, icon: Icons.repeat_rounded),
                        if (low) const MedTag(label: 'Refill soon', color: AppColors.warning, icon: Icons.warning_amber_rounded),
                      ]),
                    ]),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                  ),
                ]),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final t in m.times)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(_periodIcon(t.hour), size: 14, color: m.color),
                              const SizedBox(width: 6),
                              Text(t.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: StockBar(stock: m.stock, color: stockColor)),
                  const SizedBox(width: 12),
                  Text(
                    days == null ? '${m.stock} left' : '${m.stock} left · $days ${days == 1 ? 'day' : 'days'}',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: low ? AppColors.warning : AppColors.textFaint),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Sun / moon style icon for a reminder hour.
IconData _periodIcon(int hour) {
  if (hour >= 5 && hour < 12) return Icons.wb_sunny_rounded;
  if (hour >= 12 && hour < 17) return Icons.light_mode_rounded;
  if (hour >= 17 && hour < 21) return Icons.wb_twilight_rounded;
  return Icons.nightlight_round;
}

class _EmptyCabinet extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCabinet({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line.withOpacity(0.7)),
        boxShadow: AppColors.softShadow(),
      ),
      child: Column(children: [
        Floating(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 12))],
            ),
            child: const Icon(Icons.medication_rounded, color: AppColors.mint, size: 40),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Your cabinet is empty', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        const Text(
          'Add your first medicine with a photo of the pack, and we will remind you at the right times.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.45),
        ),
        const SizedBox(height: 20),
        GradientButton(label: 'Add medicine', icon: Icons.add_rounded, onPressed: onAdd, height: 54),
      ]),
    );
  }
}


/// Swipe a cabinet card left to delete the medicine (with confirmation,
/// since it also removes its dose history and photo).
class _SwipeToDelete extends StatelessWidget {
  final Medication medication;
  final Widget child;
  const _SwipeToDelete({required this.medication, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('med-${medication.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 30),
            title: Text('Delete ${medication.name}?'),
            content: const Text('This removes the medicine, its reminders, photo and dose history. It cannot be undone.', style: TextStyle(height: 1.4)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800))),
            ],
          ),
        );
        return ok == true;
      },
      onDismissed: (_) async {
        try {
          await AppData.instance.deleteMedication(medication.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${medication.name} deleted')));
          }
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [AppColors.danger.withOpacity(0.9), AppColors.danger.withOpacity(0.55)]),
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.delete_rounded, color: Colors.white, size: 26),
          SizedBox(height: 4),
          Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ]),
      ),
      child: child,
    );
  }
}
