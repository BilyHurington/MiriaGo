import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'confirm_action_dialog.dart';

class AppInputDialog extends StatelessWidget {
  const AppInputDialog({
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel = '取消',
    super.key,
  });

  final String title;
  final Widget content;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight =
        (mediaQuery.size.height - mediaQuery.viewInsets.bottom - 48).clamp(
          0.0,
          double.infinity,
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
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              Flexible(child: SingleChildScrollView(child: content)),
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
    borderSide: const BorderSide(color: AppColors.border),
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
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.error, width: 1.25),
    ),
  );
}
