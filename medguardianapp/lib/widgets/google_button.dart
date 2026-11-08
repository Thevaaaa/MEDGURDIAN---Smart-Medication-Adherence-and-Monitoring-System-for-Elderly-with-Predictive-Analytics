import 'package:flutter/material.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';

/// White "Continue with Google" button (outlined, with a coloured G).
class GoogleButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const GoogleButton({super.key, this.label = 'Continue with Google', required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Pressable(
      onTap: enabled ? onPressed : null,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line, width: 1.6),
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335)],
                      stops: [0.0, 0.4, 0.7, 1.0],
                    ).createShader(r),
                    child: const Text('G', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                  ),
                  const SizedBox(width: 12),
                  Text(label, style: TextStyle(color: enabled ? AppColors.textPrimary : AppColors.textFaint, fontWeight: FontWeight.w800, fontSize: 15.5)),
                ]),
        ),
      ),
    );
  }
}
