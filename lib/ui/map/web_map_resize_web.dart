import 'package:web/web.dart' as web;

/// maplibre-gl sizes its canvas when the container is attached. Flutter
/// attaches the platform view before it has its final size, so the base map
/// stays blank until the next window resize. Dispatching a synthetic resize
/// makes maplibre-gl (and Flutter, harmlessly) re-measure.
void nudgeWebMapResize() {
  web.window.dispatchEvent(web.Event('resize'));
}
