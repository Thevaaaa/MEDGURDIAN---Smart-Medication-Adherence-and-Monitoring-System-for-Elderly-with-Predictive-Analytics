import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../services/location_service.dart';
import '../../services/location_snapshot.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../widgets/common_widgets.dart';

/// Emergency screen. SOS is *press and hold* (1.6 s) so it can't be sent by
/// an accidental tap, with haptic ticks and a filling ring as feedback.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  bool _sent = false;
  bool _sending = false;
  int _lastTick = 0;
  LocationSnapshot? _lastFix;

  @override
  void initState() {
    super.initState();
    _hold.addListener(() {
      final tick = (_hold.value * 8).floor();
      if (tick != _lastTick && _hold.isAnimating && _hold.status == AnimationStatus.forward) {
        _lastTick = tick;
        HapticFeedback.selectionClick();
      }
    });
    _hold.addStatusListener((s) {
      if (s == AnimationStatus.completed) _fire();
    });
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  Future<void> _fire() async {
    if (_sending || _sent) return;
    setState(() => _sending = true);
    HapticFeedback.heavyImpact();
    try {
      // Best-effort — SOS still sends immediately if a fresh fix isn't available.
      LocationSnapshot? snapshot;
      try {
        final pos = await LocationService.instance.currentPosition().timeout(const Duration(seconds: 6));
        if (pos != null) snapshot = LocationSnapshot(lat: pos.latitude, lng: pos.longitude);
      } catch (_) {}
      _lastFix = snapshot;
      await AppData.instance.triggerSOS(location: snapshot);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sending = false;
      });
      // People without the app (emergency contacts) and caregivers whose
      // phone may be off data still get a plain SMS with the location.
      if (_smsNumbers().isNotEmpty) await _textEveryone();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _hold.reverse();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send SOS: $e. Call for help directly.')));
    }
  }

  void _start() {
    if (_sent || _sending) return;
    _lastTick = 0;
    _hold.forward();
  }

  void _cancel() {
    if (_sent || _sending) return;
    if (_hold.status != AnimationStatus.completed) _hold.reverse();
  }

  /// Every phone number that should get the SOS by text: emergency contacts
  /// (who don't have MedGuardian) plus linked caregivers.
  List<String> _smsNumbers() {
    final data = AppData.instance;
    final all = <String>{
      for (final c in data.elderly.emergencyContacts)
        if (c.phone.trim().isNotEmpty) c.phone.replaceAll(RegExp(r'[\s\-()]'), ''),
      for (final c in data.caregivers)
        if (c.phone.trim().isNotEmpty) c.phone.replaceAll(RegExp(r'[\s\-()]'), ''),
    };
    return all.toList();
  }

  Future<void> _textEveryone() async {
    final numbers = _smsNumbers();
    if (numbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add emergency contacts in Profile so they can be texted.')));
      return;
    }
    final data = AppData.instance;
    final who = (data.me?.name ?? data.elderly.name).trim();
    final where = _lastFix == null ? '' : ' My location: https://maps.google.com/?q=${_lastFix!.lat},${_lastFix!.lng}';
    final body = 'SOS from ${who.isEmpty ? 'MedGuardian' : who}: I need help now.$where';
    // Android separates recipients with ";" and iOS with ",".
    final to = numbers.join(Platform.isIOS ? ',' : ';');
    final uri = Uri.parse('sms:$to${Platform.isIOS ? '&' : '?'}body=${Uri.encodeComponent(body)}');
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open your messages app.')));
    }
  }

  static Caregiver? _primaryCaregiver(List<Caregiver> list) {
    for (final c in list) {
      if (c.phone.isNotEmpty) return c;
    }
    return null;
  }

  Future<void> _call(String number) async {
    if (!await launchUrl(Uri(scheme: 'tel', path: number)) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the phone app.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppData.instance,
      builder: (context, _) {
        final data = AppData.instance;
        final noCaregiver = data.caregivers.isEmpty;
        final Caregiver? primary = _primaryCaregiver(data.caregivers);

        return Scaffold(
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
            child: Container(
              decoration: const BoxDecoration(gradient: AppColors.emergencyGradient),
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  children: [
                    const HeroBar(title: 'Emergency', subtitle: 'Help is one long-press away'),
                    const SizedBox(height: 20),
                    Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: _sent
                            ? Column(
                                key: const ValueKey('sent'),
                                children: [
                                  const SizedBox(height: 40),
                                  const DrawCheck(size: 140, color: Colors.white, strokeWidth: 7),
                                  const SizedBox(height: 22),
                                  const Text('SOS sent', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 6),
                                  Text(noCaregiver ? 'No caregiver is linked — please call for help.' : 'Your caregivers have been alerted in the app.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                                  const SizedBox(height: 18),
                                  Pressable(
                                    onTap: _textEveryone,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white38)),
                                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.sms_rounded, color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Text('Text my contacts again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                      ]),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton(onPressed: () => setState(() {
                                    _sent = false;
                                    _hold.value = 0;
                                  }), style: TextButton.styleFrom(foregroundColor: Colors.white70), child: const Text('Back')),
                                ],
                              )
                            : GestureDetector(
                                key: const ValueKey('button'),
                                onTapDown: (_) => _start(),
                                onTapUp: (_) => _cancel(),
                                onTapCancel: _cancel,
                                child: AnimatedBuilder(
                                  animation: _hold,
                                  builder: (context, _) {
                                    final p = _hold.value;
                                    return PulseRings(
                                      color: Colors.white,
                                      size: 280,
                                      rings: 3,
                                      active: p == 0,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(width: 214, height: 214, child: CircularProgressIndicator(value: p, strokeWidth: 9, strokeCap: StrokeCap.round, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white))),
                                          Transform.scale(
                                            scale: 1 - 0.06 * p,
                                            child: Container(
                                              width: 180,
                                              height: 180,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: const RadialGradient(colors: [Color(0xFFFF6B57), Color(0xFFC0392B)]),
                                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, 14)), BoxShadow(color: const Color(0xFFFF6B57).withOpacity(0.5 + 0.3 * p), blurRadius: 40, spreadRadius: 4)],
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  _sending ? const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4)) : const Icon(Icons.sos_rounded, color: Colors.white, size: 60),
                                                  const SizedBox(height: 6),
                                                  Text(_sending ? 'SENDING…' : (p > 0 ? 'KEEP HOLDING' : 'HOLD FOR SOS'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (noCaregiver && !_sent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GlassCard(
                          radius: 20,
                          child: const Row(children: [
                            Icon(Icons.warning_amber_rounded, color: AppColors.accent),
                            SizedBox(width: 12),
                            Expanded(child: Text('No caregiver is linked yet, so nobody would receive an SOS. Share your link code from Profile — and call 999 in a real emergency.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, height: 1.4))),
                          ]),
                        ),
                      ),
                    if (primary != null) ...[
                      _CallCaregiverButton(caregiver: primary, onCall: _call),
                      const SizedBox(height: 12),
                    ],
                    Pressable(
                      onTap: () => _call('999'),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 8))]),
                        child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.local_hospital_rounded, color: AppColors.danger), SizedBox(width: 10), Text('Call 999 — emergency services', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 16))])),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...data.caregivers.where((c) => !identical(c, primary)).map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            radius: 22,
                            padding: const EdgeInsets.all(14),
                            onTap: c.phone.isEmpty ? null : () => _call(c.phone),
                            child: Row(children: [
                              InitialsAvatar(name: c.name, color: Colors.white, photoUrl: c.photoUrl),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
                                  Text(c.phone.isEmpty ? c.relation : '${c.relation} · ${c.phone}', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                                ]),
                              ),
                              if (c.phone.isNotEmpty) Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle), child: const Icon(Icons.call_rounded, color: Colors.white, size: 20)),
                            ]),
                          ),
                        )),
                    const SizedBox(height: 14),
                    GlassCard(
                      radius: 24,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          data.elderly.fallDetection ? const LiveDot(color: AppColors.mint) : const Icon(Icons.pause_circle_outline_rounded, color: Colors.white54, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(data.elderly.fallDetection ? 'Fall detection is on' : 'Fall detection is off', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                          Switch(value: data.elderly.fallDetection, activeColor: AppColors.mint, onChanged: (v) => data.setSharing(fallDetection: v)),
                        ]),
                        const SizedBox(height: 4),
                        const Text("Runs in the background — even with the app closed. After a hard fall, the countdown screen opens straight away and you have 20 seconds to say you're OK before your caregivers are alerted.", style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


/// Big one-tap "Call <caregiver>" button — the fastest way to a real person.
class _CallCaregiverButton extends StatelessWidget {
  final Caregiver caregiver;
  final Future<void> Function(String) onCall;
  const _CallCaregiverButton({required this.caregiver, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final first = caregiver.name.trim().isEmpty ? 'caregiver' : caregiver.name.trim().split(' ').first;
    return Pressable(
      onTap: () {
        HapticFeedback.heavyImpact();
        onCall(caregiver.phone);
      },
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4CC38A), Color(0xFF2E9461)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFF2E9461).withOpacity(0.55), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          Breathing(
            minScale: 0.94,
            maxScale: 1.06,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), shape: BoxShape.circle),
              child: const Icon(Icons.call_rounded, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Call $first now', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.3)),
              Text([if (caregiver.relation.isNotEmpty) caregiver.relation, caregiver.phone].join(' · '), style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
          InitialsAvatar(name: caregiver.name, color: Colors.white, photoUrl: caregiver.photoUrl, radius: 20),
        ]),
      ),
    );
  }
}
