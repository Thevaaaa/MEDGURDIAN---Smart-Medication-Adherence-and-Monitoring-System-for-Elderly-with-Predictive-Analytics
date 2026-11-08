import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medguardianapp/theme/app_animations.dart';
import '../services/app_data.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'common_widgets.dart';


class EditableAvatar extends StatefulWidget {
  final String name;
  final Color color;
  final String photoUrl;
  final double radius;
  const EditableAvatar({super.key, required this.name, required this.color, required this.photoUrl, this.radius = 44});

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${source == ImageSource.camera ? 'the camera' : 'your photos'}: $e')));
      return;
    }
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await File(file.path).readAsBytes();
      await AppData.instance.uploadProfilePhoto(bytes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${AuthService.friendlyError(e)}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await AppData.instance.removeProfilePhoto();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not remove photo: ${AuthService.friendlyError(e)}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 18, 20, 6), child: Align(alignment: Alignment.centerLeft, child: Text('Profile photo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))),
            ListTile(leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary), title: const Text('Take a photo'), onTap: () {
              Navigator.pop(c);
              _pick(ImageSource.camera);
            }),
            ListTile(leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary), title: const Text('Choose from gallery'), onTap: () {
              Navigator.pop(c);
              _pick(ImageSource.gallery);
            }),
            if (widget.photoUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('Remove photo', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(c);
                  _remove();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: _busy ? null : _openSheet,
      child: SizedBox(
        width: widget.radius * 2 + 8,
        height: widget.radius * 2 + 8,
        child: Stack(
          children: [
            InitialsAvatar(name: widget.name, color: widget.color, radius: widget.radius, ring: true, photoUrl: widget.photoUrl),
            if (_busy)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38),
                  child: const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
