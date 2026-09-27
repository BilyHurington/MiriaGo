import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../application/settings_store.dart';
import '../../map/map_tile_config.dart';
import '../../plan/pilgrimage_models.dart';
import '../design/theme.dart';
import 'map_panel_layout.dart';
import 'web_map_resize_stub.dart'
    if (dart.library.js_interop) 'web_map_resize_web.dart';

/// Fallback map centre when nothing else is known (Kyoto, as in the old app).
const LatLng kDefaultMapCenter = LatLng(34.9671, 135.7727);

/// Default zoom for plan maps (old app: 15).
const double kDefaultMapZoom = 15;

/// Minimum zoom for every plan map (old app: 4).
const double kMapMinZoom = 4;

const Epsg3857 _crs = Epsg3857();

/// Imperative handle for a [PlanMap].
///
/// Wraps flutter_map's [MapController] (available as [mapController] for
/// anything this class does not cover) and adds helpers that understand the
/// part of the map covered by floating UI ([obscuredInsets]): centring a
/// point in the visible area, fitting bounds with padding and animated
/// moves that respect "reduce motion".
class PlanMapController {
  PlanMapController({MapController? mapController})
    : mapController = mapController ?? MapController(),
      _ownsMapController = mapController == null;

  /// The underlying flutter_map controller.
  final MapController mapController;
  final bool _ownsMapController;

  _PlanMapState? _map;

  /// Kind of the most recent pointer that touched or hovered the map. Used
  /// by [MapControls] to show zoom buttons only for mouse / trackpad input.
  final ValueNotifier<PointerDeviceKind?> lastPointerKind = ValueNotifier(null);

  /// Whether a [PlanMap] using this controller is mounted and ready.
  bool get isReady => _map?._ready ?? false;

  /// The current camera, or `null` before the map is ready.
  MapCamera? get camera => isReady ? mapController.camera : null;

  /// Insets of the map covered by floating UI (bottom sheet, side panel,
  /// inspector). Zero when no map is attached.
  EdgeInsets get obscuredInsets => _map?._obscured ?? EdgeInsets.zero;

  /// The coordinate at the centre of the unobscured area.
  LatLng? get visibleCenter {
    final camera = this.camera;
    if (camera == null) return null;
    return camera.screenOffsetToLatLng(
      visibleRect(camera.nonRotatedSize).center,
    );
  }

  /// The screen rectangle of the map not covered by floating UI.
  Rect visibleRect(Size mapSize) {
    final insets = obscuredInsets;
    final rect = Rect.fromLTRB(
      insets.left,
      insets.top,
      mapSize.width - insets.right,
      mapSize.height - insets.bottom,
    );
    if (rect.width <= 0 || rect.height <= 0) return Offset.zero & mapSize;
    return rect;
  }

  /// Moves so that [point] is at the centre of the unobscured area.
  ///
  /// Animated unless [animate] is false or the platform asks for reduced
  /// motion. Returns when the move finished (or was interrupted by a
  /// gesture).
  Future<void> moveTo(
    LatLng point, {
    double? zoom,
    bool animate = true,
    bool centerInVisibleArea = true,
  }) async {
    final camera = this.camera;
    if (camera == null) return;
    final targetZoom = _clampZoom(camera, zoom ?? camera.zoom);
    final center = centerInVisibleArea
        ? centerForVisiblePoint(
            point,
            zoom: targetZoom,
            obscured: obscuredInsets,
            rotationRad: camera.rotationRad,
          )
        : point;
    await _animateCamera(center, targetZoom, animate: animate);
  }

  /// Fits [points] into the unobscured area plus [padding].
  Future<void> fitPoints(
    Iterable<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(48),
    double maxZoom = 17,
    bool animate = true,
  }) async {
    final list = points.toList(growable: false);
    final camera = this.camera;
    if (camera == null || list.isEmpty) return;
    if (list.length == 1) {
      await moveTo(
        list.single,
        zoom: math.max(camera.zoom, math.min(maxZoom, kDefaultMapZoom)),
        animate: animate,
      );
      return;
    }
    await fitBounds(
      LatLngBounds.fromPoints(list),
      padding: padding,
      maxZoom: maxZoom,
      animate: animate,
    );
  }

  /// Fits [bounds] into the unobscured area plus [padding].
  Future<void> fitBounds(
    LatLngBounds bounds, {
    EdgeInsets padding = const EdgeInsets.all(48),
    double maxZoom = 17,
    bool animate = true,
  }) async {
    final camera = this.camera;
    if (camera == null) return;
    final target = CameraFit.bounds(
      bounds: bounds,
      padding: padding + obscuredInsets,
      maxZoom: math.min(maxZoom, camera.maxZoom ?? maxZoom),
    ).fit(camera);
    await _animateCamera(target.center, target.zoom, animate: animate);
  }

  /// Zooms in or out by [delta] around the centre of the unobscured area.
  Future<void> zoomBy(double delta, {bool animate = true}) async {
    final camera = this.camera;
    if (camera == null) return;
    final anchor = visibleCenter ?? camera.center;
    await moveTo(anchor, zoom: camera.zoom + delta, animate: animate);
  }

  Future<void> _animateCamera(
    LatLng center,
    double zoom, {
    required bool animate,
  }) async {
    final map = _map;
    if (map == null || !map._ready) return;
    await map._animateTo(center, zoom, animate: animate);
  }

  double _clampZoom(MapCamera camera, double zoom) {
    final min = camera.minZoom ?? kMapMinZoom;
    final max = camera.maxZoom ?? 22;
    return zoom.clamp(min, max).toDouble();
  }

  void _attach(_PlanMapState map) => _map = map;

  void _detach(_PlanMapState map) {
    if (identical(_map, map)) _map = null;
  }

  void dispose() {
    lastPointerKind.dispose();
    if (_ownsMapController) mapController.dispose();
  }
}

/// Returns the map centre that places [point] at the centre of the area not
/// covered by [obscured], at [zoom].
@visibleForTesting
LatLng centerForVisiblePoint(
  LatLng point, {
  required double zoom,
  required EdgeInsets obscured,
  double rotationRad = 0,
}) {
  if (obscured == EdgeInsets.zero) return point;
  var delta = Offset(
    (obscured.left - obscured.right) / 2,
    (obscured.top - obscured.bottom) / 2,
  );
  if (rotationRad != 0) {
    final cos = math.cos(-rotationRad);
    final sin = math.sin(-rotationRad);
    delta = Offset(
      delta.dx * cos - delta.dy * sin,
      delta.dx * sin + delta.dy * cos,
    );
  }
  final projected = _crs.latLngToOffset(point, zoom);
  final center = _crs.offsetToLatLng(projected - delta, zoom);
  return LatLng(
    center.latitude.clamp(-85.0, 85.0).toDouble(),
    center.longitude,
  );
}

/// Gives descendants (marker layers, controls) access to the enclosing
/// [PlanMap]'s controller.
class PlanMapScope extends InheritedWidget {
  const PlanMapScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final PlanMapController controller;

  static PlanMapController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlanMapScope>()?.controller;

  @override
  bool updateShouldNotify(PlanMapScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}

/// The one map widget used by every map page.
///
/// - Tile layer from the user's map settings (OpenFreeMap / MapLibre /
///   raster / custom), dark style when the app is dark or the map
///   appearance setting asks for it.
/// - Zoom limits [minZoom] (4) … `settings.mapMaxZoom`; rotation disabled
///   unless [allowRotation].
/// - Attribution kept clear of floating UI via [obscuredInsets] (read from
///   an enclosing [MapPanelLayout] when not given).
/// - [layers] are drawn above the tiles (polygons, circles, routes);
///   [children] above them (markers, box selection …).
///
/// Use [disableTiles] / [tileLayerOverride] in widget tests to avoid
/// network access.
class PlanMap extends StatefulWidget {
  const PlanMap({
    this.controller,
    this.initialCenter,
    this.initialZoom = kDefaultMapZoom,
    this.initialFitPoints,
    this.initialFitPadding = const EdgeInsets.all(48),
    this.initialFitMaxZoom = 17,
    this.minZoom = kMapMinZoom,
    this.maxZoom,
    this.allowRotation = false,
    this.interactive = true,
    this.layers = const [],
    this.children = const [],
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onMapEvent,
    this.onMapReady,
    this.obscuredInsets,
    this.attributionPadding = EdgeInsets.zero,
    this.attributionAlignment = AttributionAlignment.bottomLeft,
    this.showAttribution = true,
    this.settings,
    this.tileLayerOverride,
    this.disableTiles = false,
    super.key,
  });

  final PlanMapController? controller;

  /// Initial centre of the *visible* area. Defaults to [kDefaultMapCenter].
  final LatLng? initialCenter;
  final double initialZoom;

  /// When non-empty, the initial camera fits these coordinates instead of
  /// using [initialCenter]/[initialZoom].
  final List<LatLng>? initialFitPoints;
  final EdgeInsets initialFitPadding;
  final double initialFitMaxZoom;

  final double minZoom;

  /// Defaults to `settings.mapMaxZoom`.
  final double? maxZoom;
  final bool allowRotation;

  /// False disables every gesture (static preview maps).
  final bool interactive;

  /// Layers between the tiles and [children] (polygons, circles, routes).
  final List<Widget> layers;

  /// Layers on top (markers, box selection, location puck).
  final List<Widget> children;

  final ValueChanged<LatLng>? onTap;
  final ValueChanged<LatLng>? onLongPress;

  /// Right click / secondary tap; defaults to [onLongPress].
  final ValueChanged<LatLng>? onSecondaryTap;
  final void Function(MapEvent event)? onMapEvent;
  final VoidCallback? onMapReady;

  /// Area covered by floating UI. When null, the resting insets of an
  /// enclosing [MapPanelLayout] are used.
  final EdgeInsets? obscuredInsets;

  /// Extra padding for the attribution on top of [obscuredInsets].
  final EdgeInsets attributionPadding;
  final AttributionAlignment attributionAlignment;
  final bool showAttribution;

  /// Settings override; defaults to the provided [SettingsStore].
  final AppSettings? settings;

  /// Replaces the configured tile layer (tests, previews).
  final Widget? tileLayerOverride;

  /// Renders no base map at all (tests).
  final bool disableTiles;

  /// Global test switch: when true every [PlanMap] renders without tiles,
  /// so router-built pages never hit the network in widget tests.
  static bool debugDisableTiles = false;

  @override
  State<PlanMap> createState() => _PlanMapState();
}

class _PlanMapState extends State<PlanMap> with SingleTickerProviderStateMixin {
  late PlanMapController _controller;
  bool _ownsController = false;
  bool _ready = false;
  EdgeInsets _obscured = EdgeInsets.zero;
  AnimationController? _animationController;
  AnimationController get _animation =>
      _animationController ??= AnimationController(vsync: this);
  StreamSubscription<MapEvent>? _events;
  Completer<void>? _animationDone;
  VoidCallback? _tick;
  CurvedAnimation? _curve;
  static const _animationId = 'plan-map-animated-move';

  @override
  void initState() {
    super.initState();
    _bindController();
    _scheduleWebResizeNudge();
  }

  Size? _lastWebSize;

  /// See [nudgeWebMapResize]: re-measure the MapLibre element once it has
  /// been attached and whenever the map's size changes.
  void _scheduleWebResizeNudge() {
    if (!kIsWeb) return;
    for (final delay in const [100, 400, 1200]) {
      Future<void>.delayed(Duration(milliseconds: delay), () {
        if (mounted) nudgeWebMapResize();
      });
    }
  }

  void _checkWebSize(Size size) {
    if (!kIsWeb || size == _lastWebSize) return;
    final first = _lastWebSize == null;
    _lastWebSize = size;
    if (!first) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) nudgeWebMapResize();
      });
    }
  }

  void _bindController() {
    final external = widget.controller;
    if (external != null) {
      _controller = external;
      _ownsController = false;
    } else {
      _controller = PlanMapController();
      _ownsController = true;
    }
    _controller._attach(this);
    _events?.cancel();
    _events = _controller.mapController.mapEventStream.listen(_onMapEvent);
  }

  @override
  void didUpdateWidget(covariant PlanMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _stopAnimation();
      _controller._detach(this);
      if (_ownsController) _controller.dispose();
      _ready = false;
      _bindController();
    }
  }

  @override
  void dispose() {
    _stopAnimation();
    _events?.cancel();
    _animationController?.dispose();
    _controller._detach(this);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (event.source == MapEventSource.nonRotatedSizeChange) {
      _checkWebSize(event.camera.nonRotatedSize);
    }
    // A user gesture interrupts a programmatic animation.
    if ((_animationController?.isAnimating ?? false) &&
        event.source != MapEventSource.mapController &&
        event.source != MapEventSource.nonRotatedSizeChange) {
      _stopAnimation();
    }
  }

  void _stopAnimation() {
    final animation = _animationController;
    if (animation != null && animation.isAnimating) animation.stop();
    _detachTick();
    final done = _animationDone;
    _animationDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  void _detachTick() {
    final tick = _tick;
    if (tick != null) _animationController?.removeListener(tick);
    _tick = null;
    _curve?.dispose();
    _curve = null;
  }

  Future<void> _animateTo(LatLng center, double zoom, {required bool animate}) {
    _stopAnimation();
    final mapController = _controller.mapController;
    final reduced = !mounted || Motion.reduced(context);
    if (!animate || reduced) {
      mapController.move(center, zoom, id: _animationId);
      return Future.value();
    }
    final start = mapController.camera;
    final startCenter = start.center;
    final startZoom = start.zoom;
    final distance =
        (start.projectAtZoom(center) - start.projectAtZoom(startCenter))
            .distance;
    if (distance < 0.5 && (zoom - startZoom).abs() < 0.001) {
      return Future.value();
    }
    // Longer hops take a little longer, capped so it never drags.
    final millis =
        (Motion.emphasis.inMilliseconds +
                math.min(250, distance / 8) +
                (zoom - startZoom).abs() * 40)
            .clamp(Motion.emphasis.inMilliseconds, 650)
            .round();
    final curve = _curve = CurvedAnimation(
      parent: _animation,
      curve: Motion.emphasized,
    );
    void tick() {
      final t = curve.value;
      mapController.move(
        LatLng(
          startCenter.latitude + (center.latitude - startCenter.latitude) * t,
          startCenter.longitude +
              (center.longitude - startCenter.longitude) * t,
        ),
        startZoom + (zoom - startZoom) * t,
        id: _animationId,
      );
    }

    final done = _animationDone = Completer<void>();
    _tick = tick;
    _animation
      ..duration = Duration(milliseconds: millis)
      ..addListener(tick);
    _animation.forward(from: 0).whenCompleteOrCancel(() {
      if (identical(_tick, tick)) _detachTick();
      if (!done.isCompleted) done.complete();
      if (identical(_animationDone, done)) _animationDone = null;
    });
    return done.future;
  }

  void _recordPointer(PointerEvent event) {
    if (_controller.lastPointerKind.value != event.kind) {
      _controller.lastPointerKind.value = event.kind;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        widget.settings ??
        context.select<SettingsStore, AppSettings>((store) => store.settings);
    final colors = context.colors;
    final dark = colors.isDark;
    _obscured =
        widget.obscuredInsets ??
        MapPanelScope.maybeOf(context)?.obscured ??
        EdgeInsets.zero;
    final maxZoom = math.max(
      widget.minZoom,
      widget.maxZoom ?? settings.mapMaxZoom.toDouble(),
    );
    final initialZoom = widget.initialZoom
        .clamp(widget.minZoom, maxZoom)
        .toDouble();
    final initialCenter = centerForVisiblePoint(
      widget.initialCenter ?? kDefaultMapCenter,
      zoom: initialZoom,
      obscured: _obscured,
    );
    final fitPoints = widget.initialFitPoints;
    final CameraFit? initialFit = fitPoints == null || fitPoints.length < 2
        ? null
        : CameraFit.coordinates(
            coordinates: fitPoints,
            padding: widget.initialFitPadding + _obscured,
            maxZoom: math.min(widget.initialFitMaxZoom, maxZoom),
          );
    final singleFit = fitPoints != null && fitPoints.length == 1
        ? centerForVisiblePoint(
            fitPoints.single,
            zoom: initialZoom,
            obscured: _obscured,
          )
        : null;

    final flags = !widget.interactive
        ? InteractiveFlag.none
        : widget.allowRotation
        ? InteractiveFlag.all
        : InteractiveFlag.all & ~InteractiveFlag.rotate;

    final Widget? tiles = widget.disableTiles || PlanMap.debugDisableTiles
        ? null
        : widget.tileLayerOverride ??
              configuredMapTileLayer(settings, dark: dark);

    final onLongPress = widget.onLongPress;
    final onSecondary = widget.onSecondaryTap ?? onLongPress;

    return PlanMapScope(
      controller: _controller,
      child: Listener(
        onPointerDown: _recordPointer,
        onPointerHover: _recordPointer,
        onPointerPanZoomStart: _recordPointer,
        child: FlutterMap(
          mapController: _controller.mapController,
          options: MapOptions(
            initialCenter: singleFit ?? initialCenter,
            initialZoom: initialZoom,
            initialCameraFit: initialFit,
            minZoom: widget.minZoom,
            maxZoom: maxZoom,
            keepAlive: true,
            // Transparent on web: CanvasKit may composite this fill above the
            // MapLibre platform view, hiding the base map.
            backgroundColor: kIsWeb && tiles != null
                ? Colors.transparent
                : dark
                ? colors.canvas
                : colors.surfaceMuted,
            interactionOptions: InteractionOptions(flags: flags),
            onTap: widget.onTap == null
                ? null
                : (_, point) => widget.onTap!(point),
            onLongPress: onLongPress == null
                ? null
                : (_, point) => onLongPress(point),
            onSecondaryTap: onSecondary == null
                ? null
                : (_, point) => onSecondary(point),
            onMapEvent: widget.onMapEvent,
            onMapReady: () {
              _ready = true;
              widget.onMapReady?.call();
            },
          ),
          children: [
            ?tiles,
            ...widget.layers,
            ...widget.children,
            if (widget.showAttribution)
              _MapAttribution(
                settings: settings,
                insets: _obscured + widget.attributionPadding,
                alignment: widget.attributionAlignment,
              ),
          ],
        ),
      ),
    );
  }
}

/// Themed copy of [configuredMapAttribution], padded clear of floating UI
/// and hidden when the visible map area is too small to hold it.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution({
    required this.settings,
    required this.insets,
    required this.alignment,
  });

  final AppSettings settings;
  final EdgeInsets insets;
  final AttributionAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final base = configuredMapAttribution(settings);
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleHeight = constraints.maxHeight - insets.vertical;
        final visibleWidth = constraints.maxWidth - insets.horizontal;
        if (visibleHeight < 96 || visibleWidth < 160) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: insets,
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: insets.left > 0,
            removeTop: insets.top > 0,
            removeRight: insets.right > 0,
            removeBottom: insets.bottom > 0,
            child: RichAttributionWidget(
              key: const ValueKey('plan-map-attribution'),
              attributions: base.attributions,
              alignment: alignment,
              showFlutterMapAttribution: base.showFlutterMapAttribution,
              popupBackgroundColor: colors.surface,
              popupBorderRadius: Radii.mdAll,
              permanentHeight: 20,
              openButton: (context, open) => _AttributionButton(
                icon: Symbols.info_rounded,
                tooltip: '地图数据署名',
                onPressed: open,
              ),
              closeButton: (context, close) => _AttributionButton(
                icon: Symbols.close_rounded,
                tooltip: '关闭',
                onPressed: close,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AttributionButton extends StatelessWidget {
  const _AttributionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: colors.textSecondary,
        backgroundColor: colors.surfaceOverlay,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}
