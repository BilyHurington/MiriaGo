import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:miriago/map/current_location_resolver.dart';

void main() {
  test('rechecks permission and waits after the first grant', () async {
    var permissionChecks = 0;
    var requested = false;
    Duration? waitedDuration;
    final position = _position(latitude: 35, longitude: 139);

    final result = await resolveCurrentLocation(
      isServiceEnabled: () async => true,
      checkPermission: () async {
        permissionChecks += 1;
        return permissionChecks == 1
            ? LocationPermission.denied
            : LocationPermission.whileInUse;
      },
      requestPermission: () async {
        requested = true;
        return LocationPermission.whileInUse;
      },
      delay: (duration) async {
        waitedDuration = duration;
      },
      waitForAppResume: () async {},
      positionStream: (_) => Stream.value(position),
    );

    expect(result, position);
    expect(requested, isTrue);
    expect(permissionChecks, 2);
    expect(waitedDuration, const Duration(milliseconds: 350));
  });

  test('reports denied permission without requesting a position', () async {
    var requestedPosition = false;

    await expectLater(
      resolveCurrentLocation(
        isServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async => LocationPermission.deniedForever,
        positionStream: (_) {
          requestedPosition = true;
          return const Stream.empty();
        },
      ),
      throwsA(
        isA<CurrentLocationException>().having(
          (error) => error.failure,
          'failure',
          CurrentLocationFailure.permissionDenied,
        ),
      ),
    );
    expect(requestedPosition, isFalse);
  });

  test('cancels the native position stream after timeout', () async {
    var canceled = false;
    final controller = StreamController<Position>(
      onCancel: () {
        canceled = true;
      },
    );
    addTearDown(controller.close);

    await expectLater(
      resolveCurrentLocation(
        isServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        requestPermission: () async => LocationPermission.whileInUse,
        positionStream: (_) => controller.stream,
        normalTimeout: const Duration(milliseconds: 5),
      ),
      throwsA(
        isA<CurrentLocationException>().having(
          (error) => error.failure,
          'failure',
          CurrentLocationFailure.timeout,
        ),
      ),
    );
    expect(canceled, isTrue);
  });

  test(
    'reports disabled location services before checking permission',
    () async {
      var checkedPermission = false;

      await expectLater(
        resolveCurrentLocation(
          isServiceEnabled: () async => false,
          checkPermission: () async {
            checkedPermission = true;
            return LocationPermission.whileInUse;
          },
        ),
        throwsA(
          isA<CurrentLocationException>().having(
            (error) => error.failure,
            'failure',
            CurrentLocationFailure.serviceDisabled,
          ),
        ),
      );
      expect(checkedPermission, isFalse);
    },
  );
}

Position _position({required double latitude, required double longitude}) {
  return Position(
    longitude: longitude,
    latitude: latitude,
    timestamp: DateTime(2026, 7, 20),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
