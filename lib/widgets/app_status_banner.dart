import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';

enum AppStatusBannerKind { running, success, warning, error }

const appStatusSnackDuration = Duration(seconds: 3);

String statusBannerSentence(String text) {
  if (text.endsWith('。') && !text.substring(0, text.length - 1).contains('。')) {
    return text.substring(0, text.length - 1);
  }
  return text;
}

IconData statusBannerIcon({
  required AppStatusBannerKind kind,
  required String title,
  IconData? icon,
}) {
  if (icon != null) {
    return icon;
  }
  return switch (kind) {
    AppStatusBannerKind.success => LucideIcons.check,
    AppStatusBannerKind.warning => LucideIcons.triangleAlert,
    AppStatusBannerKind.error => LucideIcons.circleAlert,
    AppStatusBannerKind.running => statusBannerRunningIcon(title),
  };
}

IconData statusBannerRunningIcon(String title) {
  if (title.contains('取消')) {
    return LucideIcons.circleX;
  }
  if (title.contains('导出')) {
    return LucideIcons.share2;
  }
  if (title.contains('导入')) {
    return LucideIcons.mapPinPlus;
  }
  if (title.contains('替换')) {
    return LucideIcons.arrowLeftRight;
  }
  if (title.contains('比例') || title.contains('读取')) {
    return LucideIcons.ratio;
  }
  if (title.contains('清除') || title.contains('重新加载')) {
    return LucideIcons.brushCleaning;
  }
  if (title.contains('缩略图')) {
    return LucideIcons.images;
  }
  if (title.contains('缓存')) {
    return LucideIcons.refreshCw;
  }
  if (title.contains('保存')) {
    return LucideIcons.save;
  }
  return LucideIcons.hourglass;
}

SnackBar appStatusSnackBar({
  required AppStatusBannerKind kind,
  required String title,
  String? subtitle,
  IconData? icon,
  Duration duration = appStatusSnackDuration,
}) {
  return SnackBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    behavior: SnackBarBehavior.floating,
    duration: duration,
    content: AppStatusBanner(
      kind: kind,
      title: title,
      subtitle: subtitle,
      icon: icon,
    ),
  );
}

Future<void> showStatusBannerOverlay({
  required BuildContext context,
  required Widget Function(BuildContext dialogContext) builder,
}) async {
  final scaffold = context.findAncestorWidgetOfExactType<Scaffold>();
  final navExtra = scaffold?.bottomNavigationBar == null
      ? 0.0
      : (NavigationBarTheme.of(context).height ?? 80);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _AutoClosingStatusOverlay(
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + navExtra),
              child: SizedBox(
                width: double.infinity,
                child: builder(dialogContext),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AutoClosingStatusOverlay extends StatefulWidget {
  const _AutoClosingStatusOverlay({required this.child});

  final Widget child;

  @override
  State<_AutoClosingStatusOverlay> createState() =>
      _AutoClosingStatusOverlayState();
}

class _AutoClosingStatusOverlayState extends State<_AutoClosingStatusOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(appStatusSnackDuration, () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppStatusBanner extends StatelessWidget {
  const AppStatusBanner({
    super.key,
    required this.kind,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.footer,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.icon,
  });

  final AppStatusBannerKind kind;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? footer;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppStatusBannerPalette.of(kind);
    return Material(
      color: palette.background,
      elevation: kind == AppStatusBannerKind.running ? 8 : 2,
      shadowColor: Colors.black.withValues(
        alpha: AppColors.isDark ? 0.45 : 0.18,
      ),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _StatusIcon(
                  kind: kind,
                  palette: palette,
                  title: title,
                  icon: icon,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusBannerSentence(title),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: 0,
                        ),
                      ),
                      if (subtitleWidget != null ||
                          (subtitle != null && subtitle!.isNotEmpty)) ...[
                        const SizedBox(height: 2),
                        if (subtitleWidget != null)
                          subtitleWidget!
                        else
                          Text(
                            statusBannerSentence(subtitle!),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.2,
                              letterSpacing: 0,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(width: 8),
                  _ActionButton(
                    buttonKey: actionKey,
                    label: actionLabel!,
                    color: palette.action,
                    onPressed: onAction ?? () {},
                  ),
                ],
              ],
            ),
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ),
      ),
    );
  }
}

class AppStatusBannerPalette {
  const AppStatusBannerPalette({
    required this.background,
    required this.border,
    required this.iconFill,
    required this.iconColor,
    required this.action,
  });

  final Color background;
  final Color border;
  final Color iconFill;
  final Color iconColor;
  final Color action;

  factory AppStatusBannerPalette.of(AppStatusBannerKind kind) {
    final isDark = AppColors.isDark;
    final surface = AppColors.surface;
    return switch (kind) {
      AppStatusBannerKind.running => AppStatusBannerPalette(
        background: surface,
        border: AppColors.border,
        iconFill: AppColors.accent.withValues(alpha: isDark ? 0.22 : 0.12),
        iconColor: AppColors.accent,
        action: AppColors.accent,
      ),
      AppStatusBannerKind.success => AppStatusBannerPalette(
        background: isDark
            ? Color.alphaBlend(
                AppColors.accent.withValues(alpha: 0.28),
                surface,
              )
            : const Color(0xFFE8F6F1),
        border: AppColors.accent.withValues(alpha: isDark ? 0.55 : 0.38),
        iconFill: AppColors.accent,
        iconColor: Colors.white,
        action: AppColors.accent,
      ),
      AppStatusBannerKind.warning => AppStatusBannerPalette(
        background: isDark
            ? Color.alphaBlend(
                AppColors.warning.withValues(alpha: 0.28),
                surface,
              )
            : const Color(0xFFFFF6E5),
        border: AppColors.warning.withValues(alpha: isDark ? 0.58 : 0.42),
        iconFill: isDark ? AppColors.warning : const Color(0xFFE2A336),
        iconColor: Colors.white,
        action: isDark ? AppColors.warning : const Color(0xFFD48806),
      ),
      AppStatusBannerKind.error => AppStatusBannerPalette(
        background: isDark
            ? Color.alphaBlend(AppColors.error.withValues(alpha: 0.28), surface)
            : const Color(0xFFFDECEC),
        border: AppColors.error.withValues(alpha: isDark ? 0.58 : 0.42),
        iconFill: AppColors.error,
        iconColor: Colors.white,
        action: AppColors.error,
      ),
    };
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.kind,
    required this.palette,
    required this.title,
    this.icon,
  });

  final AppStatusBannerKind kind;
  final AppStatusBannerPalette palette;
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (kind == AppStatusBannerKind.warning) {
      return Icon(LucideIcons.triangleAlert, size: 32, color: palette.iconFill);
    }
    if (kind == AppStatusBannerKind.error) {
      return Icon(LucideIcons.circleAlert, size: 32, color: palette.iconFill);
    }
    final resolved = statusBannerIcon(kind: kind, title: title, icon: icon);
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: palette.iconFill,
        shape: const CircleBorder(),
      ),
      child: Icon(resolved, size: 18, color: palette.iconColor),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.buttonKey,
  });

  final Key? buttonKey;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      child: Text(label),
    );
  }
}

class AppStatusBannerProgressLine extends StatelessWidget {
  const AppStatusBannerProgressLine({
    required this.countLabel,
    required this.percentLabel,
    required this.value,
    this.barKey,
    super.key,
  });

  final String countLabel;
  final String percentLabel;
  final double value;
  final Key? barKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          countLabel,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              key: barKey,
              value: value,
              minHeight: 4,
              backgroundColor: AppColors.border.withValues(alpha: 0.7),
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          percentLabel,
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
