import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class AddAppointmentScreen extends StatefulWidget {
  const AddAppointmentScreen({super.key});

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  bool _saving = false;

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    setState(() => _saving = true);
    try {
      await AppData.instance.addAppointment(Appointment(
        id: AppData.instance.newId(),
        title: _titleCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty ? 'Not specified' : _locationCtrl.text.trim(),
        dateTime: DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
        notes: _notesCtrl.text.trim(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  Widget _pickerTile(IconData icon, String label, String value, VoidCallback onTap) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.softShadow(AppColors.info), border: Border.all(color: AppColors.info.withOpacity(0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AppColors.info, size: 22),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textFaint)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New appointment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: staggered([
          TextField(controller: _titleCtrl, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What is it for?', hintText: 'e.g. Cardiology follow-up', prefixIcon: Icon(Icons.local_hospital_rounded))),
          const SizedBox(height: 14),
          TextField(controller: _locationCtrl, decoration: const InputDecoration(labelText: 'Where?', hintText: 'e.g. Hospital Kulim', prefixIcon: Icon(Icons.place_rounded))),
          const SizedBox(height: 18),
          Row(children: [
            _pickerTile(Icons.calendar_month_rounded, 'DATE', Fmt.mediumDate(_date), _pickDate),
            const SizedBox(width: 12),
            _pickerTile(Icons.access_time_filled_rounded, 'TIME', _time.format(context), _pickTime),
          ]),
          const SizedBox(height: 18),
          TextField(controller: _notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.notes_rounded))),
          const SizedBox(height: 12),
          const Row(children: [
            Icon(Icons.notifications_active_outlined, size: 16, color: AppColors.textFaint),
            SizedBox(width: 8),
            Expanded(child: Text("You'll get a reminder the day before and 1 hour before.", style: TextStyle(color: AppColors.textFaint, fontSize: 12.5))),
          ]),
          const SizedBox(height: 24),
          GradientButton(label: 'Save appointment', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
        ]),
      ),
    );
  }
}
