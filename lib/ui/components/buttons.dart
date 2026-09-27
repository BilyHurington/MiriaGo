import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/theme.dart';
import '../layout/input_mode.dart';
import 'font_aware_layout_builder.dart';
import 'pressable.dart';

/// Visual weight of a [MiriaButton].
enum MiriaButtonVariant {
  /// Filled primary colour. One per view.
  primary,

  /// Surface with a strong hairline. Default for secondary actions.
  secondary,

  /// Text only, primary coloured. Tertiary actions, toolbars.
  ghost,

  /// Filled danger colour. Destructive confirmations.
  danger,

  /// Primary container. Soft emphasis (e.g. 「设为当前目标」).
  tonal,
}

/// Height / density of a [MiriaButton]. Every size keeps a ≥ 44 px hit
/// target.
enum MiriaButtonSize {
  /// 48 px — bottom bars, dialogs, primary page actions.
  lg(48, 20, 20),

  /// 44 px — default.
  md(44, 16, 18),

  /// 36 px visual (hit area padded to 48) — dense toolbars, pointer UIs.
  sm(36, 12, 16);

  const MiriaButtonSize(this.height, this.horizontalPadding, this.iconSize);
  final double height;
  final double horizontalPadding;
  final double iconSize;
}

/// The Miria button.
///
/// * [variant]: primary / secondary / ghost / danger / tonal.
/// * [size]: lg / md / sm.
/// * [loading] shows a spinner in place of the icon and ignores presses.
/// * [expand] stretches the button to the available width.
/// * Responsive label: when the available width is too small for [label],
///   the button shows [shortLabel], then only [icon] (with a tooltip and
///   the full label for screen readers). Old `ResponsiveButtonContent`.
///
/// ```dart
/// MiriaButton(
///   label: '开始巡礼',
///   shortLabel: '开始',
///   icon: Symbols.explore_rounded,
///   onPressed: start,
/// )
/// ```
///
/// Responsive collapse measures its constraints; do not put a collapsible
/// button (one with an [icon] or [shortLabel]) inside `IntrinsicWidth`.
class MiriaButton extends StatelessWidget {
  const MiriaButton({
    required this.label,
    required this.onPressed,
    this.variant = MiriaButtonVariant.primary,
    this.size = MiriaButtonSize.md,
    this.icon,
    this.shortLabel,
    this.loading = false,
    this.expand = false,
    this.tooltip,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    this.trailingIcon,
    super.key,
  });

  /// Convenience for [MiriaButtonVariant.secondary].
  const MiriaButton.secondary({
    required this.label,
    required this.onPressed,
    this.size = MiriaButtonSize.md,
    this.icon,
    this.shortLabel,
    this.loading = false,
    this.expand = false,
    this.tooltip,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    this.trailingIcon,
    super.key,
  }) : variant = MiriaButtonVariant.secondary;

  /// Convenience for [MiriaButtonVariant.ghost].
  const MiriaButton.ghost({
    required this.label,
    required this.onPressed,
    this.size = MiriaButtonSize.md,
    this.icon,
    this.shortLabel,
    this.loading = false,
    this.expand = false,
    this.tooltip,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    this.trailingIcon,
    super.key,
  }) : variant = MiriaButtonVariant.ghost;

  /// Convenience for [MiriaButtonVariant.danger].
  const MiriaButton.danger({
    required this.label,
    required this.onPressed,
    this.size = MiriaButtonSize.md,
    this.icon,
    this.shortLabel,
    this.loading = false,
    this.expand = false,
    this.tooltip,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    this.trailingIcon,
    super.key,
  }) : variant = MiriaButtonVariant.danger;

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final MiriaButtonVariant variant;
  final MiriaButtonSize size;
  final IconData? icon;

  /// Shown when [label] does not fit.
  final String? shortLabel;
  final bool loading;
  final bool expand;

  /// Tooltip; defaults to the full label when the label is collapsed.
  final String? tooltip;

  /// Screen-reader label; defaults to [label].
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Small icon after the label (e.g. `Symbols.expand_more_rounded`).
  final IconData? trailingIcon;

  bool get _collapsible => icon != null || shortLabel != null;

  @override
  Widget build(BuildContext context) {
    // Rebuild when keyboard navigation starts / stops (focus ring).
    return ValueListenableBuilder<bool>(
      valueListenable: InputMode.keyboardNavigating,
      builder: (context, _, _) => _buildResponsive(context),
    );
  }

  Widget _buildResponsive(BuildContext context) {
    if (!_collapsible) {
      return _build(context, _LabelMode.full);
    }
    return FontAwareLayoutBuilder(
      builder: (context, constraints) {
        final mode = _modeFor(context, constraints.maxWidth);
        return _build(context, mode);
      },
    );
  }

  TextStyle _textStyle(BuildContext context) {
    final text = context.text;
    return (size == MiriaButtonSize.sm ? text.labelMedium : text.labelLarge)!
        .copyWith(fontWeight: FontWeight.w600);
  }

  _LabelMode _modeFor(BuildContext context, double maxWidth) {
    if (!maxWidth.isFinite) return _LabelMode.full;
    final available = maxWidth - size.horizontalPadding * 2;
    if (_contentWidth(context, label) <= available) return _LabelMode.full;
    final short = shortLabel;
    if (short != null && _contentWidth(context, short) <= available) {
      return _LabelMode.short;
    }
    return icon != null ? _LabelMode.iconOnly : _LabelMode.full;
  }

  double _contentWidth(BuildContext context, String value) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: _textStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final iconWidth = icon != null || loading ? size.iconSize + Space.x2 : 0;
    final trailing = trailingIcon != null ? size.iconSize + Space.x1 : 0;
    final width = painter.width + iconWidth + trailing + 1;
    painter.dispose();
    return width;
  }

  Widget _build(BuildContext context, _LabelMode mode) {
    final c = context.colors;
    final (bg, fg, hoverBg, border) = switch (variant) {
      MiriaButtonVariant.primary => (
        c.primary,
        c.onPrimary,
        c.primaryHover,
        null,
      ),
      MiriaButtonVariant.secondary => (
        c.surface,
        c.textPrimary,
        c.surfaceMuted,
        c.hairlineStrong,
      ),
      MiriaButtonVariant.ghost => (
        Colors.transparent,
        c.primaryText,
        c.primary.withValues(alpha: 0.08),
        null,
      ),
      MiriaButtonVariant.danger => (
        c.danger,
        c.isDark ? c.canvas : c.surface,
        Color.lerp(c.danger, c.textPrimary, 0.12)!,
        null,
      ),
      MiriaButtonVariant.tonal => (
        c.primaryContainer,
        c.onPrimaryContainer,
        Color.lerp(c.primaryContainer, c.primary, 0.12)!,
        null,
      ),
    };
    final filled =
        variant != MiriaButtonVariant.ghost &&
        variant != MiriaButtonVariant.secondary;
    final enabled = onPressed != null && !loading;
    final iconOnly = mode == _LabelMode.iconOnly;
    final visibleLabel = mode == _LabelMode.short ? shortLabel! : label;

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(size.height, size.height)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: iconOnly ? Space.x2 : size.horizontalPadding,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: Radii.smAll),
      ),
      textStyle: WidgetStatePropertyAll(_textStyle(context)),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      elevation: const WidgetStatePropertyAll(0),
      animationDuration: Motion.fast,
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) && !loading) {
          return filled ? c.surfaceMuted : Colors.transparent;
        }
        if (states.contains(WidgetState.hovered)) return hoverBg;
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) && !loading) {
          return c.textDisabled;
        }
        return fg;
      }),
      iconColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) && !loading) {
          return c.textDisabled;
        }
        return fg;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        final base = filled ? fg : c.textPrimary;
        if (states.contains(WidgetState.pressed)) {
          return base.withValues(alpha: 0.12);
        }
        return Colors.transparent;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused) && showsKeyboardFocus) {
          return BorderSide(
            color: c.primary,
            width: 2,
            strokeAlign: filled
                ? BorderSide.strokeAlignOutside
                : BorderSide.strokeAlignInside,
          );
        }
        if (border == null) return BorderSide.none;
        if (states.contains(WidgetState.disabled) && !loading) {
          return BorderSide(color: c.hairline);
        }
        return BorderSide(color: border);
      }),
      mouseCursor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
      ),
    );

    final spinner = SizedBox.square(
      dimension: size.iconSize - 2,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: fg,
        semanticsLabel: '正在处理',
      ),
    );
    final leading = loading
        ? spinner
        : icon == null
        ? null
        : Icon(icon, size: size.iconSize);

    Widget content;
    if (iconOnly) {
      content = leading!;
    } else {
      content = Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: Space.x2)],
          Flexible(
            child: Text(
              visibleLabel,
              maxLines: _collapsible ? 1 : 2,
              softWrap: !_collapsible,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: Space.x1),
            Icon(trailingIcon, size: size.iconSize),
          ],
        ],
      );
    }

    Widget button = TextButton(
      onPressed: enabled ? onPressed : null,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      child: Semantics(
        label: semanticLabel ?? label,
        excludeSemantics: true,
        child: content,
      ),
    );
    final tip = tooltip ?? (mode == _LabelMode.full ? null : label);
    if (tip != null) {
      button = Tooltip(message: tip, excludeFromSemantics: true, child: button);
    }
    if (expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

enum _LabelMode { full, short, iconOnly }

/// Visual style of a [MiriaIconButton].
enum MiriaIconButtonVariant {
  /// No background.
  plain,

  /// Muted background (toolbar toggles).
  filled,

  /// Primary background.
  primary,

  /// Translucent floating chrome with a soft shadow (over maps / photos).
  overlay,
}

/// Icon-only button. A [tooltip] is required and doubles as the
/// screen-reader label.
///
/// * [selected] fills the icon and tints it with the primary colour
///   (toggle buttons); announced as selected.
/// * [badgeCount] / [badgeDot] show a small badge on the icon.
///
/// ```dart
/// MiriaIconButton(
///   icon: Symbols.layers_rounded,
///   tooltip: '叠影',
///   selected: overlayOn,
///   onPressed: toggleOverlay,
/// )
/// ```
class MiriaIconButton extends StatelessWidget {
  const MiriaIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = MiriaIconButtonVariant.plain,
    this.selected = false,
    this.selectedIcon,
    this.compact = false,
    this.badgeCount,
    this.badgeDot = false,
    this.color,
    this.focusNode,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final MiriaIconButtonVariant variant;
  final bool selected;

  /// Icon when [selected]; defaults to [icon] with fill 1.
  final IconData? selectedIcon;

  /// 36 px visual (hit area stays ≥ 44).
  final bool compact;
  final int? badgeCount;
  final bool badgeDot;

  /// Foreground override (e.g. `colors.onDarkroom` in the camera).
  final Color? color;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: InputMode.keyboardNavigating,
      builder: (context, _, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final c = context.colors;
    final dimension = compact ? 36.0 : 44.0;
    final iconSize = compact ? 20.0 : 22.0;
    final (Color bg, Color fg) = switch (variant) {
      MiriaIconButtonVariant.plain => (
        selected ? c.primaryContainer : Colors.transparent,
        selected ? c.onPrimaryContainer : c.textPrimary,
      ),
      MiriaIconButtonVariant.filled => (
        selected ? c.primaryContainer : c.surfaceMuted,
        selected ? c.onPrimaryContainer : c.textPrimary,
      ),
      MiriaIconButtonVariant.primary => (c.primary, c.onPrimary),
      MiriaIconButtonVariant.overlay => (
        c.surfaceOverlay,
        selected ? c.primaryText : c.textPrimary,
      ),
    };
    final foreground = color ?? fg;
    Widget glyph = Icon(
      selected ? (selectedIcon ?? icon) : icon,
      size: iconSize,
      fill: selected ? 1 : 0,
    );
    final count = badgeCount;
    if (badgeDot || (count != null && count > 0)) {
      glyph = Badge(
        smallSize: 8,
        isLabelVisible: true,
        label: count == null || count <= 0
            ? null
            : Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(fontFeatures: MiriaFonts.tabular),
              ),
        child: glyph,
      );
    }
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      focusNode: focusNode,
      isSelected: selected,
      icon: glyph,
      style: ButtonStyle(
        fixedSize: WidgetStatePropertyAll(Size.square(dimension)),
        minimumSize: WidgetStatePropertyAll(Size.square(dimension)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: variant == MiriaIconButtonVariant.overlay
                ? Radii.pillAll
                : Radii.smAll,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled) &&
              variant == MiriaIconButtonVariant.primary) {
            return c.surfaceMuted;
          }
          if (states.contains(WidgetState.hovered)) {
            return switch (variant) {
              MiriaIconButtonVariant.primary => c.primaryHover,
              MiriaIconButtonVariant.overlay => c.surface,
              _ => Color.alphaBlend(c.textPrimary.withValues(alpha: 0.06), bg),
            };
          }
          return bg;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.textDisabled;
          return foreground;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return foreground.withValues(alpha: 0.12);
          }
          return Colors.transparent;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused) && showsKeyboardFocus) {
            return BorderSide(color: c.primary, width: 2);
          }
          if (variant == MiriaIconButtonVariant.overlay) {
            return BorderSide(color: c.hairline.withValues(alpha: 0.6));
          }
          return BorderSide.none;
        }),
      ),
    );
    if (variant != MiriaIconButtonVariant.overlay) return button;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: Elevations.level1(c),
      ),
      child: button,
    );
  }
}

/// Split navigation button (old `SplitNavigationButton`): left half starts
/// in-app walking navigation, right half opens the external map app.
///
/// Semantics: 「应用内导航：{label}」 and 「打开外部地图」. When the point has
/// no coordinates pass `available: false`: both halves are disabled and the
/// label reads 「坐标待补充」.
///
/// ```dart
/// SplitNavButton(
///   available: point.hasCoordinates,
///   onNavigate: () => openRoutePreview(context, pointId: point.id),
///   onOpenExternal: () => launcher.open(point),
/// )
/// ```
class SplitNavButton extends StatelessWidget {
  const SplitNavButton({
    required this.onNavigate,
    required this.onOpenExternal,
    this.label = '导航',
    this.available = true,
    this.size = MiriaButtonSize.md,
    this.inAppKey = const ValueKey('map-in-app-navigation-button'),
    this.externalKey = const ValueKey('map-external-navigation-button'),
    super.key,
  });

  final VoidCallback? onNavigate;
  final VoidCallback? onOpenExternal;

  /// Visible label of the in-app half.
  final String label;

  /// False when the point has no coordinates.
  final bool available;
  final MiriaButtonSize size;
  final Key inAppKey;
  final Key externalKey;

  static const unavailableLabel = '坐标待补充';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final navigate = available ? onNavigate : null;
    final external = available ? onOpenExternal : null;
    final enabled = navigate != null || external != null;
    final bg = enabled ? c.primary : c.surfaceMuted;
    final fg = enabled ? c.onPrimary : c.textDisabled;
    final shownLabel = available ? label : unavailableLabel;
    final textStyle =
        (size == MiriaButtonSize.sm
                ? context.text.labelMedium
                : context.text.labelLarge)!
            .copyWith(
              fontWeight: FontWeight.w600,
              color: navigate == null ? c.textDisabled : fg,
            );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: size.height),
      child: Material(
        color: bg,
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SplitHalf(
                  key: inAppKey,
                  semanticLabel: '应用内导航：$shownLabel',
                  onTap: navigate,
                  foreground: fg,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Symbols.directions_walk_rounded,
                        size: size.iconSize + 2,
                        color: navigate == null ? c.textDisabled : fg,
                      ),
                      const SizedBox(width: Space.x2),
                      Flexible(
                        child: Text(
                          shownLabel,
                          style: textStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.x3),
                child: VerticalDivider(
                  key: const ValueKey('map-navigation-button-divider'),
                  width: 1,
                  thickness: 1,
                  color: fg.withValues(alpha: 0.32),
                ),
              ),
              SizedBox(
                width: size.height + Space.x2,
                child: _SplitHalf(
                  key: externalKey,
                  semanticLabel: '打开外部地图',
                  onTap: external,
                  foreground: fg,
                  child: Icon(
                    Symbols.open_in_new_rounded,
                    size: size.iconSize,
                    color: external == null ? c.textDisabled : fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitHalf extends StatefulWidget {
  const _SplitHalf({
    required this.semanticLabel,
    required this.onTap,
    required this.foreground,
    required this.child,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback? onTap;
  final Color foreground;
  final Widget child;

  @override
  State<_SplitHalf> createState() => _SplitHalfState();
}

class _SplitHalfState extends State<_SplitHalf> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.semanticLabel,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (value) => setState(() => _focused = value),
          hoverColor: widget.foreground.withValues(alpha: 0.10),
          focusColor: Colors.transparent,
          highlightColor: widget.foreground.withValues(alpha: 0.12),
          splashColor: widget.foreground.withValues(alpha: 0.12),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: Radii.smAll,
              border: _focused && showsKeyboardFocus
                  ? Border.all(color: c.onPrimary, width: 2)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x3,
                vertical: Space.x2,
              ),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
