import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/google_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  UserRole _role = UserRole.elderly;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _birthDate;
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _googleBusy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
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
      initialEntryMode: DatePickerEntryMode.calendar,
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
    } else if (_email.text.trim().isEmpty) {
      problem = 'Please enter your email address.';
    } else if (_password.text.length < 6) {
      problem = 'Choose a password with at least 6 characters.';
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
      await AuthService.instance.signUp(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        role: _role,
        phone: _phone.text,
        birthDate: elderly ? _birthDate : null,
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst); // AuthGate takes over
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      final ok = await AuthService.instance.signInWithGoogle();
      if (ok && mounted) Navigator.of(context).popUntil((r) => r.isFirst); // AuthGate takes over
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final elderly = _role == UserRole.elderly;
    return AuthScaffold(
      eyebrow: 'Get started',
      title: 'Create account',
      subtitle: 'Two minutes to a safer, calmer routine.',
      showBack: true,
      decorIcons: const [Icons.favorite_rounded, Icons.volunteer_activism_rounded, Icons.medication_rounded, Icons.elderly_rounded],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: staggered([
          const Text('I am…', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: RoleCard(icon: Icons.elderly_rounded, label: 'Using it myself', selected: elderly, onTap: () => setState(() => _role = UserRole.elderly))),
              const SizedBox(width: 12),
              Expanded(child: RoleCard(icon: Icons.volunteer_activism_rounded, label: 'A caregiver', selected: !elderly, onTap: () => setState(() => _role = UserRole.caregiver))),
            ],
          ),
          const SizedBox(height: 22),
          AuthField(controller: _name, label: 'Full name', icon: Icons.person_outline_rounded, iconColor: AppColors.primary, textCapitalization: TextCapitalization.words),
          const SizedBox(height: 14),
          AuthField(controller: _phone, label: 'Phone number *', hint: '+60 12-345 6789', icon: Icons.phone_outlined, iconColor: AppColors.success, keyboardType: TextInputType.phone),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: elderly
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: BirthDateField(date: _birthDate, onTap: _pickBirthDate),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 14),
          AuthField(controller: _email, label: 'Email', icon: Icons.mail_outline_rounded, iconColor: AppColors.info, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          AuthField(
            controller: _password,
            label: 'Password',
            hint: 'Min. 6 characters',
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.coral,
            obscureText: _obscure,
            suffix: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, key: ValueKey(_obscure)),
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          PasswordStrengthBar(password: _password.text),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey(elderly),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    elderly ? 'You will get a 6-digit code to share with your caregiver.' : "You'll link to the person you care for with the code from their app.",
                    style: const TextStyle(color: AppColors.info, fontSize: 12, fontWeight: FontWeight.w700, height: 1.35),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null) ErrorBanner(_error!),
          GradientButton(label: 'Create account', icon: Icons.check_rounded, loading: _busy, onPressed: _submit),
          const SizedBox(height: 14),
          Row(children: const [
            Expanded(child: Divider(color: AppColors.line)),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: AppColors.textFaint, fontSize: 12, fontWeight: FontWeight.w700))),
            Expanded(child: Divider(color: AppColors.line)),
          ]),
          const SizedBox(height: 14),
          GoogleButton(label: 'Sign up with Google', loading: _googleBusy, onPressed: _busy ? null : _google),
          const SizedBox(height: 18),
          Center(
            child: RichText(
              text: TextSpan(style: const TextStyle(color: AppColors.textFaint, fontSize: 11.5, height: 1.5), children: const [
                TextSpan(text: 'By continuing you agree to MedGuardian\'s '),
                TextSpan(text: 'Terms', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                TextSpan(text: ' and '),
                TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                TextSpan(text: '.'),
              ]),
              textAlign: TextAlign.center,
            ),
          ),
        ], startMs: 260),
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const RoleCard({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.heroGradient : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? Colors.transparent : AppColors.line, width: 1.5),
          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))] : AppColors.softShadow(),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                AnimatedScale(scale: selected ? 1.15 : 1, duration: const Duration(milliseconds: 280), child: Icon(icon, color: selected ? Colors.white : AppColors.primary, size: 30)),
                const SizedBox(height: 9),
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: selected ? Colors.white : AppColors.textPrimary)),
              ],
            ),
            Positioned(
              top: -4,
              right: -4,
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.elasticOut,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Tappable date-of-birth field styled like [AuthField]. Storing the birth
/// date (not an age) keeps the age correct automatically every year.
class BirthDateField extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  const BirthDateField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final has = date != null;
    return Pressable(
      onTap: onTap,
      scaleTo: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.fromLTRB(0, 6, 14, 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: has ? AppColors.accent.withOpacity(0.45) : AppColors.line, width: 1.4),
        ),
        child: Row(children: [
          chipIcon(Icons.cake_outlined, AppColors.accent),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Date of birth *', style: TextStyle(color: has ? AppColors.accent : AppColors.textSecondary, fontSize: has ? 11.5 : 15, fontWeight: has ? FontWeight.w700 : FontWeight.w500)),
              if (has) ...[
                const SizedBox(height: 2),
                Text('${date!.day} ${Fmt.month(date!)} ${date!.year}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ]),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: has
                ? Container(
                    key: const ValueKey('age'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text('${ageFromBirthDate(date!)} yrs', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 12)),
                  )
                : const Icon(Icons.calendar_month_rounded, key: ValueKey('cal'), color: AppColors.textFaint),
          ),
        ]),
      ),
    );
  }
}
