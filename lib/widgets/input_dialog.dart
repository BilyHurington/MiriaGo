import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import 'confirm_action_dialog.dart';

class AppInputDialog extends StatelessWidget {
  const AppInputDialog({
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel = '取消',
    this.titleTrailing,
    this.errorText,
    super.key,
  });

  final String title;
  final Widget content;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final Widget? titleTrailing;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight =
        (mediaQuery.size.height - mediaQuery.viewInsets.bottom - 48).clamp(
          0.0,
          double.infinity,
        );
    final titleStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (titleTrailing == null)
                Text(title, style: titleStyle)
              else
                SizedBox(
                  height: 32,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Text(title, style: titleStyle)),
                      const SizedBox(width: 8),
                      titleTrailing!,
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Flexible(child: SingleChildScrollView(child: content)),
              if (errorText != null && errorText!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  errorText!,
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AppDialogActionRow(
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
                onCancel: () => Navigator.of(context).pop(),
                onConfirm: onConfirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppDialogPasteButton extends StatelessWidget {
  const AppDialogPasteButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('dialog-paste-button'),
      onPressed: onPressed,
      icon: const Icon(LucideIcons.clipboardPaste, size: 16),
      label: const Text('粘贴'),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class AppDialogField extends StatefulWidget {
  const AppDialogField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  State<AppDialogField> createState() => _AppDialogFieldState();
}

class _AppDialogFieldState extends State<AppDialogField> {
  var _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (_hasFocus != hasFocus) {
          setState(() => _hasFocus = hasFocus);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              color: _hasFocus ? AppColors.accentDark : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          widget.child,
        ],
      ),
    );
  }
}

InputDecoration appDialogInputDecoration({
  String? hintText,
  String? helperText,
  String? errorText,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: AppColors.border),
  );
  return InputDecoration(
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    filled: true,
    fillColor: AppColors.background,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.accent, width: 1.25),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.error, width: 1.25),
    ),
  );
}
