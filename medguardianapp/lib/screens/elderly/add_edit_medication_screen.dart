import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/med_visuals.dart';

class AddEditMedicationScreen extends StatefulWidget {
  final Medication? existing;
  const AddEditMedicationScreen({super.key, this.existing});

  @override
  State<AddEditMedicationScreen> createState() => _AddEditMedicationScreenState();
}

class _AddEditMedicationScreenState extends State<AddEditMedicationScreen> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final List<MedTime> _times = [const MedTime(8, 0)];
  int _stock = 30;
  Color _color = AppColors.primary;
  String _iconKey = 'pill';
  bool _saving = false;
  String _status = '';

  /// Newly picked photo (not yet uploaded).
  Uint8List? _photoBytes;

  /// Existing photo URL; cleared when the user removes the photo.
  String _photoUrl = '';

  final _colors = const [AppColors.primary, Color(0xFFE0824A), Color(0xFF3E7CB1), Color(0xFF9B6BC7), Color(0xFFE0604F), Color(0xFF3FA772), Color(0xFFD4669A), Color(0xFF4A5568)];

  static const _presets = [
    (label: 'Morning', time: MedTime(8, 0), icon: Icons.wb_sunny_rounded),
    (label: 'Noon', time: MedTime(13, 0), icon: Icons.light_mode_rounded),
    (label: 'Evening', time: MedTime(18, 0), icon: Icons.wb_twilight_rounded),
    (label: 'Night', time: MedTime(21, 30), icon: Icons.nightlight_round),
  ];

  bool get _isEdit => widget.existing != null;
  bool get _hasPhoto => _photoBytes != null || _photoUrl.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _dosageCtrl.text = e.dosage;
      _instructionsCtrl.text = e.instructions;
      _times
        ..clear()
        ..addAll(e.times);
      _stock = e.stock;
      _color = e.color;
      _iconKey = e.iconKey;
      _photoUrl = e.photoUrl;
    }
    _nameCtrl.addListener(() => setState(() {}));
    _dosageCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  // ── Photo ─────────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 82);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _photoBytes = bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${source == ImageSource.camera ? 'the camera' : 'your photos'}: $e')));
      }
    }
  }

  void _removePhoto() {
    HapticFeedback.selectionClick();
    setState(() {
      _photoBytes = null;
      _photoUrl = '';
    });
  }

  Future<void> _photoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Medicine photo', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            const Text('A clear photo of the box or the pill itself works best.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _SheetOption(icon: Icons.photo_camera_rounded, label: 'Take photo', color: _color, onTap: () {
                Navigator.pop(c);
                _pickPhoto(ImageSource.camera);
              })),
              const SizedBox(width: 12),
              Expanded(child: _SheetOption(icon: Icons.photo_library_rounded, label: 'Gallery', color: _color, onTap: () {
                Navigator.pop(c);
                _pickPhoto(ImageSource.gallery);
              })),
            ]),
            if (_hasPhoto) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  _removePhoto();
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                label: const Text('Remove photo', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ── Times ─────────────────────────────────────────────────────────────

  Future<void> _pickTime(int index) async {
    final t = await showTimePicker(context: context, initialTime: _times[index].asTimeOfDay);
    if (t != null) setState(() => _times[index] = MedTime(t.hour, t.minute));
  }

  bool _hasTime(MedTime t) => _times.any((x) => x.hour == t.hour && x.minute == t.minute);

  void _togglePreset(MedTime t) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_hasTime(t)) {
        if (_times.length > 1) _times.removeWhere((x) => x.hour == t.hour && x.minute == t.minute);
      } else {
        _times.add(t);
      }
      _sortTimes();
    });
  }

  void _sortTimes() => _times.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

  // ── Save ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a medication name')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _status = _photoBytes != null ? 'Uploading photo…' : 'Saving…';
    });
    final data = AppData.instance;
    final id = widget.existing?.id ?? data.newId();
    try {
      // 1. Photo first, so the medicine doc is written once with its final URL.
      var photoUrl = _photoUrl;
      if (_photoBytes != null) {
        photoUrl = await data.uploadMedicationPhoto(id, _photoBytes!);
      } else if (_isEdit && _photoUrl.isEmpty && widget.existing!.photoUrl.isNotEmpty) {
        await data.deleteMedicationPhoto(id);
      }
      if (mounted) setState(() => _status = 'Saving…');

      // 2. The medicine itself.
      _sortTimes();
      if (_isEdit) {
        final m = widget.existing!
          ..name = _nameCtrl.text.trim()
          ..dosage = _dosageCtrl.text.trim()
          ..instructions = _instructionsCtrl.text.trim()
          ..times = List.of(_times)
          ..color = _color
          ..iconKey = _iconKey
          ..stock = _stock
          ..photoUrl = photoUrl;
        await data.updateMedication(m);
      } else {
        await data.addMedication(Medication(
          id: id,
          name: _nameCtrl.text.trim(),
          dosage: _dosageCtrl.text.trim().isEmpty ? '1 tablet' : _dosageCtrl.text.trim(),
          instructions: _instructionsCtrl.text.trim(),
          times: List.of(_times),
          color: _color,
          iconKey: _iconKey,
          stock: _stock,
          photoUrl: photoUrl,
        ));
      }
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: ${AuthService.friendlyError(e)}')));
      }
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = _nameCtrl.text.trim().isEmpty ? 'Medicine name' : _nameCtrl.text.trim();
    final dosage = _dosageCtrl.text.trim().isEmpty ? 'Dosage' : _dosageCtrl.text.trim();
    final dark = Color.lerp(_color, Colors.black, 0.5)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: _SaveBar(
          label: _isEdit ? 'Save changes' : 'Add medicine',
          status: _status,
          saving: _saving,
          color: _color,
          onSave: _save,
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // ── Live preview header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(_color, Colors.white, 0.05)!, _color, dark]),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 20, 26),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                        const SizedBox(width: 2),
                        Text(_isEdit ? 'Edit medicine' : 'New medicine', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                      ]),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _PhotoStage(
                          bytes: _photoBytes,
                          url: _photoUrl,
                          color: _color,
                          icon: MedIcons.byKey(_iconKey),
                          onTap: _photoSheet,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(name, key: ValueKey(name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26, letterSpacing: -0.8)),
                          ),
                          const SizedBox(height: 2),
                          Text(dosage, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14.5)),
                          const SizedBox(height: 12),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final t in _times)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.2))),
                                child: Text(t.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),

            // ── Form ────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate(staggered([
                  _FormSection(
                    step: 1,
                    title: 'Details',
                    color: _color,
                    child: Column(children: [
                      _Field(controller: _nameCtrl, label: 'Medicine name', hint: 'e.g. Amlodipine', icon: Icons.medication_rounded, color: _color, capitalize: true),
                      const SizedBox(height: 12),
                      _Field(controller: _dosageCtrl, label: 'Dosage', hint: 'e.g. 5 mg · 1 tablet', icon: Icons.scale_rounded, color: _color),
                      const SizedBox(height: 12),
                      _Field(controller: _instructionsCtrl, label: 'Instructions (optional)', hint: 'e.g. Take with food', icon: Icons.notes_rounded, color: _color, lines: 2),
                    ]),
                  ),
                  _FormSection(
                    step: 2,
                    title: 'Look',
                    subtitle: _hasPhoto ? 'Colour themes reminders and cards.' : 'Icon is shown until you add a photo.',
                    color: _color,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _colors.map((c) {
                          final selected = c.value == _color.value;
                          return Pressable(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _color = c);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutBack,
                              width: 38,
                              height: 38,
                              padding: EdgeInsets.all(selected ? 3 : 0),
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? c : Colors.transparent, width: 2)),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(c, Colors.white, 0.15)!, c]),
                                ),
                                child: AnimatedScale(
                                  scale: selected ? 1 : 0,
                                  duration: const Duration(milliseconds: 220),
                                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: MedIcons.all.entries.map((entry) {
                          final selected = entry.key == _iconKey;
                          return Pressable(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _iconKey = entry.key);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: selected ? _color : AppColors.background,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: selected ? _color : AppColors.line, width: 1.2),
                                boxShadow: selected ? [BoxShadow(color: _color.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))] : null,
                              ),
                              child: Icon(entry.value, color: selected ? Colors.white : AppColors.textFaint, size: 22),
                            ),
                          );
                        }).toList(),
                      ),
                    ]),
                  ),
                  _FormSection(
                    step: 3,
                    title: 'Reminders',
                    subtitle: 'Tap a preset or set exact times.',
                    color: _color,
                    child: Column(children: [
                      Row(children: [
                        for (var i = 0; i < _presets.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _PresetChip(
                              label: _presets[i].label,
                              icon: _presets[i].icon,
                              time: _presets[i].time.label,
                              selected: _hasTime(_presets[i].time),
                              color: _color,
                              onTap: () => _togglePreset(_presets[i].time),
                            ),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 14),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: Column(children: [
                          for (var i = 0; i < _times.length; i++)
                            Padding(
                              key: ValueKey('${_times[i].hour}:${_times[i].minute}:$i'),
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TimeRow(
                                time: _times[i],
                                color: _color,
                                onTap: () => _pickTime(i),
                                onRemove: _times.length > 1 ? () => setState(() => _times.removeAt(i)) : null,
                              ),
                            ),
                        ]),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 12, minute: 0));
                            if (t == null) return;
                            final mt = MedTime(t.hour, t.minute);
                            if (_hasTime(mt)) return;
                            setState(() {
                              _times.add(mt);
                              _sortTimes();
                            });
                          },
                          style: TextButton.styleFrom(foregroundColor: _color),
                          icon: const Icon(Icons.add_circle_rounded, size: 20),
                          label: const Text('Add custom time', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ]),
                  ),
                  _FormSection(
                    step: 4,
                    title: 'Stock',
                    subtitle: 'We\'ll warn you when it\'s running low.',
                    color: _color,
                    child: Column(children: [
                      Row(children: [
                        _RoundStep(icon: Icons.remove_rounded, onTap: _stock == 0 ? null : () => setState(() => _stock = (_stock - 1).clamp(0, 999))),
                        Expanded(
                          child: Column(children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                              child: Text('$_stock', key: ValueKey(_stock), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _times.isEmpty ? 'tablets' : 'tablets · ~${(_stock / _times.length).floor()} days',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                        _RoundStep(icon: Icons.add_rounded, onTap: () => setState(() => _stock = (_stock + 1).clamp(0, 999))),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        for (final n in const [10, 30, 60]) ...[
                          if (n != 10) const SizedBox(width: 8),
                          Expanded(
                            child: Pressable(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _stock = (_stock + n).clamp(0, 999));
                              },
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(color: _color.withOpacity(0.09), borderRadius: BorderRadius.circular(12)),
                                child: Center(child: Text('+$n', style: TextStyle(color: _color, fontWeight: FontWeight.w800))),
                              ),
                            ),
                          ),
                        ],
                      ]),
                    ]),
                  ),
                ], stepMs: 60)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Pieces
// ═════════════════════════════════════════════════════════════════════════

/// Large tappable photo slot in the preview header.
class _PhotoStage extends StatelessWidget {
  final Uint8List? bytes;
  final String url;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _PhotoStage({required this.bytes, required this.url, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final has = bytes != null || url.isNotEmpty;
    return Pressable(
      onTap: onTap,
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
            child: has
                ? MedThumb(key: ValueKey(bytes?.hashCode ?? url), color: color, icon: icon, photoUrl: url, bytes: bytes, size: 108, radius: 30)
                : _EmptyPhoto(key: const ValueKey('empty'), icon: icon),
          ),
          Positioned(
            right: -6,
            bottom: -6,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.sunGradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Icon(has ? Icons.edit_rounded : Icons.add_a_photo_rounded, color: Colors.white, size: 16),
            ),
          ),
        ]),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(has ? 'Photo added' : 'Add a photo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              has ? 'Tap to retake, change or remove it.' : 'Snap the box or pill so it\'s easy to recognise at a glance.',
              style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12.5, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _EmptyPhoto extends StatelessWidget {
  final IconData icon;
  const _EmptyPhoto({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 34),
        const SizedBox(height: 6),
        Text('PHOTO', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
      ]),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.18))),
        child: Column(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))]),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final int step;
  final String title;
  final String? subtitle;
  final Color color;
  final Widget child;
  const _FormSection({required this.step, required this.title, this.subtitle, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.line.withOpacity(0.7)),
          boxShadow: AppColors.softShadow(),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Center(child: Text('$step', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5))),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.only(left: 36), child: Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5))),
          ],
          const SizedBox(height: 16),
          child,
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  final bool capitalize;
  final int lines;
  const _Field({required this.controller, required this.label, required this.hint, required this.icon, required this.color, this.capitalize = false, this.lines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: lines,
      textCapitalization: capitalize ? TextCapitalization.words : TextCapitalization.sentences,
      cursorColor: color,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.background,
        floatingLabelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color, width: 1.6)),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String time;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.icon, required this.time, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : AppColors.line),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.32), blurRadius: 12, offset: const Offset(0, 5))] : null,
        ),
        child: Column(children: [
          Icon(icon, size: 19, color: selected ? Colors.white : AppColors.textSecondary),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: selected ? Colors.white : AppColors.textPrimary)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(time, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: selected ? Colors.white.withOpacity(0.8) : AppColors.textFaint)),
          ),
        ]),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final MedTime time;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  const _TimeRow({required this.time, required this.color, required this.onTap, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Pressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.alarm_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(time.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
              const Spacer(),
              const Text('Change', style: TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textFaint),
            ]),
          ),
        ),
      ),
      if (onRemove != null) ...[
        const SizedBox(width: 8),
        Pressable(
          onTap: onRemove,
          child: Container(
            width: 46,
            height: 58,
            decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.close_rounded, color: AppColors.danger, size: 20),
          ),
        ),
      ],
    ]);
  }
}

class _RoundStep extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundStep({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.35 : 1,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: AppColors.background, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final String label;
  final String status;
  final bool saving;
  final Color color;
  final VoidCallback onSave;
  const _SaveBar({required this.label, required this.status, required this.saving, required this.color, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: saving && status.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(status, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            GradientButton(
              label: label,
              icon: Icons.check_rounded,
              loading: saving,
              height: 56,
              gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.05)!, Color.lerp(color, Colors.black, 0.3)!]),
              onPressed: onSave,
            ),
          ]),
        ),
      ),
    );
  }
}
