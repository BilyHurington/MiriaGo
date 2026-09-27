import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/theme.dart';
import 'map_markers.dart';
import 'map_panel_layout.dart';
import 'plan_map.dart';

/// A [PlanMap] with a fixed pin at the centre of its visible (unobscured)
/// area, for "drag the map until the pin is on the place" location picking
/// (DESIGN §8.10 / §8.11).
///
/// [onChanged] reports the coordinate under the pin whenever the camera
/// moves (and once when the map is ready). The pin lifts while the map is
/// being dragged.
class CenterPinPicker extends StatefulWidget {
  const CenterPinPicker({
    required this.onChanged,
    this.controller,
    this.initialCenter,
    this.initialZoom = 16,
    this.obscuredInsets,
    this.layers = const [],
    this.children = const [],
    this.pinColor,
    this.tileLayerOverride,
    this.disableTiles = false,
    super.key,
  });

  final ValueChanged<LatLng> onChanged;
  final PlanMapController? controller;
  final LatLng? initialCenter;
  final double initialZoom;

  /// Area covered by floating UI; defaults to the enclosing
  /// [MapPanelLayout]'s resting insets.
  final EdgeInsets? obscuredInsets;
  final List<Widget> layers;
  final List<Widget> children;

  /// Defaults to the primary colour.
  final Color? pinColor;
  final Widget? tileLayerOverride;
  final bool disableTiles;

  @override
  State<CenterPinPicker> createState() => _CenterPinPickerState();
}

class _CenterPinPickerState extends State<CenterPinPicker> {
  PlanMapController? _ownController;
  bool _moving = false;

  PlanMapController get _controller =>
      widget.controller ?? (_ownController ??= PlanMapController());

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  void _report() {
    final center = _controller.visibleCenter;
    if (center != null) widget.onChanged(center);
  }

  void _onMapEvent(MapEvent event) {
    final moving =
        event is MapEventMoveStart ||
        event is MapEventFlingAnimationStart ||
        (event is MapEventMove && event.source != MapEventSource.mapController);
    final settled =
        event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventFlingAnimationNotStarted;
    if (moving && !_moving) {
      setState(() => _moving = true);
    } else if (settled && _moving) {
      setState(() => _moving = false);
    }
    if (event is MapEventWithMove || settled) _report();
  }

  @override
  Widget build(BuildContext context) {
    final obscured =
        widget.obscuredInsets ??
        MapPanelScope.maybeOf(context)?.obscured ??
        EdgeInsets.zero;
    final colors = context.colors;
    final color = widget.pinColor ?? colors.primary;
    final reduced = Motion.reduced(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        PlanMap(
          controller: _controller,
          initialCenter: widget.initialCenter,
          initialZoom: widget.initialZoom,
          obscuredInsets: obscured,
          layers: widget.layers,
          onMapEvent: _onMapEvent,
          onMapReady: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _report();
          }),
          tileLayerOverride: widget.tileLayerOverride,
          disableTiles: widget.disableTiles,
          children: widget.children,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: obscured,
              child: Center(
                child: SizedBox(
                  // Pin tip sits exactly on the centre.
                  width: 48,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ground shadow / crosshair dot.
                      Container(
                        key: const ValueKey('center-pin-dot'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(color: kMapMarkerRing, width: 2),
                        ),
                      ),
                      AnimatedSlide(
                        offset: Offset(0, _moving ? -0.56 : -0.42),
                        duration: reduced ? Duration.zero : Motion.fast,
                        curve: Motion.standardCurve,
                        child: Icon(
                          Symbols.location_on_rounded,
                          key: const ValueKey('center-pin'),
                          size: 44,
                          fill: 1,
                          color: color,
                          shadows: [
                            Shadow(
                              color: colors.shadow.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
