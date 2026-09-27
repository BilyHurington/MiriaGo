import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../map/map_location_tracker.dart' show locationUpdateError;
import '../../map/navigation_heading.dart';
import '../../map/navigation_progress.dart';
import '../../map/valhalla_route_client.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan/plan_group_utils.dart';
import 'route_planner.dart';

/// One location fix fed to the navigation.
@immutable
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

Stream<NavigationLocationSample> defaultNavigationLocationStream() {
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

/// One page of the maneuver pager.
@immutable
class NavigationStep {
  const NavigationStep({
    required this.maneuverType,
    required this.distanceLabel,
    required this.instruction,
  });

  /// Valhalla maneuver type; -1 for the 「路线中」 placeholder.
  final int maneuverType;
  final String distanceLabel;
  final String instruction;
}

/// Trip panel figures.
@immutable
class NavigationTripMetrics {
  const NavigationTripMetrics({
    required this.arrivalText,
    required this.durationText,
    required this.distanceText,
  });

  final String arrivalText;
  final String durationText;
  final String distanceText;
}

/// What the arrival sheet shows.
@immutable
class NavigationArrival {
  const NavigationArrival({
    required this.arrived,
    required this.isLast,
    required this.stopNumber,
    required this.remainingCount,
    this.nextStop,
  });

  final PilgrimagePoint arrived;
  final bool isLast;
  final int stopNumber;
  final int remainingCount;
  final PilgrimagePoint? nextStop;
}

/// 「N米」 / 「x公里」.
String navigationDistanceLabel(double kilometers) {
  final meters = kilometers * 1000;
  if (meters < 1000) return '${math.max(1, meters.round())}米';
  return '${kilometers.toStringAsFixed(kilometers >= 10 ? 0 : 1)}公里';
}

/// 「终点: X」 for the last stop.
String navigationStopHeadline(PilgrimagePoint stop, {required bool isLast}) {
  return isLast ? '终点: ${stop.name}' : stop.name;
}

/// 「作品 · 集数」.
String navigationDestinationSubtitle(PilgrimagePoint point) {
  final episode = point.displayEpisodeLabel.trim();
  if (episode.isEmpty) {
    return point.work.title;
  }
  return '${point.work.title} · $episode';
}

List<NavigationStep> navigationStepsFor(
  NavigationRoute route, {
  List<PilgrimagePoint> stops = const [],
}) {
  if (route.maneuvers.isEmpty) {
    return const [
      NavigationStep(
        maneuverType: -1,
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
      NavigationStep(
        maneuverType: maneuvers[i].type,
        // A maneuver's own length is the distance walked after it, so the
        // distance leading up to maneuver i is the previous maneuver's length.
        distanceLabel: navigationDistanceLabel(
          i == 0 ? maneuvers[i].distanceKm : maneuvers[i - 1].distanceKm,
        ),
        instruction: instructionFor(i),
      ),
  ];
}

NavigationTripMetrics navigationTripMetricsForLeg(
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
  return NavigationTripMetrics(
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

/// In-app navigation state machine, ported 1:1 from the old
/// `InAppNavigationScreen` state: location stream (paused in the
/// background), coarse-fix filtering, arrival and off-route decisions with
/// the original thresholds, reroute throttling and step tracking.
///
/// Navigation never marks points complete.
///
/// The page connects [onFollowMove], [onShowStepPage] and
/// [onArrivalDetected] and calls [setActive] from `MapLocationLifecycle`.
class NavigationSession extends ChangeNotifier {
  NavigationSession({
    required this.args,
    required this._settings,
    ValhallaRouteClient? routeClient,
    NavigationLocationStreamFactory? locationStreamFactory,
    NavigationHeadingStreamFactory? headingStreamFactory,
    NavigationPreciseLocationCheck? preciseLocationCheck,
    DateTime Function()? now,
  }) : _routeClient = routeClient ?? args.routeClient ?? ValhallaRouteClient(),
       _locationStreamFactory =
           locationStreamFactory ?? defaultNavigationLocationStream,
       _headingStreamFactory = headingStreamFactory ?? nativeNavigationHeading,
       _preciseLocationCheck =
           preciseLocationCheck ?? defaultNavigationPreciseLocationCheck,
       _now = now ?? DateTime.now {
    stops = coordinateNavigationStops(point: args.point, stops: args.stops);
    startIndex = navigationStartIndex(point: args.point, stops: stops);
    activeStops = remainingNavigationStops(point: args.point, stops: stops);
    _navigationRoute = args.initialRoute;
    _route = _navigationRoute.shape;
    _routeDistances = cumulativeRouteDistances(_route);
    _steps = navigationStepsFor(_navigationRoute, stops: _routeStops(0));
    _currentLocation = args.initialLocation;
    _progress = _progressFor(_currentLocation);
    _upcomingStepIndex = _upcomingStepFor(_progress);
    _stepIndex = _upcomingStepIndex;
  }

  final NavigationArgs args;
  AppSettings _settings;
  final ValhallaRouteClient _routeClient;
  final NavigationLocationStreamFactory _locationStreamFactory;
  final NavigationHeadingStreamFactory _headingStreamFactory;
  final NavigationPreciseLocationCheck _preciseLocationCheck;
  final DateTime Function() _now;

  /// Moves the map when following the user.
  ValueChanged<LatLng>? onFollowMove;

  /// Pages the maneuver pager.
  void Function(int index, {required bool animate})? onShowStepPage;

  /// An arrival was detected; the page shows the sheet after the frame.
  VoidCallback? onArrivalDetected;

  static const userStepBrowseHold = Duration(seconds: 6);
  static const rerouteInterval = Duration(seconds: 25);
  static const locationExpiry = Duration(seconds: 45);

  /// All stops with coordinates (for the map and the all-stops sheet).
  late final List<PilgrimagePoint> stops;

  /// Stops before this index were skipped (shown grey).
  late final int startIndex;

  /// Stops still to visit, starting with the chosen point.
  late final List<PilgrimagePoint> activeStops;

  final heading = NavigationHeading();

  var _disposed = false;
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
  Future<void> _locationCancelled = Future<void>.value();
  Timer? _locationExpiry;
  int _locationSession = 0;
  String? _locationError;

  late NavigationRoute _navigationRoute;
  late List<LatLng> _route;
  late List<double> _routeDistances;
  late List<NavigationStep> _steps;
  late LatLng _currentLocation;
  late RouteProgress _progress;
  late int _upcomingStepIndex;
  DateTime? _userBrowsedStepsAt;
  late int _stepIndex;

  AppSettings get settings => _settings;

  /// Live settings (route service URL, map max zoom).
  void updateSettings(AppSettings value) => _settings = value;

  bool get isDisposed => _disposed;
  int get targetIndex => _targetIndex;
  bool get followLocation => _followLocation;
  bool get arrivalSheetOpen => _arrivalSheetOpen;
  bool? get preciseLocation => _preciseLocation;
  String? get locationError => _locationError;
  NavigationRoute get navigationRoute => _navigationRoute;
  List<LatLng> get route => _route;
  List<NavigationStep> get steps => _steps;
  LatLng get currentLocation => _currentLocation;
  RouteProgress get progress => _progress;
  int get upcomingStepIndex => _upcomingStepIndex;
  int get stepIndex => _stepIndex;
  String? get groupName => args.groupName;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Stops served by a route requested when [targetIndex] was the target, in
  /// leg order.
  List<PilgrimagePoint> _routeStops(int targetIndex) {
    if (activeStops.isEmpty) return [args.point];
    return activeStops.skip(targetIndex).toList(growable: false);
  }

  NavigationLeg get currentLeg {
    final legs = _navigationRoute.legs;
    final index = (_targetIndex - _routeTargetOffset).clamp(0, legs.length - 1);
    return legs[index];
  }

  /// Route distance left to the current target (end of the current leg).
  double get legRemainingMeters {
    final end = currentLeg.endShapeIndex.clamp(0, _routeDistances.length - 1);
    return math.max(
      0,
      _routeDistances[end] - _progress.distanceAlongRouteMeters,
    );
  }

  NavigationTripMetrics get tripMetrics => navigationTripMetricsForLeg(
    currentLeg,
    remainingDistanceMeters: legRemainingMeters,
    now: _now(),
  );

  RouteProgress _progressFor(LatLng position, {double? previousAlong}) {
    final leg = currentLeg;
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
    final leg = currentLeg;
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
  double? get upcomingStepDistanceMeters {
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

  PilgrimagePoint get currentTarget {
    if (activeStops.isEmpty) {
      return args.point;
    }
    final index = _targetIndex.clamp(0, activeStops.length - 1);
    return activeStops[index];
  }

  bool get currentIsLast {
    if (activeStops.isEmpty) {
      return true;
    }
    return _targetIndex >= activeStops.length - 1;
  }

  PilgrimagePoint? get nextStop {
    if (currentIsLast || _targetIndex + 1 >= activeStops.length) {
      return null;
    }
    return activeStops[_targetIndex + 1];
  }

  // ---------------------------------------------------------------------
  // Location lifecycle (old onLocationActivityChanged / _startLocation).

  /// The page became visible and foreground (true) or not (false).
  void setActive(bool active) {
    _stopLocation();
    if (active) {
      unawaited(checkPreciseLocation());
      unawaited(_startLocation(_locationSession));
      heading.start(() => _headingStreamFactory(_currentLocation));
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
    heading.stop();
  }

  Future<void> _startLocation(int session) async {
    await _locationCancelled;
    if (_disposed || session != _locationSession) return;
    try {
      _locationSubscription = _locationStreamFactory().listen(
        (sample) {
          if (_disposed || session != _locationSession) return;
          if (onLocation(sample)) _armLocationExpiry(session);
        },
        onError: (Object error) {
          if (_disposed || session != _locationSession) return;
          _locationError = locationUpdateError(error);
          _notify();
        },
        onDone: () {
          if (_disposed || session != _locationSession) return;
          _locationError = '定位更新已停止，请重试。';
          _notify();
        },
      );
      _armLocationExpiry(session);
    } catch (error) {
      if (!_disposed && session == _locationSession) {
        _locationError = locationUpdateError(error);
        _notify();
      }
    }
  }

  void _armLocationExpiry(int session) {
    _locationExpiry?.cancel();
    _locationExpiry = Timer(locationExpiry, () {
      if (!_disposed && session == _locationSession) {
        _locationError = '暂未收到新的定位，当前位置可能已过期。';
        _notify();
      }
    });
  }

  /// Ask for temporary full accuracy at most once per navigation session;
  /// later checks (returning from Settings or the background, where iOS may
  /// have revoked it) only read the current state.
  Future<void> checkPreciseLocation() async {
    final mayRequest = !_temporaryAccuracyRequested;
    _temporaryAccuracyRequested = true;
    final precise = await _preciseLocationCheck(mayRequest: mayRequest);
    if (_disposed || precise == _preciseLocation) return;
    _preciseLocation = precise;
    _notify();
  }

  // ---------------------------------------------------------------------
  // Location decisions (old _onLocation).

  /// Applies one fix. Returns false for invalid samples (they do not keep
  /// the location fresh).
  @visibleForTesting
  bool onLocation(NavigationLocationSample sample) {
    if (_disposed) return false;
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
        browsedAt != null && _now().difference(browsedAt) < userStepBrowseHold;
    _locationError = null;
    _currentLocation = sample.position;
    _progress = progress;
    _upcomingStepIndex = maneuverIndex;
    if (!keepUserPage) {
      _userBrowsedStepsAt = null;
      _stepIndex = maneuverIndex;
    }
    _notify();
    if (!keepUserPage) onShowStepPage?.call(maneuverIndex, animate: true);
    if (_followLocation) onFollowMove?.call(sample.position);

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
      unawaited(reroute());
    }

    final target = currentTarget;
    final arrivalRadius = arrivalRadiusMeters(sample.accuracy);
    final distanceToTarget = const Distance()(sample.position, target.position);
    final legRemaining = legRemainingMeters;
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
      onArrivalDetected?.call();
    }
    return true;
  }

  /// Requests a new route from the current location through the remaining
  /// stops; at most every 25 s unless [force] (前往下一点).
  Future<void> reroute({bool force = false}) async {
    final now = _now();
    if (!force &&
        _lastRerouteAt != null &&
        now.difference(_lastRerouteAt!) < rerouteInterval) {
      return;
    }
    _lastRerouteAt = now;
    _offRouteSamples = 0;
    final version = ++_rerouteVersion;
    final targetId = currentTarget.id;
    final targetIndex = _targetIndex;
    try {
      final route = await _routeClient.route(
        baseUrl: _settings.valhallaBaseUrl,
        locations: [
          _currentLocation,
          for (final stop in activeStops.skip(_targetIndex)) stop.position,
        ],
      );
      if (_disposed ||
          version != _rerouteVersion ||
          targetId != currentTarget.id) {
        return;
      }
      _navigationRoute = route;
      _route = route.shape;
      _routeDistances = cumulativeRouteDistances(_route);
      _routeTargetOffset = targetIndex;
      _steps = navigationStepsFor(route, stops: _routeStops(targetIndex));
      _progress = _progressFor(_currentLocation);
      _upcomingStepIndex = _upcomingStepFor(_progress);
      _stepIndex = _upcomingStepIndex;
      _userBrowsedStepsAt = null;
      _notify();
      onShowStepPage?.call(_stepIndex, animate: false);
    } on Object {
      // Keep the previous route visible; another location update may retry later.
    }
  }

  // ---------------------------------------------------------------------
  // Steps, following.

  /// The pager moved to [index]; [programmatic] when the session paged it.
  void stepPageChanged(int index, {required bool programmatic}) {
    _stepIndex = index;
    if (!programmatic) {
      _userBrowsedStepsAt = index == _upcomingStepIndex ? null : _now();
    }
    _notify();
  }

  /// The user dragged the map.
  void stopFollowing() {
    if (!_followLocation) return;
    _followLocation = false;
    _notify();
  }

  /// 回到当前位置: follow again at min(17, mapMaxZoom). Returns the zoom.
  double recenter() {
    _followLocation = true;
    _notify();
    return math.min(17.0, _settings.mapMaxZoom.toDouble());
  }

  // ---------------------------------------------------------------------
  // Arrival.

  /// Opens the arrival prompt; null when one is already open.
  NavigationArrival? beginArrival() {
    if (_arrivalSheetOpen) return null;
    _arrivalSheetOpen = true;
    return NavigationArrival(
      arrived: currentTarget,
      isLast: currentIsLast,
      stopNumber: _targetIndex + 1,
      remainingCount: activeStops.isEmpty ? 1 : activeStops.length,
      nextStop: nextStop,
    );
  }

  /// The arrival prompt closed. Dismissing it keeps the user at this stop;
  /// do not reopen it until they have clearly walked away and come back.
  void endArrival(NavigationArrival arrival, {required bool advanced}) {
    _arrivalSheetOpen = false;
    if (!advanced) {
      _arrivalSuppressedStopId = arrival.arrived.id;
    }
  }

  /// 前往下一点: next target, forced reroute.
  void advanceToNextStop() {
    if (nextStop == null) return;
    _targetIndex++;
    _notify();
    unawaited(reroute(force: true));
  }

  @override
  void dispose() {
    _disposed = true;
    _stopLocation();
    heading.dispose();
    super.dispose();
  }
}
