import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../widgets/common_widgets.dart';

class LogSymptomScreen extends StatefulWidget {
  const LogSymptomScreen({super.key});

  @override
  State<LogSymptomScreen> createState() => _LogSymptomScreenState();
}

class _LogSymptomScreenState extends State<LogSymptomScreen> {
  static const _symptoms = <String, IconData>{
    'Dizziness': Icons.rotate_right_rounded,
    'Vomiting': Icons.sick_rounded,
    'Headache': Icons.psychology_alt_rounded,
    'Chest pain': Icons.monitor_heart_rounded,
    'Fatigue': Icons.bedtime_rounded,
    'Breathless': Icons.air_rounded,
    'Other': Icons.more_horiz_rounded,
  };
  static const _faces = ['😊', '🙂', '😐', '😟', '😣'];
  static const _words = ['Very mild', 'Mild', 'Moderate', 'Strong', 'Severe'];

  String _selected = 'Dizziness';
  double _severity = 2;
  final _noteCtrl = TextEditingController();
  bool _saving = false;
  bool _submitted = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await AppData.instance.addSymptom(SymptomLog(id: AppData.instance.newId(), time: DateTime.now(), symptom: _selected, severity: _severity.round(), note: _noteCtrl.text.trim()));
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _submitted = true);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sev = _severity.round();
    final c = severityScaleColor(sev);

    if (_submitted) {
      final severe = sev >= 4;
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DrawCheck(size: 110, color: severe ? AppColors.warning : AppColors.success),
            const SizedBox(height: 22),
            FadeSlideIn(delayMs: 500, child: Text(severe ? 'Logged — your caregiver was notified' : 'Symptom logged', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('How are you feeling?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: staggered([
          const Text('What is bothering you?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _symptoms.entries.map((e) {
              final selected = e.key == _selected;
              return Pressable(
                onTap: () => setState(() => _selected = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.heroGradient : null,
                    color: selected ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? Colors.transparent : AppColors.line, width: 1.4),
                    boxShadow: selected ? [BoxShadow(color: AppColors.primary.withOpacity(0.32), blurRadius: 14, offset: const Offset(0, 6))] : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(e.value, size: 18, color: selected ? Colors.white : AppColors.primary),
                    const SizedBox(width: 8),
                    Text(e.key, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w800)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          const Text('How strong is it?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          SoftCard(
            shadowTint: c,
            child: Column(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (ch, a) => ScaleTransition(scale: a, child: ch),
                child: Text(_faces[sev - 1], key: ValueKey(sev), style: const TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 250), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c), child: Text('${_words[sev - 1]} · $sev / 5')),
              SliderTheme(
                data: SliderThemeData(trackHeight: 8, activeTrackColor: c, inactiveTrackColor: AppColors.surfaceMuted, thumbColor: c, overlayColor: c.withOpacity(0.15), thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13)),
                child: Slider(value: _severity, min: 1, max: 5, divisions: 4, onChanged: (v) {
                  if (v.round() != _severity.round()) HapticFeedback.selectionClick();
                  setState(() => _severity = v);
                }),
              ),
              if (sev >= 4)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.notifications_active_rounded, size: 16, color: AppColors.warning),
                    SizedBox(width: 8),
                    Expanded(child: Text('Your caregiver will be notified.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 22),
          TextField(controller: _noteCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Add a note (optional)', hintText: 'e.g. Started after lunch', prefixIcon: Icon(Icons.edit_note_rounded))),
          const SizedBox(height: 26),
          GradientButton(label: 'Save', icon: Icons.check_rounded, loading: _saving, onPressed: _submit),
        ]),
      ),
    );
  }
}
