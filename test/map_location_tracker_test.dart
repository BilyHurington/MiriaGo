import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:miriago/map/current_location_resolver.dart';
import 'package:miriago/map/map_location_tracker.dart';

Position fix(double latitude) => Position(
  latitude: latitude,
  longitude: 139,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  testWidgets(
    'resume waits for old resolver cleanup and explicit disable cancels queued resume',
    (tester) async {
      final cleanup = Completer<void>();
      final cancellationReached = Completer<void>();
      var resolves = 0;
      var listens = 0;
      final tracker = MapLocationTracker(
        resolve: (cancelled) async {
          resolves++;
          if (resolves == 1) {
            await cancelled;
            cancellationReached.complete();
            await cleanup.future;
            throw const CurrentLocationCancelled();
          }
          return fix(36);
        },
        streamFactory: (_) {
          listens++;
          return const Stream.empty();
        },
      );
      tracker.configure(active: true, continuous: true);
      final old = tracker.locate();
      await tester.pump();
      tracker.configure(active: false, continuous: true);
      tracker.configure(active: true, continuous: true);
      await tester.pump();
      expect(cancellationReached.isCompleted, isTrue);
      expect(resolves, 1);
      expect(listens, 0);
      cleanup.complete();
      await tester.pump();
      expect(await old, isNull);
      expect(resolves, 2);
      expect(listens, 1);
      tracker.dispose();

      final suspended = Completer<Position>();
      var requests = 0;
      final second = MapLocationTracker(
        resolve: (_) {
          requests++;
          return suspended.future;
        },
      );
      second.configure(active: true, continuous: false);
      final request = second.locate();
      await tester.pump();
      second.configure(active: false, continuous: false);
      second.configure(active: true, continuous: false);
      second.disable();
      suspended.complete(fix(35));
      await tester.pump();
      expect(await request, isNull);
      expect(requests, 1);
      expect(second.enabled, isFalse);
      second.dispose();
    },
  );

  testWidgets('tracking starts only after locating; toggle keeps last fix', (
    tester,
  ) async {
    var listens = 0;
    var cancels = 0;
    final stream = StreamController<Position>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    final tracker = MapLocationTracker(
      resolve: (_) async => fix(35),
      streamFactory: (_) => stream.stream,
    );
    tracker.configure(active: true, continuous: true);
    await tester.pump();
    expect(listens, 0);
    await tracker.locate();
    await tester.pump();
    expect(listens, 1);
    stream.add(fix(36));
    await tester.pump();
    expect(tracker.position!.latitude, 36);
    tracker.configure(active: true, continuous: false);
    await tester.pump();
    expect(cancels, 1);
    expect(tracker.position!.latitude, 36);
    tracker.configure(active: true, continuous: true);
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(listens, 2);
    tracker.disable();
    await tester.pump();
    expect(cancels, 2);
    expect(tracker.enabled, isFalse);
    tracker.dispose();
    await stream.close();
  });

  testWidgets('single-shot preference never starts continuous stream', (
    tester,
  ) async {
    var requested = 0;
    final tracker = MapLocationTracker(
      resolve: (_) async => fix(35),
      streamFactory: (_) {
        requested++;
        return const Stream.empty();
      },
    );
    tracker.configure(active: true, continuous: false);
    await tracker.locate();
    await tester.pump();
    expect(requested, 0);
    expect(tracker.enabled, isTrue);
    tracker.dispose();
  });

  testWidgets(
    'hidden first request is invalidated and resumed without old result',
    (tester) async {
      final first = Completer<Position>();
      var calls = 0;
      var cancelled = false;
      final tracker = MapLocationTracker(
        resolve: (cancellation) {
          calls++;
          cancellation.then((_) => cancelled = true);
          return calls == 1 ? first.future : Future.value(fix(36));
        },
        streamFactory: (_) => const Stream.empty(),
      );
      tracker.configure(active: true, continuous: false);
      final original = tracker.locate();
      await tester.pump();
      tracker.configure(active: false, continuous: false);
      await tester.pump();
      expect(cancelled, isTrue);
      first.complete(fix(35));
      expect(await original, isNull);
      expect(tracker.position, isNull);
      tracker.configure(active: true, continuous: false);
      await tester.pump();
      expect(calls, 2);
      expect(tracker.position!.latitude, 36);
      tracker.dispose();
    },
  );

  testWidgets('stream errors, stale fixes and recovery are exposed', (
    tester,
  ) async {
    final stream = StreamController<Position>.broadcast();
    final tracker = MapLocationTracker(
      resolve: (_) async => fix(35),
      streamFactory: (_) => stream.stream,
      staleAfter: const Duration(seconds: 5),
    );
    tracker.configure(active: true, continuous: true);
    await tracker.locate();
    await tester.pump();
    stream.addError(
      const CurrentLocationException(CurrentLocationFailure.permissionDenied),
    );
    await tester.pump();
    expect(tracker.error, contains('权限'));
    stream.add(fix(36));
    await tester.pump();
    expect(tracker.error, isNull);
    await tester.pump(const Duration(seconds: 6));
    expect(tracker.error, contains('过期'));
    tracker.configure(active: false, continuous: true);
    stream.add(fix(37));
    await tester.pump();
    expect(tracker.position!.latitude, 36);
    tracker.configure(active: true, continuous: true);
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
    await tester.pump();
    stream.add(fix(38));
    await tester.pump();
    expect(tracker.error, isNull);
    tracker.dispose();
    await stream.close();
  });

  testWidgets('route, tab and foreground changes pause and restore tracking', (
    tester,
  ) async {
    var active = true;
    final transitions = <bool>[];
    late StateSetter rebuild;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _LifecycleProbe(active: active, onChange: transitions.add);
          },
        ),
      ),
    );
    expect(transitions.last, isTrue);
    rebuild(() => active = false);
    await tester.pump();
    expect(transitions.last, isFalse);
    rebuild(() => active = true);
    await tester.pump();
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    expect(transitions.last, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(transitions.last, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(transitions.last, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(transitions.last, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({required this.active, required this.onChange});
  final bool active;
  final ValueChanged<bool> onChange;
  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe>
    with MapLocationLifecycle<_LifecycleProbe> {
  @override
  bool get locationPageEnabled => widget.active;
  @override
  void onLocationActivityChanged(bool active) => widget.onChange(active);
  @override
  Widget build(BuildContext context) => const Scaffold();
}
