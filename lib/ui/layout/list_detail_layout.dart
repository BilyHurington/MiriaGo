import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/theme.dart';
import 'input_mode.dart';
import 'window_class.dart';

/// List + detail layout (DESIGN §5.3 "列表-详情").
///
/// * `expanded` and wider: a list pane (default 360–420 wide) next to the
///   detail pane, separated by a hairline. On pointer devices the divider
///   can be dragged (double-click resets it); with a keyboard focus it and
///   use ←/→.
/// * Below `expanded`: only [list] is shown. Pages push the detail as a
///   route when an item is tapped (use `context.layout.showsListDetail` to
///   decide between selecting and pushing).
///
/// When [detail] is null the wide layout shows [detailPlaceholder]
/// (typically an [EmptyState]).
///
/// ```dart
/// ListDetailLayout(
///   list: RecordsList(onSelect: ...),
///   detail: selectedId == null ? null : RecordDetail(id: selectedId),
///   detailPlaceholder: const EmptyState(title: '选择一条记录'),
/// )
/// ```
class ListDetailLayout extends StatefulWidget {
  const ListDetailLayout({
    required this.list,
    this.detail,
    this.detailPlaceholder,
    this.minListWidth = 320,
    this.maxListWidth = 520,
    this.initialListWidth,
    this.forceSinglePane,
    super.key,
  });

  final Widget list;
  final Widget? detail;
  final Widget? detailPlaceholder;

  /// Drag range of the list pane.
  final double minListWidth;
  final double maxListWidth;

  /// Starting width; defaults to 32 % of the window clamped to 360–420.
  final double? initialListWidth;

  /// Overrides the automatic decision (null = `!context.layout.showsListDetail`).
  final bool? forceSinglePane;

  @override
  State<ListDetailLayout> createState() => _ListDetailLayoutState();
}

class _ListDetailLayoutState extends State<ListDetailLayout> {
  double? _listWidth;
  bool _hovering = false;
  bool _dragging = false;
  bool _focused = false;

  double _defaultWidth(double total) =>
      widget.initialListWidth ?? (total * 0.32).clamp(360.0, 420.0);

  double _clamp(double value, double total) {
    final max = (total - 360).clamp(widget.minListWidth, widget.maxListWidth);
    return value.clamp(widget.minListWidth, max);
  }

  double? _hingeOffset(BuildContext context, double total) {
    for (final feature in MediaQuery.displayFeaturesOf(context)) {
      final bounds = feature.bounds;
      if (feature.type == DisplayFeatureType.cutout) continue;
      if (bounds.height >= MediaQuery.sizeOf(context).height * 0.5 &&
          bounds.left > 0 &&
          bounds.left < total) {
        return bounds.left;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final single = widget.forceSinglePane ?? !context.layout.showsListDetail;
    if (single) return widget.list;
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final hinge = _hingeOffset(context, total);
        final width =
            hinge ?? _clamp(_listWidth ?? _defaultWidth(total), total);
        final active = _hovering || _dragging || _focused;
        final resizable = hinge == null;
        final handle = _Divider(
          active: active,
          resizable: resizable,
          onHover: (value) => setState(() => _hovering = value),
          onFocus: (value) => setState(() => _focused = value),
          onDragStart: () => setState(() => _dragging = true),
          onDragEnd: () => setState(() => _dragging = false),
          onDrag: (dx) =>
              setState(() => _listWidth = _clamp(width + dx, total)),
          onReset: () => setState(() => _listWidth = null),
        );
        return Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: width, child: widget.list),
                AnimatedContainer(
                  duration: Motion.of(context, Motion.fast),
                  width: 1,
                  color: active ? c.primary : c.hairline,
                ),
                Expanded(
                  child:
                      widget.detail ??
                      widget.detailPlaceholder ??
                      const SizedBox.shrink(),
                ),
              ],
            ),
            if (resizable)
              Positioned(
                left: width - 4,
                top: 0,
                bottom: 0,
                width: 9,
                child: handle,
              ),
          ],
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({
    required this.active,
    required this.resizable,
    required this.onHover,
    required this.onFocus,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onDrag,
    required this.onReset,
  });

  final bool active;
  final bool resizable;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onFocus;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InputModeBuilder(
      builder: (context, pointer) {
        if (!pointer) return const SizedBox.shrink();
        return Semantics(
          label: '调整列表宽度',
          child: Focus(
            onFocusChange: onFocus,
            onKeyEvent: (node, event) {
              if (event is KeyUpEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                onDrag(-16);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                onDrag(16);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => onHover(true),
              onExit: (_) => onHover(false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => onDragStart(),
                onHorizontalDragEnd: (_) => onDragEnd(),
                onHorizontalDragCancel: onDragEnd,
                onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
                onDoubleTap: onReset,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: active ? 1 : 0,
                    duration: Motion.of(context, Motion.fast),
                    child: Container(
                      width: 4,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: Radii.pillAll,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
