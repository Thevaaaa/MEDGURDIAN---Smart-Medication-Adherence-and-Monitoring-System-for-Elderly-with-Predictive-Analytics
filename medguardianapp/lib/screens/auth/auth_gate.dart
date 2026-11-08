import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/app_data.dart';
import '../../services/auth_service.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../models/models.dart';
import '../caregiver/caregiver_shell.dart';
import '../elderly/elderly_shell.dart';
import 'complete_profile_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _sub;
  User? _user;
  bool _authResolved = false;
  bool _profileMissing = false; // signed in with Google but no MedGuardian profile yet

  @override
  void initState() {
    super.initState();
    _sub = AuthService.instance.authChanges.listen((user) {
      if (user != null) {
        AppData.instance.start(user);
      } else {
        AppData.instance.stop();
      }
      if (mounted) {
        setState(() {
          _user = user;
          _authResolved = true;
          if (user == null) _profileMissing = false;
        });
      }
      if (user != null) _checkProfile(user.uid);
    });
  }

  Future<void> _checkProfile(String uid) async {
    final has = await AuthService.instance.hasProfile(uid);
    if (mounted && _user?.uid == uid) setState(() => _profileMissing = !has);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authResolved) return const _Loading();
    if (_user == null) return const LoginScreen();
    if (_profileMissing) return CompleteProfileScreen(onDone: () => setState(() => _profileMissing = false));

    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        if (!data.ready) return const _Loading(showSignOut: true);
        return data.me!.role == UserRole.elderly ? const ElderlyShell() : const CaregiverShell();
      },
    );
  }
}

class _Loading extends StatefulWidget {
  final bool showSignOut;
  const _Loading({this.showSignOut = false});

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading> {
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PulseRings(
                color: AppColors.mint,
                size: 150,
                rings: 3,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.14), border: Border.all(color: Colors.white.withOpacity(0.4))),
                  child: const Icon(Icons.shield_moon_rounded, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 22),
              const Shimmer(child: Text('Loading your care circle…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
              if (widget.showSignOut && _slow) ...[
                const SizedBox(height: 18),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: AuthService.instance.signOut,
                  child: const Text('Taking too long? Sign out'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
