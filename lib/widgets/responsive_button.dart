import 'package:flutter/material.dart';

/// Content for buttons whose label can degrade without reducing text size.
///
/// The surrounding button supplies its own visual style, key, callback, and
/// state. This widget only selects the content that fits its finite width.
class ResponsiveButtonContent extends StatelessWidget {
  const ResponsiveButtonContent({
    required this.icon,
    required this.label,
    this.shortLabel,
    this.semanticLabel,
    this.iconSize = 18,
    this.iconOnlyBelowWidth,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? shortLabel;
  final String? semanticLabel;
  final double iconSize;
  final double? iconOnlyBelowWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final display = _displayFor(context, constraints.maxWidth);
        final fullSemantics = semanticLabel ?? label;
        switch (display) {
          case _ResponsiveButtonDisplay.full:
            return _LabelAndIcon(icon: icon, label: label, iconSize: iconSize);
          case _ResponsiveButtonDisplay.short:
            return _LabelAndIcon(
              icon: icon,
              label: shortLabel!,
              iconSize: iconSize,
            );
          case _ResponsiveButtonDisplay.iconOnly:
            return Tooltip(
              message: fullSemantics,
              child: Semantics(
                label: fullSemantics,
                child: Icon(icon, size: iconSize),
              ),
            );
        }
      },
    );
  }

  _ResponsiveButtonDisplay _displayFor(BuildContext context, double maxWidth) {
    if (!maxWidth.isFinite) return _ResponsiveButtonDisplay.full;
    if (iconOnlyBelowWidth != null && maxWidth < iconOnlyBelowWidth!) {
      return _ResponsiveButtonDisplay.iconOnly;
    }

    final fullWidth = _contentWidth(context, label);
    if (fullWidth <= maxWidth) return _ResponsiveButtonDisplay.full;

    final compactLabel = shortLabel;
    if (compactLabel != null &&
        _contentWidth(context, compactLabel) <= maxWidth) {
      return _ResponsiveButtonDisplay.short;
    }
    return _ResponsiveButtonDisplay.iconOnly;
  }

  double _contentWidth(BuildContext context, String text) {
    final textStyle = DefaultTextStyle.of(context).style;
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return iconSize + 8 + painter.width;
  }
}

class _LabelAndIcon extends StatelessWidget {
  const _LabelAndIcon({
    required this.icon,
    required this.label,
    required this.iconSize,
  });

  final IconData icon;
  final String label;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize),
        const SizedBox(width: 8),
        Text(label, maxLines: 1, softWrap: false),
      ],
    );
  }
}

enum _ResponsiveButtonDisplay { full, short, iconOnly }

/// A two-button action area that becomes a vertical stack before it overflows.
class ResponsiveTwoButtonRow extends StatelessWidget {
  const ResponsiveTwoButtonRow({
    required this.first,
    required this.second,
    this.spacing = 8,
    this.minimumButtonWidth = 44,
    this.stackBelowWidth,
    super.key,
  });

  final Widget first;
  final Widget second;
  final double spacing;
  final double minimumButtonWidth;
  final double? stackBelowWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final threshold =
            (stackBelowWidth ?? minimumButtonWidth * 2 + spacing) *
            (stackBelowWidth == null ? 1 : textScale.clamp(1, 2));
        final stack =
            constraints.maxWidth.isFinite && constraints.maxWidth < threshold;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              SizedBox(height: spacing),
              second,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: first),
            SizedBox(width: spacing),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
