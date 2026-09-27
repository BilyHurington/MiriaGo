import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/navigation/navigation_session.dart';
import '../../../application/navigation/route_planner.dart';
import '../../../application/settings_store.dart';
import '../../../map/map_location_tracker.dart' show MapLocationLifecycle;
import '../../../map/map_marker_scale.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../components/components.dart';
import '../../map/map.dart';
import '../camera/camera_entry.dart';
import 'navigation_services.dart';
import 'navigation_widgets.dart';

/// In-app walking navigation (DESIGN §8.4), immersive. [args] must be a
/// [NavigationArgs] from the route preview.
///
/// Navigation never marks points complete.
class NavigationPage extends StatelessWidget {
  const NavigationPage({required this.args, super.key});

  /// Opaque arguments produced by RoutePreviewPage.
  final Object args;

  @override
  Widget build(BuildContext context) {
    final navigationArgs = args;
    if (navigationArgs is! NavigationArgs) {
      return MiriaPageScaffold(
        title: '应用内导航',
        body: EmptyState(
          icon: Symbols.route_rounded,
          title: '没有正在进行的导航',
          message: '请从点位详情重新开始导航。',
          actionLabel: '返回',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }
    return InAppNavigationView(args: navigationArgs);
  }
}

/// The navigation screen for [args].
class InAppNavigationView extends StatefulWidget {
  const InAppNavigationView({required this.args, super.key});

  final NavigationArgs args;

  @override
  State<InAppNavigationView> createState() => _InAppNavigationViewState();
}

class _InAppNavigationViewState extends State<InAppNavigationView>
    with MapLocationLifecycle<InAppNavigationView> {
  late final NavigationSession _session;
  final PlanMapController _map = PlanMapController();
  late final PageController _steps;
  var _pagingProgrammatically = false;
  var _expanded = false;
  SettingsStore? _settingsStore;

  static const _gestureSources = {
    MapEventSource.dragStart,
    MapEventSource.onDrag,
    MapEventSource.multiFingerGestureStart,
    MapEventSource.onMultiFinger,
    MapEventSource.doubleTap,
    MapEventSource.doubleTapHold,
    MapEventSource.scrollWheel,
    MapEventSource.flingAnimationController,
    MapEventSource.doubleTapZoomAnimationController,
    MapEventSource.keyboard,
    MapEventSource.cursorKeyboardRotation,
  };

  @override
  bool get locationPageEnabled => true;

  @override
  void initState() {
    super.initState();
    final services = NavigationServices.maybeOf(context);
    _settingsStore = context.read<SettingsStore?>();
    _session =
        NavigationSession(
            args: widget.args,
            settings: _settingsStore?.settings ?? const AppSettings(),
            routeClient: services?.routeClient,
            locationStreamFactory: services?.locationStreamFactory,
            headingStreamFactory: services?.headingStreamFactory,
            preciseLocationCheck: services?.preciseLocationCheck,
          )
          ..onFollowMove = _followMove
          ..onShowStepPage = _showStepPage
          ..onArrivalDetected = _arrivalDetected
          ..addListener(_changed);
    _steps = PageController(initialPage: _session.stepIndex);
    // The mixin starts location from didChangeDependencies.
    _settingsStore?.addListener(_settingsChanged);
  }

  @override
  void onLocationActivityChanged(bool active) => _session.setActive(active);

  @override
  void dispose() {
    _settingsStore?.removeListener(_settingsChanged);
    _session
      ..removeListener(_changed)
      ..dispose();
    _steps.dispose();
    _map.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _settingsChanged() {
    final store = _settingsStore;
    if (store != null) _session.updateSettings(store.settings);
  }

  void _followMove(LatLng position) {
    if (!_map.isReady) return;
    final camera = _map.mapController.camera;
    _map.mapController.move(position, camera.zoom);
  }

  void _showStepPage(int index, {required bool animate}) {
    if (!_steps.hasClients) return;
    if ((_steps.page?.round() ?? 0) == index) return;
    _pagingProgrammatically = true;
    if (animate && !Motion.reduced(context)) {
      _steps
          .animateToPage(
            index,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          )
          .whenComplete(() => _pagingProgrammatically = false);
    } else {
      _steps.jumpToPage(index);
      _pagingProgrammatically = false;
    }
  }

  void _arrivalDetected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showArrival());
    });
  }

  void _recenter() {
    final zoom = _session.recenter();
    if (_map.isReady) {
      _map.mapController.move(_session.currentLocation, zoom);
    }
  }

  void _onMapEvent(MapEvent event) {
    if (_gestureSources.contains(event.source)) _session.stopFollowing();
  }

  Future<void> _showArrival() async {
    final arrival = _session.beginArrival();
    if (arrival == null) return;
    var advanced = false;
    await showAdaptiveSheet<void>(
      context,
      title: '到达点位',
      builder: (sheetContext) => ArrivalSheetContent(
        arrival: arrival,
        onOpenCamera: () =>
            unawaited(openCamera(context, pointId: arrival.arrived.id)),
        onGoNext: arrival.nextStop == null
            ? null
            : () {
                advanced = true;
                Navigator.of(sheetContext).pop();
                setState(() => _expanded = false);
                _session.advanceToNextStop();
              },
        onFinish: arrival.isLast
            ? () {
                Navigator.of(sheetContext).pop();
                unawaited(Navigator.of(context).maybePop());
              }
            : null,
      ),
    );
    _session.endArrival(arrival, advanced: advanced);
  }

  Future<void> _showAllStops() {
    return showAdaptiveSheet<void>(
      context,
      title: '全部点位',
      builder: (_) => AllStopsSheetContent(
        stops: _session.stops,
        startIndex: _session.startIndex,
        groupName: _session.groupName,
      ),
    );
  }

  void _endRoute() => unawaited(Navigator.of(context).maybePop());

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final sideBySide = layout.width > layout.height && layout.usesSidePanel;
    final disableTiles =
        NavigationServices.maybeOf(context)?.disableMapTiles ?? false;
    final map = _NavigationMap(
      session: _session,
      controller: _map,
      disableTiles: disableTiles,
      onMapEvent: _onMapEvent,
      // Old padding keeps the route clear of the card and the panel; the
      // side-by-side layout has neither over the map.
      fitPadding: sideBySide
          ? const EdgeInsets.all(48)
          : EdgeInsets.fromLTRB(
              48,
              math.min(260, layout.height * 0.3),
              48,
              math.min(200, layout.height * 0.25),
            ),
    );
    final recenter = _RecenterButton(onPressed: _recenter);
    final card = ManeuverCard(
      steps: _session.steps,
      controller: _steps,
      index: _session.stepIndex,
      liveIndex: _session.upcomingStepIndex,
      liveDistanceMeters: _session.upcomingStepDistanceMeters,
      groupName: _session.groupName,
      onPageChanged: (index) => _session.stepPageChanged(
        index,
        programmatic: _pagingProgrammatically,
      ),
    );
    final banners = _banners(context);
    final trip = TripPanel(
      target: _session.currentTarget,
      isLast: _session.currentIsLast,
      stopCount: _session.stops.length,
      metrics: _session.tripMetrics,
      expanded: _expanded,
      collapsible: !sideBySide,
      onToggleExpanded: () => setState(() => _expanded = !_expanded),
      onShowAllStops: () => unawaited(_showAllStops()),
      onArrive: () => unawaited(_showArrival()),
      onEndRoute: _endRoute,
    );
    final c = context.colors;

    if (sideBySide) {
      return Scaffold(
        key: const ValueKey('in-app-navigation-screen'),
        backgroundColor: c.canvas,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(right: BorderSide(color: c.hairline)),
              ),
              child: SizedBox(
                width: layout.isShort ? 340 : 380,
                child: SafeArea(
                  right: false,
                  child: ListView(
                    padding: const EdgeInsets.all(Space.x4),
                    children: [
                      card,
                      for (final banner in banners) ...[
                        const SizedBox(height: Space.x3),
                        banner,
                      ],
                      const SizedBox(height: Space.x4),
                      trip,
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: map),
                  Positioned(
                    right: Space.x4,
                    bottom: Space.x4,
                    child: SafeArea(child: recenter),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: const ValueKey('in-app-navigation-screen'),
      backgroundColor: c.canvas,
      body: Stack(
        children: [
          Positioned.fill(child: map),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Glass(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(Radii.lg),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.gutter + Space.x1,
                    Space.x2,
                    layout.gutter + Space.x1,
                    Space.x3,
                  ),
                  child: card,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final banner in banners)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      layout.gutter,
                      0,
                      layout.gutter,
                      Space.x2,
                    ),
                    child: banner,
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(0, 0, layout.gutter, Space.x3),
                    child: recenter,
                  ),
                ),
                _Glass(
                  key: const ValueKey('in-app-navigation-bottom-panel'),
                  borderRadius: Radii.sheetTop,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: layout.height * 0.62,
                    ),
                    child: SingleChildScrollView(
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            layout.gutter + Space.x1,
                            Space.x4,
                            layout.gutter,
                            Space.x4,
                          ),
                          child: AnimatedSize(
                            duration: Motion.of(context, Motion.emphasis),
                            curve: Motion.emphasized,
                            alignment: Alignment.topCenter,
                            child: trip,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _banners(BuildContext context) {
    return [
      if (_session.preciseLocation == false)
        InfoBanner(
          key: const ValueKey('navigation-precise-location-warning'),
          kind: InfoBannerKind.warning,
          message: '精确位置已关闭，到达提醒和偏航判断可能不准确。',
          actionLabel: '去设置',
          // Re-checked when the app returns to the foreground.
          onAction: () => unawaited(Geolocator.openAppSettings()),
        ),
      if (_session.locationError != null)
        InfoBanner(
          key: const ValueKey('navigation-location-error'),
          kind: InfoBannerKind.error,
          message: _session.locationError!,
          actionLabel: '重试定位',
          onAction: () => syncLocationActivity(force: true),
        ),
    ];
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, required this.borderRadius, super.key});

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: borderRadius,
      child: child,
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: Elevations.level2(c),
      ),
      child: MiriaIconButton(
        key: const ValueKey('in-app-navigation-recenter'),
        icon: Symbols.near_me_rounded,
        tooltip: '回到当前位置',
        variant: MiriaIconButtonVariant.overlay,
        onPressed: onPressed,
      ),
    );
  }
}

class _NavigationMap extends StatelessWidget {
  const _NavigationMap({
    required this.session,
    required this.controller,
    required this.disableTiles,
    required this.onMapEvent,
    required this.fitPadding,
  });

  final NavigationSession session;
  final EdgeInsets fitPadding;
  final PlanMapController controller;
  final bool disableTiles;
  final void Function(MapEvent event) onMapEvent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scale = normalizedMapMarkerScale(session.settings.mapMarkerScale);
    final stops = session.stops;
    final start = session.startIndex;
    final route = session.route;
    return PlanMap(
      controller: controller,
      initialCenter: session.currentLocation,
      initialFitPoints: route.length >= 2 ? route : null,
      initialFitPadding: fitPadding,
      initialFitMaxZoom: 18,
      allowRotation: true,
      disableTiles: disableTiles,
      onMapEvent: onMapEvent,
      layers: [RouteLayer(route: route, stops: const [])],
      children: [
        MarkerLayer(
          markers: [
            for (var i = 0; i < stops.length; i++)
              if (i < start)
                scaledMapMarker(
                  key: ValueKey('navigation-stop-skipped-$i'),
                  point: stops[i].position,
                  baseSize: const Size(24, 24),
                  scale: scale,
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: c.textTertiary,
                        shape: BoxShape.circle,
                        border: Border.all(color: kMapMarkerRing, width: 2),
                      ),
                    ),
                  ),
                )
              else if (i == stops.length - 1)
                scaledMapMarker(
                  key: const ValueKey('navigation-destination'),
                  point: stops[i].position,
                  baseSize: DestinationMarker.size,
                  scale: scale,
                  child: DestinationMarker(tooltip: stops[i].name),
                )
              else
                scaledMapMarker(
                  key: ValueKey('navigation-stop-$i'),
                  point: stops[i].position,
                  baseSize: NumberedStopMarker.size,
                  scale: scale,
                  child: NumberedStopMarker(
                    number: i - start + 1,
                    tooltip: stops[i].name,
                  ),
                ),
          ],
        ),
        ValueListenableBuilder<double?>(
          valueListenable: session.heading,
          builder: (context, heading, _) => MarkerLayer(
            markers: [
              LocationPuck.marker(
                key: const ValueKey('navigation-location-puck'),
                point: session.currentLocation,
                scale: scale,
                child: LocationPuck(
                  stale: session.locationError != null,
                  headingTurns: heading,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
