import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../plan/plan_group_utils.dart';
import '../widgets/app_back_button.dart';
import 'current_location_resolver.dart';
import 'in_app_navigation_screen.dart';
import 'map_navigation_launcher.dart';
import 'map_tile_config.dart';
import 'valhalla_route_client.dart';

const _endRouteRed = Color(0xFFFF3B30);

typedef NavigationLocationResolver = Future<LatLng> Function();

class NavigationRouteConfirmScreen extends StatefulWidget {
  const NavigationRouteConfirmScreen({
    required this.point,
    required this.settings,
    this.groupName,
    this.stops = const [],
    this.planController,
    this.routeClient,
    this.locationResolver,
    this.externalNavigationLauncher = const MapNavigationLauncher(),
    super.key,
  });

  final PilgrimagePoint point;
  final AppSettings settings;
  final String? groupName;
  final List<PilgrimagePoint> stops;
  final PilgrimagePlanController? planController;
  final ValhallaRouteClient? routeClient;
  final NavigationLocationResolver? locationResolver;
  final MapNavigationLauncher externalNavigationLauncher;

  static Route<void> route({
    required PilgrimagePoint point,
    required AppSettings settings,
    String? groupName,
    List<PilgrimagePoint> stops = const [],
    PilgrimagePlanController? planController,
    ValhallaRouteClient? routeClient,
    NavigationLocationResolver? locationResolver,
    MapNavigationLauncher externalNavigationLauncher =
        const MapNavigationLauncher(),
  }) {
    return MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => NavigationRouteConfirmScreen(
        point: point,
        settings: settings,
        groupName: groupName,
        stops: stops,
        planController: planController,
        routeClient: routeClient,
        locationResolver: locationResolver,
        externalNavigationLauncher: externalNavigationLauncher,
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
    ValhallaRouteClient? routeClient,
    NavigationLocationResolver? locationResolver,
    MapNavigationLauncher externalNavigationLauncher =
        const MapNavigationLauncher(),
  }) {
    return Navigator.of(context).push<void>(
      route(
        point: point,
        settings: settings,
        groupName: groupName,
        stops: stops,
        planController: planController,
        routeClient: routeClient,
        locationResolver: locationResolver,
        externalNavigationLauncher: externalNavigationLauncher,
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
  State<NavigationRouteConfirmScreen> createState() =>
      _NavigationRouteConfirmScreenState();
}

class _NavigationRouteConfirmScreenState
    extends State<NavigationRouteConfirmScreen> {
  late final ValhallaRouteClient _routeClient =
      widget.routeClient ?? ValhallaRouteClient();
  NavigationRoute? _route;
  LatLng? _start;
  Object? _error;
  var _loading = true;
  var _requestToken = 0;

  late final List<PilgrimagePoint> _resolvedStops = _coordinateStops(
    point: widget.point,
    stops: widget.stops,
  );
  late final List<PilgrimagePoint> _remainingStops = remainingNavigationStops(
    point: widget.point,
    stops: _resolvedStops,
  );

  @override
  void initState() {
    super.initState();
    _loadRoute(_remainingStops);
  }

  Future<void> _loadRoute(List<PilgrimagePoint> stops) async {
    final requestToken = ++_requestToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final start = _start ?? await _resolveLocation();
      final route = await _routeClient.route(
        baseUrl: widget.settings.valhallaBaseUrl,
        locations: [start, for (final stop in stops) stop.position],
      );
      if (!mounted || requestToken != _requestToken) return;
      setState(() {
        _start = start;
        _route = route;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || requestToken != _requestToken) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<LatLng> _resolveLocation() async {
    final custom = widget.locationResolver;
    if (custom != null) return custom();
    final position = await resolveCurrentLocation();
    return LatLng(position.latitude, position.longitude);
  }

  String get _errorMessage {
    final error = _error;
    if (error is CurrentLocationException) {
      return currentLocationFailureMessage(error);
    }
    if (error is ValhallaRouteException) return error.message;
    return '路线加载失败，请检查定位和路径服务设置';
  }

  @override
  Widget build(BuildContext context) {
    final remainingStops = _remainingStops;
    final canChainZone = remainingStops.length >= 2;
    final routePoints =
        _route?.shape ??
        [
          _start,
          for (final stop in remainingStops) stop.position,
        ].whereType<LatLng>().toList(growable: false);
    final brightness = resolvedAppBrightness(
      widget.settings,
      platformBrightness: MediaQuery.platformBrightnessOf(context),
    );
    applyAppColorsFromSettings(
      widget.settings,
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
              settings: widget.settings,
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
                    if (widget.groupName != null &&
                        widget.groupName!.trim().isNotEmpty) ...[
                      _GroupNameRow(name: widget.groupName!.trim()),
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
                          : '终点：${widget.point.name}',
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
                    const SizedBox(height: 12),
                    if (_loading) ...[
                      const LinearProgressIndicator(minHeight: 3),
                      const SizedBox(height: 8),
                      Text(
                        '正在获取当前位置并规划步行路线…',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ] else if (_error != null) ...[
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _loadRoute(remainingStops),
                              icon: const Icon(Icons.refresh),
                              label: const Text('重试'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openExternalNavigation,
                              icon: const Icon(Icons.open_in_new),
                              label: Text(widget.settings.navigationApp.label),
                            ),
                          ),
                        ],
                      ),
                    ] else if (canChainZone) ...[
                      _PrimaryZoneButton(
                        onTap: () => _startNavigation(
                          context,
                          chainZone: true,
                          resolvedStops: _resolvedStops,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SecondaryPointButton(
                        onTap: () => _startNavigation(
                          context,
                          chainZone: false,
                          resolvedStops: _resolvedStops,
                        ),
                      ),
                    ] else
                      _PrimaryZoneButton(
                        singlePoint: true,
                        onTap: () => _startNavigation(
                          context,
                          chainZone: false,
                          resolvedStops: _resolvedStops,
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
    final selectedStops = chainZone ? resolvedStops : [widget.point];
    final activeStops = remainingNavigationStops(
      point: widget.point,
      stops: selectedStops,
    );
    if (_route == null || (!chainZone && _remainingStops.length > 1)) {
      _loadAndStart(activeStops, chainZone: chainZone);
      return;
    }
    _openNavigation(activeStops, chainZone: chainZone, route: _route!);
  }

  Future<void> _loadAndStart(
    List<PilgrimagePoint> stops, {
    required bool chainZone,
  }) async {
    await _loadRoute(stops);
    if (!mounted || _route == null || _error != null) return;
    _openNavigation(stops, chainZone: chainZone, route: _route!);
  }

  void _openNavigation(
    List<PilgrimagePoint> stops, {
    required bool chainZone,
    required NavigationRoute route,
  }) {
    Navigator.of(context).pushReplacement(
      InAppNavigationScreen.route(
        point: widget.point,
        settings: widget.settings,
        groupName: chainZone ? widget.groupName : null,
        stops: stops,
        planController: widget.planController,
        initialRoute: route,
        initialLocation: _start!,
        routeClient: _routeClient,
      ),
    );
  }

  Future<void> _openExternalNavigation() async {
    final opened = await widget.externalNavigationLauncher.openWalking(
      widget.point,
      widget.settings.navigationApp,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开外部地图')));
    }
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
