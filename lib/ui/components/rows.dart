import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/theme.dart';
import '../layout/adaptive_modal.dart';
import '../layout/input_mode.dart';
import 'copyable_text.dart';
import 'pressable.dart';
import 'route.dart';
import 'status.dart';

/// The standard list row.
///
/// * Min height (default 56), never a fixed height: titles wrap
///   ([titleMaxLines]) and the row grows with text scale.
/// * [onTap] / [onLongPress]; hover highlight on pointer devices; keyboard
///   focus ring; [selected] tint.
/// * [contextActions] open on right click, and on long press when
///   [onLongPress] is null (same actions both ways), and are exposed to
///   screen readers as custom actions.
/// * [routeLine] draws the signature route connector in a left rail.
/// * With large text on narrow widths [trailing] moves below the texts.
///
/// ```dart
/// ListRow(
///   title: point.name,
///   titleLocale: MiriaFonts.japanese,
///   subtitle: '${group.name} · 350 m',
///   routeLine: RouteLine(status: point.status, isFirst: i == 0, isLast: i == n - 1),
///   trailing: StatusBadge(status: point.status),
///   onTap: () => showPointDetail(context, pointId: point.id, scope: scope),
///   contextActions: [MenuAction(label: '删除', destructive: true, onSelected: delete)],
/// )
/// ```
class ListRow extends StatelessWidget {
  const ListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.below,
    this.onTap,
    this.onLongPress,
    this.contextActions = const [],
    this.contextMenuTitle,
    this.selected = false,
    this.enabled = true,
    this.showChevron = false,
    this.titleLocale,
    this.subtitleLocale,
    this.titleMaxLines = 2,
    this.subtitleMaxLines = 2,
    this.titleStyle,
    this.routeLine,
    this.padding,
    this.minHeight = 56,
    this.borderRadius = BorderRadius.zero,
    this.semanticLabel,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Icon, avatar or thumbnail (vertically centred).
  final Widget? leading;

  /// Badge, count, switch, icon button…
  final Widget? trailing;

  /// Extra content under the subtitle (tags, progress).
  final Widget? below;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final List<MenuAction> contextActions;
  final String? contextMenuTitle;
  final bool selected;
  final bool enabled;

  /// Trailing chevron for rows that navigate.
  final bool showChevron;

  /// `MiriaFonts.japanese` for point / place names.
  final Locale? titleLocale;
  final Locale? subtitleLocale;
  final int titleMaxLines;
  final int subtitleMaxLines;
  final TextStyle? titleStyle;
  final RouteLine? routeLine;

  /// Defaults to 16 horizontal, 10 vertical.
  final EdgeInsetsGeometry? padding;
  final double minHeight;
  final BorderRadius borderRadius;

  /// Replaces the merged semantics of title + subtitle.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final muted = !enabled;
    final hasMenu = contextActions.isNotEmpty && enabled;

    final titleText = Text(
      title,
      locale: titleLocale,
      maxLines: titleMaxLines,
      overflow: TextOverflow.ellipsis,
      style: (titleStyle ?? text.titleSmall)?.copyWith(
        color: muted ? c.textDisabled : null,
      ),
    );
    final texts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleText,
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            locale: subtitleLocale,
            maxLines: subtitleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: muted ? c.textDisabled : c.textSecondary,
            ),
          ),
        ],
        if (below != null) ...[const SizedBox(height: Space.x2), below!],
      ],
    );

    final railWidth = routeLine?.width ?? 0;
    final basePadding =
        (padding ??
                const EdgeInsets.symmetric(
                  horizontal: Space.x4,
                  vertical: Space.x2 + 2,
                ))
            .resolve(Directionality.of(context));
    final contentPadding = basePadding.copyWith(
      left: basePadding.left + (routeLine == null ? 0 : railWidth + Space.x1),
    );

    Widget row(bool stackTrailing) => Row(
      children: [
        if (leading != null) ...[
          IconTheme.merge(
            data: IconThemeData(
              color: muted ? c.textDisabled : c.textSecondary,
              size: 22,
            ),
            child: leading!,
          ),
          const SizedBox(width: Space.x3),
        ],
        Expanded(
          child: stackTrailing
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    texts,
                    const SizedBox(height: Space.x2),
                    trailing!,
                  ],
                )
              : texts,
        ),
        if (trailing != null && !stackTrailing) ...[
          const SizedBox(width: Space.x3),
          trailing!,
        ],
        if (showChevron) ...[
          const SizedBox(width: Space.x1),
          Icon(Symbols.chevron_right_rounded, size: 20, color: c.textTertiary),
        ],
      ],
    );

    // With large text on narrow rows the trailing widget moves under the
    // texts so the title keeps a readable width.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    Widget content = Padding(
      padding: contentPadding,
      child: trailing == null || scale <= 1.2
          ? row(false)
          : LayoutBuilder(
              builder: (context, constraints) =>
                  row(constraints.maxWidth < 180 * scale),
            ),
    );

    if (routeLine != null) {
      content = Stack(
        children: [
          Positioned(
            left: basePadding.left - Space.x1,
            top: 0,
            bottom: 0,
            width: railWidth,
            child: routeLine!,
          ),
          content,
        ],
      );
    }

    return MiriaPressable(
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      onContextMenu: hasMenu
          ? (position) => showActionMenu(
              context,
              actions: contextActions,
              title: contextMenuTitle ?? title,
              position: position,
            )
          : null,
      borderRadius: borderRadius,
      selected: selected,
      enabled: enabled,
      semanticLabel: semanticLabel,
      excludeSemantics: semanticLabel != null,
      customSemanticsActions: hasMenu
          ? {
              for (final action in contextActions.where((a) => a.enabled))
                CustomSemanticsAction(label: action.label): action.onSelected,
            }
          : null,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        decoration: BoxDecoration(
          color: selected
              ? c.primaryContainer.withValues(alpha: c.isDark ? 0.55 : 0.6)
              : Colors.transparent,
          borderRadius: borderRadius,
        ),
        constraints: BoxConstraints(minHeight: minHeight),
        alignment: AlignmentDirectional.centerStart,
        child: content,
      ),
    );
  }
}

/// Heading for a group of rows: title, optional [count] bubble and a
/// trailing action.
///
/// ```dart
/// SectionHeader(title: '宇治', count: 12, actionLabel: '全部', onAction: showAll)
/// ```
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.count,
    this.trailing,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      Space.x4,
      Space.x5,
      Space.x2,
      Space.x1,
    ),
    super.key,
  });

  final String title;
  final int? count;

  /// Custom trailing widget; overrides [actionLabel].
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: context.text.titleSmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: Space.x2),
                    CountBubble(count: count!),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

/// Label / value row for details (coordinates, dates, sources).
///
/// Long press (or right click) shows the 「复制」 bubble; on pointer
/// devices a copy button is shown too. Copying toasts 「已复制」. Narrow
/// widths or large text stack label above value.
///
/// ```dart
/// KeyValueRow(label: '坐标', value: '34.8894, 135.8077', monospaceDigits: true)
/// ```
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    required this.label,
    required this.value,
    this.copyable = true,
    this.copyValue,
    this.valueLocale,
    this.monospaceDigits = false,
    this.onTap,
    this.valueWidget,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Space.x4,
      vertical: Space.x2 + 2,
    ),
    super.key,
  });

  final String label;
  final String value;
  final bool copyable;

  /// Value to copy when different from the visible one.
  final String? copyValue;
  final Locale? valueLocale;

  /// Tabular figures (coordinates, sizes).
  final bool monospaceDigits;
  final VoidCallback? onTap;

  /// Replaces the value text (copying still uses [value]).
  final Widget? valueWidget;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final canCopy = copyable && value.isNotEmpty;
    final valueStyle = text.bodyMedium?.copyWith(
      color: c.textPrimary,
      fontFeatures: monospaceDigits ? MiriaFonts.tabular : null,
    );
    return InputModeBuilder(
      builder: (context, pointer) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final stacked = constraints.maxWidth < 300 * math.max(1, scale * 0.9);
          final labelText = Text(
            label,
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          );
          final valueText = Builder(
            builder: (valueContext) =>
                valueWidget ??
                Text(
                  value,
                  locale: valueLocale,
                  textAlign: stacked ? TextAlign.start : TextAlign.end,
                  style: valueStyle,
                ),
          );
          final copyButton = canCopy && pointer
              ? Padding(
                  padding: const EdgeInsets.only(left: Space.x1),
                  child: IconButton(
                    tooltip: '复制$label',
                    visualDensity: VisualDensity.compact,
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(Size(32, 32)),
                      fixedSize: WidgetStatePropertyAll(Size(32, 32)),
                      padding: WidgetStatePropertyAll(EdgeInsets.zero),
                    ),
                    onPressed: () => copyToClipboard(
                      context,
                      copyValue ?? value,
                      label: label,
                    ),
                    icon: Icon(
                      Symbols.content_copy_rounded,
                      size: 16,
                      color: c.textTertiary,
                    ),
                  ),
                )
              : null;
          final body = stacked
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          labelText,
                          const SizedBox(height: 2),
                          valueText,
                        ],
                      ),
                    ),
                    ?copyButton,
                  ],
                )
              : Row(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.42,
                      ),
                      child: labelText,
                    ),
                    const SizedBox(width: Space.x4),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: valueText,
                      ),
                    ),
                    ?copyButton,
                  ],
                );
          return Builder(
            builder: (rowContext) => MiriaPressable(
              onTap: onTap,
              button: onTap != null,
              borderRadius: BorderRadius.zero,
              onLongPress: canCopy
                  ? () => showCopyBubble(
                      rowContext,
                      value: copyValue ?? value,
                      label: label,
                    )
                  : null,
              onContextMenu: canCopy
                  ? (_) => showCopyBubble(
                      rowContext,
                      value: copyValue ?? value,
                      label: label,
                    )
                  : null,
              customSemanticsActions: canCopy
                  ? {
                      CustomSemanticsAction(label: '复制$label'): () =>
                          copyToClipboard(
                            context,
                            copyValue ?? value,
                            label: label,
                          ),
                    }
                  : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(padding: padding, child: body),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A row with a title, optional subtitle and a switch. The whole row is
/// tappable and announced as one toggle.
///
/// ```dart
/// SwitchRow(
///   title: '显示参考图缩略图',
///   subtitle: '在地图上用参考图代替圆点',
///   value: settings.thumbnails,
///   onChanged: (v) => store.patch((s) => s.copyWith(thumbnails: v)),
/// )
/// ```
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Space.x4,
      vertical: Space.x2 + 2,
    ),
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;

  /// Null disables the row.
  final ValueChanged<bool>? onChanged;
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final enabled = onChanged != null;
    return MergeSemantics(
      child: MiriaPressable(
        onTap: enabled ? () => onChanged!(!value) : null,
        enabled: enabled,
        button: false,
        borderRadius: BorderRadius.zero,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                if (leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(
                      color: enabled ? c.textSecondary : c.textDisabled,
                      size: 22,
                    ),
                    child: leading!,
                  ),
                  const SizedBox(width: Space.x3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: text.bodyLarge?.copyWith(
                          color: enabled ? c.textPrimary : c.textDisabled,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: text.bodySmall?.copyWith(
                            color: enabled ? c.textSecondary : c.textDisabled,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.x3),
                ExcludeFocus(
                  child: Switch(value: value, onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slider padding used by Miria rows: the track reaches close to the row
/// gutters while the hit area stays 48 px tall.
const EdgeInsets kMiriaSliderPadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 14,
);

/// Title + value capsule + slider. Supports a logarithmic scale
/// ([logScale], requires `min > 0`) and [divisions].
///
/// ```dart
/// SliderRow(
///   title: '曝光',
///   value: exposure,
///   min: -2, max: 2, divisions: 40,
///   format: (v) => v.toStringAsFixed(1),
///   onChanged: setExposure,
/// )
/// ```
class SliderRow extends StatelessWidget {
  const SliderRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.logScale = false,
    this.format,
    this.subtitle,
    this.onChangeStart,
    this.onChangeEnd,
    this.padding = const EdgeInsets.fromLTRB(
      Space.x4,
      Space.x2 + 2,
      Space.x4,
      Space.x1,
    ),
    super.key,
  }) : assert(!logScale || min > 0, 'logScale requires min > 0');

  final String title;
  final double value;

  /// Null disables the slider.
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final bool logScale;

  /// Text of the value capsule and screen-reader value.
  final String Function(double value)? format;
  final String? subtitle;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final EdgeInsetsGeometry padding;

  double _toSlider(double v) {
    final clamped = v.clamp(min, max);
    if (!logScale) return clamped;
    return (math.log(clamped) - math.log(min)) /
        (math.log(max) - math.log(min));
  }

  double _fromSlider(double t) {
    if (!logScale) return t;
    return math.exp(math.log(min) + t * (math.log(max) - math.log(min)));
  }

  String _format(double v) =>
      format?.call(v) ??
      (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final enabled = onChanged != null;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: text.bodyLarge?.copyWith(
                        color: enabled ? c.textPrimary : c.textDisabled,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: Space.x2),
              ValueCapsule(label: _format(value), enabled: enabled),
            ],
          ),
          Slider(
            padding: kMiriaSliderPadding,
            value: _toSlider(value),
            min: logScale ? 0 : min,
            max: logScale ? 1 : max,
            divisions: divisions,
            label: _format(value),
            semanticFormatterCallback: (t) => _format(_fromSlider(t)),
            onChangeStart: onChangeStart == null
                ? null
                : (t) => onChangeStart!(_fromSlider(t)),
            onChangeEnd: onChangeEnd == null
                ? null
                : (t) => onChangeEnd!(_fromSlider(t)),
            onChanged: onChanged == null
                ? null
                : (t) => onChanged!(_fromSlider(t)),
          ),
        ],
      ),
    );
  }
}

/// Small pill showing a numeric value with tabular figures (used by
/// [SliderRow]; handy next to any control).
class ValueCapsule extends StatelessWidget {
  const ValueCapsule({required this.label, this.enabled = true, super.key});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: enabled ? c.primaryContainer : c.surfaceMuted,
        borderRadius: Radii.pillAll,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: context.text.labelMedium?.copyWith(
          color: enabled ? c.onPrimaryContainer : c.textDisabled,
          fontFeatures: MiriaFonts.tabular,
        ),
      ),
    );
  }
}
