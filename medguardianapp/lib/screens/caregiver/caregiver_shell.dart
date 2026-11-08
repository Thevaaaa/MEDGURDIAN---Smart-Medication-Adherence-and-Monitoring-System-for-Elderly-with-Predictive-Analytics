import 'package:flutter/material.dart';
import '../../services/app_data.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bottom_nav.dart';
import 'caregiver_home_tab.dart';
import 'alerts_tab.dart';
import 'location_screen.dart';
import 'caregiver_profile_tab.dart';

class CaregiverShell extends StatefulWidget {
  const CaregiverShell({super.key});

  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.tapTarget.addListener(_onTap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTap());
  }

  @override
  void dispose() {
    NotificationService.instance.tapTarget.removeListener(_onTap);
    super.dispose();
  }

  void _onTap() {
    final t = NotificationService.instance.tapTarget.value;
    if (t == null) return;
    NotificationService.instance.tapTarget.value = null;
    if (mounted) setState(() => _index = switch (t) { 'alerts' => 1, 'location' => 2, 'profile' => 3, _ => 0 });
  }

  final _tabs = const [
    CaregiverHomeTab(),
    AlertsTab(),
    LocationScreen(),
    CaregiverProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final unread = AppData.instance.unacknowledgedCount;
        final items = [
          const NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Overview'),
          NavItem(icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded, label: 'Alerts', badge: unread),
          const NavItem(icon: Icons.location_on_outlined, activeIcon: Icons.location_on_rounded, label: 'Location'),
          const NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
        ];
        return Scaffold(
          backgroundColor: AppColors.background,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim), child: child),
            ),
            child: KeyedSubtree(key: ValueKey(_index), child: _tabs[_index]),
          ),
          bottomNavigationBar: GuardianBottomNav(items: items, currentIndex: _index, onTap: (i) => setState(() => _index = i)),
        );
      },
    );
  }
}
