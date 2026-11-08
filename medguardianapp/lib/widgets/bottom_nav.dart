import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  const NavItem({required this.icon, required this.activeIcon, required this.label, this.badge = 0});
}


class GuardianBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GuardianBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(color: AppColors.deep.withOpacity(0.16), blurRadius: 32, offset: const Offset(0, 14)),
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (i) {
            final selected = i == currentIndex;
            final item = items[i];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!selected) HapticFeedback.selectionClick();
                onTap(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 14, vertical: 13),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.heroGradient : null,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: selected ? [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                          child: Icon(selected ? item.activeIcon : item.icon, key: ValueKey(selected), size: 24, color: selected ? Colors.white : AppColors.textFaint),
                        ),
                        if (item.badge > 0)
                          Positioned(
                            top: -6,
                            right: -8,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.elasticOut,
                              builder: (context, v, child) => Transform.scale(scale: v, child: child),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
                                child: Text(item.badge > 9 ? '9+' : '${item.badge}', style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      child: selected
                          ? Padding(padding: const EdgeInsets.only(left: 9), child: Text(item.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)))
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
