import 'package:flutter/material.dart';

import '../design/theme.dart';
import 'window_class.dart';

/// Preview + controls layout for editors (DESIGN §5.3 "编辑器双栏"): auto
/// grading, comparison export, capture confirmation.
///
/// * Compact portrait: preview on top, controls below (preview gets
///   [previewFlex] of the height, controls the rest).
/// * Wide (≥ 720) or landscape (width > height and ≥ 560): preview on the
///   left, a [controlsWidth] (340) control column on the right.
///
/// Both panes receive bounded constraints; make [controls] scrollable
/// (e.g. a `ListView`).
///
/// ```dart
/// EditorLayout(
///   preview: PhotoCompare.images(...),
///   controls: ListView(children: [SliderRow(...), ...]),
/// )
/// ```
class EditorLayout extends StatelessWidget {
  const EditorLayout({
    required this.preview,
    required this.controls,
    this.controlsWidth = 340,
    this.previewFlex = 5,
    this.controlsFlex = 6,
    this.previewBackground,
    this.controlsBackground,
    this.forceSideBySide,
    super.key,
  });

  final Widget preview;
  final Widget controls;
  final double controlsWidth;
  final int previewFlex;
  final int controlsFlex;

  /// Defaults to `colors.surfaceMuted`; pass `colors.darkroom` for photo
  /// editors that want an immersive stage.
  final Color? previewBackground;

  /// Defaults to `colors.surface`.
  final Color? controlsBackground;

  /// Overrides the automatic decision.
  final bool? forceSideBySide;

  /// Whether [EditorLayout] would place the panes side by side in a window
  /// of [size].
  static bool sideBySideFor(Size size) =>
      size.width >= kSidePanelMinWidth ||
      (size.width > size.height && size.width >= 560);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final side = forceSideBySide ?? sideBySideFor(context.layout.size);
    final stage = ColoredBox(
      color: previewBackground ?? c.surfaceMuted,
      child: preview,
    );
    final panel = ColoredBox(
      color: controlsBackground ?? c.surface,
      child: controls,
    );
    if (side) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: stage),
          VerticalDivider(width: 1, thickness: 1, color: c.hairline),
          SizedBox(width: controlsWidth, child: panel),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: previewFlex, child: stage),
        Divider(height: 1, thickness: 1, color: c.hairline),
        Expanded(flex: controlsFlex, child: panel),
      ],
    );
  }
}
