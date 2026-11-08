import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/editable_avatar.dart';
import '../../widgets/profile_kit.dart';
import '../auth/link_person_screen.dart';

class CaregiverProfileTab extends StatelessWidget {
  const CaregiverProfileTab({super.key});

  static const _prefKeys = ['doseReminders', 'missedDose', 'health', 'geofence'];

  void _addPerson(BuildContext context) => Navigator.push(context, slideFadeRoute(const LinkPersonScreen()));

  Future<void> _unlink(BuildContext context, ElderlyProfile d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Unlink ${d.name}?'),
        content: const Text("You'll stop receiving their alerts and won't see their data."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Unlink', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) await AppData.instance.unlinkDependent(d.uid);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final me = data.me;
        final name = (me?.name ?? '').isEmpty ? 'Caregiver' : me!.name;
        final caring = data.dependents.length;
        final alertsOn = 1 + _prefKeys.where(data.notifyPref).length; // SOS & falls are always on

        return PageShell(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              HeroHeader(
                bottomRadius: 40,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(children: [
                  Row(children: [
                    const Expanded(
                      child: FadeSlideIn(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('ACCOUNT', style: TextStyle(color: AppColors.mint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                          SizedBox(height: 2),
                          Text('Profile', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                        ]),
                      ),
                    ),
                    FadeSlideIn(delayMs: 60, child: HeroIconButton(icon: Icons.person_add_alt_1_rounded, label: 'Add', onTap: () => _addPerson(context))),
                  ]),
                  const SizedBox(height: 6),
                  FadeSlideIn(
                    delayMs: 80,
                    child: AvatarHalo(child: EditableAvatar(name: name, color: Colors.white, photoUrl: me?.photoUrl ?? '', radius: 46)),
                  ),
                  FadeSlideIn(
                    delayMs: 140,
                    child: Text(name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
                  ),
                  if ((me?.email ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    FadeSlideIn(delayMs: 180, child: Text(me!.email, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.68), fontSize: 13.5))),
                  ],
                  const SizedBox(height: 12),
                  const FadeSlideIn(delayMs: 210, child: RoleBadge(icon: Icons.volunteer_activism_rounded, label: 'Caregiver')),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delayMs: 250,
                    child: ProfileStatsStrip(stats: [
                      ProfileStat('$caring', caring == 1 ? 'Person' : 'People'),
                      ProfileStat('${data.unacknowledgedCount}', 'Unread alerts'),
                      ProfileStat('$alertsOn/${_prefKeys.length + 1}', 'Alerts on'),
                    ]),
                  ),
                ]),
              ),
              PageBody(
                top: 26,
                children: staggered([
                  SettingsGroup(
                    label: 'People you care for',
                    actionLabel: 'Add',
                    onAction: () => _addPerson(context),
                    children: data.dependents.isEmpty
                        ? const [GroupEmptyRow(icon: Icons.people_outline_rounded, title: 'Nobody linked yet', subtitle: 'Tap Add and enter their 6-digit caregiver code.')]
                        : [
                            for (final d in data.dependents)
                              SettingsRow(
                                leading: InitialsAvatar(name: d.name, color: d.color, photoUrl: d.photoUrl, radius: 20),
                                title: d.name,
                                subtitle: d.conditions.isEmpty ? (d.age > 0 ? '${d.age} years old' : 'No conditions listed') : d.conditions.join(', '),
                                subtitleLines: 1,
                                trailing: IconButton(
                                  tooltip: 'Unlink',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.link_off_rounded, color: AppColors.textFaint, size: 21),
                                  onPressed: () => _unlink(context, d),
                                ),
                              ),
                          ],
                  ),
                  SettingsGroup(
                    label: 'Alert preferences',
                    footer: 'Choose which updates are pushed to your phone. Emergency alerts can never be turned off.',
                    children: [
                      SettingsRow.icon(
                        icon: Icons.sos_rounded,
                        color: AppColors.danger,
                        title: 'SOS & fall alerts',
                        subtitle: 'Always on for their safety',
                        trailing: const StatusCapsule(label: 'Always on', color: AppColors.danger, icon: Icons.lock_rounded),
                      ),
                      SettingsRow.toggle(
                        icon: Icons.medication_rounded,
                        color: AppColors.primary,
                        title: 'Medicine reminders',
                        subtitle: 'When they are reminded to take a dose',
                        value: data.notifyPref('doseReminders'),
                        onChanged: (v) => data.setNotifyPref('doseReminders', v),
                      ),
                      SettingsRow.toggle(
                        icon: Icons.medication_liquid_rounded,
                        color: AppColors.warning,
                        title: 'Missed medication',
                        subtitle: 'When a dose is missed',
                        value: data.notifyPref('missedDose'),
                        onChanged: (v) => data.setNotifyPref('missedDose', v),
                      ),
                      SettingsRow.toggle(
                        icon: Icons.monitor_heart_rounded,
                        color: AppColors.coral,
                        title: 'Symptoms & vitals',
                        subtitle: 'Severe symptoms, abnormal readings',
                        value: data.notifyPref('health'),
                        onChanged: (v) => data.setNotifyPref('health', v),
                      ),
                      SettingsRow.toggle(
                        icon: Icons.location_on_rounded,
                        color: AppColors.info,
                        title: 'Safe zone',
                        subtitle: 'Left or returned home',
                        value: data.notifyPref('geofence'),
                        onChanged: (v) => data.setNotifyPref('geofence', v),
                      ),
                    ],
                  ),
                  const SettingsGroup(label: 'This phone', children: [NotificationStatusRow()]),
                  const AccountActions(),
                  const ProfileFooter(),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}
