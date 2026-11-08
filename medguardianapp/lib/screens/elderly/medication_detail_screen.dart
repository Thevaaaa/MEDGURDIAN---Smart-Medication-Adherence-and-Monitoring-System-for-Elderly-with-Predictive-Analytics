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

class MedicationDetailScreen extends StatelessWidget {
  final String medicationId;
  const MedicationDetailScreen({super.key, required this.medicationId});

  Future<void> _delete(BuildContext context, Medication med) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove medicine?'),
        content: Text('This removes ${med.name}, its photo and its dose history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok == true) {
      await AppData.instance.deleteMedication(med.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _openPhoto(BuildContext context, Medication med) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => _PhotoViewer(med: med),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final med = data.medicationById(medicationId);
        if (med == null) {
          return const Scaffold(body: Center(child: Text('Medication removed')));
        }

        final now = DateTime.now();
        final medLogs = data.doseLogs.where((d) => d.medicationId == med.id).toList();
        final weekStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        final weekDone = medLogs.where((d) => d.status != DoseStatus.pending && !d.scheduledTime.isBefore(weekStart)).toList();
        final weekTaken = weekDone.where((d) => d.status == DoseStatus.taken).length;
        final adherence = weekDone.isEmpty ? null : weekTaken / weekDone.length;

        final last7 = List.generate(7, (i) {
          final day = now.subtract(Duration(days: 6 - i));
          final logs = medLogs.where((d) => Fmt.isSameDay(d.scheduledTime, day) && d.status != DoseStatus.pending);
          if (logs.isEmpty) return 0.02;
          return logs.where((d) => d.status == DoseStatus.taken).length / logs.length;
        });
        final labels = List.generate(7, (i) => Fmt.weekdayShort(now.subtract(Duration(days: 6 - i))).substring(0, 2));

        final todays = medLogs.where((d) => Fmt.isSameDay(d.scheduledTime, now)).toList();
        final recent = medLogs.where((d) => d.status != DoseStatus.pending).toList()..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
        final low = med.stock <= 8;
        final days = daysOfSupply(med);
        final dark = Color.lerp(med.color, Colors.black, 0.55)!;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: AppColors.background,
            bottomNavigationBar: _BottomBar(
              color: med.color,
              onEdit: () => Navigator.push(context, slideFadeRoute(AddEditMedicationScreen(existing: med))),
              onDelete: () => _delete(context, med),
            ),
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  stretch: true,
                  expandedHeight: med.hasPhoto ? 380 : 320,
                  backgroundColor: dark,
                  foregroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  systemOverlayStyle: SystemUiOverlayStyle.light,
                  automaticallyImplyLeading: false,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context)),
                  ),
                  leadingWidth: 60,
                  title: _CollapsedTitle(name: med.name),
                  actions: [
                    if (med.hasPhoto) _GlassIconButton(icon: Icons.open_in_full_rounded, onTap: () => _openPhoto(context, med)),
                    const SizedBox(width: 8),
                    _GlassIconButton(icon: Icons.edit_rounded, onTap: () => Navigator.push(context, slideFadeRoute(AddEditMedicationScreen(existing: med)))),
                    const SizedBox(width: 12),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    stretchModes: const [StretchMode.zoomBackground],
                    background: _HeroBackdrop(med: med, onPhotoTap: med.hasPhoto ? () => _openPhoto(context, med) : null),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: staggered([
                        Row(children: [
                          _StatTile(
                            icon: Icons.verified_rounded,
                            color: adherence == null ? AppColors.textFaint : AppColors.riskColor(1 - adherence),
                            value: adherence == null ? '—' : '${(adherence * 100).round()}%',
                            label: '7-day adherence',
                          ),
                          const SizedBox(width: 10),
                          _StatTile(icon: Icons.repeat_rounded, color: med.color, value: '${med.times.length}×', label: 'Per day'),
                          const SizedBox(width: 10),
                          _StatTile(
                            icon: Icons.event_available_rounded,
                            color: low ? AppColors.warning : AppColors.info,
                            value: days == null ? '—' : '$days',
                            label: days == 1 ? 'Day of supply' : 'Days of supply',
                          ),
                        ]),
                        const SizedBox(height: 22),
                        if (med.instructions.isNotEmpty) ...[
                          _InstructionCard(text: med.instructions, color: med.color),
                          const SizedBox(height: 26),
                        ],
                        const _SectionTitle('Today\'s schedule'),
                        _ScheduleTimeline(med: med, todays: todays),
                        const SizedBox(height: 26),
                        const _SectionTitle('Last 7 days'),
                        _Panel(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(adherence == null ? 'No doses logged yet' : '$weekTaken of ${weekDone.length} doses taken',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                              const Spacer(),
                              const _Legend(color: AppColors.success, label: 'On track'),
                            ]),
                            const SizedBox(height: 14),
                            WeeklyBars(values: last7, labels: labels),
                          ]),
                        ),
                        const SizedBox(height: 26),
                        const _SectionTitle('Stock'),
                        _StockPanel(med: med, low: low, days: days),
                        if (recent.isNotEmpty) ...[
                          const SizedBox(height: 26),
                          const _SectionTitle('Recent activity'),
                          _Panel(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(children: [
                              for (var i = 0; i < recent.length && i < 6; i++) ...[
                                if (i > 0) const Divider(height: 1, indent: 64, color: AppColors.line),
                                _HistoryRow(log: recent[i]),
                              ],
                            ]),
                          ),
                        ],
                      ], stepMs: 55),
                    ),
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

// ═════════════════════════════════════════════════════════════════════════
// Hero
// ═════════════════════════════════════════════════════════════════════════

class _HeroBackdrop extends StatelessWidget {
  final Medication med;
  final VoidCallback? onPhotoTap;
  const _HeroBackdrop({required this.med, this.onPhotoTap});

  @override
  Widget build(BuildContext context) {
    final dark = Color.lerp(med.color, Colors.black, 0.55)!;
    return Stack(fit: StackFit.expand, children: [
      if (med.hasPhoto)
        GestureDetector(
          onTap: onPhotoTap,
          child: Image.network(
            med.photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [med.color, dark]))),
          ),
        )
      else
        AuroraBackground(
          base: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(med.color, Colors.white, 0.08)!, med.color, dark]),
          blobs: [Colors.white, AppColors.mint, Color.lerp(med.color, Colors.white, 0.4)!],
          child: Stack(children: [
            Positioned(
              right: -40,
              top: 50,
              child: Floating(amplitude: 8, child: Icon(med.icon, size: 230, color: Colors.white.withOpacity(0.08))),
            ),
          ]),
        ),
      // Legibility scrim.
      IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.35, 1],
              colors: [Colors.black.withOpacity(0.35), Colors.transparent, dark.withOpacity(med.hasPhoto ? 0.95 : 0.6)],
            ),
          ),
        ),
      ),
      Positioned(
        left: 22,
        right: 22,
        bottom: 24,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!med.hasPhoto) ...[
            FadeSlideIn(child: Hero(tag: 'med-icon-${med.id}', child: MedThumb.of(med, size: 76, radius: 24))),
            const SizedBox(height: 16),
          ],
          FadeSlideIn(
            delayMs: 80,
            child: Text(med.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1)),
          ),
          const SizedBox(height: 6),
          FadeSlideIn(
            delayMs: 130,
            child: Text(med.dosage, style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 15.5, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delayMs: 180,
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in med.times) _HeroChip(icon: Icons.access_time_filled_rounded, label: t.label),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.22))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Pressable(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.18), border: Border.all(color: Colors.white.withOpacity(0.25))),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

/// Title that fades in only once the header has collapsed.
class _CollapsedTitle extends StatelessWidget {
  final String name;
  const _CollapsedTitle({required this.name});

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    var t = 1.0;
    if (settings != null && settings.maxExtent > settings.minExtent) {
      t = ((settings.maxExtent - settings.currentExtent) / (settings.maxExtent - settings.minExtent)).clamp(0.0, 1.0);
    }
    return AnimatedOpacity(
      opacity: t > 0.85 ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Body sections
// ═════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.textPrimary)),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(18), this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line.withOpacity(0.7)),
        boxShadow: AppColors.softShadow(tint),
      ),
      child: child,
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatTile({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line.withOpacity(0.7)),
          boxShadow: AppColors.softShadow(color),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final String text;
  final Color color;
  const _InstructionCard({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.12), color.withOpacity(0.04)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.tips_and_updates_rounded, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HOW TO TAKE', style: TextStyle(color: Color.lerp(color, Colors.black, 0.2), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(height: 1.45, fontSize: 14.5, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }
}

class _ScheduleTimeline extends StatelessWidget {
  final Medication med;
  final List<DoseLog> todays;
  const _ScheduleTimeline({required this.med, required this.todays});

  @override
  Widget build(BuildContext context) {
    final times = [...med.times]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return _Panel(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(children: [
        for (var i = 0; i < times.length; i++)
          _timelineRow(
            times[i],
            _statusFor(times[i]),
            isFirst: i == 0,
            isLast: i == times.length - 1,
          ),
      ]),
    );
  }

  DoseStatus? _statusFor(MedTime t) {
    for (final d in todays) {
      if (d.scheduledTime.hour == t.hour && d.scheduledTime.minute == t.minute) return d.status;
    }
    return null;
  }

  Widget _timelineRow(MedTime t, DoseStatus? status, {required bool isFirst, required bool isLast}) {
    final now = TimeOfDay.now();
    final upcoming = (t.hour * 60 + t.minute) > (now.hour * 60 + now.minute);
    late final Color c;
    late final IconData icon;
    late final String label;
    switch (status) {
      case DoseStatus.taken:
        c = AppColors.success;
        icon = Icons.check_rounded;
        label = 'Taken';
      case DoseStatus.missed:
        c = AppColors.danger;
        icon = Icons.close_rounded;
        label = 'Missed';
      case DoseStatus.skipped:
        c = AppColors.textFaint;
        icon = Icons.redo_rounded;
        label = 'Skipped';
      case DoseStatus.pending:
      case null:
        c = upcoming ? med.color : AppColors.warning;
        icon = upcoming ? Icons.schedule_rounded : Icons.notifications_active_rounded;
        label = upcoming ? 'Upcoming' : 'Due';
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 34,
          child: Column(children: [
            Expanded(child: Container(width: 2, color: isFirst ? Colors.transparent : AppColors.line)),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c.withOpacity(status == DoseStatus.taken ? 1 : 0.13),
                shape: BoxShape.circle,
                boxShadow: status == DoseStatus.taken ? [BoxShadow(color: c.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))] : null,
              ),
              child: Icon(icon, size: 16, color: status == DoseStatus.taken ? Colors.white : c),
            ),
            Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : AppColors.line)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, letterSpacing: -0.3, color: AppColors.textPrimary)),
                  Text(med.dosage, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                ]),
              ),
              MedTag(label: label, color: c),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _StockPanel extends StatelessWidget {
  final Medication med;
  final bool low;
  final int? days;
  const _StockPanel({required this.med, required this.low, required this.days});

  Future<void> _set(BuildContext context, int stock) async {
    HapticFeedback.selectionClick();
    try {
      await AppData.instance.setMedicationStock(med.id, stock);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update stock: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = low ? AppColors.warning : med.color;
    return _Panel(
      tint: c,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          AnimatedNumber(
            end: med.stock.toDouble(),
            builder: (v) => v.round().toString(),
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.4, height: 1, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: Text('remaining', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          if (low) const MedTag(label: 'Refill soon', color: AppColors.warning, icon: Icons.warning_amber_rounded, solid: true),
        ]),
        const SizedBox(height: 14),
        StockBar(stock: med.stock, color: c, height: 10),
        const SizedBox(height: 10),
        Text(
          days == null ? 'No reminder times set.' : (days == 0 ? 'You have run out — refill today.' : 'Enough for about $days ${days == 1 ? 'day' : 'days'} at ${med.times.length}× daily.'),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        Row(children: [
          _StockButton(icon: Icons.remove_rounded, label: '1', onTap: med.stock == 0 ? null : () => _set(context, med.stock - 1)),
          const SizedBox(width: 8),
          _StockButton(icon: Icons.add_rounded, label: '1', onTap: () => _set(context, med.stock + 1)),
          const SizedBox(width: 8),
          Expanded(
            child: Pressable(
              onTap: () => _set(context, med.stock + 30),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color.lerp(med.color, Colors.white, 0.1)!, Color.lerp(med.color, Colors.black, 0.15)!]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: med.color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 17),
                  SizedBox(width: 7),
                  Text('Refill +30', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _StockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _StockButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: AppColors.textPrimary),
            const SizedBox(width: 2),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ]),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final DoseLog log;
  const _HistoryRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final (Color c, IconData icon, String label) = switch (log.status) {
      DoseStatus.taken => (AppColors.success, Icons.check_circle_rounded, 'Taken'),
      DoseStatus.missed => (AppColors.danger, Icons.cancel_rounded, 'Missed'),
      DoseStatus.skipped => (AppColors.textFaint, Icons.redo_rounded, 'Skipped'),
      DoseStatus.pending => (AppColors.warning, Icons.schedule_rounded, 'Pending'),
    };
    final when = log.actionTime;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 18, color: c),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Fmt.dateTime(log.scheduledTime), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
            if (when != null && log.status == DoseStatus.taken)
              Text('Logged at ${Fmt.time12(when)}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ]),
        ),
        Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12.5)),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _BottomBar({required this.color, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(children: [
            Pressable(
              onTap: onDelete,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                label: 'Edit medicine',
                icon: Icons.edit_rounded,
                height: 54,
                gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.05)!, Color.lerp(color, Colors.black, 0.3)!]),
                onPressed: onEdit,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Full-screen photo viewer
// ═════════════════════════════════════════════════════════════════════════

class _PhotoViewer extends StatelessWidget {
  final Medication med;
  const _PhotoViewer({required this.med});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(child: Image.network(med.photoUrl, fit: BoxFit.contain)),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _GlassIconButton(icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(med.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
