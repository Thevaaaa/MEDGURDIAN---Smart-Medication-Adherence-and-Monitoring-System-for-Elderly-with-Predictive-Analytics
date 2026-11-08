import 'package:flutter/material.dart';
import '../../services/app_data.dart';
import '../../services/fall_background_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bottom_nav.dart';
import 'elderly_home_tab.dart';
import 'medications_tab.dart';
import 'health_tab.dart';
import 'elderly_profile_tab.dart';
import 'fall_countdown_dialog.dart';

class ElderlyShell extends StatefulWidget {
  const ElderlyShell({super.key});

  @override
  State<ElderlyShell> createState() => _ElderlyShellState();
}

class _ElderlyShellState extends State<ElderlyShell> {
  int _index = 0;
  bool? _lastFallSetting;
  bool? _lastShareSetting;

  final _tabs = const [
    ElderlyHomeTab(),
    MedicationsTab(),
    HealthTab(),
    ElderlyProfileTab(),
  ];

  final _items = const [
    NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    NavItem(icon: Icons.medication_outlined, activeIcon: Icons.medication_rounded, label: 'Medicine'),
    NavItem(icon: Icons.favorite_border_rounded, activeIcon: Icons.favorite_rounded, label: 'Health'),
    NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    FallCoordinator.instance.startWatching();
    AppData.instance.addListener(_syncServices);
    NotificationService.instance.tapTarget.addListener(_onTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncServices();
      _onTap();
    });
  }

  @override
  void dispose() {
    AppData.instance.removeListener(_syncServices);
    NotificationService.instance.tapTarget.removeListener(_onTap);
    FallCoordinator.instance.stopWatching();
    super.dispose();
  }

  /// Start/stop the sensor services to match the user's saved settings —
  /// only when the setting actually changes, since starting the background
  /// service is not free.
  void _syncServices() {
    final el = AppData.instance.elderly;
    if (el.uid.isEmpty) return;
    if (el.fallDetection != _lastFallSetting) {
      _lastFallSetting = el.fallDetection;
      FallBackgroundService.instance.setEnabled(el.fallDetection);
    }
    if (el.shareLocation != _lastShareSetting) {
      _lastShareSetting = el.shareLocation;
      LocationService.instance.setEnabled(el.shareLocation);
    }
  }

  void _onTap() {
    final t = NotificationService.instance.tapTarget.value;
    if (t == null) return;
    NotificationService.instance.tapTarget.value = null;
    if (!mounted) return;
    if (t == 'fall') {
      FallCoordinator.instance.check();
      return;
    }
    setState(() => _index = switch (t) { 'meds' => 1, 'appointments' => 2, 'profile' => 3, _ => 0 });
  }

  @override
  Widget build(BuildContext context) {
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
      bottomNavigationBar: GuardianBottomNav(items: _items, currentIndex: _index, onTap: (i) => setState(() => _index = i)),
    );
  }
}
