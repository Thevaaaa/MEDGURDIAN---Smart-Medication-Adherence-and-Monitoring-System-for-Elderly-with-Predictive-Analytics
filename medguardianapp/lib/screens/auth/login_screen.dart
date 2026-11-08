import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/google_button.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _googleBusy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signIn(_email.text, _password.text);
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
      await AuthService.instance.signInWithGoogle(); // AuthGate takes over
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _forgot() async {
    final ctrl = TextEditingController(text: _email.text);
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(c).viewInsets.bottom + 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 44, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.mail_lock_outlined, color: AppColors.info)),
            const SizedBox(height: 14),
            const Text('Reset your password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            const Text("We'll email you a link to choose a new one.", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 18),
            AuthField(controller: ctrl, label: 'Email', icon: Icons.mail_outline_rounded, iconColor: AppColors.info, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 18),
            GradientButton(label: 'Send reset link', icon: Icons.send_rounded, gradient: const LinearGradient(colors: [Color(0xFF3E7CB1), Color(0xFF2B5F8C)]), onPressed: () => Navigator.pop(c, ctrl.text)),
          ],
        ),
      ),
    );
    if (email == null || email.trim().isEmpty) return;
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AuthService.friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      eyebrow: 'Welcome back',
      title: 'Good to see you',
      subtitle: 'Sign in to keep your care circle close.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: staggered([
          AuthField(
            controller: _email,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            iconColor: AppColors.info,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 14),
          AuthField(
            controller: _password,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.primary,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            onSubmitted: _signIn,
            suffix: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, key: ValueKey(_obscure)),
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _forgot, child: const Text('Forgot password?'))),
          if (_error != null) ErrorBanner(_error!),
          const SizedBox(height: 4),
          GradientButton(label: 'Sign in', icon: Icons.arrow_forward_rounded, loading: _busy, onPressed: _signIn),
          const SizedBox(height: 14),
          GoogleButton(loading: _googleBusy, onPressed: _busy ? null : _google),
          const SizedBox(height: 22),
          Row(children: const [
            Expanded(child: Divider(color: AppColors.line)),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('New here?', style: TextStyle(color: AppColors.textFaint, fontSize: 12, fontWeight: FontWeight.w700))),
            Expanded(child: Divider(color: AppColors.line)),
          ]),
          const SizedBox(height: 16),
          Pressable(
            onTap: () => Navigator.push(context, slideFadeRoute(const SignupScreen())),
            child: Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary, width: 1.6)),
              child: const Center(child: Text('Create an account', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15.5))),
            ),
          ),
        ], startMs: 300),
      ),
    );
  }
}
