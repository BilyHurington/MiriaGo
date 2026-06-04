import 'package:flutter/material.dart';

import '../app_theme.dart';

Future<bool> showConfirmActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData? icon,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: destructive ? AppColors.warning : AppColors.accentDark,
              size: 22,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.warning)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
