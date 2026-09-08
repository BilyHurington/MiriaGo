import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';

class PhotoLocationStatusPanel extends StatelessWidget {
  const PhotoLocationStatusPanel({
    required this.label,
    required this.loading,
    this.onSkip,
    super.key,
  });

  final String label;
  final bool loading;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(LucideIcons.mapPin, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          if (onSkip != null)
            OutlinedButton(
              onPressed: onSkip,
              style: AppButtonStyles.compactOutlinedButton(),
              child: const Text('跳过'),
            ),
        ],
      ),
    );
  }
}
