import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';

class CopyableInfoRow extends StatelessWidget {
  const CopyableInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.labelWidth = 64,
    this.maxLines,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final double labelWidth;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onLongPress: () => copyValue(context, label: label, value: value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: AppColors.textSecondary, size: 19),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: labelWidth,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: maxLines,
                overflow: maxLines == null ? null : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 4),
            CopyValueButton(label: label, value: value),
          ],
        ),
      ),
    );
  }
}

class CopyValueButton extends StatelessWidget {
  const CopyValueButton({
    required this.label,
    required this.value,
    this.iconSize = 18,
    super.key,
  });

  final String label;
  final String value;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '复制$label',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      onPressed: () => copyValue(context, label: label, value: value),
      icon: Icon(Icons.copy_outlined, size: iconSize),
    );
  }
}

Future<void> copyValue(
  BuildContext context, {
  required String label,
  required String value,
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('已复制：$label')));
}
