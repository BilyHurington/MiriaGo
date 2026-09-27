import 'package:geolocator/geolocator.dart';

import '../map/current_location_resolver.dart';
import 'visit_record_save_assets.dart';

class PhotoLocationData {
  const PhotoLocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.altitude,
  });

  factory PhotoLocationData.fromPosition(Position position) {
    return PhotoLocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      timestamp: position.timestamp,
    );
  }

  final double latitude;
  final double longitude;
  final double accuracy;
  final double? altitude;
  final DateTime timestamp;

  Map<String, Object> toPlatformArguments() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'altitude': ?altitude,
    'locationTimestampMillis': timestamp.millisecondsSinceEpoch,
  };
}

typedef LastKnownPositionReader = Future<Position?> Function();
typedef CurrentPositionResolver = Future<Position> Function();
typedef PhotoLocationPermissionReader = Future<LocationPermission> Function();
typedef PhotoLocationWriter =
    Future<bool> Function(String path, PhotoLocationData location);

class PreparedPhotoLocation extends PreparedRecordImage {
  const PreparedPhotoLocation({
    required super.path,
    required this.written,
    super.discard,
  });

  final bool written;
}

typedef PhotoLocationPreparer =
    Future<PreparedPhotoLocation> Function({
      required String sourcePath,
      required PhotoLocationData location,
      required PhotoLocationWriter writer,
    });

Future<PhotoLocationData> resolveRecentPhotoLocation({
  LastKnownPositionReader? getLastKnownPosition,
  CurrentPositionResolver? resolveCurrentPosition,
  PhotoLocationPermissionReader? checkPermission,
  DateTime Function()? now,
  Duration maximumAge = const Duration(minutes: 15),
  double maximumAccuracyMeters = 250,
}) async {
  final currentResolver = resolveCurrentPosition ?? resolveCurrentLocation;
  final currentPermission =
      await (checkPermission ?? Geolocator.checkPermission)();
  final hasPermission =
      currentPermission == LocationPermission.whileInUse ||
      currentPermission == LocationPermission.always;

  if (hasPermission) {
    final lastPosition =
        await (getLastKnownPosition ?? Geolocator.getLastKnownPosition)();
    final currentTime = (now ?? DateTime.now)();
    if (lastPosition != null &&
        !currentTime.difference(lastPosition.timestamp).isNegative &&
        currentTime.difference(lastPosition.timestamp) <= maximumAge &&
        lastPosition.accuracy <= maximumAccuracyMeters) {
      return PhotoLocationData.fromPosition(lastPosition);
    }
  }

  return PhotoLocationData.fromPosition(await currentResolver());
}

Future<PhotoLocationData> resolveFreshPhotoLocation({
  CurrentPositionResolver? resolveCurrentPosition,
}) async {
  return PhotoLocationData.fromPosition(
    await (resolveCurrentPosition ?? resolveCurrentLocation)(),
  );
}
