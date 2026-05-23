import 'package:url_launcher/url_launcher.dart';

import '../plan/pilgrimage_models.dart';

class MapNavigationLauncher {
  const MapNavigationLauncher();

  Future<bool> openGoogleMapsWalking(PilgrimagePoint point) {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${point.position.latitude},${point.position.longitude}',
      'travelmode': 'walking',
    });

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
