import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../plan/plan_group_utils.dart';
import '../widgets/app_back_button.dart';
import 'in_app_navigation_screen.dart';
import 'map_tile_config.dart';

const _endRouteRed = Color(0xFFFF3B30);

class NavigationRouteConfirmScreen extends StatelessWidget {
  const NavigationRouteConfirmScreen({
    required this.point,
    required this.settings,
    this.groupName,
    this.stops = const [],
    this.planController,
    super.key,
  });

  final PilgrimagePoint point;
  final AppSettings settings;
  final String? groupName;
  final List<PilgrimagePoint> stops;
  final PilgrimagePlanController? planController;

  static Route<void> route({
    required PilgrimagePoint point,
    required AppSettings settings,
    String? groupName,
    List<PilgrimagePoint> stops = const [],
    PilgrimagePlanController? planController,
  }) {
    return MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => NavigationRouteConfirmScreen(
        point: point,
        settings: settings,
        groupName: groupName,
        stops: stops,
        planController: planController,
      ),
    );
  }

  static Future<void> open(
    BuildContext context, {
    required PilgrimagePoint point,
    required AppSettings settings,
    String? groupName,
    List<PilgrimagePoint> stops = const [],
    PilgrimagePlanController? planController,
  }) {
    return Navigator.of(context).push<void>(
      route(
        point: point,
        settings: settings,
        groupName: groupName,
        stops: stops,
        planController: planController,
      ),
    );
  }

  static Future<void> openForPoint(
    BuildContext context, {
    required PilgrimagePoint point,
    required AppSettings settings,
    List<PlanGroupBucket> buckets = const [],
    PilgrimagePlanController? planController,
  }) {
    final tour = inAppNavigationTourFor(point: point, buckets: buckets);
    return open(
      context,
      point: point,
      settings: settings,
      groupName: tour.groupName,
      stops: tour.stops,
      planController: planController,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStops = _coordinateStops(point: point, stops: stops);
    final remainingStops = remainingNavigationStops(
      point: point,
      stops: resolvedStops,
    );
    final canChainZone = remainingStops.length >= 2;
    final routePoints = _previewPolyline([
      for (final stop in remainingStops) stop.position,
    ]);
    final brightness = resolvedAppBrightness(
      settings,
      platformBrightness: MediaQuery.platformBrightnessOf(context),
    );
    applyAppColorsFromSettings(
      settings,
      platformBrightness: MediaQuery.platformBrightnessOf(context),
    );

    return Scaffold(
      key: const ValueKey('navigation-route-confirm-screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(leading: const AppBackButton(), title: const Text('确认路线')),
      body: Column(
        children: [
          Expanded(
            child: _RoutePreviewMap(
              settings: settings,
              dark: brightness == Brightness.dark,
              routePoints: routePoints,
              stops: remainingStops,
            ),
          ),
          Material(
            color: AppColors.surface,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (groupName != null && groupName!.trim().isNotEmpty) ...[
                      _GroupNameRow(name: groupName!.trim()),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      canChainZone ? '串联整个片区' : '导航到选中点',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      canChainZone
                          ? '按顺序连接 ${remainingStops.length} 个点位：${_stopChainLabel(remainingStops)}'
                          : '终点：${point.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (canChainZone) ...[
                      _PrimaryZoneButton(
                        onTap: () => _startNavigation(
                          context,
                          chainZone: true,
                          resolvedStops: resolvedStops,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SecondaryPointButton(
                        onTap: () => _startNavigation(
                          context,
                          chainZone: false,
                          resolvedStops: resolvedStops,
                        ),
                      ),
                    ] else
                      _PrimaryZoneButton(
                        singlePoint: true,
                        onTap: () => _startNavigation(
                          context,
                          chainZone: false,
                          resolvedStops: resolvedStops,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startNavigation(
    BuildContext context, {
    required bool chainZone,
    required List<PilgrimagePoint> resolvedStops,
  }) {
    final selectedStops = chainZone ? resolvedStops : [point];
    Navigator.of(context).pushReplacement(
      InAppNavigationScreen.route(
        point: point,
        settings: settings,
        groupName: chainZone ? groupName : null,
        stops: selectedStops,
        planController: planController,
      ),
    );
  }
}

class _PrimaryZoneButton extends StatelessWidget {
  const _PrimaryZoneButton({required this.onTap, this.singlePoint = false});

  final VoidCallback onTap;
  final bool singlePoint;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: ValueKey(
        singlePoint
            ? 'navigation-route-confirm-point'
            : 'navigation-route-confirm-zone',
      ),
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      icon: Icon(
        singlePoint ? Icons.near_me_outlined : Icons.route_rounded,
        size: 20,
      ),
      label: Text(singlePoint ? '开始导航' : '串联整个片区导航'),
    );
  }
}

class _SecondaryPointButton extends StatelessWidget {
  const _SecondaryPointButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('navigation-route-confirm-point'),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      icon: const Icon(Icons.location_on_outlined, size: 20),
      label: const Text('仅导航到选中点'),
    );
  }
}

class _GroupNameRow extends StatelessWidget {
  const _GroupNameRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.42)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '片区',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePreviewMap extends StatelessWidget {
  const _RoutePreviewMap({
    required this.settings,
    required this.dark,
    required this.routePoints,
    required this.stops,
  });

  final AppSettings settings;
  final bool dark;
  final List<LatLng> routePoints;
  final List<PilgrimagePoint> stops;

  @override
  Widget build(BuildContext context) {
    if (routePoints.isEmpty) {
      return const SizedBox.expand();
    }

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: routePoints,
          padding: const EdgeInsets.fromLTRB(40, 28, 40, 28),
          maxZoom: 17,
        ),
        minZoom: 4,
        maxZoom: settings.mapMaxZoom.toDouble(),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        configuredNavigationMapTileLayer(settings, dark: dark),
        PolylineLayer(
          polylines: [
            Polyline(
              points: routePoints,
              color: AppColors.accent.withValues(alpha: 0.28),
              strokeWidth: 12,
            ),
            Polyline(
              points: routePoints,
              color: AppColors.accent,
              strokeWidth: 6,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < stops.length; i++)
              if (i == stops.length - 1)
                Marker(
                  point: stops[i].position,
                  width: 36,
                  height: 44,
                  alignment: Alignment.bottomCenter,
                  child: const _DestinationPin(),
                )
              else
                Marker(
                  point: stops[i].position,
                  width: 26,
                  height: 26,
                  child: _WaypointDot(index: i + 1),
                ),
          ],
        ),
      ],
    );
  }
}

class _WaypointDot extends StatelessWidget {
  const _WaypointDot({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          '$index',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _DestinationPin extends StatelessWidget {
  const _DestinationPin();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _endRouteRed,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
        child: const Icon(Icons.location_on, color: Colors.white, size: 16),
      ),
    );
  }
}

List<PilgrimagePoint> _coordinateStops({
  required PilgrimagePoint point,
  required List<PilgrimagePoint> stops,
}) {
  final resolved = [
    for (final stop in stops)
      if (stop.hasCoordinate) stop,
  ];
  if (resolved.isEmpty && point.hasCoordinate) {
    return [point];
  }
  return resolved;
}

String _stopChainLabel(List<PilgrimagePoint> stops) {
  return [for (final stop in stops) stop.name].join(' → ');
}

List<LatLng> _previewPolyline(List<LatLng> stops) {
  if (stops.isEmpty) {
    return const [];
  }
  if (stops.length == 1) {
    final destination = stops.first;
    return [
      LatLng(destination.latitude - 0.0034, destination.longitude - 0.0026),
      destination,
    ];
  }
  return stops;
}
