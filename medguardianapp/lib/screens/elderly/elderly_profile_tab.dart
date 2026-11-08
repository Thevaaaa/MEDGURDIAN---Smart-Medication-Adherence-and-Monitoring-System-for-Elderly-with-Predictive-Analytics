import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/editable_avatar.dart';
import '../../widgets/profile_kit.dart';
import '../../services/auth_service.dart';
import '../../utils/formatters.dart';
import 'emergency_contacts_screen.dart';

class ElderlyProfileTab extends StatelessWidget {
  const ElderlyProfileTab({super.key});

  Future<void> _editProfile(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => const _EditProfileSheet(),
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    if (!await launchUrl(Uri(scheme: 'tel', path: phone)) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the phone app.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final el = data.elderly;
        final displayName = data.me?.name ?? el.name;
        final email = data.me?.email ?? '';
        final subtitle = [if (el.age > 0) '${el.age} years old', if (email.isNotEmpty) email].join('  ·  ');

        return PageShell(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              HeroHeader(
                bottomRadius: 40,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  children: [
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
                      FadeSlideIn(delayMs: 60, child: HeroIconButton(icon: Icons.edit_rounded, label: 'Edit', onTap: () => _editProfile(context))),
                    ]),
                    const SizedBox(height: 6),
                    FadeSlideIn(
                      delayMs: 80,
                      child: AvatarHalo(child: EditableAvatar(name: displayName, color: Colors.white, photoUrl: el.photoUrl, radius: 46)),
                    ),
                    FadeSlideIn(
                      delayMs: 140,
                      child: Text(displayName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      FadeSlideIn(delayMs: 180, child: Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.68), fontSize: 13.5))),
                    ],
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delayMs: 210,
                      child: RoleBadge(
                        icon: data.caregivers.isEmpty ? Icons.shield_outlined : Icons.verified_user_rounded,
                        label: data.caregivers.isEmpty ? 'Not yet protected' : 'Protected member',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      delayMs: 250,
                      child: ProfileStatsStrip(stats: [
                        ProfileStat('${data.caregivers.length}', data.caregivers.length == 1 ? 'Caregiver' : 'Caregivers'),
                        ProfileStat('${data.medications.length}', data.medications.length == 1 ? 'Medicine' : 'Medicines'),
                        ProfileStat('${el.emergencyContacts.length}', 'SOS contacts'),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(delayMs: 300, child: _CaregiverCodeCard(code: el.linkCode)),
                  ],
                ),
              ),
              PageBody(
                top: 26,
                children: staggered([
                  SettingsGroup(
                    label: 'Your caregivers',
                    footer: data.caregivers.isEmpty ? null : 'Caregivers receive your SOS, fall and missed-dose alerts. Only a caregiver can unlink themselves.',
                    children: data.caregivers.isEmpty
                        ? const [GroupEmptyRow(icon: Icons.people_outline_rounded, title: 'Nobody linked yet', subtitle: 'Share your caregiver code above to add someone.')]
                        : [
                            for (final c in data.caregivers)
                              SettingsRow(
                                leading: InitialsAvatar(name: c.name, color: c.color, photoUrl: c.photoUrl, radius: 20),
                                title: c.name,
                                subtitle: [if (c.relation.isNotEmpty) c.relation, if (c.phone.isNotEmpty) c.phone].join(' · '),
                                // Elderly users can call a caregiver but not remove them.
                                trailing: c.phone.isEmpty
                                    ? null
                                    : Pressable(
                                        onTap: () => _call(context, c.phone),
                                        child: Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: AppColors.success,
                                            shape: BoxShape.circle,
                                            boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                                          ),
                                          child: const Icon(Icons.call_rounded, color: Colors.white, size: 18),
                                        ),
                                      ),
                              ),
                          ],
                  ),
                  SettingsGroup(
                    label: 'Personal details',
                    actionLabel: 'Edit',
                    onAction: () => _editProfile(context),
                    children: [
                      SettingsRow.icon(
                        icon: Icons.phone_rounded,
                        color: AppColors.primary,
                        title: 'Phone',
                        subtitle: el.phone.isEmpty ? 'Required — tap to add' : el.phone,
                        onTap: () => _editProfile(context),
                        trailing: el.phone.isEmpty ? const StatusCapsule(label: 'Add', color: AppColors.danger) : const RowChevron(),
                      ),
                      SettingsRow.icon(
                        icon: Icons.cake_rounded,
                        color: AppColors.accent,
                        title: 'Date of birth',
                        subtitle: el.birthDate == null
                            ? (el.age > 0 ? '${el.age} years · add your birth date' : 'Not added')
                            : '${el.birthDate!.day} ${Fmt.month(el.birthDate!)} ${el.birthDate!.year} · ${el.age} years',
                        onTap: () => _editProfile(context),
                        trailing: const RowChevron(),
                      ),
                      SettingsRow(
                        leading: const IconTile(icon: Icons.healing_rounded, color: AppColors.coral),
                        title: 'Health conditions',
                        subtitle: el.conditions.isEmpty ? 'None added' : null,
                        onTap: () => _editProfile(context),
                        trailing: const RowChevron(),
                        extra: el.conditions.isEmpty ? null : Wrap(spacing: 6, runSpacing: 6, children: el.conditions.map((c) => _ConditionChip(label: c)).toList()),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    label: 'Safety & privacy',
                    children: [
                      SettingsRow.toggle(
                        icon: Icons.location_on_rounded,
                        color: AppColors.info,
                        title: 'Share my location',
                        subtitle: 'Lets caregivers see where you are',
                        value: el.shareLocation,
                        onChanged: (v) => data.setSharing(shareLocation: v),
                      ),
                      SettingsRow.toggle(
                        icon: Icons.personal_injury_rounded,
                        color: AppColors.danger,
                        title: 'Fall detection',
                        subtitle: 'Runs in the background, even when the app is closed',
                        value: el.fallDetection,
                        onChanged: (v) => data.setSharing(fallDetection: v),
                      ),
                      // Read-only: the safe zone is managed by the caregiver.
                      SettingsRow.icon(
                        icon: Icons.home_rounded,
                        color: AppColors.success,
                        title: 'Home safe zone',
                        subtitle: el.hasHome ? (el.homeAddress.isEmpty ? '${el.safeRadiusM.round()} m around your home' : el.homeAddress) : 'Your caregiver has not set it yet',
                        trailing: StatusCapsule(label: el.hasHome ? 'Active' : 'Caregiver sets', color: el.hasHome ? AppColors.success : AppColors.textFaint, icon: el.hasHome ? Icons.check_rounded : Icons.lock_rounded),
                      ),
                    ],
                    footer: 'Your caregiver sets and changes the home safe zone from their app.',
                  ),
                  SettingsGroup(
                    label: 'Emergency contacts',
                    actionLabel: el.emergencyContacts.isEmpty ? 'Add' : 'Manage',
                    onAction: () => Navigator.push(context, slideFadeRoute(const EmergencyContactsScreen())),
                    children: el.emergencyContacts.isEmpty
                        ? const [GroupEmptyRow(icon: Icons.contact_phone_outlined, title: 'None added', subtitle: "People who don't need the app but should be texted if you need urgent help.")]
                        : [
                            for (final c in el.emergencyContacts)
                              SettingsRow(
                                leading: InitialsAvatar(name: c.name, color: AppColors.coral, radius: 20),
                                title: c.name,
                                subtitle: c.relation.isEmpty ? c.phone : '${c.relation} · ${c.phone}',
                                trailing: const RowChevron(),
                                onTap: () => Navigator.push(context, slideFadeRoute(const EmergencyContactsScreen())),
                              ),
                          ],
                  ),
                  const SettingsGroup(label: 'Notifications', children: [NotificationStatusRow()]),
                  SettingsGroup(
                    label: 'Accessibility',
                    children: [
                      SettingsRow.toggle(
                        icon: Icons.format_size_rounded,
                        color: AppColors.primaryDark,
                        title: 'Large text mode',
                        subtitle: 'Makes everything easier to read',
                        value: data.largeText,
                        onChanged: (_) => data.toggleLargeText(),
                      ),
                    ],
                  ),
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

/// Six-slot caregiver link code on frosted glass, with a copy action.
class _CaregiverCodeCard extends StatelessWidget {
  final String code;
  const _CaregiverCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    final digits = code.isEmpty ? '——————' : code.padRight(6).substring(0, 6);
    return GlassCard(
      radius: 22,
      opacity: 0.09,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.link_rounded, color: AppColors.mint, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('CAREGIVER CODE', style: TextStyle(color: Colors.white.withOpacity(0.72), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.4))),
          Pressable(
            onTap: code.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: code));
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: AppColors.mint.withOpacity(0.16), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.mint.withOpacity(0.30))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.copy_rounded, size: 13, color: AppColors.mint),
                SizedBox(width: 5),
                Text('Copy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) SizedBox(width: i == 3 ? 14 : 7),
            Expanded(
              child: AspectRatio(
                aspectRatio: 0.82,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.07)]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: Center(
                    child: Text(digits[i], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        Text('Share this with a family member or carer so they receive your alerts.', style: TextStyle(color: Colors.white.withOpacity(0.62), fontSize: 12.5, height: 1.4)),
      ]),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final String label;
  const _ConditionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.coral.withOpacity(0.22))),
      child: Text(label, style: const TextStyle(color: Color(0xFFC4543F), fontWeight: FontWeight.w700, fontSize: 12.5)),
    );
  }
}


/// Edit-profile sheet: phone is required and age is replaced by a birth date
/// (so the age updates itself every year). Errors show inline.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final AppData _data = AppData.instance;
  late final TextEditingController _name = TextEditingController(text: _data.me?.name ?? _data.elderly.name);
  late final TextEditingController _phone = TextEditingController(text: _data.elderly.phone);
  late final TextEditingController _address = TextEditingController(text: _data.elderly.homeAddress);
  late final TextEditingController _conditions = TextEditingController(text: _data.elderly.conditions.join(', '));
  late DateTime? _birth = _data.elderly.birthDate;
  String? _nameError;
  String? _phoneError;
  String? _birthError;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _conditions]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirth() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - (_data.elderly.age > 0 ? _data.elderly.age : 70), 1, 1),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Your date of birth',
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() {
        _birth = picked;
        _birthError = null;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Please enter your name' : null;
      _phoneError = _phone.text.trim().isEmpty
          ? 'A phone number is required'
          : (AuthService.isValidPhone(_phone.text) ? null : 'Include the country code, e.g. +60 12-345 6789');
      _birthError = _birth == null ? 'Please choose your date of birth' : null;
    });
    if (_nameError != null || _phoneError != null || _birthError != null) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _saving = true);
    try {
      await _data.updateProfile(
        name: _name.text.trim(),
        birthDate: _birth,
        phone: _phone.text.trim(),
        homeAddress: _address.text.trim(),
        conditions: _conditions.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _nameError = 'Could not save: $e';
      });
    }
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
            const Text('Edit profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            const Text('Your caregivers see these details.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Name', prefixIcon: const Icon(Icons.person_outline_rounded), errorText: _nameError)),
            const SizedBox(height: 12),
            Pressable(
              onTap: _pickBirth,
              scaleTo: 0.98,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date of birth *',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  suffixIcon: const Icon(Icons.calendar_month_rounded),
                  errorText: _birthError,
                ),
                child: Text(
                  _birth == null ? 'Choose a date' : '${_birth!.day} ${Fmt.month(_birth!)} ${_birth!.year}  ·  ${ageFromBirthDate(_birth!)} years',
                  style: TextStyle(fontWeight: FontWeight.w600, color: _birth == null ? AppColors.textFaint : AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'Phone *', hintText: '+60 12-345 6789', prefixIcon: const Icon(Icons.phone_outlined), errorText: _phoneError, errorMaxLines: 2),
            ),
            const SizedBox(height: 12),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Home address', prefixIcon: Icon(Icons.home_outlined))),
            const SizedBox(height: 12),
            TextField(controller: _conditions, decoration: const InputDecoration(labelText: 'Health conditions', hintText: 'Comma separated', prefixIcon: Icon(Icons.healing_outlined))),
            const SizedBox(height: 20),
            GradientButton(label: 'Save', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
