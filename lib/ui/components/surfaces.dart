import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../design/theme.dart';
import 'pressable.dart';

/// Flat surface card with a 1 px hairline (DESIGN §6.4: the page stays
/// flat; only floating things get shadows).
///
/// With [onTap] the card becomes interactive: ink feedback, a hover
/// highlight on pointer devices and a keyboard focus ring.
///
/// ```dart
/// MiriaCard(
///   onTap: () => openWork(work),
///   child: WorkSummary(work),
/// )
/// ```
class MiriaCard extends StatefulWidget {
  const MiriaCard({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onContextMenu,
    this.padding = const EdgeInsets.all(Space.x4),
    this.selected = false,
    this.color,
    this.borderRadius = Radii.mdAll,
    this.semanticLabel,
    this.clip = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Right click / long press with position (see [ContextMenuRegion]).
  final ValueChanged<Offset>? onContextMenu;
  final EdgeInsetsGeometry padding;

  /// Primary outline + tinted background.
  final bool selected;

  /// Background; defaults to `colors.surface`.
  final Color? color;
  final BorderRadius borderRadius;
  final String? semanticLabel;

  /// Clip the child to the rounded shape (images edge to edge).
  final bool clip;

  @override
  State<MiriaCard> createState() => _MiriaCardState();
}

class _MiriaCardState extends State<MiriaCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final interactive =
        widget.onTap != null ||
        widget.onLongPress != null ||
        widget.onContextMenu != null;
    final borderColor = widget.selected
        ? c.primary
        : _hovered && interactive
        ? c.hairlineStrong
        : c.hairline;
    final background = widget.selected
        ? Color.alphaBlend(
            c.primaryContainer.withValues(alpha: 0.45),
            widget.color ?? c.surface,
          )
        : widget.color ?? c.surface;
    Widget content = Padding(padding: widget.padding, child: widget.child);
    if (interactive) {
      content = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: MiriaPressable(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onContextMenu: widget.onContextMenu,
          borderRadius: widget.borderRadius,
          selected: widget.selected,
          semanticLabel: widget.semanticLabel,
          child: content,
        ),
      );
    } else if (widget.semanticLabel != null) {
      content = Semantics(label: widget.semanticLabel, child: content);
    }
    return AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      clipBehavior: widget.clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: background,
        borderRadius: widget.borderRadius,
        border: Border.all(
          color: borderColor,
          width: widget.selected ? 1.5 : 1,
        ),
        boxShadow: _hovered && interactive ? Elevations.level1(c) : null,
      ),
      child: content,
    );
  }
}

/// Translucent floating chrome for maps and photos: `surfaceOverlay` +
/// background blur, hairline and a soft shadow.
///
/// Set [translucent] to false (low-end Android, slow web) to fall back to
/// an opaque surface without the blur (DESIGN §6.4).
///
/// ```dart
/// GlassPanel(
///   padding: const EdgeInsets.all(12),
///   child: CurrentTargetSummary(point),
/// )
/// ```
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(Space.x3),
    this.borderRadius = Radii.lgAll,
    this.translucent = true,
    this.blurSigma = 18,
    this.elevated = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// False → opaque surface, no blur.
  final bool translucent;
  final double blurSigma;

  /// Soft level-2 shadow.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: translucent ? Effects.glass(c) : c.surface,
        borderRadius: borderRadius,
        border: Border.all(color: c.hairline.withValues(alpha: 0.7)),
      ),
      child: Padding(padding: padding, child: child),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: elevated ? Elevations.level2(c) : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: translucent && Effects.backdropBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: decorated,
              )
            : decorated,
      ),
    );
  }
}

/// The small drag handle at the top of sheets and snap panels.
///
/// ```dart
/// Column(children: [const SheetHandle(), ...])
/// ```
class SheetHandle extends StatelessWidget {
  const SheetHandle({
    this.padding = const EdgeInsets.only(top: 8, bottom: 4),
    super.key,
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: context.colors.hairlineStrong,
            borderRadius: Radii.pillAll,
          ),
        ),
      ),
    );
  }
}
