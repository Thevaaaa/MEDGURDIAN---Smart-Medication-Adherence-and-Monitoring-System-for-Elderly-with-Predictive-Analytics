import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_data.dart';
import '../../services/auth_service.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common_widgets.dart';


class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  late List<EmergencyContact> _contacts = List.of(AppData.instance.elderly.emergencyContacts);
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppData.instance.setEmergencyContacts(_contacts);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: ${AuthService.friendlyError(e)}')));
      }
    }
  }

  Future<void> _editContact({EmergencyContact? existing, int? index}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final relation = TextEditingController(text: existing?.relation ?? '');

    final result = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(c).viewInsets.bottom + 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(existing == null ? 'Add emergency contact' : 'Edit contact', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline_rounded))),
            const SizedBox(height: 12),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', hintText: '+60 12-345 6789', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 12),
            TextField(controller: relation, decoration: const InputDecoration(labelText: 'Relationship (optional)', prefixIcon: Icon(Icons.favorite_border_rounded))),
            const SizedBox(height: 18),
            GradientButton(
              label: existing == null ? 'Add contact' : 'Save changes',
              icon: Icons.check_rounded,
              onPressed: () {
                if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
                  ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Enter a name and phone number.')));
                  return;
                }
                Navigator.pop(c, EmergencyContact(name: name.text.trim(), phone: phone.text.trim(), relation: relation.text.trim()));
              },
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _contacts[index] = result;
      } else {
        _contacts.add(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency contacts')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: staggered([
          const Text(
            "These people don't need MedGuardian installed. If your server's SMS gateway is set up, they're texted your location on SOS or a detected fall.",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (_contacts.isEmpty)
            const EmptyState(icon: Icons.contact_phone_outlined, title: 'No emergency contacts yet', subtitle: 'Add someone who should be texted if you need urgent help.')
          else
            ..._contacts.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  onTap: () => _editContact(existing: c, index: i),
                  child: Row(children: [
                    InitialsAvatar(name: c.name, color: AppColors.coral),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(c.relation.isEmpty ? c.phone : '${c.relation} · ${c.phone}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                    ])),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textFaint), onPressed: () => setState(() => _contacts.removeAt(i))),
                  ]),
                ),
              );
            }),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => _editContact(), icon: const Icon(Icons.add_rounded), label: const Text('Add contact')),
          const SizedBox(height: 24),
          GradientButton(label: 'Save', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
        ]),
      ),
    );
  }
}
