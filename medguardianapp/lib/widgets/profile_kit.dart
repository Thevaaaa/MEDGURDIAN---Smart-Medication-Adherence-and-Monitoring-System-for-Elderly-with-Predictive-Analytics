import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';

// ═════════════════════════════════════════════════════════════════════════
// Profile kit — premium building blocks shared by both Profile tabs.
// Grouped "inset" settings lists, a luminous identity hero and a glass
// stats strip, styled after high-end native settings screens.
// ═════════════════════════════════════════════════════════════════════════

/// Soft glowing halo behind the profile avatar.
class AvatarHalo extends StatelessWidget {
  final Widget child;
  final double size;
  const AvatarHalo({super.key, required this.child, this.size = 140});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Breathing(
            minScale: 0.94,
            maxScale: 1.04,
            duration: const Duration(milliseconds: 3200),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.mint.withOpacity(0.38), AppColors.mint.withOpacity(0.0)]),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Small pill shown under the name: role / verification badge.
class RoleBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const RoleBadge({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.mint.withOpacity(0.22), AppColors.mint.withOpacity(0.08)]),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.mint.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.mint),
        const SizedBox(width: 6),
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ]),
    );
  }
}

/// One cell of the [ProfileStatsStrip].
class ProfileStat {
  final String value;
  final String label;
  const ProfileStat(this.value, this.label);
}

/// Frosted strip of 2–4 headline numbers with hairline dividers.
class ProfileStatsStrip extends StatelessWidget {
  final List<ProfileStat> stats;
  const ProfileStatsStrip({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) cells.add(Container(width: 1, height: 34, color: Colors.white.withOpacity(0.14)));
      cells.add(Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(stats[i].value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6, fontFeatures: [ui.FontFeature.tabularFigures()])),
          const SizedBox(height: 2),
          Text(stats[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.62), fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      ));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.14), Colors.white.withOpacity(0.06)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(children: cells),
        ),
      ),
    );
  }
}

/// Circular frosted icon button for the hero top bar.
class HeroIconButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  const HeroIconButton({super.key, required this.icon, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 14),
        width: label == null ? 40 : null,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 17),
          if (label != null) ...[
            const SizedBox(width: 7),
            Text(label!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ]),
      ),
    );
  }
}

/// Grouped inset list: small-caps label, a single rounded card, and rows
/// separated by hairlines that start after the icon column.
class SettingsGroup extends StatelessWidget {
  final String? label;
  final String? footer;
  final List<Widget> children;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SettingsGroup({super.key, this.label, this.footer, required this.children, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Padding(padding: EdgeInsets.only(left: 66), child: Divider(height: 1, thickness: 1, color: AppColors.line)));
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 2, 10),
            child: Row(children: [
              Expanded(child: Text(label!.toUpperCase(), style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.4))),
              if (actionLabel != null)
                Pressable(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.09), borderRadius: BorderRadius.circular(20)),
                    child: Text(actionLabel!, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ),
            ]),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line.withOpacity(0.7)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0B3B38).withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 14)),
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 3, offset: const Offset(0, 1)),
            ],
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Column(children: rows)),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
            child: Text(footer!, style: const TextStyle(color: AppColors.textFaint, fontSize: 12, height: 1.4)),
          ),
      ]),
    );
  }
}

/// Rounded gradient icon tile used at the start of every settings row.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconTile({super.key, required this.icon, required this.color, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, 0.12)!, color]),
        boxShadow: [BoxShadow(color: color.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
    );
  }
}

/// A single row inside a [SettingsGroup].
class SettingsRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final int subtitleLines;

  /// Optional content rendered under the title/subtitle (e.g. chips).
  final Widget? extra;

  const SettingsRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.subtitleLines = 2,
    this.extra,
  });

  /// Convenience: icon-tile leading.
  factory SettingsRow.icon({
    Key? key,
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) =>
      SettingsRow(key: key, leading: IconTile(icon: icon, color: color), title: title, subtitle: subtitle, trailing: trailing, onTap: onTap, titleColor: titleColor);

  /// Convenience: switch row.
  factory SettingsRow.toggle({
    Key? key,
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      SettingsRow(
        key: key,
        leading: IconTile(icon: icon, color: color),
        title: title,
        subtitle: subtitle,
        trailing: Switch(value: value, onChanged: onChanged),
        onTap: () => onChanged(!value),
      );

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(children: [
        leading,
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2, color: titleColor ?? AppColors.textPrimary)),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle!, maxLines: subtitleLines, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.3)),
            ],
            if (extra != null) ...[const SizedBox(height: 10), extra!],
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, splashColor: AppColors.primary.withOpacity(0.06), highlightColor: AppColors.primary.withOpacity(0.04), child: body),
    );
  }
}

/// Trailing chevron for navigational rows.
class RowChevron extends StatelessWidget {
  final String? value;
  const RowChevron({super.key, this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (value != null) Text(value!, style: const TextStyle(color: AppColors.textFaint, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(width: 2),
      const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint, size: 22),
    ]);
  }
}

/// Small status capsule for row trailing slots ("Always on", "Active"…).
class StatusCapsule extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusCapsule({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.11), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Quiet empty row used inside a [SettingsGroup].
class GroupEmptyRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const GroupEmptyRow({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: AppColors.textFaint, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

/// Discreet brand sign-off at the bottom of the Profile tab.
class ProfileFooter extends StatelessWidget {
  const ProfileFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Center(
        child: Column(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.shield_rounded, color: AppColors.mint, size: 18),
          ),
          const SizedBox(height: 10),
          const Text('MedGuardian', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, letterSpacing: -0.2, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          const Text('Care that never sleeps', style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
        ]),
      ),
    );
  }
}
