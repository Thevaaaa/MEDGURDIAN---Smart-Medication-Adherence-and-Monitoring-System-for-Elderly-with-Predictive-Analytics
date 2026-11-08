import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/app_data.dart';
import '../../services/fall_background_service.dart';
import '../../services/fall_signal.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../utils/nav.dart';


class FallCoordinator with WidgetsBindingObserver {
  FallCoordinator._();
  static final FallCoordinator instance = FallCoordinator._();

  bool _pageOpen = false;
  bool _watching = false;
  Timer? _heartbeat;
  StreamSubscription<Map<String, dynamic>?>? _events;

  void startWatching() {
    if (_watching) return;
    _watching = true;
    WidgetsBinding.instance.addObserver(this);
    _events = FlutterBackgroundService().on('fall').listen((_) => check());
    _startHeartbeat();
    check();
  }

  void stopWatching() {
    if (!_watching) return;
    _watching = false;
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    _events = null;
    _stopHeartbeat();
  }

  /// Tells the background service "the app is on screen", so it opens the
  /// countdown in-app instead of via the lock-screen launcher.
  void _startHeartbeat() {
    _heartbeat?.cancel();
    Future<void> beat() async {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setInt(kAppForegroundAtPref, DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}
    }

    beat();
    _heartbeat = Timer.periodic(const Duration(seconds: 4), (_) => beat());
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
    SharedPreferences.getInstance().then((p) => p.remove(kAppForegroundAtPref)).catchError((_) => false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
      check();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _stopHeartbeat();
    }
  }

  /// Looks for an active, not-yet-expired countdown and opens the page.
  Future<void> check({int retriesLeft = 20}) async {
    if (_pageOpen) return;
    final state = await FallSignal.read();
    if (state == null || state.status != 'pending' || state.expired) return;
    final uid = AppData.instance.me?.uid;
    if (uid != null && state.uid.isNotEmpty && state.uid != uid) return; // stale signal from a previous account

    // On a cold start the navigator may not be attached for the first few
    // frames — retry briefly instead of giving up.
    if (rootNavigatorKey.currentState == null) {
      if (retriesLeft <= 0) return;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return check(retriesLeft: retriesLeft - 1);
    }
    _open();
  }

  void _open() {
    final nav = rootNavigatorKey.currentState;
    if (nav == null || _pageOpen) return;
    _pageOpen = true;
    nav
        .push(PageRouteBuilder<void>(
          opaque: true,
          fullscreenDialog: true,
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => const FallCountdownPage(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: 1.06, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
          ),
        ))
        .whenComplete(() => _pageOpen = false);
  }
}

/// Full-screen, high-contrast countdown with two very large choices.
class FallCountdownPage extends StatefulWidget {
  const FallCountdownPage({super.key});

  @override
  State<FallCountdownPage> createState() => _FallCountdownPageState();
}

class _FallCountdownPageState extends State<FallCountdownPage> with SingleTickerProviderStateMixin {
  static const _total = 20;
  Timer? _poll;
  Duration _remaining = const Duration(seconds: _total);
  int _lastWholeSecond = -1;
  bool _acting = false;
  String? _outcome; // 'ok' | 'help'
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    _tick();
    _poll = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_acting || _outcome != null) return;
    final state = await FallSignal.read();
    if (!mounted) return;
    if (state == null || state.status != 'pending') {
      // Resolved elsewhere (time ran out, or answered from another surface).
      _finish(state?.status == 'ok' ? 'ok' : 'help');
      return;
    }
    final whole = state.remaining.inSeconds;
    if (whole != _lastWholeSecond) {
      _lastWholeSecond = whole;
      HapticFeedback.vibrate();
      if (whole <= 5) SystemSound.play(SystemSoundType.alert);
    }
    setState(() => _remaining = state.remaining);
  }

  void _finish(String outcome) {
    if (_outcome != null) return;
    _poll?.cancel();
    setState(() => _outcome = outcome);
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  Future<void> _respond(bool ok) async {
    if (_acting) return;
    setState(() => _acting = true);
    HapticFeedback.mediumImpact();
    await (ok ? FallSignal.markOk() : FallSignal.markGetHelp());
    if (mounted) _finish(ok ? 'ok' : 'help');
  }

  @override
  Widget build(BuildContext context) {
    final left = _remaining.inMilliseconds / 1000;
    final secs = left.ceil().clamp(0, _total);
    final name = (AppData.instance.me?.name ?? '').trim().split(' ').first;

    return PopScope(
      canPop: _outcome != null,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFF3A0D0A),
          body: Container(
            decoration: const BoxDecoration(gradient: AppColors.emergencyGradient),
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: _outcome != null ? _Outcome(key: ValueKey(_outcome), ok: _outcome == 'ok') : _countdown(left, secs, name),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _countdown(double left, int secs, String name) {
    return Padding(
      key: const ValueKey('countdown'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            LiveDot(color: Colors.white, size: 8),
            SizedBox(width: 8),
            Text('FALL DETECTED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.6, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 18),
        Text(name.isEmpty ? 'Are you OK?' : 'Are you OK, $name?', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
        const SizedBox(height: 8),
        const Text('We felt a hard fall. Your caregivers will be alerted automatically when the timer ends.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
        const Spacer(),
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = _pulse.value;
            return SizedBox(
              width: 260,
              height: 260,
              child: Stack(alignment: Alignment.center, children: [
                for (var i = 0; i < 2; i++)
                  Opacity(
                    opacity: (1 - ((t + i * 0.5) % 1)) * 0.35,
                    child: Container(
                      width: 170 + 90 * ((t + i * 0.5) % 1),
                      height: 170 + 90 * ((t + i * 0.5) % 1),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    ),
                  ),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CustomPaint(painter: _CountdownPainter(progress: (left / _total).clamp(0.0, 1.0))),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 1.4, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
                    child: Text('$secs', key: ValueKey(secs), style: const TextStyle(color: Colors.white, fontSize: 76, fontWeight: FontWeight.w800, height: 1, fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                  const Text('seconds', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ]),
              ]),
            );
          },
        ),
        const Spacer(),
        Pressable(
          onTap: _acting ? null : () => _respond(true),
          child: Container(
            height: 76,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Center(
              child: _acting
                  ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.success))
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 32),
                      SizedBox(width: 10),
                      Text("I'm OK", style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 26)),
                    ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Pressable(
          onTap: _acting ? null : () => _respond(false),
          child: Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white54, width: 1.5)),
            child: const Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.sos_rounded, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Text('I need help — alert now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Outcome extends StatelessWidget {
  final bool ok;
  const _Outcome({super.key, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DrawCheck(size: 130, color: Colors.white, strokeWidth: 7, withCircle: ok),
          const SizedBox(height: 24),
          Text(ok ? "Glad you're OK" : 'Help is on the way', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            ok ? 'No alert was sent. Fall detection keeps watching in the background.' : 'Your caregivers have been alerted with your location.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
          ),
        ]),
      ),
    );
  }
}

class _CountdownPainter extends CustomPainter {
  final double progress;
  _CountdownPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 12,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownPainter old) => old.progress != progress;
}
