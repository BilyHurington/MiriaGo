import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../camera_reference/camerawesome_reference_screen.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../plan/plan_group_utils.dart';
import 'map_tile_config.dart';

const _endRouteRed = Color(0xFFFF3B30);

class _NavigationChrome {
  const _NavigationChrome({
    required this.brightness,
    required this.scaffold,
    required this.panel,
    required this.row,
    required this.primaryText,
    required this.secondaryText,
    required this.inactiveDot,
    required this.iconButton,
    required this.recenterFill,
    required this.detailsIconBackground,
    required this.systemOverlay,
  });

  const _NavigationChrome.light()
    : brightness = Brightness.light,
      scaffold = const Color(0xFFF2F2F7),
      panel = const Color(0xF7FFFFFF),
      row = const Color(0xFFF2F2F7),
      primaryText = const Color(0xFF1C1C1E),
      secondaryText = const Color(0xFF8E8E93),
      inactiveDot = const Color(0xFFC7C7CC),
      iconButton = const Color(0xFFE5E5EA),
      recenterFill = Colors.white,
      detailsIconBackground = const Color(0xFFE5E5EA),
      systemOverlay = SystemUiOverlayStyle.dark;

  const _NavigationChrome.dark()
    : brightness = Brightness.dark,
      scaffold = const Color(0xFF1C1C1E),
      panel = const Color(0xF21C1C1E),
      row = const Color(0xFF2C2C2E),
      primaryText = Colors.white,
      secondaryText = const Color(0xFFAEAEB2),
      inactiveDot = const Color(0xFF636366),
      iconButton = const Color(0xFF3A3A3C),
      recenterFill = const Color(0xFF2C2C2E),
      detailsIconBackground = const Color(0xFF3A3A3C),
      systemOverlay = SystemUiOverlayStyle.light;

  factory _NavigationChrome.of(Brightness brightness) {
    return brightness == Brightness.dark
        ? const _NavigationChrome.dark()
        : const _NavigationChrome.light();
  }

  final Brightness brightness;
  final Color scaffold;
  final Color panel;
  final Color row;
  final Color primaryText;
  final Color secondaryText;
  final Color inactiveDot;
  final Color iconButton;
  final Color recenterFill;
  final Color detailsIconBackground;
  final SystemUiOverlayStyle systemOverlay;

  bool get isDark => brightness == Brightness.dark;
}

class InAppNavigationScreen extends StatefulWidget {
  const InAppNavigationScreen({
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
      builder: (_) => InAppNavigationScreen(
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

  @override
  State<InAppNavigationScreen> createState() => _InAppNavigationScreenState();
}

class _InAppNavigationScreenState extends State<InAppNavigationScreen> {
  final MapController _mapController = MapController();
  final PageController _stepController = PageController();
  var _stepIndex = 0;
  var _sheetExpanded = false;
  var _debugStopIndex = 0;

  late final List<PilgrimagePoint> _stops = _resolvedStops(
    point: widget.point,
    stops: widget.stops,
  );
  late final int _startIndex = navigationStartIndex(
    point: widget.point,
    stops: _stops,
  );
  late final List<PilgrimagePoint> _activeStops = remainingNavigationStops(
    point: widget.point,
    stops: _stops,
  );
  late final List<_PreviewStep> _steps = _previewStepsFor(widget.point);
  late final List<LatLng> _route = () {
    final route = _previewRouteForStops([
      for (final stop in _activeStops) stop.position,
    ]);
    if (route.isEmpty) {
      return _previewRouteFor(widget.point.position);
    }
    return route;
  }();
  late LatLng _currentLocation = _route.first;

  PilgrimagePoint get _currentTarget {
    if (_activeStops.isEmpty) {
      return widget.point;
    }
    final index = _debugStopIndex.clamp(0, _activeStops.length - 1);
    return _activeStops[index];
  }

  bool get _currentIsLast {
    if (_activeStops.isEmpty) {
      return true;
    }
    return _debugStopIndex >= _activeStops.length - 1;
  }

  PilgrimagePoint? get _nextDebugStop {
    if (_currentIsLast || _debugStopIndex + 1 >= _activeStops.length) {
      return null;
    }
    return _activeStops[_debugStopIndex + 1];
  }

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  void _openReferenceCamera(PilgrimagePoint point) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CamerawesomeReferenceScreen(
          point: point,
          settings: widget.settings,
          controller: widget.planController,
        ),
      ),
    );
  }

  Future<void> _showArriveDebug(
    BuildContext context,
    _NavigationChrome chrome,
  ) {
    final arrived = _currentTarget;
    final next = _nextDebugStop;
    final remainingCount = _activeStops.isEmpty ? 1 : _activeStops.length;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: chrome.panel,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _ArriveDebugSheet(
          chrome: chrome,
          arrived: arrived,
          isLast: _currentIsLast,
          stopNumber: _debugStopIndex + 1,
          remainingCount: remainingCount,
          nextStop: next,
          onOpenCamera: () => _openReferenceCamera(arrived),
          onGoNext: next == null
              ? null
              : () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _debugStopIndex++;
                    _currentLocation = _currentTarget.position;
                    _sheetExpanded = false;
                  });
                  _mapController.move(_currentLocation, 17);
                },
        );
      },
    );
  }

  Future<void> _showAllStops(BuildContext context, _NavigationChrome chrome) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: chrome.panel,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return _AllStopsSheet(
          chrome: chrome,
          groupName: widget.groupName,
          stops: _stops,
          startIndex: _startIndex,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    applyAppColorsFromSettings(
      widget.settings,
      platformBrightness: platformBrightness,
    );
    final chrome = _NavigationChrome.of(
      resolvedAppBrightness(
        widget.settings,
        platformBrightness: platformBrightness,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: chrome.systemOverlay,
      child: Scaffold(
        key: const ValueKey('in-app-navigation-screen'),
        backgroundColor: chrome.scaffold,
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: _route,
                  padding: const EdgeInsets.fromLTRB(48, 260, 48, 200),
                  maxZoom: 18,
                ),
                minZoom: 4,
                maxZoom: widget.settings.mapMaxZoom.toDouble(),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                configuredNavigationMapTileLayer(
                  widget.settings,
                  dark: chrome.isDark,
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route,
                      color: AppColors.accent.withValues(alpha: 0.28),
                      strokeWidth: 12,
                    ),
                    Polyline(
                      points: _route,
                      color: AppColors.accent,
                      strokeWidth: 6,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      width: 44,
                      height: 44,
                      child: const _LocationPuck(),
                    ),
                    for (var i = 0; i < _stops.length; i++)
                      if (i < _startIndex)
                        Marker(
                          point: _stops[i].position,
                          width: 24,
                          height: 24,
                          child: const _SkippedWaypointDot(),
                        )
                      else if (i == _stops.length - 1)
                        Marker(
                          point: _stops[i].position,
                          width: 40,
                          height: 48,
                          alignment: Alignment.bottomCenter,
                          child: const _DestinationPin(),
                        )
                      else
                        Marker(
                          point: _stops[i].position,
                          width: 28,
                          height: 28,
                          child: _WaypointDot(index: i - _startIndex + 1),
                        ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _InstructionBanner(
                chrome: chrome,
                groupName: widget.groupName,
                steps: _steps,
                controller: _stepController,
                index: _stepIndex,
                onIndexChanged: (index) {
                  setState(() => _stepIndex = index);
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _RecenterButton(
                      chrome: chrome,
                      onTap: () => _mapController.move(_currentLocation, 17),
                    ),
                  ),
                  _BottomPanel(
                    chrome: chrome,
                    point: _currentTarget,
                    currentIsLast: _currentIsLast,
                    stops: _stops,
                    metrics: _tripMetricsFor(_route),
                    expanded: _sheetExpanded,
                    bottomInset: bottomInset,
                    onToggleExpanded: () {
                      setState(() => _sheetExpanded = !_sheetExpanded);
                    },
                    onShowAllStops: () => _showAllStops(context, chrome),
                    onArriveDebug: () => _showArriveDebug(context, chrome),
                    onEndRoute: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripMetrics {
  const _TripMetrics({
    required this.arrivalText,
    required this.durationText,
    required this.distanceText,
  });

  final String arrivalText;
  final String durationText;
  final String distanceText;
}

_TripMetrics _tripMetricsFor(List<LatLng> route, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  var meters = 0.0;
  final calculator = Distance();
  for (var i = 1; i < route.length; i++) {
    meters += calculator(route[i - 1], route[i]);
  }
  final minutes = math.max(1, (meters * 0.015).round());
  final arrival = clock.add(Duration(minutes: minutes));
  final km = meters / 1000;
  return _TripMetrics(
    arrivalText:
        '${arrival.hour.toString().padLeft(2, '0')}:'
        '${arrival.minute.toString().padLeft(2, '0')}',
    durationText:
        '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}',
    distanceText: km >= 10
        ? km.round().toString()
        : (km < 0.1 ? 0.1 : km).toStringAsFixed(1),
  );
}

class _PreviewStep {
  const _PreviewStep({
    required this.icon,
    required this.distanceLabel,
    required this.instruction,
  });

  final IconData icon;
  final String distanceLabel;
  final String instruction;
}

List<_PreviewStep> _previewStepsFor(PilgrimagePoint point) {
  final road = _roadHint(point);
  return [
    _PreviewStep(
      icon: Icons.turn_right_rounded,
      distanceLabel: '475米',
      instruction: '右转进入$road',
    ),
    _PreviewStep(
      icon: Icons.straight_rounded,
      distanceLabel: '210米',
      instruction: '沿$road直行',
    ),
    _PreviewStep(
      icon: Icons.turn_left_rounded,
      distanceLabel: '80米',
      instruction: '左转进入附近道路',
    ),
    _PreviewStep(
      icon: Icons.turn_slight_right_rounded,
      distanceLabel: '150米',
      instruction: '靠右前往${point.name}',
    ),
    _PreviewStep(
      icon: Icons.flag_rounded,
      distanceLabel: '40米',
      instruction: '到达终点',
    ),
  ];
}

String _roadHint(PilgrimagePoint point) {
  final subtitle = point.subtitle.trim();
  if (subtitle.isNotEmpty) {
    return subtitle;
  }
  final city = point.work.city.trim();
  if (city.isNotEmpty) {
    return '$city附近道路';
  }
  return '前方道路';
}

List<PilgrimagePoint> _resolvedStops({
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

String _stopHeadline(PilgrimagePoint stop, {required bool isLast}) {
  return isLast ? '终点: ${stop.name}' : stop.name;
}

List<LatLng> _previewRouteFor(LatLng destination) {
  return [
    LatLng(destination.latitude - 0.0034, destination.longitude - 0.0026),
    LatLng(destination.latitude - 0.0021, destination.longitude - 0.0024),
    LatLng(destination.latitude - 0.0011, destination.longitude - 0.0008),
    LatLng(destination.latitude - 0.0004, destination.longitude - 0.0002),
    destination,
  ];
}

List<LatLng> _previewRouteForStops(List<LatLng> stops) {
  if (stops.isEmpty) {
    return const [];
  }
  if (stops.length == 1) {
    return _previewRouteFor(stops.first);
  }
  final first = stops.first;
  return [
    LatLng(first.latitude - 0.0028, first.longitude - 0.0022),
    LatLng(first.latitude - 0.0012, first.longitude - 0.0009),
    ...stops,
  ];
}

class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({
    required this.chrome,
    required this.steps,
    this.groupName,
    this.controller,
    this.index = 0,
    this.onIndexChanged,
  });

  final _NavigationChrome chrome;
  final String? groupName;
  final List<_PreviewStep> steps;
  final PageController? controller;
  final int index;
  final ValueChanged<int>? onIndexChanged;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    final zoneName = groupName?.trim() ?? '';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: chrome.panel,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (zoneName.isNotEmpty)
                  Padding(
                    key: const ValueKey('in-app-navigation-top-zone'),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Center(
                      child: _GroupNameRow(
                        chrome: chrome,
                        name: zoneName,
                        centered: true,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 72,
                        child: PageView.builder(
                          key: const ValueKey('in-app-navigation-steps'),
                          controller: controller,
                          onPageChanged: onIndexChanged,
                          itemCount: steps.length,
                          itemBuilder: (context, pageIndex) {
                            final step = steps[pageIndex];
                            return Row(
                              children: [
                                Icon(
                                  step.icon,
                                  size: 52,
                                  color: chrome.primaryText,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        step.distanceLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: chrome.primaryText,
                                          fontSize: 34,
                                          height: 1.05,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        step.instruction,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: chrome.primaryText,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == index
                                    ? chrome.primaryText
                                    : chrome.inactiveDot,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.chrome,
    required this.point,
    required this.currentIsLast,
    required this.stops,
    required this.metrics,
    required this.expanded,
    required this.bottomInset,
    required this.onToggleExpanded,
    required this.onShowAllStops,
    required this.onArriveDebug,
    required this.onEndRoute,
  });

  final _NavigationChrome chrome;
  final PilgrimagePoint point;
  final bool currentIsLast;
  final List<PilgrimagePoint> stops;
  final _TripMetrics metrics;
  final bool expanded;
  final double bottomInset;
  final VoidCallback onToggleExpanded;
  final VoidCallback onShowAllStops;
  final VoidCallback onArriveDebug;
  final VoidCallback onEndRoute;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const ValueKey('in-app-navigation-bottom-panel'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: chrome.panel,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 16, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetHeader(
                    chrome: chrome,
                    headline: _stopHeadline(point, isLast: currentIsLast),
                    metrics: metrics,
                    expanded: expanded,
                    onToggleExpanded: onToggleExpanded,
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 16),
                    _InfoRow(
                      chrome: chrome,
                      icon: Icons.location_on,
                      iconColor: Colors.white,
                      iconBackground: _endRouteRed,
                      title: point.name,
                      subtitle: _destinationSubtitle(point),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      key: const ValueKey('in-app-navigation-all-stops'),
                      chrome: chrome,
                      icon: Icons.list,
                      iconColor: chrome.primaryText,
                      iconBackground: chrome.detailsIconBackground,
                      title: '全部点位',
                      subtitle: stops.isEmpty ? null : '共 ${stops.length} 个',
                      onTap: onShowAllStops,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        key: const ValueKey('in-app-navigation-arrive-debug'),
                        onPressed: onArriveDebug,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: chrome.primaryText,
                          side: BorderSide(color: chrome.iconButton),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        child: const Text('已到达'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        key: const ValueKey('in-app-navigation-end-route'),
                        onPressed: onEndRoute,
                        style: FilledButton.styleFrom(
                          backgroundColor: _endRouteRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        child: const Text('结束路线'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.chrome,
    required this.headline,
    required this.metrics,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final _NavigationChrome chrome;
  final String headline;
  final _TripMetrics metrics;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: chrome.primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: expanded ? '收起' : '展开',
              child: Material(
                color: chrome.iconButton,
                shape: const CircleBorder(),
                child: InkWell(
                  key: ValueKey(
                    expanded
                        ? 'in-app-navigation-collapse'
                        : 'in-app-navigation-expand',
                  ),
                  customBorder: const CircleBorder(),
                  onTap: onToggleExpanded,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: chrome.primaryText,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _TripSummaryRow(chrome: chrome, metrics: metrics),
      ],
    );
  }
}

class _TripSummaryRow extends StatelessWidget {
  const _TripSummaryRow({required this.chrome, required this.metrics});

  final _NavigationChrome chrome;
  final _TripMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('in-app-navigation-trip-summary'),
      children: [
        _TripMetricColumn(
          chrome: chrome,
          value: metrics.arrivalText,
          label: '到达',
        ),
        _TripMetricColumn(
          chrome: chrome,
          value: metrics.durationText,
          label: '小时',
        ),
        _TripMetricColumn(
          chrome: chrome,
          value: metrics.distanceText,
          label: '公里',
        ),
      ],
    );
  }
}

class _TripMetricColumn extends StatelessWidget {
  const _TripMetricColumn({
    required this.chrome,
    required this.value,
    required this.label,
  });

  final _NavigationChrome chrome;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: chrome.primaryText,
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: chrome.secondaryText,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupNameRow extends StatelessWidget {
  const _GroupNameRow({
    required this.chrome,
    required this.name,
    this.centered = false,
  });

  final _NavigationChrome chrome;
  final String name;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
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
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: chrome.primaryText,
              fontSize: 14,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.chrome,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final _NavigationChrome chrome;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: chrome.row,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: chrome.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: chrome.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: chrome.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.chrome, required this.onTap});

  final _NavigationChrome chrome;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '回到当前位置',
      child: Material(
        color: chrome.recenterFill,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        child: InkWell(
          key: const ValueKey('in-app-navigation-recenter'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.navigation, color: AppColors.accent, size: 22),
          ),
        ),
      ),
    );
  }
}

class _LocationPuck extends StatelessWidget {
  const _LocationPuck();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.18),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkippedWaypointDot extends StatelessWidget {
  const _SkippedWaypointDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFFC7C7CC),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _endRouteRed,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: _endRouteRed.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.location_on, color: Colors.white, size: 18),
      ),
    );
  }
}

String _destinationSubtitle(PilgrimagePoint point) {
  final episode = point.displayEpisodeLabel.trim();
  if (episode.isEmpty) {
    return point.work.title;
  }
  return '${point.work.title} · $episode';
}

class _ArriveDebugSheet extends StatelessWidget {
  const _ArriveDebugSheet({
    required this.chrome,
    required this.arrived,
    required this.isLast,
    required this.stopNumber,
    required this.remainingCount,
    required this.onOpenCamera,
    this.nextStop,
    this.onGoNext,
  });

  final _NavigationChrome chrome;
  final PilgrimagePoint arrived;
  final bool isLast;
  final int stopNumber;
  final int remainingCount;
  final VoidCallback onOpenCamera;
  final PilgrimagePoint? nextStop;
  final VoidCallback? onGoNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          key: const ValueKey('in-app-navigation-arrive-debug-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '到达点位',
              style: TextStyle(
                color: chrome.primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              chrome: chrome,
              icon: Icons.flag_rounded,
              iconColor: Colors.white,
              iconBackground: isLast ? _endRouteRed : AppColors.accent,
              title: arrived.name,
              subtitle: _destinationSubtitle(arrived),
            ),
            const SizedBox(height: 10),
            _InfoRow(
              key: const ValueKey('in-app-navigation-open-camera'),
              chrome: chrome,
              icon: Icons.photo_camera_outlined,
              iconColor: chrome.primaryText,
              iconBackground: chrome.detailsIconBackground,
              title: '打开相机',
              subtitle: '第 $stopNumber / $remainingCount 个剩余点位',
              onTap: onOpenCamera,
            ),
            if (nextStop != null) ...[
              const SizedBox(height: 10),
              _InfoRow(
                chrome: chrome,
                icon: Icons.arrow_forward_rounded,
                iconColor: chrome.primaryText,
                iconBackground: chrome.detailsIconBackground,
                title: nextStop!.name,
                subtitle: '下一点位 · ${_destinationSubtitle(nextStop!)}',
              ),
            ],
            if (onGoNext != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey('in-app-navigation-arrive-debug-next'),
                  onPressed: onGoNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  child: const Text('前往下一点'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AllStopsSheet extends StatelessWidget {
  const _AllStopsSheet({
    required this.chrome,
    required this.stops,
    required this.startIndex,
    this.groupName,
  });

  final _NavigationChrome chrome;
  final String? groupName;
  final List<PilgrimagePoint> stops;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final zoneName = groupName?.trim() ?? '';
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: SingleChildScrollView(
            child: Column(
              key: const ValueKey('in-app-navigation-all-stops-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '全部点位',
                  style: TextStyle(
                    color: chrome.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                if (zoneName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _GroupNameRow(chrome: chrome, name: zoneName),
                ],
                const SizedBox(height: 12),
                for (var index = 0; index < stops.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  _AllStopTile(
                    chrome: chrome,
                    index: index,
                    stop: stops[index],
                    isLast: index == stops.length - 1,
                    skipped: index < startIndex,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllStopTile extends StatelessWidget {
  const _AllStopTile({
    required this.chrome,
    required this.index,
    required this.stop,
    required this.isLast,
    required this.skipped,
  });

  final _NavigationChrome chrome;
  final int index;
  final PilgrimagePoint stop;
  final bool isLast;
  final bool skipped;

  @override
  Widget build(BuildContext context) {
    final titleColor = skipped ? chrome.secondaryText : chrome.primaryText;
    final subtitleColor = skipped ? chrome.inactiveDot : chrome.secondaryText;
    return Container(
      key: skipped
          ? ValueKey('in-app-navigation-stop-skipped-${stop.id}')
          : null,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: chrome.row,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: skipped
                  ? chrome.iconButton
                  : isLast
                  ? _endRouteRed
                  : AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: skipped ? chrome.secondaryText : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skipped ? stop.name : _stopHeadline(stop, isLast: isLast),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _destinationSubtitle(stop),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
