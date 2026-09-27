import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../application/settings_store.dart';
import '../../map/map_marker_scale.dart';
import '../../map/map_tile_config.dart';
import '../../plan/pilgrimage_models.dart';
import '../design/theme.dart';
import 'map_markers.dart';

/// A walking route: 6 px line in the configured route colour over a 12 px
/// halo at 0.28 alpha (old style), numbered stops and a destination pin.
///
/// [stops] are the stop coordinates in order; the last one is drawn as the
/// destination when [showDestination]. Stops before [firstActiveStop] are
/// drawn dimmed (already passed). Must be a child of [PlanMap].
class RouteLayer extends StatelessWidget {
  const RouteLayer({
    required this.route,
    this.stops = const [],
    this.stopNames = const [],
    this.showDestination = true,
    this.firstActiveStop = 0,
    this.settings,
    super.key,
  });

  final List<LatLng> route;
  final List<LatLng> stops;

  /// Optional names used as stop tooltips (same order as [stops]).
  final List<String> stopNames;
  final bool showDestination;
  final int firstActiveStop;
  final AppSettings? settings;

  @override
  Widget build(BuildContext context) {
    final settings =
        this.settings ??
        context.select<SettingsStore, AppSettings>((store) => store.settings);
    final dark = context.colors.isDark;
    final color = configuredMapRouteColor(settings, dark: dark);
    final scale = normalizedMapMarkerScale(settings.mapMarkerScale);
    String? nameAt(int index) =>
        index < stopNames.length && stopNames[index].trim().isNotEmpty
        ? stopNames[index]
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (route.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route,
                color: color.withValues(alpha: 0.28),
                strokeWidth: 12,
              ),
              Polyline(points: route, color: color, strokeWidth: 6),
            ],
          ),
        MarkerLayer(
          rotate: true,
          markers: [
            for (var i = 0; i < stops.length; i++)
              if (showDestination && i == stops.length - 1)
                scaledMapMarker(
                  key: const ValueKey('route-destination'),
                  point: stops[i],
                  baseSize: DestinationMarker.size,
                  scale: scale,
                  child: DestinationMarker(tooltip: nameAt(i)),
                )
              else
                scaledMapMarker(
                  key: ValueKey('route-stop-$i'),
                  point: stops[i],
                  baseSize: NumberedStopMarker.size,
                  scale: scale,
                  child: NumberedStopMarker(
                    number: i + 1,
                    color: color,
                    dimmed: i < firstActiveStop,
                    tooltip: nameAt(i),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
