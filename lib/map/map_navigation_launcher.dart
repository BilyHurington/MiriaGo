import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../plan/pilgrimage_models.dart';

typedef AndroidGoogleMapsLauncher =
    Future<bool> Function(PilgrimagePoint point);
typedef ExternalNavigationLauncher = Future<bool> Function(Uri uri);

class MapNavigationLauncher {
  const MapNavigationLauncher({
    this.androidGoogleMapsLauncher,
    this.externalNavigationLauncher,
    this.useAndroidGoogleMapsIntent,
  });

  static const _channel = MethodChannel('miriago/map_navigation');

  @visibleForTesting
  final AndroidGoogleMapsLauncher? androidGoogleMapsLauncher;

  @visibleForTesting
  final ExternalNavigationLauncher? externalNavigationLauncher;

  @visibleForTesting
  final bool? useAndroidGoogleMapsIntent;

  Future<bool> openWalking(PilgrimagePoint point, NavigationApp app) async {
    if (!point.hasCoordinate) {
      return false;
    }

    if (app == NavigationApp.googleMaps && _shouldUseAndroidIntent) {
      try {
        final opened =
            await (androidGoogleMapsLauncher ?? _openGoogleMapsOnAndroid)(
              point,
            );
        if (opened) {
          return true;
        }
      } on PlatformException {
        // Fall back to the universal URL when the native app is unavailable.
      } on MissingPluginException {
        // Keep navigation working on builds without the Android channel.
      }
    }

    final uri = walkingNavigationUri(point, app);
    final externalLauncher = externalNavigationLauncher;
    if (externalLauncher != null) {
      return externalLauncher(uri);
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool get _shouldUseAndroidIntent =>
      useAndroidGoogleMapsIntent ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static Future<bool> _openGoogleMapsOnAndroid(PilgrimagePoint point) async {
    return await _channel.invokeMethod<bool>('openGoogleMapsWalking', {
          'latitude': point.position.latitude,
          'longitude': point.position.longitude,
        }) ??
        false;
  }
}

Uri walkingNavigationUri(PilgrimagePoint point, NavigationApp app) {
  if (!point.hasCoordinate) {
    throw ArgumentError.value(point.id, 'point', 'Point has no coordinate.');
  }
  final latitude = _coordinate(point.position.latitude);
  final longitude = _coordinate(point.position.longitude);
  final destination = '$latitude,$longitude';
  final destinationName = _destinationName(point);

  return switch (app) {
    NavigationApp.googleMaps => Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'walking',
    }),
    NavigationApp.appleMaps => Uri.https('maps.apple.com', '/', {
      'daddr': destination,
      'dirflg': 'w',
    }),
    NavigationApp.amap => Uri.https('uri.amap.com', '/navigation', {
      'to': '$longitude,$latitude,$destinationName',
      'mode': 'walk',
      'coordinate': 'wgs84',
      'callnative': '1',
      'src': 'MiriaGo',
    }),
    NavigationApp.baiduMaps => Uri.http('api.map.baidu.com', '/direction', {
      'destination': 'latlng:$latitude,$longitude|name:$destinationName',
      'mode': 'walking',
      'coord_type': 'wgs84',
      'output': 'html',
      'src': 'webapp.miriago.miriago',
    }),
  };
}

String _coordinate(double value) => value.toStringAsFixed(6);

String _destinationName(PilgrimagePoint point) {
  final name = point.name.trim();
  if (name.isNotEmpty) {
    return name;
  }
  final subtitle = point.subtitle.trim();
  if (subtitle.isNotEmpty) {
    return subtitle;
  }
  return point.work.title;
}
