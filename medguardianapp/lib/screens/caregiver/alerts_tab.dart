import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';

enum _Filter {
  all('All', Icons.inbox_rounded),
  urgent('Urgent', Icons.priority_high_rounded),
  meds('Medicine', Icons.medication_rounded),
  health('Health', Icons.monitor_heart_rounded),
  safety('Safety', Icons.shield_rounded);

  final String label;
  final IconData icon;
  const _Filter(this.label, this.icon);

  bool matches(AlertItem a) => switch (this) {
        _Filter.all => true,
        _Filter.urgent => a.severity == AlertSeverity.critical,
        _Filter.meds => a.type == AlertType.missedDose,
        _Filter.health => a.type == AlertType.abnormalVital || a.type == AlertType.symptom || a.type == AlertType.appointment,
        _Filter.safety => a.type == AlertType.sos || a.type == AlertType.fallDetected || a.type == AlertType.geofence,
      };
}

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  _Filter _filter = _Filter.all;

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (Fmt.isSameDay(d, now)) return 'Today';
    if (Fmt.isSameDay(d, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return '${Fmt.weekday(d)}, ${d.day} ${Fmt.monthShort(d)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final all = data.alerts;
        final unreadAll = all.where((a) => !a.acknowledged).toList();
        final critical = unreadAll.where((a) => a.severity == AlertSeverity.critical).length;
        final handled = all.length - unreadAll.length;

        final visible = all.where(_filter.matches).toList();
        final unread = visible.where((a) => !a.acknowledged).toList();
        final read = visible.where((a) => a.acknowledged).toList();

        // Group handled alerts by day.
        final groups = <String, List<AlertItem>>{};
        for (final a in read) {
          groups.putIfAbsent(_dayLabel(a.time), () => []).add(a);
        }

        return PageShell(
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            children: [
              HeroHeader(
                bottomRadius: 40,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          FadeSlideIn(child: Text('INBOX', style: TextStyle(color: AppColors.mint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6))),
                          SizedBox(height: 3),
                          FadeSlideIn(delayMs: 50, child: Text('Alerts', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.9))),
                        ]),
                      ),
                      // When something is urgent, calling comes first.
                      if (critical > 0 && data.elderly.phone.isNotEmpty)
                        FadeSlideIn(
                          delayMs: 80,
                          child: Pressable(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              launchUrl(Uri(scheme: 'tel', path: data.elderly.phone));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF4CC38A), Color(0xFF2E9461)]),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 5))],
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.call_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(data.elderly.name.trim().isEmpty ? 'Call' : 'Call ${data.elderly.name.trim().split(' ').first}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                              ]),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 18),
                    FadeSlideIn(
                      delayMs: 120,
                      child: Row(children: [
                        _Count(value: unreadAll.length, label: 'Unread', icon: Icons.mark_email_unread_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        _Count(value: critical, label: 'Urgent', icon: Icons.warning_rounded, color: critical > 0 ? AppColors.coral : Colors.white, pulse: critical > 0),
                        const SizedBox(width: 10),
                        _Count(value: handled, label: 'Handled', icon: Icons.task_alt_rounded, color: AppColors.mint),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delayMs: 180,
                      child: SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            for (final f in _Filter.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _FilterChip(
                                  filter: f,
                                  selected: f == _filter,
                                  count: f == _Filter.all ? unreadAll.length : unreadAll.where(f.matches).length,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _filter = f);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PageBody(
                top: 24,
                children: staggered([
                  if (visible.isEmpty)
                    _AllClear(filtered: _filter != _Filter.all),
                  if (unread.isNotEmpty) ...[
                    _GroupLabel(title: 'Needs attention', count: unread.length, color: AppColors.danger, hint: 'Swipe right to acknowledge'),
                    ...unread.map((a) => Padding(padding: const EdgeInsets.only(bottom: 12), child: AlertTile(alert: a, phone: data.elderly.phone, personName: data.elderly.name, onAck: () => data.acknowledgeAlert(a.id)))),
                    const SizedBox(height: 14),
                  ],
                  for (final e in groups.entries) ...[
                    _GroupLabel(title: e.key, count: e.value.length, color: AppColors.textFaint),
                    ...e.value.map((a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: AlertTile(alert: a))),
                    const SizedBox(height: 12),
                  ],
                ], stepMs: 50),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Count extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color color;
  final bool pulse;
  const _Count({required this.value, required this.label, required this.icon, required this.color, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        radius: 20,
        opacity: 0.09,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 15, color: color.withOpacity(0.85)),
            const Spacer(),
            if (pulse) LiveDot(color: color, size: 7),
          ]),
          const SizedBox(height: 10),
          AnimatedNumber(end: value.toDouble(), builder: (v) => v.round().toString(), style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800, height: 1, letterSpacing: -0.6)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final _Filter filter;
  final bool selected;
  final int count;
  final VoidCallback onTap;
  const _FilterChip({required this.filter, required this.selected, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: selected ? Colors.white : Colors.white.withOpacity(0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(filter.icon, size: 15, color: selected ? AppColors.deep : Colors.white70),
          const SizedBox(width: 6),
          Text(filter.label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: selected ? AppColors.deep : Colors.white)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: selected ? AppColors.danger : AppColors.coral.withOpacity(0.9), borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final String? hint;
  const _GroupLabel({required this.title, required this.count, required this.color, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.textPrimary)),
        const SizedBox(width: 6),
        Text('$count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textFaint)),
        const Spacer(),
        if (hint != null) Text(hint!, style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _AllClear extends StatelessWidget {
  final bool filtered;
  const _AllClear({required this.filtered});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 30),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line.withOpacity(0.7)),
        boxShadow: AppColors.softShadow(AppColors.success),
      ),
      child: Column(children: [
        Floating(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.success.withOpacity(0.22), AppColors.success.withOpacity(0.06)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_paused_rounded, color: AppColors.success, size: 38),
          ),
        ),
        const SizedBox(height: 18),
        Text(filtered ? 'Nothing here' : 'All clear', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text(
          filtered ? 'No alerts match this filter.' : "You'll be notified here the moment something needs your attention.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.45),
        ),
      ]),
    );
  }
}
