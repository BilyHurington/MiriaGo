import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:maplibre/maplibre.dart';

/// Embeds a MapLibre base map as a [fm.FlutterMap] layer and keeps its camera
/// in sync with the surrounding flutter_map camera.
///
/// flutter_map_maplibre's `MapLibreLayer` only forwards `MapEventWithMove`
/// events and reads the camera once when the native map is created. A camera
/// changed by `initialCameraFit`, or moved before the native map reports
/// `onMapCreated`, was never forwarded, so the base map stayed at flutter_map's
/// default centre (Kyiv) while overlays were drawn at the fitted camera.
class SyncedMapLibreLayer extends StatefulWidget {
  const SyncedMapLibreLayer({required this.initStyle, super.key});

  final String initStyle;

  @override
  State<SyncedMapLibreLayer> createState() => _SyncedMapLibreLayerState();
}

class _SyncedMapLibreLayerState extends State<SyncedMapLibreLayer> {
  MapController? _controller;
  StreamSubscription<fm.MapEvent>? _eventSubscription;
  fm.MapController? _flutterMapController;
  fm.MapCamera? _latestCamera;
  fm.MapCamera? _syncedCamera;
  var _syncScheduled = false;

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

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _syncNow();
    });
  }

  void _syncNow({bool force = false}) {
    final controller = _controller;
    final camera = _latestCamera;
    if (controller == null || camera == null) return;
    if (!force && identical(camera, _syncedCamera)) return;
    _syncedCamera = camera;
    try {
      unawaited(
        controller
            .moveCamera(
              center: Geographic(
                lon: camera.center.longitude,
                lat: camera.center.latitude,
              ),
              zoom: camera.zoom - 1,
              bearing: -camera.rotation,
            )
            .catchError((Object _) {}),
      );
    } on Object {
      // The native map can reject camera updates while it is being torn down.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Depending on MapCamera rebuilds this layer on every camera change,
    // including fits and programmatic moves that emit no move event.
    final camera = fm.MapCamera.of(context);
    _listenToMoves(fm.MapController.of(context));
    _latestCamera = camera;
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
