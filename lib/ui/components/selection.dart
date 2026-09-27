import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/theme.dart';
import '../layout/adaptive_modal.dart';
import 'font_aware_layout_builder.dart';
import 'pressable.dart';

/// One option of a [SegmentedControl].
@immutable
class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Pill-style segmented control with a sliding thumb. Segments share the
/// width equally; when a label would not fit (narrow window, large text)
/// the options stack vertically as a list.
///
/// ```dart
/// SegmentedControl<PhotoCompareMode>(
///   options: const [
///     SegmentOption(value: PhotoCompareMode.stacked, label: '上下'),
///     SegmentOption(value: PhotoCompareMode.sideBySide, label: '并排'),
///   ],
///   value: mode,
///   onChanged: (m) => setState(() => mode = m),
/// )
/// ```
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    required this.options,
    required this.value,
    required this.onChanged,
    this.expand = true,
    this.forceStacked,
    this.collapseToIcons = true,
    this.semanticLabel,
    super.key,
  });

  final List<SegmentOption<T>> options;
  final T value;

  /// Null disables the control.
  final ValueChanged<T>? onChanged;

  /// Fill the available width (otherwise size to the widest label).
  final bool expand;

  /// Overrides the automatic stacking.
  final bool? forceStacked;

  /// When labels do not fit but every option has an icon, show icons only
  /// (labels become tooltips) before falling back to stacking.
  final bool collapseToIcons;
  final String? semanticLabel;

  static const double _pad = 3;
  static const double _segmentPadding = 12;

  TextStyle _style(BuildContext context) =>
      context.text.labelLarge!.copyWith(fontWeight: FontWeight.w600);

  double _segmentWidth(BuildContext context, SegmentOption<T> option) {
    final painter = TextPainter(
      text: TextSpan(text: option.label, style: _style(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width =
        painter.width + _segmentPadding * 2 + (option.icon != null ? 24 : 0);
    painter.dispose();
    return width + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      container: semanticLabel != null,
      child: FontAwareLayoutBuilder(
        builder: (context, constraints) {
          final widest = options
              .map((o) => _segmentWidth(context, o))
              .fold<double>(44, math.max);
          final needed = widest * options.length + _pad * 2;
          final max = constraints.maxWidth;
          final fits = !max.isFinite || needed <= max;
          final iconsNeeded = options.length * 44.0 + _pad * 2;
          final iconOnly =
              forceStacked != true &&
              !fits &&
              collapseToIcons &&
              options.every((o) => o.icon != null) &&
              iconsNeeded <= max;
          final stacked = forceStacked ?? (!fits && !iconOnly);
          if (stacked) return _buildStacked(context);
          final natural = iconOnly ? iconsNeeded : needed;
          final total = expand && max.isFinite ? max : natural;
          final segment = (total - _pad * 2) / options.length;
          return _buildRow(context, segment, iconOnly: iconOnly);
        },
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    double segment, {
    required bool iconOnly,
  }) {
    final c = context.colors;
    final index = options.indexWhere((o) => o.value == value);
    return Container(
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: Radii.pillAll,
      ),
      child: SizedBox(
        width: segment * options.length,
        child: Stack(
          children: [
            if (index >= 0)
              AnimatedPositioned(
                duration: Motion.of(context, Motion.standard),
                curve: Motion.emphasized,
                left: segment * index,
                top: 0,
                bottom: 0,
                width: segment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.isDark ? c.hairlineStrong : c.surface,
                    borderRadius: Radii.pillAll,
                    boxShadow: Elevations.level1(c),
                  ),
                ),
              ),
            Row(
              children: [
                for (final option in options)
                  SizedBox(
                    width: segment,
                    child: _segment(
                      context,
                      option,
                      stacked: false,
                      iconOnly: iconOnly,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStacked(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              decoration: BoxDecoration(
                color: option.value == value
                    ? (c.isDark ? c.hairlineStrong : c.surface)
                    : Colors.transparent,
                borderRadius: Radii.smAll,
                boxShadow: option.value == value ? Elevations.level1(c) : null,
              ),
              child: _segment(context, option, stacked: true),
            ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    SegmentOption<T> option, {
    required bool stacked,
    bool iconOnly = false,
  }) {
    final c = context.colors;
    final selected = option.value == value;
    final enabled = onChanged != null;
    final color = !enabled
        ? c.textDisabled
        : selected
        ? c.textPrimary
        : c.textSecondary;
    final label = Text(
      option.label,
      maxLines: stacked ? 3 : 1,
      overflow: TextOverflow.ellipsis,
      textAlign: stacked ? TextAlign.start : TextAlign.center,
      style: _style(context).copyWith(
        color: color,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
    if (iconOnly) {
      return Semantics(
        inMutuallyExclusiveGroup: true,
        selected: selected,
        label: option.label,
        excludeSemantics: true,
        child: Tooltip(
          message: option.label,
          excludeFromSemantics: true,
          child: MiriaPressable(
            onTap: enabled && !selected ? () => onChanged!(option.value) : null,
            enabled: enabled,
            selected: selected,
            borderRadius: Radii.pillAll,
            child: SizedBox(
              height: 38,
              child: Center(
                child: Icon(
                  option.icon,
                  size: 20,
                  color: color,
                  fill: selected ? 1 : 0,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: MiriaPressable(
        onTap: enabled && !selected ? () => onChanged!(option.value) : null,
        enabled: enabled,
        selected: selected,
        borderRadius: stacked ? Radii.smAll : Radii.pillAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: stacked ? Space.x3 : _segmentPadding,
              vertical: 6,
            ),
            child: Row(
              mainAxisAlignment: stacked
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (option.icon != null) ...[
                  Icon(
                    option.icon,
                    size: 18,
                    color: color,
                    fill: selected ? 1 : 0,
                  ),
                  const SizedBox(width: 6),
                ],
                if (stacked) Expanded(child: label) else Flexible(child: label),
                if (stacked && selected)
                  Icon(Symbols.check_rounded, size: 18, color: c.primaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One chip of a [ChipGroup].
@immutable
class ChipOption<T> {
  const ChipOption({
    required this.value,
    required this.label,
    this.icon,
    this.count,
    this.color,
    this.locale,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Small count after the label.
  final int? count;

  /// Colour dot (group colours).
  final Color? color;
  final Locale? locale;
}

/// Filter / choice chips, single or multi select, wrapping or in one
/// horizontally scrolling line.
///
/// ```dart
/// ChipGroup<String>.single(
///   options: [for (final g in groups) ChipOption(value: g.id, label: g.name)],
///   value: selectedGroupId,
///   onSelected: selectGroup,
///   scrollable: true,
/// )
///
/// ChipGroup<Filter>(
///   options: filterOptions,
///   selected: filters,
///   onChanged: (next) => setState(() => filters = next),
/// )
/// ```
class ChipGroup<T> extends StatelessWidget {
  /// Multi select (default).
  const ChipGroup({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiSelect = true,
    this.scrollable = false,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    super.key,
  });

  /// Single select: exactly one chip is selected.
  ChipGroup.single({
    required this.options,
    required T? value,
    required ValueChanged<T>? onSelected,
    this.scrollable = false,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    super.key,
  }) : selected = {?value},
       multiSelect = false,
       onChanged = onSelected == null
           ? null
           : ((Set<T> next) {
               if (next.isNotEmpty) onSelected(next.first);
             });

  final List<ChipOption<T>> options;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onChanged;
  final bool multiSelect;

  /// One line with horizontal scrolling instead of wrapping.
  final bool scrollable;

  /// Padding of the scroll view (align the first chip with the gutter).
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  void _toggle(T value) {
    final callback = onChanged;
    if (callback == null) return;
    if (!multiSelect) {
      if (!selected.contains(value)) callback({value});
      return;
    }
    final next = {...selected};
    if (!next.remove(value)) next.add(value);
    callback(next);
  }

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final option in options)
        _Chip<T>(
          option: option,
          selected: selected.contains(option.value),
          multiSelect: multiSelect,
          onTap: onChanged == null ? null : () => _toggle(option.value),
        ),
    ];
    final Widget body;
    if (scrollable) {
      body = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: Space.x2),
              chips[i],
            ],
          ],
        ),
      );
    } else {
      body = Padding(
        padding: padding,
        child: Wrap(spacing: Space.x2, children: chips),
      );
    }
    return Semantics(
      label: semanticLabel,
      container: semanticLabel != null,
      child: body,
    );
  }
}

class _Chip<T> extends StatelessWidget {
  const _Chip({
    required this.option,
    required this.selected,
    required this.multiSelect,
    required this.onTap,
  });

  final ChipOption<T> option;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final enabled = onTap != null;
    final fg = !enabled
        ? c.textDisabled
        : selected
        ? c.onPrimaryContainer
        : c.textPrimary;
    final leadingIcon = multiSelect && selected
        ? Symbols.check_rounded
        : option.icon;
    final chip = AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      decoration: BoxDecoration(
        color: selected ? c.primaryContainer : c.surface,
        borderRadius: Radii.pillAll,
        border: Border.all(
          color: selected ? c.primary.withValues(alpha: 0.35) : c.hairline,
        ),
      ),
      child: MiriaPressable(
        onTap: onTap,
        enabled: enabled,
        selected: selected,
        borderRadius: Radii.pillAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              leadingIcon != null || option.color != null ? 10 : 14,
              6,
              14,
              6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.color != null && !(multiSelect && selected)) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: option.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 16, color: fg),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    option.label,
                    locale: option.locale,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (option.count != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${option.count}',
                    style: text.labelMedium?.copyWith(
                      color: selected ? c.onPrimaryContainer : c.textTertiary,
                      fontFeatures: MiriaFonts.tabular,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    // Transparent padding extends the hit target to 44 px.
    return Semantics(
      inMutuallyExclusiveGroup: !multiSelect,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        excludeFromSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: chip,
        ),
      ),
    );
  }
}

/// One option of a [SelectField].
@immutable
class SelectOption<T> {
  const SelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/// Field-looking button that opens an adaptive picker (bottom list on
/// touch / compact, anchored popup on pointer / wide) with the current
/// choice checked.
///
/// ```dart
/// SelectField<NavigationApp>(
///   label: '外部地图',
///   value: settings.navigationApp,
///   options: [for (final app in NavigationApp.values) SelectOption(value: app, label: app.label)],
///   onChanged: (app) => store.patch((s) => s.copyWith(navigationApp: app)),
/// )
/// ```
class SelectField<T> extends StatelessWidget {
  const SelectField({
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint = '请选择',
    this.pickerTitle,
    this.helper,
    this.error,
    super.key,
  });

  final List<SelectOption<T>> options;
  final T? value;

  /// Null disables the field.
  final ValueChanged<T>? onChanged;
  final String? label;
  final String hint;

  /// Title of the picker; defaults to [label].
  final String? pickerTitle;
  final String? helper;
  final String? error;

  Future<void> _open(BuildContext anchor) async {
    final picked = await showAdaptiveMenu<T>(
      anchor,
      anchor: anchor,
      title: pickerTitle ?? label,
      items: [
        for (final option in options)
          AdaptiveMenuItem(
            label: option.label,
            value: option.value,
            subtitle: option.subtitle,
            icon: option.icon,
            checked: option.value == value,
          ),
      ],
    );
    if (picked != null && picked != value) onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final enabled = onChanged != null;
    SelectOption<T>? current;
    for (final option in options) {
      if (option.value == value) current = option;
    }
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ExcludeSemantics(
              child: Text(
                label!,
                style: text.labelMedium?.copyWith(
                  color: hasError ? c.danger : c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Builder(
          builder: (anchor) => DecoratedBox(
            decoration: BoxDecoration(
              color: enabled ? c.surfaceSunken : c.surfaceMuted,
              borderRadius: Radii.smAll,
              border: Border.all(color: hasError ? c.danger : c.hairline),
            ),
            child: MiriaPressable(
              onTap: enabled ? () => _open(anchor) : null,
              enabled: enabled,
              semanticLabel: [?label, current?.label ?? hint].join('：'),
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 46),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  child: Row(
                    children: [
                      if (current?.icon != null) ...[
                        Icon(current!.icon, size: 20, color: c.textSecondary),
                        const SizedBox(width: Space.x2),
                      ],
                      Expanded(
                        child: Text(
                          current?.label ?? hint,
                          style: text.bodyLarge?.copyWith(
                            color: !enabled
                                ? c.textDisabled
                                : current == null
                                ? c.textTertiary
                                : c.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Symbols.unfold_more_rounded,
                        size: 20,
                        color: enabled ? c.textSecondary : c.textDisabled,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (error != null || helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              error ?? helper!,
              style: text.bodySmall?.copyWith(
                color: hasError ? c.danger : c.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
