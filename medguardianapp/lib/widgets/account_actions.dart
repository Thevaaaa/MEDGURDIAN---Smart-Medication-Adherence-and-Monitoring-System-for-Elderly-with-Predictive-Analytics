import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../services/app_data.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'profile_kit.dart';

/// Settings-row view of whether push notifications can reach this phone.
/// Offers a one-tap fix when permission is missing or registration stalled.
class NotificationStatusRow extends StatelessWidget {
  const NotificationStatusRow({super.key});

  @override
  Widget build(BuildContext context) {
    final ns = NotificationService.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([ns.permission, ns.tokenRegistered]),
      builder: (context, _) {
        final denied = ns.permission.value == AuthorizationStatus.denied;
        final ok = !denied && ns.tokenRegistered.value;

        final Color c = denied ? AppColors.danger : (ok ? AppColors.success : AppColors.warning);
        final IconData icon = denied ? Icons.notifications_off_rounded : (ok ? Icons.notifications_active_rounded : Icons.sync_rounded);
        final String title = denied ? 'Notifications are off' : (ok ? 'Push notifications' : 'Connecting…');
        final String subtitle = denied
            ? 'Turn them on in Settings → Apps → MedGuardian → Notifications.'
            : (ok ? 'Reminders and alerts will reach this phone' : 'Waiting for permission or a connection');

        Future<void> fix() async {
          final uid = AppData.instance.me?.uid;
          if (uid == null) return;
          if (denied) {
            await ns.refreshPermission();
          } else {
            await ns.registerForUser(uid);
          }
        }

        return SettingsRow.icon(
          icon: icon,
          color: c,
          title: title,
          subtitle: subtitle,
          onTap: ok ? null : fix,
          trailing: ok
              ? const StatusCapsule(label: 'Active', color: AppColors.success, icon: Icons.check_rounded)
              : StatusCapsule(label: denied ? 'Check again' : 'Retry', color: c, icon: Icons.refresh_rounded),
        );
      },
    );
  }
}

/// Sign-out + permanent account deletion (required by app-store policy).
class AccountActions extends StatelessWidget {
  const AccountActions({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      label: 'Account',
      children: [
        SettingsRow.icon(
          icon: Icons.logout_rounded,
          color: AppColors.primaryDark,
          title: 'Sign out',
          subtitle: AppData.instance.me?.email,
          trailing: const RowChevron(),
          onTap: () => _confirmSignOut(context),
        ),
        SettingsRow.icon(
          icon: Icons.delete_outline_rounded,
          color: AppColors.danger,
          title: 'Delete account',
          titleColor: AppColors.danger,
          subtitle: 'Permanently remove your account and data',
          trailing: const RowChevron(),
          onTap: () => showDeleteAccountDialog(context),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will stop receiving reminders and alerts on this phone until you sign in again.', style: TextStyle(height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok == true) await AuthService.instance.signOut();
  }
}

Future<void> showDeleteAccountDialog(BuildContext context) async {
  final pw = TextEditingController();
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This permanently deletes your account and all your data, and unlinks you from everyone. It cannot be undone.', style: TextStyle(height: 1.4)),
          const SizedBox(height: 14),
          if (AuthService.instance.usesGoogleOnly)
            const Text('You will be asked to confirm with your Google account.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
          else
            TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm with your password')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete forever', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await AuthService.instance.deleteAccount(pw.text);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(AuthService.friendlyError(e))));
  }
}
