import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../camera_reference/camerawesome_reference_screen.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../plan/plan_group_utils.dart';
import 'map_tile_config.dart';
import 'navigation_progress.dart';
import 'valhalla_route_client.dart';
import 'map_location_tracker.dart';
import 'navigation_heading.dart';

const _endRouteRed = Color(0xFFFF3B30);

class NavigationLocationSample {
  const NavigationLocationSample({required this.position, this.accuracy = 0});
  final LatLng position;
  final double accuracy;
}

typedef NavigationLocationStreamFactory =
    Stream<NavigationLocationSample> Function();

/// Returns true when precise location is available, false when the user only
/// granted approximate location, and null when the platform cannot tell.
/// [mayRequest] allows asking iOS for temporary full accuracy.
typedef NavigationPreciseLocationCheck =
    Future<bool?> Function({required bool mayRequest});

const _temporaryFullAccuracyPurposeKey = 'MiriaGoNavigation';

Future<bool?> defaultNavigationPreciseLocationCheck({
  required bool mayRequest,
}) async {
  if (kIsWeb) return null;
  try {
    var status = await Geolocator.getLocationAccuracy();
    if (mayRequest &&
        status == LocationAccuracyStatus.reduced &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      status = await Geolocator.requestTemporaryFullAccuracy(
        purposeKey: _temporaryFullAccuracyPurposeKey,
      );
    }
    return status == LocationAccuracyStatus.precise;
  } on Object {
    return null;
  }
}

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
    required this.initialRoute,
    required this.initialLocation,
    this.groupName,
    this.stops = const [],
    this.planController,
    this.routeClient,
    this.locationStreamFactory,
    this.headingStreamFactory,
    this.preciseLocationCheck,
    super.key,
  });

  final PilgrimagePoint point;
  final AppSettings settings;
  final NavigationRoute initialRoute;
  final LatLng initialLocation;
  final String? groupName;
  final List<PilgrimagePoint> stops;
  final PilgrimagePlanController? planController;
  final ValhallaRouteClient? routeClient;
  final NavigationLocationStreamFactory? locationStreamFactory;
  final NavigationHeadingStreamFactory? headingStreamFactory;
  final NavigationPreciseLocationCheck? preciseLocationCheck;

  static Route<void> route({
    required PilgrimagePoint point,
    required AppSettings settings,
    required NavigationRoute initialRoute,
    required LatLng initialLocation,
    String? groupName,
    List<PilgrimagePoint> stops = const [],
    PilgrimagePlanController? planController,
    ValhallaRouteClient? routeClient,
    NavigationLocationStreamFactory? locationStreamFactory,
    NavigationHeadingStreamFactory? headingStreamFactory,
    NavigationPreciseLocationCheck? preciseLocationCheck,
  }) {
    return MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => InAppNavigationScreen(
        point: point,
        settings: settings,
        initialRoute: initialRoute,
        initialLocation: initialLocation,
        groupName: groupName,
        stops: stops,
        planController: planController,
        routeClient: routeClient,
        locationStreamFactory: locationStreamFactory,
        headingStreamFactory: headingStreamFactory,
        preciseLocationCheck: preciseLocationCheck,
      ),
    );
  }

  static Future<void> open(
    BuildContext context, {
    required PilgrimagePoint point,
    required AppSettings settings,
    required NavigationRoute initialRoute,
    required LatLng initialLocation,
    String? groupName,
    List<PilgrimagePoint> stops = const [],
    PilgrimagePlanController? planController,
    ValhallaRouteClient? routeClient,
    NavigationLocationStreamFactory? locationStreamFactory,
    NavigationHeadingStreamFactory? headingStreamFactory,
    NavigationPreciseLocationCheck? preciseLocationCheck,
  }) {
    return Navigator.of(context).push<void>(
      route(
        point: point,
        settings: settings,
        initialRoute: initialRoute,
        initialLocation: initialLocation,
        groupName: groupName,
        stops: stops,
        planController: planController,
        routeClient: routeClient,
        locationStreamFactory: locationStreamFactory,
        headingStreamFactory: headingStreamFactory,
        preciseLocationCheck: preciseLocationCheck,
      ),
    );
  }

  @override
  State<InAppNavigationScreen> createState() => _InAppNavigationScreenState();
}

class _InAppNavigationScreenState extends State<InAppNavigationScreen>
    with MapLocationLifecycle<InAppNavigationScreen> {
  final MapController _mapController = MapController();

  /// The panel, warnings and recenter button over the map's lower edge;
  /// measured so the map attribution stays visible above them.
  final _bottomOverlayKey = GlobalKey();
  double _bottomOverlayHeight = 200;
  var _bottomOverlayMeasureScheduled = false;

  void _scheduleBottomOverlayMeasure() {
    if (_bottomOverlayMeasureScheduled) return;
    _bottomOverlayMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bottomOverlayMeasureScheduled = false;
      final box =
          _bottomOverlayKey.currentContext?.findRenderObject() as RenderBox?;
      if (!mounted || box == null || !box.hasSize) return;
      final height = box.size.height;
      if ((height - _bottomOverlayHeight).abs() > 1) {
        setState(() => _bottomOverlayHeight = height);
      }
    });
  }

  late final PageController _stepController = PageController(
    initialPage: _stepIndex,
  );
  var _sheetExpanded = false;
  var _targetIndex = 0;
  var _followLocation = true;
  var _offRouteSamples = 0;
  var _arrivalSheetOpen = false;
  String? _arrivalSuppressedStopId;
  bool? _preciseLocation;
  var _temporaryAccuracyRequested = false;
  var _routeTargetOffset = 0;
  DateTime? _lastRerouteAt;
  int _rerouteVersion = 0;
  StreamSubscription<NavigationLocationSample>? _locationSubscription;
  final _heading = NavigationHeading();
  Future<void> _locationCancelled = Future<void>.value();
  Timer? _locationExpiry;
  int _locationSession = 0;
  String? _locationError;

  @override
  bool get locationPageEnabled => true;

  @override
  void onLocationActivityChanged(bool active) {
    _stopLocation();
    if (active) {
      unawaited(_checkPreciseLocation());
      unawaited(_startLocation(_locationSession));
      _heading.start(
        () => (widget.headingStreamFactory ?? nativeNavigationHeading)(
          _currentLocation,
        ),
      );
    }
  }

  void _stopLocation() {
    ++_locationSession;
    _locationExpiry?.cancel();
    final subscription = _locationSubscription;
    _locationSubscription = null;
    if (subscription != null) {
      _locationCancelled = subscription.cancel().catchError((Object _) {});
    }
    _heading.stop();
  }

  Future<void> _startLocation(int session) async {
    await _locationCancelled;
    if (!mounted || session != _locationSession) return;
    try {
      final factory = widget.locationStreamFactory ?? _defaultLocationStream;
      _locationSubscription = factory().listen(
        (sample) {
          if (!mounted || session != _locationSession) return;
          if (_onLocation(sample)) _armLocationExpiry(session);
        },
        onError: (Object error) {
          if (!mounted || session != _locationSession) return;
          setState(() => _locationError = locationUpdateError(error));
        },
        onDone: () {
          if (!mounted || session != _locationSession) return;
          setState(() => _locationError = '定位更新已停止，请重试。');
        },
      );
      _armLocationExpiry(session);
    } catch (error) {
      if (mounted && session == _locationSession) {
        setState(() => _locationError = locationUpdateError(error));
      }
    }
  }

  void _armLocationExpiry(int session) {
    _locationExpiry?.cancel();
    _locationExpiry = Timer(const Duration(seconds: 45), () {
      if (mounted && session == _locationSession) {
        setState(() => _locationError = '暂未收到新的定位，当前位置可能已过期。');
      }
    });
  }

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
  late final ValhallaRouteClient _routeClient =
      widget.routeClient ?? ValhallaRouteClient();
  late NavigationRoute _navigationRoute = widget.initialRoute;
  late List<LatLng> _route = _navigationRoute.shape;
  late List<double> _routeDistances = cumulativeRouteDistances(_route);
  late List<_PreviewStep> _steps = _stepsFor(
    _navigationRoute,
    stops: _routeStops(0),
  );
  late LatLng _currentLocation = widget.initialLocation;
  late RouteProgress _progress = _progressFor(_currentLocation);
  late int _upcomingStepIndex = _upcomingStepFor(_progress);
  DateTime? _userBrowsedStepsAt;
  var _pagingProgrammatically = false;
  late int _stepIndex = _upcomingStepIndex;

  /// Stops served by a route requested when [targetIndex] was the target, in
  /// leg order.
  List<PilgrimagePoint> _routeStops(int targetIndex) {
    if (_activeStops.isEmpty) return [widget.point];
    return _activeStops.skip(targetIndex).toList(growable: false);
  }

  NavigationLeg get _currentLeg {
    final legs = _navigationRoute.legs;
    final index = (_targetIndex - _routeTargetOffset).clamp(0, legs.length - 1);
    return legs[index];
  }

  /// Route distance left to the current target (end of the current leg).
  double get _legRemainingMeters {
    final end = _currentLeg.endShapeIndex.clamp(0, _routeDistances.length - 1);
    return math.max(
      0,
      _routeDistances[end] - _progress.distanceAlongRouteMeters,
    );
  }

  RouteProgress _progressFor(LatLng position, {double? previousAlong}) {
    final leg = _currentLeg;
    return routeProgressFor(
      position,
      _route,
      fromShapeIndex: leg.startShapeIndex,
      toShapeIndex: leg.endShapeIndex,
      previousAlongRouteMeters: previousAlong,
      cumulativeDistances: _routeDistances,
    );
  }

  int _upcomingStepFor(RouteProgress progress) {
    final maneuvers = _navigationRoute.maneuvers;
    if (maneuvers.isEmpty) return 0;
    final leg = _currentLeg;
    return upcomingManeuverIndex(
      segmentIndex: progress.segmentIndex,
      beginShapeIndices: [
        for (final maneuver in maneuvers) maneuver.beginShapeIndex,
      ],
      firstManeuverIndex: leg.firstManeuverIndex,
      endManeuverIndex: leg.endManeuverIndex,
    ).clamp(0, math.max(0, _steps.length - 1)).toInt();
  }

  /// Live route distance to the next maneuver the user has to perform.
  double? get _upcomingStepDistanceMeters {
    final maneuvers = _navigationRoute.maneuvers;
    if (_upcomingStepIndex < 0 || _upcomingStepIndex >= maneuvers.length) {
      return null;
    }
    final begin = maneuvers[_upcomingStepIndex].beginShapeIndex.clamp(
      0,
      _routeDistances.length - 1,
    );
    return math.max(
      0,
      _routeDistances[begin] - _progress.distanceAlongRouteMeters,
    );
  }

  PilgrimagePoint get _currentTarget {
    if (_activeStops.isEmpty) {
      return widget.point;
    }
    final index = _targetIndex.clamp(0, _activeStops.length - 1);
    return _activeStops[index];
  }

  bool get _currentIsLast {
    if (_activeStops.isEmpty) {
      return true;
    }
    return _targetIndex >= _activeStops.length - 1;
  }

  PilgrimagePoint? get _nextStop {
    if (_currentIsLast || _targetIndex + 1 >= _activeStops.length) {
      return null;
    }
    return _activeStops[_targetIndex + 1];
  }

  Stream<NavigationLocationSample> _defaultLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).map(
      (position) => NavigationLocationSample(
        position: LatLng(position.latitude, position.longitude),
        accuracy: position.accuracy,
      ),
    );
  }

  Future<void> _checkPreciseLocation() async {
    final check =
        widget.preciseLocationCheck ?? defaultNavigationPreciseLocationCheck;
    // Ask for temporary full accuracy at most once per navigation session;
    // later checks (returning from Settings or the background, where iOS may
    // have revoked it) only read the current state.
    final mayRequest = !_temporaryAccuracyRequested;
    _temporaryAccuracyRequested = true;
    final precise = await check(mayRequest: mayRequest);
    if (!mounted || precise == _preciseLocation) return;
    setState(() => _preciseLocation = precise);
  }

  @override
  void dispose() {
    _stopLocation();
    _heading.dispose();
    _stepController.dispose();
    super.dispose();
  }

  bool _onLocation(NavigationLocationSample sample) {
    if (!mounted) return false;
    if (!sample.position.latitude.isFinite ||
        !sample.position.longitude.isFinite ||
        sample.position.latitude.abs() > 90 ||
        sample.position.longitude.abs() > 180 ||
        !sample.accuracy.isFinite ||
        sample.accuracy < 0) {
      return false;
    }
    final progress = _progressFor(
      sample.position,
      previousAlong: _progress.distanceAlongRouteMeters,
    );
    final maneuverIndex = _upcomingStepFor(progress);
    final browsedAt = _userBrowsedStepsAt;
    // Let the user look through upcoming steps for a while before the banner
    // snaps back to the next maneuver.
    final keepUserPage =
        browsedAt != null &&
        DateTime.now().difference(browsedAt) < _userStepBrowseHold;
    setState(() {
      _locationError = null;
      _currentLocation = sample.position;
      _progress = progress;
      _upcomingStepIndex = maneuverIndex;
      if (!keepUserPage) {
        _userBrowsedStepsAt = null;
        _stepIndex = maneuverIndex;
      }
    });
    if (!keepUserPage) _showStepPage(maneuverIndex, animate: true);
    if (_followLocation) {
      _mapController.move(sample.position, _mapController.camera.zoom);
    }

    // Coarse fixes (approximate location, poor GPS) still move the puck, but
    // must not trigger arrival or rerouting.
    if (sample.accuracy > maxDecisionAccuracyMeters) {
      return true;
    }

    _offRouteSamples =
        progress.distanceFromRouteMeters > offRouteLimitMeters(sample.accuracy)
        ? _offRouteSamples + 1
        : 0;
    if (_offRouteSamples >= 3) {
      _reroute();
    }

    final target = _currentTarget;
    final arrivalRadius = arrivalRadiusMeters(sample.accuracy);
    final distanceToTarget = const Distance()(sample.position, target.position);
    final legRemaining = _legRemainingMeters;
    // A stop inside a shrine precinct or on a river bank can be far from the
    // nearest walkable way; reaching the end of the leg counts as arrival.
    final atLegEnd =
        legRemaining <= legEndArrivalMeters &&
        progress.distanceFromRouteMeters <= arrivalRadius &&
        distanceToTarget <= maxLegEndArrivalDistanceMeters;
    final arrived = distanceToTarget <= arrivalRadius || atLegEnd;
    // Re-arm a dismissed prompt once the user has clearly left the stop:
    // away from it, and either back along the leg or off the route (a very
    // short leg may never leave enough route behind).
    if (_arrivalSuppressedStopId == target.id &&
        distanceToTarget > arrivalRadius + arrivalRearmMarginMeters &&
        (legRemaining > legEndArrivalMeters + arrivalRearmMarginMeters ||
            progress.distanceFromRouteMeters >
                arrivalRadius + arrivalRearmMarginMeters)) {
      _arrivalSuppressedStopId = null;
    }
    if (!_arrivalSheetOpen &&
        _arrivalSuppressedStopId != target.id &&
        arrived) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showArrival(
            context,
            _NavigationChrome.of(
              resolvedAppBrightness(
                widget.settings,
                platformBrightness: MediaQuery.platformBrightnessOf(context),
              ),
            ),
          );
        }
      });
    }
    return true;
  }

  Future<void> _reroute({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastRerouteAt != null &&
        now.difference(_lastRerouteAt!) < const Duration(seconds: 25)) {
      return;
    }
    _lastRerouteAt = now;
    _offRouteSamples = 0;
    final version = ++_rerouteVersion;
    final targetId = _currentTarget.id;
    final targetIndex = _targetIndex;
    try {
      final route = await _routeClient.route(
        baseUrl: widget.settings.valhallaBaseUrl,
        locations: [
          _currentLocation,
          for (final stop in _activeStops.skip(_targetIndex)) stop.position,
        ],
      );
      if (!mounted ||
          version != _rerouteVersion ||
          targetId != _currentTarget.id) {
        return;
      }
      setState(() {
        _navigationRoute = route;
        _route = route.shape;
        _routeDistances = cumulativeRouteDistances(_route);
        _routeTargetOffset = targetIndex;
        _steps = _stepsFor(route, stops: _routeStops(targetIndex));
        _progress = _progressFor(_currentLocation);
        _upcomingStepIndex = _upcomingStepFor(_progress);
        _stepIndex = _upcomingStepIndex;
      });
      _userBrowsedStepsAt = null;
      _showStepPage(_stepIndex, animate: false);
    } on Object {
      // Keep the previous route visible; another location update may retry later.
    }
  }

  static const _userStepBrowseHold = Duration(seconds: 6);

  void _showStepPage(int index, {required bool animate}) {
    if (!_stepController.hasClients) return;
    if ((_stepController.page?.round() ?? 0) == index) return;
    _pagingProgrammatically = true;
    if (animate) {
      _stepController
          .animateToPage(
            index,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          )
          .whenComplete(() => _pagingProgrammatically = false);
    } else {
      _stepController.jumpToPage(index);
      _pagingProgrammatically = false;
    }
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

  Future<void> _showArrival(
    BuildContext context,
    _NavigationChrome chrome,
  ) async {
    if (_arrivalSheetOpen) {
      return;
    }
    final arrived = _currentTarget;
    final next = _nextStop;
    final remainingCount = _activeStops.isEmpty ? 1 : _activeStops.length;
    _arrivalSheetOpen = true;
    var advanced = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: chrome.brightness == Brightness.dark
          ? const Color(0xFF121417)
          : chrome.panel,
      shape: chrome.brightness == Brightness.dark
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              side: BorderSide(color: Color(0xFF2C2C2E)),
            )
          : null,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _ArrivalSheet(
          chrome: chrome,
          arrived: arrived,
          isLast: _currentIsLast,
          stopNumber: _targetIndex + 1,
          remainingCount: remainingCount,
          nextStop: next,
          onOpenCamera: () => _openReferenceCamera(arrived),
          onFinish: _currentIsLast
              ? () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).maybePop();
                }
              : null,
          onGoNext: next == null
              ? null
              : () {
                  advanced = true;
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _targetIndex++;
                    _sheetExpanded = false;
                  });
                  _reroute(force: true);
                },
        );
      },
    );
    _arrivalSheetOpen = false;
    if (!advanced) {
      // Dismissing the prompt keeps the user at this stop; do not reopen it
      // until they have clearly walked away and come back.
      _arrivalSuppressedStopId = arrived.id;
    }
  }

  Future<void> _showAllStops(BuildContext context, _NavigationChrome chrome) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: chrome.brightness == Brightness.dark
          ? const Color(0xFF121417)
          : chrome.panel,
      shape: chrome.brightness == Brightness.dark
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              side: BorderSide(color: Color(0xFF2C2C2E)),
            )
          : null,
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
    // Also catches the first layout, which SizeChangedLayoutNotifier skips.
    _scheduleBottomOverlayMeasure();
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
                initialCenter: _currentLocation,
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
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture && _followLocation) {
                    setState(() => _followLocation = false);
                  }
                },
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
                      color: configuredMapRouteColor(
                        widget.settings,
                        dark: chrome.isDark,
                      ).withValues(alpha: 0.28),
                      strokeWidth: 12,
                    ),
                    Polyline(
                      points: _route,
                      color: configuredMapRouteColor(
                        widget.settings,
                        dark: chrome.isDark,
                      ),
                      strokeWidth: 6,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      width: 56,
                      height: 56,
                      rotate: false,
                      child: NavigationLocationPuck(
                        heading: _heading,
                        stale: _locationError != null,
                      ),
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
                // Above the bottom panel and warnings, which cover the map's
                // lower edge.
                Padding(
                  padding: EdgeInsets.only(bottom: _bottomOverlayHeight + 4),
                  child: configuredMapAttribution(widget.settings),
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
                liveIndex: _upcomingStepIndex,
                liveDistanceMeters: _upcomingStepDistanceMeters,
                onIndexChanged: (index) {
                  setState(() {
                    _stepIndex = index;
                    if (!_pagingProgrammatically) {
                      _userBrowsedStepsAt = index == _upcomingStepIndex
                          ? null
                          : DateTime.now();
                    }
                  });
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (_) {
                  _scheduleBottomOverlayMeasure();
                  return true;
                },
                child: SizeChangedLayoutNotifier(
                  child: KeyedSubtree(
                    key: _bottomOverlayKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_preciseLocation == false)
                          Material(
                            key: const ValueKey(
                              'navigation-precise-location-warning',
                            ),
                            color: chrome.panel,
                            child: ListTile(
                              dense: true,
                              title: const Text('精确位置已关闭，到达提醒和偏航判断可能不准确。'),
                              trailing: TextButton(
                                // The state is re-checked when the app returns to the
                                // foreground (onLocationActivityChanged).
                                onPressed: Geolocator.openAppSettings,
                                child: const Text('去设置'),
                              ),
                            ),
                          ),
                        if (_locationError != null)
                          Material(
                            color: chrome.panel,
                            child: ListTile(
                              dense: true,
                              title: Text(_locationError!),
                              trailing: IconButton(
                                key: const ValueKey(
                                  'navigation-location-retry',
                                ),
                                tooltip: '重试定位',
                                icon: const Icon(LucideIcons.refreshCw),
                                onPressed: () =>
                                    syncLocationActivity(force: true),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _RecenterButton(
                            chrome: chrome,
                            onTap: () {
                              setState(() => _followLocation = true);
                              _mapController.move(
                                _currentLocation,
                                math.min(
                                  17.0,
                                  widget.settings.mapMaxZoom.toDouble(),
                                ),
                              );
                            },
                          ),
                        ),
                        _BottomPanel(
                          chrome: chrome,
                          point: _currentTarget,
                          currentIsLast: _currentIsLast,
                          stops: _stops,
                          metrics: _tripMetricsForLeg(
                            _currentLeg,
                            remainingDistanceMeters: _legRemainingMeters,
                          ),
                          expanded: _sheetExpanded,
                          bottomInset: bottomInset,
                          onToggleExpanded: () {
                            setState(() => _sheetExpanded = !_sheetExpanded);
                          },
                          onShowAllStops: () => _showAllStops(context, chrome),
                          onArrive: () => _showArrival(context, chrome),
                          onEndRoute: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ),
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

_TripMetrics _tripMetricsForLeg(
  NavigationLeg leg, {
  required double remainingDistanceMeters,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final totalMeters = math.max(1.0, leg.distanceKm * 1000);
  final ratio = (remainingDistanceMeters / totalMeters).clamp(0.0, 1.0);
  final minutes = math.max(1, (leg.duration.inSeconds * ratio / 60).round());
  final arrival = clock.add(Duration(minutes: minutes));
  final km = remainingDistanceMeters / 1000;
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

List<_PreviewStep> _stepsFor(
  NavigationRoute route, {
  List<PilgrimagePoint> stops = const [],
}) {
  if (route.maneuvers.isEmpty) {
    return const [
      _PreviewStep(
        icon: LucideIcons.arrowUp,
        distanceLabel: '路线中',
        instruction: '沿路线继续前行',
      ),
    ];
  }
  final maneuvers = route.maneuvers;
  final legs = route.legs;
  String instructionFor(int index) {
    final maneuver = maneuvers[index];
    if (maneuver.type != 4 && maneuver.type != 5 && maneuver.type != 6) {
      return maneuver.instruction;
    }
    final legIndex = legs.indexWhere(
      (leg) => index >= leg.firstManeuverIndex && index < leg.endManeuverIndex,
    );
    final isLastLeg = legIndex < 0 || legIndex == legs.length - 1;
    final stop = legIndex >= 0 && legIndex < stops.length
        ? stops[legIndex]
        : null;
    final side = switch (maneuver.type) {
      5 => '，在右侧',
      6 => '，在左侧',
      _ => '',
    };
    if (stop == null) return isLastLeg ? '到达终点$side' : '到达途经点$side';
    return isLastLeg ? '到达终点 ${stop.name}$side' : '到达途经点 ${stop.name}$side';
  }

  return [
    for (var i = 0; i < maneuvers.length; i++)
      _PreviewStep(
        icon: navigationManeuverIcon(maneuvers[i].type),
        // A maneuver's own length is the distance walked after it, so the
        // distance leading up to maneuver i is the previous maneuver's length.
        distanceLabel: _distanceLabel(
          i == 0 ? maneuvers[i].distanceKm : maneuvers[i - 1].distanceKm,
        ),
        instruction: instructionFor(i),
      ),
  ];
}

/// Icons follow Valhalla's `DirectionsLeg.Maneuver.Type` numbering, the same
/// numbering [localizedManeuverInstruction] uses for the text.
IconData navigationManeuverIcon(int type) => switch (type) {
  4 || 5 || 6 => LucideIcons.flag,
  2 || 10 || 11 || 20 || 37 => LucideIcons.cornerUpRight,
  3 || 14 || 15 || 21 || 38 => LucideIcons.cornerUpLeft,
  9 || 18 || 23 => LucideIcons.arrowUpRight,
  16 || 19 || 24 => LucideIcons.arrowUpLeft,
  // 12 is a right U-turn, 13 a left one.
  12 => LucideIcons.redo2,
  13 => LucideIcons.undo2,
  26 || 27 => LucideIcons.rotateCw,
  39 || 40 || 41 || 44 => LucideIcons.arrowUpDown,
  _ => LucideIcons.arrowUp,
};

String _distanceLabel(double kilometers) {
  final meters = kilometers * 1000;
  if (meters < 1000) return '${math.max(1, meters.round())}米';
  return '${kilometers.toStringAsFixed(kilometers >= 10 ? 0 : 1)}公里';
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

class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({
    required this.chrome,
    required this.steps,
    this.groupName,
    this.controller,
    this.index = 0,
    this.liveIndex,
    this.liveDistanceMeters,
    this.onIndexChanged,
  });

  final _NavigationChrome chrome;
  final String? groupName;
  final List<_PreviewStep> steps;
  final PageController? controller;
  final int index;
  final int? liveIndex;
  final double? liveDistanceMeters;
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
                            final liveDistance = pageIndex == liveIndex
                                ? liveDistanceMeters
                                : null;
                            final distanceLabel = liveDistance == null
                                ? step.distanceLabel
                                : _distanceLabel(liveDistance / 1000);
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
                                        distanceLabel,
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
                      _StepDots(
                        chrome: chrome,
                        count: steps.length,
                        index: index,
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

/// Page dots for the instruction pager. Long routes show a window of dots
/// around the current page plus an "n / total" counter instead of one dot per
/// maneuver, which would overflow the banner.
class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.chrome,
    required this.count,
    required this.index,
  });

  static const maxDots = 9;

  final _NavigationChrome chrome;
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox(height: 6);
    final current = index.clamp(0, count - 1);
    final visible = math.min(count, maxDots);
    final first = (current - visible ~/ 2).clamp(0, count - visible);
    return Row(
      key: const ValueKey('in-app-navigation-step-dots'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = first; i < first + visible; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current ? chrome.primaryText : chrome.inactiveDot,
            ),
          ),
        if (count > maxDots) ...[
          const SizedBox(width: 8),
          Text(
            '${current + 1} / $count',
            style: TextStyle(
              color: chrome.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
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
    required this.onArrive,
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
  final VoidCallback onArrive;
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
                      icon: LucideIcons.mapPin,
                      iconColor: Colors.white,
                      iconBackground: _endRouteRed,
                      title: point.name,
                      subtitle: _destinationSubtitle(point),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      key: const ValueKey('in-app-navigation-all-stops'),
                      chrome: chrome,
                      icon: LucideIcons.list,
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
                        key: const ValueKey('in-app-navigation-arrive'),
                        onPressed: onArrive,
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
                          ? LucideIcons.chevronDown
                          : LucideIcons.chevronUp,
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
                Icon(LucideIcons.chevronRight, color: chrome.secondaryText),
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
            child: Icon(
              LucideIcons.navigation,
              color: AppColors.accent,
              size: 22,
            ),
          ),
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
        child: const Icon(LucideIcons.mapPin, color: Colors.white, size: 18),
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

class _ArrivalSheet extends StatelessWidget {
  const _ArrivalSheet({
    required this.chrome,
    required this.arrived,
    required this.isLast,
    required this.stopNumber,
    required this.remainingCount,
    required this.onOpenCamera,
    this.nextStop,
    this.onGoNext,
    this.onFinish,
  });

  final _NavigationChrome chrome;
  final PilgrimagePoint arrived;
  final bool isLast;
  final int stopNumber;
  final int remainingCount;
  final VoidCallback onOpenCamera;
  final PilgrimagePoint? nextStop;
  final VoidCallback? onGoNext;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          key: const ValueKey('in-app-navigation-arrival-sheet'),
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
              icon: LucideIcons.flag,
              iconColor: Colors.white,
              iconBackground: isLast ? _endRouteRed : AppColors.accent,
              title: arrived.name,
              subtitle: _destinationSubtitle(arrived),
            ),
            const SizedBox(height: 10),
            _InfoRow(
              key: const ValueKey('in-app-navigation-open-camera'),
              chrome: chrome,
              icon: LucideIcons.camera,
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
                icon: LucideIcons.arrowRight,
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
                  key: const ValueKey('in-app-navigation-arrival-next'),
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
            if (onFinish != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey('in-app-navigation-arrival-finish'),
                  onPressed: onFinish,
                  style: FilledButton.styleFrom(
                    backgroundColor: _endRouteRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('结束路线'),
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
