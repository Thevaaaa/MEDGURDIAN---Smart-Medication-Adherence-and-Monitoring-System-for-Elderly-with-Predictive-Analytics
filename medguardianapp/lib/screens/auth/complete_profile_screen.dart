import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/common_widgets.dart';
import 'signup_screen.dart';

/// Shown once to a brand-new Google user: Google gives us a name and email,
/// MedGuardian still needs the role, a phone number (for emergencies) and,
/// for people using the app themselves, a date of birth.
class CompleteProfileScreen extends StatefulWidget {
  final VoidCallback onDone;
  const CompleteProfileScreen({super.key, required this.onDone});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  UserRole _role = UserRole.elderly;
  late final TextEditingController _name = TextEditingController(text: FirebaseAuth.instance.currentUser?.displayName ?? '');
  final _phone = TextEditingController();
  DateTime? _birthDate;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 70, 1, 1),
      firstDate: DateTime(now.year - 120),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Your date of birth',
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _submit() async {
    final elderly = _role == UserRole.elderly;
    String? problem;
    if (_name.text.trim().isEmpty) {
      problem = 'Please enter your full name.';
    } else if (_phone.text.trim().isEmpty) {
      problem = 'A phone number is required so you can be reached in an emergency.';
    } else if (!AuthService.isValidPhone(_phone.text)) {
      problem = 'That phone number does not look right — include the country code, e.g. +60 12-345 6789.';
    } else if (elderly && _birthDate == null) {
      problem = 'Please choose your date of birth.';
    }
    if (problem != null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.completeGoogleProfile(name: _name.text, role: _role, phone: _phone.text, birthDate: elderly ? _birthDate : null);
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final elderly = _role == UserRole.elderly;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return AuthScaffold(
      eyebrow: 'Almost there',
      title: 'Finish setting up',
      subtitle: email.isEmpty ? 'Just a few details to get started.' : 'Signed in as $email',
      decorIcons: const [Icons.favorite_rounded, Icons.volunteer_activism_rounded, Icons.medication_rounded, Icons.elderly_rounded],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: staggered([
          const Text('I am…', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: RoleCard(icon: Icons.elderly_rounded, label: 'Using it myself', selected: elderly, onTap: () => setState(() => _role = UserRole.elderly))),
            const SizedBox(width: 12),
            Expanded(child: RoleCard(icon: Icons.volunteer_activism_rounded, label: 'A caregiver', selected: !elderly, onTap: () => setState(() => _role = UserRole.caregiver))),
          ]),
          const SizedBox(height: 22),
          AuthField(controller: _name, label: 'Full name', icon: Icons.person_outline_rounded, iconColor: AppColors.primary, textCapitalization: TextCapitalization.words),
          const SizedBox(height: 14),
          AuthField(controller: _phone, label: 'Phone number *', hint: '+60 12-345 6789', icon: Icons.phone_outlined, iconColor: AppColors.success, keyboardType: TextInputType.phone),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: elderly
                ? Padding(padding: const EdgeInsets.only(top: 14), child: BirthDateField(date: _birthDate, onTap: _pickBirthDate))
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 20),
          if (_error != null) ErrorBanner(_error!),
          GradientButton(label: 'Continue', icon: Icons.check_rounded, loading: _busy, onPressed: _submit),
          const SizedBox(height: 10),
          Center(child: TextButton(onPressed: _busy ? null : AuthService.instance.signOut, child: const Text('Use a different account'))),
        ], startMs: 200),
      ),
    );
  }
}
