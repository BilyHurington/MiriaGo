import 'package:url_launcher/url_launcher.dart';

import '../plan/pilgrimage_models.dart';

class MapNavigationLauncher {
  const MapNavigationLauncher();

  Future<bool> openWalking(PilgrimagePoint point, NavigationApp app) {
    return launchUrl(
      walkingNavigationUri(point, app),
      mode: LaunchMode.externalApplication,
    );
  }
}

Uri walkingNavigationUri(PilgrimagePoint point, NavigationApp app) {
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
