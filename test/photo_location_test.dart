import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:miriago/camera_reference/photo_location.dart';

void main() {
  test('uses a recent accurate last-known position', () async {
    final now = DateTime(2026, 8, 13, 12);
    final recent = _position(
      latitude: 35.658,
      longitude: 139.745,
      timestamp: now.subtract(const Duration(minutes: 3)),
      accuracy: 20,
    );
    var resolvedFresh = false;

    final result = await resolveRecentPhotoLocation(
      checkPermission: () async => LocationPermission.whileInUse,
      getLastKnownPosition: () async => recent,
      resolveCurrentPosition: () async {
        resolvedFresh = true;
        return recent;
      },
      now: () => now,
    );

    expect(result.latitude, recent.latitude);
    expect(result.longitude, recent.longitude);
    expect(resolvedFresh, isFalse);
  });

  test('refreshes a stale last-known position', () async {
    final now = DateTime(2026, 8, 13, 12);
    final stale = _position(
      latitude: 35,
      longitude: 139,
      timestamp: now.subtract(const Duration(hours: 1)),
      accuracy: 10,
    );
    final fresh = _position(
      latitude: 34.7,
      longitude: 135.5,
      timestamp: now,
      accuracy: 5,
    );

    final result = await resolveRecentPhotoLocation(
      checkPermission: () async => LocationPermission.whileInUse,
      getLastKnownPosition: () async => stale,
      resolveCurrentPosition: () async => fresh,
      now: () => now,
    );

    expect(result.latitude, fresh.latitude);
    expect(result.longitude, fresh.longitude);
  });

  test('platform arguments contain GPS values and timestamp', () {
    final timestamp = DateTime(2026, 8, 13, 12, 34, 56);
    final data = PhotoLocationData(
      latitude: 35.1,
      longitude: 139.2,
      accuracy: 8,
      altitude: 42,
      timestamp: timestamp,
    );

    expect(data.toPlatformArguments(), {
      'latitude': 35.1,
      'longitude': 139.2,
      'accuracy': 8,
      'altitude': 42,
      'locationTimestampMillis': timestamp.millisecondsSinceEpoch,
    });
  });
}

Position _position({
  required double latitude,
  required double longitude,
  required DateTime timestamp,
  required double accuracy,
}) {
  return Position(
    longitude: longitude,
    latitude: latitude,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
