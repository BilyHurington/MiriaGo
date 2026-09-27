import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/theme.dart';
import 'route.dart';

/// Point status pill: 待访问 (neutral), 当前目标 (spot yellow with ✦),
/// 已完成 (success with check).
///
/// ```dart
/// StatusBadge(status: point.status)
/// ```
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, this.compact = false, super.key});

  final VisitStatus status;

  /// Smaller padding for dense rows.
  final bool compact;

  static String labelFor(VisitStatus status) => RouteLine.semanticsFor(status);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color fg, Widget icon) = switch (status) {
      VisitStatus.pending => (
        c.surfaceMuted,
        c.textSecondary,
        Icon(
          Symbols.radio_button_unchecked_rounded,
          size: 13,
          color: c.textTertiary,
        ),
      ),
      VisitStatus.current => (
        c.spotContainer,
        c.isDark ? c.spot : c.onSpot,
        Sparkle(size: 12, color: c.isDark ? c.spot : c.onSpot),
      ),
      VisitStatus.completed => (
        c.successContainer,
        c.success,
        Icon(Symbols.check_circle_rounded, size: 14, color: c.success, fill: 1),
      ),
    };
    return Semantics(
      label: labelFor(status),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 2 : 3,
        ),
        decoration: BoxDecoration(color: bg, borderRadius: Radii.pillAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                labelFor(status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colour tone shared by [Tag], [CountBubble] and [InfoBanner].
enum MiriaTone { neutral, primary, spot, success, warning, danger, info }

/// Background / foreground pair of a [MiriaTone].
(Color background, Color foreground) toneColors(MiriaColors c, MiriaTone tone) {
  return switch (tone) {
    MiriaTone.neutral => (c.surfaceMuted, c.textSecondary),
    MiriaTone.primary => (c.primaryContainer, c.onPrimaryContainer),
    MiriaTone.spot => (c.spotContainer, c.isDark ? c.spot : c.onSpot),
    MiriaTone.success => (c.successContainer, c.success),
    MiriaTone.warning => (c.warningContainer, c.warning),
    MiriaTone.danger => (c.dangerContainer, c.danger),
    MiriaTone.info => (c.infoContainer, c.info),
  };
}

/// Small label chip (radius 6). Use [color] for user / group colours
/// (e.g. `colors.groupColor(i)`), otherwise a semantic [tone].
///
/// ```dart
/// Tag(label: '宇治', color: context.colors.groupColor(group.index))
/// Tag(label: '离线可用', tone: MiriaTone.success, icon: Symbols.download_done_rounded)
/// ```
class Tag extends StatelessWidget {
  const Tag({
    required this.label,
    this.tone = MiriaTone.neutral,
    this.color,
    this.icon,
    this.onTap,
    this.locale,
    super.key,
  });

  final String label;
  final MiriaTone tone;

  /// Custom accent (a dot + tinted background); overrides [tone].
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    var (bg, fg) = toneColors(c, tone);
    final accent = color;
    if (accent != null) {
      bg = accent.withValues(alpha: c.isDark ? 0.22 : 0.12);
      fg = c.textPrimary;
    }
    Widget tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: Radii.xsAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accent != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              locale: locale,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
    if (onTap != null) {
      tag = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: Radii.xsAll, child: tag),
      );
    }
    return Semantics(button: onTap != null, child: tag);
  }
}

/// Count pill with tabular figures (99+ cap).
///
/// ```dart
/// CountBubble(count: group.points.length)
/// ```
class CountBubble extends StatelessWidget {
  const CountBubble({
    required this.count,
    this.tone = MiriaTone.neutral,
    this.max = 999,
    super.key,
  });

  final int count;
  final MiriaTone tone;
  final int max;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(context.colors, tone);
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: Radii.pillAll),
      child: Text(
        count > max ? '$max+' : '$count',
        textAlign: TextAlign.center,
        style: context.text.labelSmall?.copyWith(
          color: fg,
          fontFeatures: MiriaFonts.tabular,
        ),
      ),
    );
  }
}

/// Kind of an [InfoBanner].
enum InfoBannerKind { info, success, warning, error }

/// Inline notice inside a page or panel (not a toast): icon, optional
/// title, message, optional action and dismiss button.
///
/// ```dart
/// InfoBanner(
///   kind: InfoBannerKind.warning,
///   message: '有 3 张参考图未缓存，离线时无法显示。',
///   actionLabel: '缓存',
///   onAction: startCaching,
/// )
/// ```
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.message,
    this.kind = InfoBannerKind.info,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    super.key,
  });

  final String message;
  final InfoBannerKind kind;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final (bg, fg, defaultIcon) = switch (kind) {
      InfoBannerKind.info => (c.infoContainer, c.info, Symbols.info_rounded),
      InfoBannerKind.success => (
        c.successContainer,
        c.success,
        Symbols.check_circle_rounded,
      ),
      InfoBannerKind.warning => (
        c.warningContainer,
        c.warning,
        Symbols.warning_rounded,
      ),
      InfoBannerKind.error => (
        c.dangerContainer,
        c.danger,
        Symbols.error_rounded,
      ),
    };
    return Semantics(
      container: true,
      liveRegion: kind == InfoBannerKind.error,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: Radii.smAll,
          border: Border.all(color: fg.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon ?? defaultIcon, size: 20, color: fg, fill: 1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: text.titleSmall?.copyWith(color: c.textPrimary),
                      ),
                    Text(
                      message,
                      style: text.bodySmall?.copyWith(color: c.textPrimary),
                    ),
                    if (actionLabel != null && onAction != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextButton(
                          onPressed: onAction,
                          style: TextButton.styleFrom(
                            foregroundColor: fg,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(44, 36),
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          child: Text(actionLabel!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: '关闭',
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: Icon(
                  Symbols.close_rounded,
                  size: 18,
                  color: c.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
