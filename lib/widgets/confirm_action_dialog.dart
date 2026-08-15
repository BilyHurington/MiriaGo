import 'package:flutter/material.dart';

import '../app_theme.dart';

Future<bool> showConfirmActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  String cancelLabel = '取消',
  String? notice,
  List<String> emphasizedValues = const [],
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => ConfirmActionDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
      cancelLabel: cancelLabel,
      notice: notice,
      emphasizedValues: emphasizedValues,
    ),
  );
  return confirmed == true;
}

class ConfirmActionDialog extends StatelessWidget {
  const ConfirmActionDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
    this.cancelLabel = '取消',
    this.notice,
    this.emphasizedValues = const [],
    this.additionalContent,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final String cancelLabel;
  final String? notice;
  final List<String> emphasizedValues;
  final Widget? additionalContent;

  static const dangerColor = Color(0xFFF44348);

  @override
  Widget build(BuildContext context) {
    if (!destructive) {
      return _StandardConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        notice: notice,
        emphasizedValues: emphasizedValues,
        additionalContent: additionalContent,
      );
    }

    final maxHeight = _availableDialogHeight(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
        child: SingleChildScrollView(
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
                const SizedBox(height: 12),
                _EmphasizedMessage(message, emphasizedValues: emphasizedValues),
                if (additionalContent != null) ...[
                  const SizedBox(height: 12),
                  additionalContent!,
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: dangerColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_rounded, color: dangerColor, size: 17),
                      SizedBox(width: 8),
                      Text(
                        '此操作无法撤销',
                        style: TextStyle(
                          color: dangerColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppDialogActionRow(
                  cancelLabel: cancelLabel,
                  confirmLabel: confirmLabel,
                  confirmColor: dangerColor,
                  onCancel: () => Navigator.of(context).pop(false),
                  onConfirm: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StandardConfirmDialog extends StatelessWidget {
  const _StandardConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.notice,
    required this.emphasizedValues,
    required this.additionalContent,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final String? notice;
  final List<String> emphasizedValues;
  final Widget? additionalContent;

  @override
  Widget build(BuildContext context) {
    final maxHeight = _availableDialogHeight(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
        child: SingleChildScrollView(
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
                const SizedBox(height: 12),
                _EmphasizedMessage(message, emphasizedValues: emphasizedValues),
                if (additionalContent != null) ...[
                  const SizedBox(height: 12),
                  additionalContent!,
                ],
                if (notice != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_rounded,
                          color: AppColors.accent,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notice!,
                            style: TextStyle(
                              color: AppColors.accentDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppDialogActionRow(
                  cancelLabel: cancelLabel,
                  confirmLabel: confirmLabel,
                  onCancel: () => Navigator.of(context).pop(false),
                  onConfirm: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppDialogActionRow extends StatelessWidget {
  const AppDialogActionRow({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.confirmColor,
    super.key,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Color? confirmColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: onCancel,
            style: FilledButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: AppColors.surfaceMuted,
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _DialogActionLabel(cancelLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: confirmColor ?? AppColors.accent,
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _DialogActionLabel(confirmLabel),
          ),
        ),
      ],
    );
  }
}

class _DialogActionLabel extends StatelessWidget {
  const _DialogActionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, softWrap: false),
    );
  }
}

double _availableDialogHeight(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  return (mediaQuery.size.height - mediaQuery.viewInsets.bottom - 48).clamp(
    0.0,
    double.infinity,
  );
}

class _EmphasizedMessage extends StatelessWidget {
  const _EmphasizedMessage(this.message, {required this.emphasizedValues});

  final String message;
  final List<String> emphasizedValues;

  @override
  Widget build(BuildContext context) {
    final values =
        emphasizedValues
            .where((value) => value.isNotEmpty && message.contains(value))
            .toSet()
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    final baseStyle = const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      height: 1.55,
      letterSpacing: 0,
    );
    if (values.isEmpty) {
      return Text(message, style: baseStyle);
    }

    final pattern = RegExp(values.map(RegExp.escape).join('|'));
    final spans = <TextSpan>[];
    var start = 0;
    for (final match in pattern.allMatches(message)) {
      if (match.start > start) {
        spans.add(TextSpan(text: message.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      start = match.end;
    }
    if (start < message.length) {
      spans.add(TextSpan(text: message.substring(start)));
    }
    return Text.rich(TextSpan(children: spans), style: baseStyle);
  }
}
