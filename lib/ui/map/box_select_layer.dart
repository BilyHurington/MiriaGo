import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../design/theme.dart';

/// The geographic bounds covered by the screen rectangle [rect] of a map
/// showing [camera]. All four corners are used, so it stays correct for a
/// rotated camera.
LatLngBounds boundsForScreenRect(MapCamera camera, Rect rect) {
  final normalized = Rect.fromLTRB(
    math.min(rect.left, rect.right),
    math.min(rect.top, rect.bottom),
    math.max(rect.left, rect.right),
    math.max(rect.top, rect.bottom),
  );
  return LatLngBounds.fromPoints([
    camera.screenOffsetToLatLng(normalized.topLeft),
    camera.screenOffsetToLatLng(normalized.topRight),
    camera.screenOffsetToLatLng(normalized.bottomLeft),
    camera.screenOffsetToLatLng(normalized.bottomRight),
  ]);
}

/// Items of [items] whose position lies inside [bounds].
List<T> itemsInBounds<T>(
  Iterable<T> items,
  LatLng? Function(T item) positionOf,
  LatLngBounds bounds,
) => [
  for (final item in items)
    if (positionOf(item) case final position? when bounds.contains(position))
      item,
];

/// Holds the current box selection (two opposite corners).
class BoxSelectController extends ChangeNotifier {
  LatLng? _start;
  LatLng? _end;

  LatLng? get start => _start;
  LatLng? get end => _end;

  /// Selected bounds, or null when nothing is selected.
  LatLngBounds? get bounds {
    final start = _start;
    final end = _end;
    if (start == null || end == null) return null;
    return LatLngBounds.fromPoints([start, end]);
  }

  bool get hasSelection => bounds != null;

  void setCorners(LatLng start, LatLng end) {
    if (_start == start && _end == end) return;
    _start = start;
    _end = end;
    notifyListeners();
  }

  void clear() {
    if (_start == null && _end == null) return;
    _start = null;
    _end = null;
    notifyListeners();
  }
}

/// Drag-a-rectangle selection on a [PlanMap] (must be one of its
/// `children`).
///
/// While [active], the layer claims every pointer on the map, so the map
/// does not pan; dragging draws a primary dashed rectangle with a
/// translucent fill. The selection is stored as coordinates, so it stays
/// put when the map is zoomed afterwards. Inactive, it only paints the
/// current selection (if any) and lets gestures through.
class BoxSelectLayer extends StatefulWidget {
  const BoxSelectLayer({
    required this.active,
    this.controller,
    this.onChanged,
    this.onSelected,
    this.clearWhenDeactivated = true,
    super.key,
  });

  final bool active;
  final BoxSelectController? controller;

  /// Called while dragging.
  final ValueChanged<LatLngBounds>? onChanged;

  /// Called when a drag ends.
  final ValueChanged<LatLngBounds>? onSelected;

  /// Clears the selection when [active] turns false.
  final bool clearWhenDeactivated;

  @override
  State<BoxSelectLayer> createState() => _BoxSelectLayerState();
}

class _BoxSelectLayerState extends State<BoxSelectLayer> {
  BoxSelectController? _ownController;
  int? _pointer;

  BoxSelectController get _controller =>
      widget.controller ?? (_ownController ??= BoxSelectController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant BoxSelectLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.controller ?? _ownController;
    if (!identical(oldController, _controller)) {
      oldController?.removeListener(_changed);
      _controller.addListener(_changed);
    }
    if (oldWidget.active && !widget.active) {
      _pointer = null;
      if (widget.clearWhenDeactivated) _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _ownController?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    final camera = MapCamera.of(context);
    final point = camera.screenOffsetToLatLng(event.localPosition);
    _controller.setCorners(point, point);
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final start = _controller.start;
    if (start == null) return;
    final camera = MapCamera.of(context);
    _controller.setCorners(
      start,
      camera.screenOffsetToLatLng(event.localPosition),
    );
    final bounds = _controller.bounds;
    if (bounds != null) widget.onChanged?.call(bounds);
  }

  void _onUp(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    final bounds = _controller.bounds;
    if (bounds != null) widget.onSelected?.call(bounds);
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final start = _controller.start;
    final end = _controller.end;
    final colors = context.colors;
    final painter = _SelectionPainter(
      rect: start == null || end == null
          ? null
          : Rect.fromPoints(
              camera.latLngToScreenOffset(start),
              camera.latLngToScreenOffset(end),
            ),
      color: colors.primary,
    );
    final paint = CustomPaint(painter: painter, child: const SizedBox.expand());
    if (!widget.active) return IgnorePointer(child: paint);
    return Semantics(
      label: '框选点位',
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            // Wins the gesture arena immediately so the map never pans.
            EagerGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                  EagerGestureRecognizer.new,
                  (_) {},
                ),
          },
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onUp,
            child: paint,
          ),
        ),
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter({required this.rect, required this.color});

  final Rect? rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = this.rect;
    if (rect == null) return;
    final normalized = Rect.fromLTRB(
      math.min(rect.left, rect.right),
      math.min(rect.top, rect.bottom),
      math.max(rect.left, rect.right),
      math.max(rect.top, rect.bottom),
    );
    canvas.drawRect(normalized, Paint()..color = color.withValues(alpha: 0.12));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRect(normalized);
    for (final metric in path.computeMetrics()) {
      _dash(canvas, metric, stroke);
    }
  }

  void _dash(Canvas canvas, ui.PathMetric metric, Paint paint) {
    const dash = 8.0;
    const gap = 5.0;
    var distance = 0.0;
    while (distance < metric.length) {
      final next = math.min(distance + dash, metric.length);
      canvas.drawPath(metric.extractPath(distance, next), paint);
      distance = next + gap;
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      old.rect != rect || old.color != color;
}
