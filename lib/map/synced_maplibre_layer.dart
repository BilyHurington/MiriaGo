import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart';

/// Embeds a MapLibre base map as a [fm.FlutterMap] layer and keeps its camera
/// in sync with the surrounding flutter_map camera.
///
/// flutter_map_maplibre's `MapLibreLayer` only forwards `MapEventWithMove`
/// events and reads the camera once when the native map is created. A camera
/// changed by `initialCameraFit`, or moved before the native map reports
/// `onMapCreated`, was never forwarded, so the base map stayed at flutter_map's
/// default centre (Kyiv) while overlays were drawn at the fitted camera.
///
/// The native map may also draw its centre away from the middle of the view:
/// maplibre_ios turns on `automaticallyAdjustsContentInset`, so under the
/// status bar the base map sits half the safe-area inset lower than the
/// overlays. The layer measures where the native map actually draws the
/// synced centre and shifts the native camera by that offset.
/// The centre to give a native map that draws its centre at
/// [nativeCenterOffset] from the middle of the view, so that it shows
/// [camera]'s centre in the middle like the flutter_map overlays.
LatLng compensatedNativeCenter(fm.MapCamera camera, Offset nativeCenterOffset) {
  if (nativeCenterOffset == Offset.zero) return camera.center;
  final middle = camera.nonRotatedSize.center(Offset.zero);
  return camera.screenOffsetToLatLng(middle + nativeCenterOffset);
}

class SyncedMapLibreLayer extends StatefulWidget {
  const SyncedMapLibreLayer({required this.initStyle, super.key});

  final String initStyle;

  @override
  State<SyncedMapLibreLayer> createState() => _SyncedMapLibreLayerState();
}

class _SyncedMapLibreLayerState extends State<SyncedMapLibreLayer> {
  /// Offsets below this are treated as aligned (logical pixels).
  static const _alignedTolerance = 0.5;

  MapController? _controller;
  StreamSubscription<fm.MapEvent>? _eventSubscription;
  fm.MapController? _flutterMapController;
  fm.MapCamera? _latestCamera;
  fm.MapCamera? _syncedCamera;
  var _syncScheduled = false;

  /// Where the native map draws the requested centre, relative to the middle
  /// of the view.
  Offset _nativeCenterOffset = Offset.zero;
  var _corrections = 0;
  var _layoutNudges = 0;
  var _active = true;
  Size? _measuredSize;

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _controller = null;
    super.dispose();
  }

  void _listenToMoves(fm.MapController controller) {
    if (identical(controller, _flutterMapController)) return;
    _eventSubscription?.cancel();
    _flutterMapController = controller;
    // Gestures and animated moves: follow immediately, before the frame, so
    // the base map does not trail overlays by a frame.
    _eventSubscription = controller.mapEventStream.listen((event) {
      if (event is fm.MapEventWithMove) {
        _latestCamera = event.camera;
        _syncNow();
      }
    });
  }

  void _scheduleSync({bool force = false}) {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _syncNow(force: force);
    });
    // Nothing else may be scheduling frames while the map is idle.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _syncNow({bool force = false}) {
    final controller = _controller;
    final camera = _latestCamera;
    if (controller == null || camera == null) return;
    if (!force && identical(camera, _syncedCamera)) return;
    if (!force) _corrections = 0;
    _syncedCamera = camera;
    var center = compensatedNativeCenter(camera, _nativeCenterOffset);
    if (_layoutNudges.isOdd) {
      // A camera change makes the native view pick up its final size.
      center = LatLng(center.latitude + 1e-7, center.longitude);
    }
    try {
      unawaited(
        controller
            .moveCamera(
              center: Geographic(lon: center.longitude, lat: center.latitude),
              zoom: camera.zoom - 1,
              bearing: -camera.rotation,
            )
            .then((_) => _measure(controller, camera))
            .catchError((Object _) {}),
      );
    } on Object {
      // The native map can reject camera updates while it is being torn down.
    }
  }

  /// Checks where the native map drew [camera]'s centre and corrects the
  /// stored offset. Measurements taken before the native view has its final
  /// size are implausible and ignored; the check repeats on the next frame
  /// until the base map is aligned.
  void _measure(MapController controller, fm.MapCamera camera) {
    if (!mounted || !identical(controller, _controller)) return;
    final Offset drawn;
    try {
      drawn = controller.toScreenLocation(
        Geographic(lon: camera.center.longitude, lat: camera.center.latitude),
      );
    } on Object {
      return;
    }
    final size = camera.nonRotatedSize;
    final residual = drawn - size.center(Offset.zero);
    final plausible =
        drawn.dx.isFinite &&
        drawn.dy.isFinite &&
        size.shortestSide > 0 &&
        residual.distance < size.shortestSide / 4;
    if (!plausible) {
      // The native view is not laid out yet (or is offstage). Keep nudging
      // while the map is visible; a hidden tab retries when it is shown.
      if (_active && _layoutNudges < 60) {
        _layoutNudges++;
        _scheduleSync(force: true);
      }
      return;
    }
    if (_layoutNudges.isOdd) _layoutNudges++;
    // A few corrections per camera converge; more would only chase noise
    // and resync every frame.
    if (residual.distance > _alignedTolerance && _corrections < 3) {
      _corrections++;
      _nativeCenterOffset += residual;
      _scheduleSync(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Depending on MapCamera rebuilds this layer on every camera change,
    // including fits and programmatic moves that emit no move event.
    final camera = fm.MapCamera.of(context);
    _listenToMoves(fm.MapController.of(context));
    _latestCamera = camera;
    // Re-check alignment when the map becomes visible again (tabs keep it
    // alive offstage) or its size changes (rotation, split view).
    final active = TickerMode.valuesOf(context).enabled;
    if ((active && !_active) || camera.nonRotatedSize != _measuredSize) {
      _measuredSize = camera.nonRotatedSize;
      _layoutNudges = 0;
      _corrections = 0;
      if (_controller != null && active) _scheduleSync(force: true);
    }
    _active = active;
    if (_controller != null && !identical(camera, _syncedCamera)) {
      _scheduleSync();
    }

    return MapLibreMap(
      options: MapOptions(
        initCenter: Geographic(
          lon: camera.center.longitude,
          lat: camera.center.latitude,
        ),
        initBearing: -camera.rotation,
        initZoom: camera.zoom - 1,
        initStyle: widget.initStyle,
        maxPitch: 0,
        gestures: const MapGestures.none(),
      ),
      gestureRecognizers: const {},
      onMapCreated: (controller) {
        _controller = controller;
        _syncNow(force: true);
      },
      onStyleLoaded: (_) => _syncNow(force: true),
    );
  }
}
