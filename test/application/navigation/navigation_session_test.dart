import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/navigation/navigation_session.dart';
import 'package:miriago/application/navigation/route_planner.dart';
import 'package:miriago/map/navigation_progress.dart';
import 'package:miriago/map/valhalla_route_client.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

// Scenarios ported from the old in_app_navigation_screen_test.dart, run
// against the state machine.

const _work = PilgrimageWork(
  id: 'work-1',
  title: '测试作品',
  subtitle: '',
  city: '京都',
  source: WorkSource.manual,
);
const _point = PilgrimagePoint(
  id: 'point-1',
  work: _work,
  name: '宇治桥',
  subtitle: '表参道',
  position: LatLng(34.8894, 135.8074),
  episodeLabel: 'EP 1',
  referenceLabel: '手动',
);
const _lastPoint = PilgrimagePoint(
  id: 'point-2',
  work: _work,
  name: '京阪宇治站前',
  subtitle: '京阪宇治駅前',
  position: LatLng(34.8942, 135.8069),
  episodeLabel: 'EP 5',
  referenceLabel: '手动',
);

LatLng _start(PilgrimagePoint p) =>
    LatLng(p.position.latitude - 0.003, p.position.longitude - 0.002);
LatLng _turn(PilgrimagePoint p) =>
    LatLng(p.position.latitude - 0.003, p.position.longitude);

NavigationRoute _testRoute(
  PilgrimagePoint selected,
  List<PilgrimagePoint> stops,
) {
  final targets = stops.isEmpty ? [selected] : stops;
  final shape = [
    _start(selected),
    _turn(selected),
    for (final p in targets) p.position,
  ];
  return NavigationRoute(
    shape: shape,
    maneuvers: [
      const NavigationManeuver(
        type: 1,
        instruction: '开始步行',
        distanceKm: 0.475,
        beginShapeIndex: 0,
        endShapeIndex: 1,
      ),
      const NavigationManeuver(
        type: 10,
        instruction: '右转进入表参道',
        distanceKm: 0.210,
        beginShapeIndex: 1,
        endShapeIndex: 2,
      ),
      NavigationManeuver(
        type: 4,
        instruction: '到达终点',
        distanceKm: 0,
        beginShapeIndex: shape.length - 1,
        endShapeIndex: shape.length - 1,
      ),
    ],
    distanceKm: 0.685,
    duration: const Duration(minutes: 12),
  );
}

class _RecordingRouteClient extends ValhallaRouteClient {
  final requests = <List<LatLng>>[];
  final responses = <Completer<NavigationRoute>>[];
  bool deferred = false;

  @override
  Future<NavigationRoute> route({
    required String baseUrl,
    required List<LatLng> locations,
  }) {
    requests.add(List.of(locations));
    if (deferred) {
      final response = Completer<NavigationRoute>();
      responses.add(response);
      return response.future;
    }
    return Future.value(
      NavigationRoute(
        shape: locations,
        maneuvers: const [],
        distanceKm: 1,
        duration: const Duration(minutes: 10),
      ),
    );
  }
}

class _Clock {
  DateTime now = DateTime(2026, 9, 27, 10);
  void advance(Duration duration) => now = now.add(duration);
}

NavigationSession _session({
  PilgrimagePoint point = _point,
  List<PilgrimagePoint> stops = const [],
  NavigationRoute? route,
  LatLng? initialLocation,
  ValhallaRouteClient? routeClient,
  _Clock? clock,
  NavigationLocationStreamFactory? stream,
  NavigationPreciseLocationCheck? precise,
  AppSettings settings = const AppSettings(),
}) {
  final session = NavigationSession(
    args: NavigationArgs(
      point: point,
      stops: stops,
      initialRoute: route ?? _testRoute(point, stops),
      initialLocation: initialLocation ?? _start(point),
      groupName: stops.length > 1 ? '宇治站附近' : null,
    ),
    settings: settings,
    routeClient: routeClient ?? _RecordingRouteClient(),
    locationStreamFactory: stream ?? () => const Stream.empty(),
    headingStreamFactory: (_) => const Stream.empty(),
    preciseLocationCheck: precise ?? ({required mayRequest}) async => null,
    now: clock == null ? null : () => clock.now,
  );
  addTearDown(session.dispose);
  return session;
}

NavigationLocationSample _at(LatLng position, {double accuracy = 5}) =>
    NavigationLocationSample(position: position, accuracy: accuracy);

void main() {
  test('thresholds match the old app', () {
    expect(arrivalRadiusMeters(0), 18);
    expect(arrivalRadiusMeters(20), 28);
    expect(arrivalRadiusMeters(100), 40);
    expect(offRouteLimitMeters(0), 45);
    expect(offRouteLimitMeters(50), 75);
    expect(offRouteLimitMeters(500), 100);
    expect(maxDecisionAccuracyMeters, 65);
    expect(arrivalRearmMarginMeters, 20);
    expect(NavigationSession.rerouteInterval, const Duration(seconds: 25));
    expect(NavigationSession.userStepBrowseHold, const Duration(seconds: 6));
    expect(NavigationSession.locationExpiry, const Duration(seconds: 45));
  });

  test('invalid samples are ignored', () {
    final session = _session();
    final before = session.currentLocation;
    expect(session.onLocation(_at(const LatLng(double.nan, 135))), isFalse);
    expect(session.onLocation(_at(const LatLng(91, 135))), isFalse);
    expect(
      session.onLocation(_at(const LatLng(34.887, 135.805), accuracy: -1)),
      isFalse,
    );
    expect(session.currentLocation, before);
  });

  test('arrival within the radius opens the prompt and advances', () {
    final session = _session(stops: const [_point, _lastPoint]);
    var arrivals = 0;
    session.onArrivalDetected = () => arrivals++;
    session.onLocation(_at(_point.position));
    expect(arrivals, 1);
    final arrival = session.beginArrival()!;
    expect(arrival.arrived.id, _point.id);
    expect(arrival.stopNumber, 1);
    expect(arrival.remainingCount, 2);
    expect(arrival.nextStop?.id, _lastPoint.id);
    expect(session.beginArrival(), isNull);
    session.advanceToNextStop();
    session.endArrival(arrival, advanced: true);
    expect(session.currentTarget.id, _lastPoint.id);
    expect(session.currentIsLast, isTrue);
    expect(
      navigationStopHeadline(session.currentTarget, isLast: true),
      '终点: 京阪宇治站前',
    );
  });

  test('a dismissed prompt stays closed until the user left by 20 m', () {
    final session = _session(stops: const [_point, _lastPoint]);
    var arrivals = 0;
    session.onArrivalDetected = () => arrivals++;
    session.onLocation(_at(_point.position, accuracy: 0));
    final arrival = session.beginArrival()!;
    session.endArrival(arrival, advanced: false);
    for (var i = 0; i < 3; i++) {
      session.onLocation(_at(_point.position, accuracy: 0));
    }
    expect(arrivals, 1);
    // ~110 m away re-arms the prompt; coming back opens it again.
    session.onLocation(
      _at(
        LatLng(_point.position.latitude - 0.001, _point.position.longitude),
        accuracy: 0,
      ),
    );
    expect(arrivals, 1);
    session.onLocation(_at(_point.position, accuracy: 0));
    expect(arrivals, 2);
  });

  test('coarse fixes move the puck but never arrive or reroute', () {
    final routes = _RecordingRouteClient();
    final session = _session(routeClient: routes);
    var arrivals = 0;
    session.onArrivalDetected = () => arrivals++;
    final near = LatLng(
      _point.position.latitude - 0.0002,
      _point.position.longitude,
    );
    session.onLocation(_at(near, accuracy: 1500));
    expect(session.currentLocation, near);
    expect(arrivals, 0);
    for (var i = 0; i < 4; i++) {
      session.onLocation(_at(const LatLng(34.95, 135.9), accuracy: 1500));
    }
    expect(routes.requests, isEmpty);
  });

  test('three off-route fixes reroute, throttled to 25 s', () async {
    final routes = _RecordingRouteClient();
    final clock = _Clock();
    final session = _session(routeClient: routes, clock: clock);
    const far = LatLng(34.88, 135.79);
    session.onLocation(_at(far));
    session.onLocation(_at(far));
    expect(routes.requests, isEmpty);
    session.onLocation(_at(far));
    expect(routes.requests, hasLength(1));
    expect(routes.requests.single.first, far);
    expect(routes.requests.single.last, _point.position);
    await Future<void>.delayed(Duration.zero);
    // The rerouted shape starts at the user, so fixes near it are on route.
    // Far away again within 25 s: no new request.
    const farther = LatLng(34.87, 135.78);
    for (var i = 0; i < 3; i++) {
      session.onLocation(_at(farther));
    }
    expect(routes.requests, hasLength(1));
    clock.advance(const Duration(seconds: 26));
    for (var i = 0; i < 3; i++) {
      session.onLocation(_at(farther));
    }
    expect(routes.requests, hasLength(2));
  });

  test('an on-route fix resets the off-route count', () {
    final routes = _RecordingRouteClient();
    final session = _session(routeClient: routes);
    const far = LatLng(34.88, 135.79);
    session.onLocation(_at(far));
    session.onLocation(_at(far));
    session.onLocation(_at(_turn(_point)));
    session.onLocation(_at(far));
    session.onLocation(_at(far));
    expect(routes.requests, isEmpty);
  });

  test('reaching the end of the leg counts as arrival', () {
    final routeEnd = LatLng(
      _point.position.latitude - 0.0006,
      _point.position.longitude,
    );
    final session = _session(
      route: NavigationRoute(
        shape: [_start(_point), routeEnd],
        maneuvers: const [],
        distanceKm: 0.3,
        duration: const Duration(minutes: 4),
      ),
    );
    var arrivals = 0;
    session.onArrivalDetected = () => arrivals++;
    session.onLocation(_at(routeEnd));
    expect(arrivals, 1);
  });

  test(
    'forced rerouting bypasses the throttle; stale responses are ignored',
    () async {
      final next = _point.copyWith(
        id: 'next',
        position: const LatLng(34.9, 135.82),
      );
      final last = _point.copyWith(
        id: 'last',
        position: const LatLng(34.91, 135.83),
      );
      final routes = _RecordingRouteClient()..deferred = true;
      final session = _session(
        stops: [_point, next, last],
        routeClient: routes,
      );
      session.advanceToNextStop();
      session.advanceToNextStop();
      expect(routes.requests, hasLength(2));
      expect(routes.requests.last, hasLength(2));
      expect(routes.requests.last.last, last.position);
      NavigationRoute response(int i) => NavigationRoute(
        shape: routes.requests[i],
        maneuvers: const [],
        distanceKm: 1,
        duration: const Duration(minutes: 10),
      );
      routes.responses[1].complete(response(1));
      await Future<void>.delayed(Duration.zero);
      expect(session.route, routes.requests[1]);
      routes.responses[0].complete(response(0));
      await Future<void>.delayed(Duration.zero);
      expect(session.route, routes.requests[1]);
    },
  );

  test('the step pager follows the upcoming maneuver', () {
    final session = _session();
    final pages = <int>[];
    session.onShowStepPage = (index, {required animate}) => pages.add(index);
    expect(session.steps.map((s) => s.instruction), [
      '开始步行',
      '右转进入表参道',
      '到达终点 宇治桥',
    ]);
    expect(session.steps.first.distanceLabel, '475米');
    // The distance before maneuver i is the previous maneuver's length.
    expect(session.steps[1].distanceLabel, '475米');
    expect(session.steps[2].distanceLabel, '210米');
    final halfway = LatLng(
      (_start(_point).latitude + _turn(_point).latitude) / 2,
      (_start(_point).longitude + _turn(_point).longitude) / 2,
    );
    session.onLocation(_at(halfway));
    expect(session.upcomingStepIndex, 1);
    expect(
      session.upcomingStepDistanceMeters,
      closeTo(const Distance()(halfway, _turn(_point)), 3),
    );
    final afterTurn = LatLng(
      _turn(_point).latitude + 0.0005,
      _turn(_point).longitude,
    );
    session.onLocation(_at(afterTurn));
    expect(session.upcomingStepIndex, 2);
    expect(pages, [1, 2]);
  });

  test('browsing steps is held for 6 s against new fixes', () {
    final clock = _Clock();
    final session = _session(clock: clock);
    session.stepPageChanged(2, programmatic: false);
    session.onLocation(
      _at(LatLng(_start(_point).latitude, _start(_point).longitude + 0.0002)),
    );
    expect(session.stepIndex, 2);
    clock.advance(const Duration(seconds: 7));
    session.onLocation(
      _at(LatLng(_start(_point).latitude, _start(_point).longitude + 0.0003)),
    );
    expect(session.stepIndex, session.upcomingStepIndex);
  });

  test('intermediate stops are announced as waypoints', () {
    final start = _start(_point);
    final session = _session(
      stops: const [_point, _lastPoint],
      initialLocation: start,
      route: NavigationRoute(
        shape: [start, _point.position, _lastPoint.position],
        maneuvers: const [
          NavigationManeuver(
            type: 1,
            instruction: '开始步行',
            distanceKm: 0.3,
            beginShapeIndex: 0,
            endShapeIndex: 1,
          ),
          NavigationManeuver(
            type: 5,
            instruction: '到达终点',
            distanceKm: 0,
            beginShapeIndex: 1,
            endShapeIndex: 1,
          ),
          NavigationManeuver(
            type: 1,
            instruction: '开始步行',
            distanceKm: 0.5,
            beginShapeIndex: 1,
            endShapeIndex: 2,
          ),
          NavigationManeuver(
            type: 6,
            instruction: '到达终点',
            distanceKm: 0,
            beginShapeIndex: 2,
            endShapeIndex: 2,
          ),
        ],
        distanceKm: 0.8,
        duration: const Duration(minutes: 11),
        legs: const [
          NavigationLeg(
            startShapeIndex: 0,
            endShapeIndex: 1,
            firstManeuverIndex: 0,
            maneuverCount: 2,
            distanceKm: 0.3,
            duration: Duration(minutes: 4),
          ),
          NavigationLeg(
            startShapeIndex: 1,
            endShapeIndex: 2,
            firstManeuverIndex: 2,
            maneuverCount: 2,
            distanceKm: 0.5,
            duration: Duration(minutes: 7),
          ),
        ],
      ),
    );
    expect(session.steps[1].instruction, '到达途经点 宇治桥，在右侧');
    expect(session.steps[3].instruction, '到达终点 京阪宇治站前，在左侧');
  });

  test('a zone tour from a later point skips earlier stops', () {
    final first = _point.copyWith(id: 'point-0', name: '井用机前步行道');
    final session = _session(stops: [first, _point, _lastPoint]);
    expect(session.startIndex, 1);
    expect(session.activeStops.map((s) => s.id), ['point-1', 'point-2']);
    expect(session.currentTarget.id, 'point-1');
  });

  test('without maneuvers the card shows 路线中', () {
    final session = _session(
      route: NavigationRoute(
        shape: [_start(_point), _point.position],
        maneuvers: const [],
        distanceKm: 0.3,
        duration: const Duration(minutes: 4),
      ),
    );
    expect(session.steps.single.distanceLabel, '路线中');
    expect(session.steps.single.instruction, '沿路线继续前行');
  });

  test('labels and trip metrics keep the old formats', () {
    expect(navigationDistanceLabel(0.0004), '1米');
    expect(navigationDistanceLabel(0.35), '350米');
    expect(navigationDistanceLabel(1.26), '1.3公里');
    expect(navigationDistanceLabel(12.4), '12公里');
    final metrics = navigationTripMetricsForLeg(
      const NavigationLeg(
        startShapeIndex: 0,
        endShapeIndex: 1,
        firstManeuverIndex: 0,
        maneuverCount: 0,
        distanceKm: 1,
        duration: Duration(minutes: 20),
      ),
      remainingDistanceMeters: 500,
      now: DateTime(2026, 9, 27, 9, 55),
    );
    expect(metrics.arrivalText, '10:05');
    expect(metrics.durationText, '0:10');
    expect(metrics.distanceText, '0.5');
    expect(
      navigationDestinationSubtitle(_point),
      '测试作品 · ${_point.displayEpisodeLabel}',
    );
  });

  test('recenter follows again at min(17, mapMaxZoom)', () {
    final session = _session(settings: const AppSettings(mapMaxZoom: 16));
    final moves = <LatLng>[];
    session.onFollowMove = moves.add;
    session.stopFollowing();
    session.onLocation(_at(_turn(_point)));
    expect(moves, isEmpty);
    expect(session.recenter(), 16);
    session.onLocation(_at(_turn(_point)));
    expect(moves, hasLength(1));
    session.updateSettings(const AppSettings(mapMaxZoom: 20));
    expect(session.recenter(), 17);
  });

  testWidgets('stream errors and silence surface location errors', (
    tester,
  ) async {
    {
      final controller = StreamController<NavigationLocationSample>.broadcast();
      final session = NavigationSession(
        args: NavigationArgs(
          point: _point,
          stops: const [],
          initialRoute: _testRoute(_point, const []),
          initialLocation: _start(_point),
        ),
        settings: const AppSettings(),
        routeClient: _RecordingRouteClient(),
        locationStreamFactory: () => controller.stream,
        headingStreamFactory: (_) => const Stream.empty(),
        preciseLocationCheck: ({required mayRequest}) async => null,
      );
      session.setActive(true);
      await tester.pump();
      controller.add(_at(_turn(_point)));
      await tester.pump();
      expect(session.locationError, isNull);
      controller.addError(StateError('service'));
      await tester.pump();
      expect(session.locationError, '定位更新失败，请检查权限和定位服务后重试。');
      controller.add(_at(_turn(_point)));
      await tester.pump();
      expect(session.locationError, isNull);
      // Invalid samples do not keep the fix fresh.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 10));
        controller.add(_at(const LatLng(double.nan, 135)));
        await tester.pump();
      }
      expect(session.locationError, '暂未收到新的定位，当前位置可能已过期。');
      // Background: the stream is paused.
      expect(controller.hasListener, isTrue);
      session.setActive(false);
      await tester.pump();
      expect(controller.hasListener, isFalse);
      session.dispose();
    }
  });

  testWidgets('a finished stream asks to retry', (tester) async {
    {
      final controller = StreamController<NavigationLocationSample>();
      final session = NavigationSession(
        args: NavigationArgs(
          point: _point,
          stops: const [],
          initialRoute: _testRoute(_point, const []),
          initialLocation: _start(_point),
        ),
        settings: const AppSettings(),
        routeClient: _RecordingRouteClient(),
        locationStreamFactory: () => controller.stream,
        headingStreamFactory: (_) => const Stream.empty(),
        preciseLocationCheck: ({required mayRequest}) async => null,
      );
      session.setActive(true);
      await tester.pump();
      unawaited(controller.close());
      await tester.pump();
      expect(session.locationError, '定位更新已停止，请重试。');
      session.dispose();
    }
  });

  test('temporary full accuracy is requested once per session', () async {
    final requests = <bool>[];
    final session = _session(
      precise: ({required mayRequest}) async {
        requests.add(mayRequest);
        return false;
      },
    );
    await session.checkPreciseLocation();
    await session.checkPreciseLocation();
    expect(requests, [true, false]);
    expect(session.preciseLocation, isFalse);
  });
}
