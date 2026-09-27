import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../components/components.dart';

/// A titled card grouping related settings. Children are laid out edge to
/// edge (rows bring their own 16 px gutters); wrap free-form content in
/// [SettingsBlock].
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.children,
    this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x3),
      child: MiriaCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.x4,
                  Space.x4,
                  Space.x4,
                  Space.x1,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title!, style: text.titleSmall),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: text.bodySmall?.copyWith(
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              )
            else
              const SizedBox(height: Space.x2),
            ...children,
            const SizedBox(height: Space.x2),
          ],
        ),
      ),
    );
  }
}

/// Free-form content inside a [SettingsGroup] with the row gutters.
class SettingsBlock extends StatelessWidget {
  const SettingsBlock({
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Space.x4,
      vertical: Space.x2,
    ),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(padding: padding, child: child);
}

/// Secondary explanatory text inside a group.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SettingsBlock(
      padding: const EdgeInsets.fromLTRB(
        Space.x4,
        Space.x1,
        Space.x4,
        Space.x2,
      ),
      child: Text(
        text,
        style: context.text.bodySmall?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

/// A small heading inside a group.
class SettingsSubheading extends StatelessWidget {
  const SettingsSubheading(this.title, {this.icon, super.key});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SettingsBlock(
      padding: const EdgeInsets.fromLTRB(
        Space.x4,
        Space.x3,
        Space.x4,
        Space.x1,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: c.textSecondary),
            const SizedBox(width: Space.x2),
          ],
          Expanded(child: Text(title, style: context.text.titleSmall)),
        ],
      ),
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.x2),
    child: Divider(height: 1, thickness: 1, color: context.colors.hairline),
  );
}

// ---------------------------------------------------------------------------
// Option tiles
// ---------------------------------------------------------------------------

@immutable
class OptionTileData<T> {
  const OptionTileData({
    required this.value,
    required this.label,
    this.hint,
    this.icon,
    this.key,
  });

  final T value;
  final String label;
  final String? hint;
  final IconData? icon;
  final Key? key;
}

/// A wrapping grid of selectable tiles (aspect ratios, map sources,
/// navigation apps). Tiles keep a minimum height and grow with the text.
class OptionTileGrid<T> extends StatelessWidget {
  const OptionTileGrid({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.maxColumns = 4,
    this.minTileWidth = 72,
    this.maxTileWidth = 200,
    this.trailing = const [],
    super.key,
  });

  final List<OptionTileData<T>> options;
  final T? selected;
  final ValueChanged<T>? onSelected;
  final int maxColumns;
  final double minTileWidth;
  final double maxTileWidth;

  /// Extra tiles appended after [options] (e.g. 「自定义」).
  final List<OptionTile> trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = Space.x2;
        final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
        final minWidth = minTileWidth * scale;
        var columns = maxColumns;
        while (columns > 1 &&
            (constraints.maxWidth - spacing * (columns - 1)) / columns <
                minWidth) {
          columns--;
        }
        final tileWidth =
            ((constraints.maxWidth - spacing * (columns - 1)) / columns).clamp(
              0.0,
              maxTileWidth * scale,
            );
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final option in options)
              SizedBox(
                width: tileWidth,
                child: OptionTile(
                  key: option.key,
                  label: option.label,
                  hint: option.hint,
                  icon: option.icon,
                  selected: option.value == selected,
                  onTap: onSelected == null
                      ? null
                      : () => onSelected!(option.value),
                ),
              ),
            for (final tile in trailing)
              SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

class OptionTile extends StatelessWidget {
  const OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.icon,
    super.key,
  });

  final String label;
  final String? hint;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final fg = selected ? c.onPrimary : c.textPrimary;
    final hintColor = selected
        ? c.onPrimary.withValues(alpha: 0.82)
        : c.textSecondary;
    final leadingIcon = selected ? Symbols.check_rounded : icon;
    final labelColumn = Column(
      crossAxisAlignment: icon == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null && selected) ...[
              Icon(Symbols.check_rounded, size: 14, color: fg),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (hint != null)
          Text(
            hint!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(color: hintColor),
          ),
      ],
    );
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surface,
          borderRadius: Radii.smAll,
          border: Border.all(color: selected ? c.primary : c.hairlineStrong),
        ),
        child: MiriaPressable(
          onTap: onTap,
          borderRadius: Radii.smAll,
          selected: selected,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x2 + 2,
                vertical: Space.x2 - 2,
              ),
              child: icon == null
                  ? Center(child: labelColumn)
                  : Row(
                      children: [
                        Icon(
                          leadingIcon,
                          size: 18,
                          color: selected ? c.onPrimary : c.textSecondary,
                        ),
                        const SizedBox(width: Space.x2),
                        Expanded(child: labelColumn),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Numeric rows
// ---------------------------------------------------------------------------

/// Icon + title + description with a − value + stepper (old
/// `_NumberStepperSetting`). Stacks the stepper under the text when narrow.
class NumberStepperRow extends StatelessWidget {
  const NumberStepperRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.format,
    required this.onChanged,
    this.icon,
    super.key,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int value) format;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final stepper = MiriaStepper(
      value: value.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      step: step.toDouble(),
      semanticLabel: title,
      format: (v) => format(v.round()),
      onChanged: (v) => onChanged(v.round().clamp(min, max)),
    );
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: text.bodyLarge),
        const SizedBox(height: 2),
        Text(subtitle, style: text.bodySmall?.copyWith(color: c.textSecondary)),
      ],
    );
    return SettingsBlock(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x2 + 2,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final stacked = constraints.maxWidth < 380 * scale.clamp(1.0, 2.0);
          final leading = icon == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: Space.x3, top: 2),
                  child: Icon(icon, size: 22, color: c.textSecondary),
                );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: Space.x2),
                FittedBox(fit: BoxFit.scaleDown, child: stepper),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?leading,
              Expanded(child: label),
              const SizedBox(width: Space.x3),
              stepper,
            ],
          );
        },
      ),
    );
  }
}

/// Title + value (capsule or stepper) + slider + tick labels (old
/// `_PercentScaleControl`). The value is committed when a drag ends so the
/// layout does not jump under the finger (page zoom, font size).
class ScaleSliderRow extends StatefulWidget {
  const ScaleSliderRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.tickLabels = const [],
    this.format,
    this.showStepper = false,
    this.commitOnRelease = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final List<String> tickLabels;
  final String Function(double value)? format;
  final bool showStepper;

  /// Only call [onChanged] when the drag ends.
  final bool commitOnRelease;
  final ValueChanged<double> onChanged;

  @override
  State<ScaleSliderRow> createState() => _ScaleSliderRowState();
}

class _ScaleSliderRowState extends State<ScaleSliderRow> {
  double? _dragValue;

  double get _step => (widget.max - widget.min) / widget.divisions;

  String _format(double v) => widget.format?.call(v) ?? '${(v * 100).round()}%';

  double _snap(double v) {
    final steps = ((v - widget.min) / _step).round();
    return (widget.min + steps * _step).clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final value = (_dragValue ?? widget.value).clamp(widget.min, widget.max);
    return SettingsBlock(
      padding: const EdgeInsets.fromLTRB(
        Space.x4,
        Space.x2 + 2,
        Space.x4,
        Space.x1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.icon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(widget.icon, size: 22, color: c.textSecondary),
                ),
                const SizedBox(width: Space.x3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.title, style: text.bodyLarge),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.x2),
              if (!widget.showStepper) ValueCapsule(label: _format(value)),
            ],
          ),
          if (widget.showStepper) ...[
            const SizedBox(height: Space.x2),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: MiriaStepper(
                  value: value,
                  min: widget.min,
                  max: widget.max,
                  step: _step,
                  format: _format,
                  semanticLabel: widget.title,
                  onChanged: (v) => widget.onChanged(_snap(v)),
                ),
              ),
            ),
          ],
          Slider(
            padding: kMiriaSliderPadding,
            value: value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: _format(value),
            semanticFormatterCallback: _format,
            onChanged: (v) {
              if (widget.commitOnRelease) {
                setState(() => _dragValue = v);
              } else {
                widget.onChanged(v);
              }
            },
            onChangeEnd: widget.commitOnRelease
                ? (v) {
                    setState(() => _dragValue = null);
                    widget.onChanged(v);
                  }
                : null,
          ),
          if (widget.tickLabels.isNotEmpty)
            ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final label in widget.tickLabels)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: text.caption.copyWith(color: c.textTertiary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Link / URL rows
// ---------------------------------------------------------------------------

/// A row showing a URL (or placeholder) with an edit affordance.
class UrlRow extends StatelessWidget {
  const UrlRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListRow(
      title: label,
      titleMaxLines: 2,
      titleStyle: context.text.bodyMedium?.copyWith(color: c.textSecondary),
      leading: Icon(icon, color: c.textSecondary),
      trailing: Icon(Symbols.edit_rounded, size: 20, color: c.textSecondary),
      semanticLabel: semanticLabel,
      onTap: onTap,
    );
  }
}

/// URL input dialog of the old `_showMapUrlDialog`.
Future<String?> showUrlInputDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required String helperText,
  required String? Function(String value) validator,
}) {
  return showInputDialog(
    context,
    title: title,
    label: 'URL 地址',
    helper: helperText,
    initialValue: initialValue,
    confirmLabel: '保存',
    keyboardType: TextInputType.url,
    validator: validator,
    trim: false,
    showPasteButton: true,
  );
}

/// Label-over-value information row with copy on long press (old
/// `_AboutInfoTile` / `_InfoRow`).
class InfoLine extends StatelessWidget {
  const InfoLine({
    required this.icon,
    required this.value,
    this.label,
    this.paragraph = false,
    super.key,
  });

  final IconData icon;
  final String? label;
  final String value;

  /// Plain wrapping paragraph instead of copyable text.
  final bool paragraph;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return SettingsBlock(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x2,
      ),
      child: Row(
        crossAxisAlignment: label == null
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: label == null ? 0 : 2),
            child: Icon(icon, size: 20, color: c.textSecondary),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null) ...[
                  Text(
                    label!,
                    style: text.caption.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: 2),
                ],
                if (paragraph)
                  Text(
                    value,
                    style: text.bodyMedium?.copyWith(color: c.textSecondary),
                  )
                else
                  CopyableText(
                    text: value,
                    copyLabel: label ?? value,
                    copyText: value,
                    style: text.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps a numeric text field to decimals.
final decimalInputFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9.]'),
);
