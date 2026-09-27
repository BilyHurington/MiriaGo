import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../design/theme.dart';
import '../layout/input_mode.dart';

/// Whether keyboard focus should be drawn: the user is navigating with
/// Tab / arrow keys (not touching or clicking). See [InputMode].
bool get showsKeyboardFocus => InputMode.isKeyboardNavigating;

/// The Miria base for custom tappable surfaces: ink feedback, pointer-only
/// hover tint, a visible 2 px focus ring for keyboard users, secondary
/// click and long press with the pointer position, and semantics.
///
/// Prefer the higher-level components ([ListRow], [MiriaCard], buttons);
/// use this when building a custom interactive tile.
///
/// ```dart
/// MiriaPressable(
///   onTap: open,
///   semanticLabel: '打开「宇治橋」',
///   borderRadius: Radii.mdAll,
///   child: Padding(padding: const EdgeInsets.all(12), child: content),
/// )
/// ```
class MiriaPressable extends StatefulWidget {
  const MiriaPressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onContextMenu,
    this.borderRadius = Radii.smAll,
    this.selected = false,
    this.enabled = true,
    this.semanticLabel,
    this.excludeSemantics = false,
    this.button = true,
    this.hoverColor,
    this.focusNode,
    this.autofocus = false,
    this.customSemanticsActions,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Long press (touch). Receives nothing; use [onContextMenu] if you need
  /// the press position.
  final VoidCallback? onLongPress;

  /// Secondary click (right click) and — when [onLongPress] is null — long
  /// press. Receives the global pointer position.
  final ValueChanged<Offset>? onContextMenu;

  final BorderRadius borderRadius;
  final bool selected;
  final bool enabled;
  final String? semanticLabel;

  /// Replace the child's semantics with [semanticLabel].
  final bool excludeSemantics;

  /// Whether the region is announced as a button.
  final bool button;

  /// Hover tint (pointer only). Defaults to the theme hover colour.
  final Color? hoverColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions;

  @override
  State<MiriaPressable> createState() => _MiriaPressableState();
}

class _MiriaPressableState extends State<MiriaPressable> {
  bool _focused = false;
  Offset? _lastDown;

  @override
  void initState() {
    super.initState();
    InputMode.keyboardNavigating.addListener(_onHighlightMode);
  }

  @override
  void dispose() {
    InputMode.keyboardNavigating.removeListener(_onHighlightMode);
    super.dispose();
  }

  void _onHighlightMode() {
    if (_focused && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.enabled;
    final contextMenu = widget.onContextMenu;
    final longPress =
        widget.onLongPress ??
        (contextMenu == null
            ? null
            : () => contextMenu(_lastDown ?? _center(context)));
    final ring = _focused && showsKeyboardFocus;
    return Semantics(
      container: true,
      button: widget.button && widget.onTap != null,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeSemantics,
      customSemanticsActions: widget.customSemanticsActions,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          borderRadius: widget.borderRadius,
          onTap: enabled ? widget.onTap : null,
          onLongPress: enabled ? longPress : null,
          onTapDown: (details) => _lastDown = details.globalPosition,
          onSecondaryTapUp: enabled && contextMenu != null
              ? (details) => contextMenu(details.globalPosition)
              : null,
          onFocusChange: (value) => setState(() => _focused = value),
          hoverColor:
              widget.hoverColor ?? c.textPrimary.withValues(alpha: 0.04),
          focusColor: Colors.transparent,
          highlightColor: c.textPrimary.withValues(alpha: 0.06),
          splashColor: c.primary.withValues(alpha: 0.10),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: ring
                  ? Border.all(
                      color: c.primary,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    )
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Offset _center(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    return box.localToGlobal(box.size.center(Offset.zero));
  }
}

/// A 2 px keyboard-focus ring shown only while keyboard navigating. Wrap a
/// custom focusable that does not use [MiriaPressable].
class FocusRing extends StatelessWidget {
  const FocusRing({
    required this.focused,
    required this.child,
    this.borderRadius = Radii.smAll,
    super.key,
  });

  final bool focused;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: InputMode.keyboardNavigating,
      builder: (context, keyboard, _) => _ring(context, focused && keyboard),
    );
  }

  Widget _ring(BuildContext context, bool show) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: show
            ? Border.all(
                color: context.colors.primary,
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside,
              )
            : null,
      ),
      child: child,
    );
  }
}
