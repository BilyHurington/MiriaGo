import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../application/settings_store.dart';
import '../../map/map_location_tracker.dart';
import '../../map/map_marker_scale.dart';
import '../design/theme.dart';
import 'map_markers.dart';

/// Location state for an ordinary map page (the old
/// `MapLocationLifecycle` + `MapLocationTracker` pair).
///
/// Wrap the page in a [MapLocationBinding] so tracking only runs while the
/// page is visible and the app is in the foreground, continuous or one-shot
/// according to `settings.continuousMapLocation`. Nothing is requested
/// until [locate] is called (e.g. by the 「定位」 button); after the first
/// fix, continuous mode keeps following.
///
/// [error] carries the old app's messages:
/// 「定位更新已停止，请点击定位重试。」, 「暂未收到新的定位，当前位置可能已过期。」,
/// 「定位服务未开启，请开启后重试。」, 「定位权限不可用，请检查权限后重试。」,
/// 「定位更新失败，请检查权限和定位服务后重试。」 (plus the one-shot resolver's
/// own timeout messages).
class MapLocationController extends ChangeNotifier {
  MapLocationController({MapLocationTracker? tracker})
    : _tracker = tracker ?? MapLocationTracker(),
      _ownsTracker = tracker == null {
    _tracker.addListener(_relay);
  }

  final MapLocationTracker _tracker;
  final bool _ownsTracker;
  bool _active = false;
  bool _disposed = false;

  /// The raw geolocator fix.
  Position? get rawPosition => _tracker.position;

  LatLng? get position {
    final value = _tracker.position;
    return value == null ? null : LatLng(value.latitude, value.longitude);
  }

  /// Horizontal accuracy in metres, when known.
  double? get accuracyMeters {
    final accuracy = _tracker.position?.accuracy;
    if (accuracy == null || !accuracy.isFinite || accuracy <= 0) return null;
    return accuracy;
  }

  String? get error => _tracker.error;
  bool get isLocating => _tracker.locating;

  /// The shown position may be outdated (error or no recent update).
  bool get isStale => _tracker.error != null;

  /// Whether the page is currently allowed to use location.
  bool get isActive => _active;

  /// Called by [MapLocationBinding]; exposed for tests and custom hosts.
  void configure({required bool active, required bool continuous}) {
    _active = active;
    _tracker.configure(active: active, continuous: continuous);
  }

  /// Requests one fix (asking for permission if needed). Returns null on
  /// failure; see [error].
  Future<LatLng?> locate() async {
    final result = await _tracker.locate();
    if (result == null) return null;
    return LatLng(result.latitude, result.longitude);
  }

  /// Stops tracking and forgets the error.
  void disable() => _tracker.disable();

  void _relay() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tracker.removeListener(_relay);
    if (_ownsTracker) _tracker.dispose();
    super.dispose();
  }
}

/// Keeps a [MapLocationController] active only while this subtree is
/// visible (current route, ticking branch of the tab shell) and the app is
/// in the foreground. Continuous or one-shot tracking follows
/// `settings.continuousMapLocation` unless [continuous] is given.
///
/// [onError] fires when a new error appears while active, so the page can
/// show it as a toast (the old app showed a snack bar).
class MapLocationBinding extends StatefulWidget {
  const MapLocationBinding({
    required this.controller,
    required this.child,
    this.enabled = true,
    this.continuous,
    this.onError,
    super.key,
  });

  final MapLocationController controller;
  final bool enabled;
  final bool? continuous;
  final ValueChanged<String>? onError;
  final Widget child;

  @override
  State<MapLocationBinding> createState() => _MapLocationBindingState();
}

class _MapLocationBindingState extends State<MapLocationBinding>
    with WidgetsBindingObserver {
  bool _foreground = true;
  bool _routeVisible = true;
  bool _ticking = true;
  bool _continuous = true;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onLocationChanged);
    _lastError = widget.controller.error;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeVisible = ModalRoute.isCurrentOf(context) ?? true;
    _ticking = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(covariant MapLocationBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onLocationChanged);
      widget.controller.addListener(_onLocationChanged);
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onLocationChanged);
    widget.controller.configure(active: false, continuous: _continuous);
    super.dispose();
  }

  bool get _active =>
      widget.enabled && _routeVisible && _ticking && _foreground;

  void _sync() {
    final controller = widget.controller;
    // Lifecycle callbacks can arrive during build; configure after it.
    scheduleMicrotask(() {
      if (!mounted) return;
      controller.configure(active: _active, continuous: _continuous);
    });
  }

  void _onLocationChanged() {
    final error = widget.controller.error;
    if (error != null && error != _lastError && _active) {
      widget.onError?.call(error);
    }
    _lastError = error;
  }

  @override
  Widget build(BuildContext context) {
    final continuous =
        widget.continuous ??
        context.select<SettingsStore, bool>(
          (store) => store.settings.continuousMapLocation,
        );
    if (continuous != _continuous) {
      _continuous = continuous;
      _sync();
    }
    return widget.child;
  }
}

/// Draws the [MapLocationController]'s position on a [PlanMap] (must be one
/// of its `children`): an accuracy circle in metres plus a [LocationPuck].
class LocationPuckLayer extends StatelessWidget {
  const LocationPuckLayer({
    required this.controller,
    this.heading,
    this.showAccuracy = true,
    this.scale,
    super.key,
  });

  final MapLocationController controller;

  /// Heading in unwrapped turns (e.g. `NavigationHeading`).
  final ValueListenable<double?>? heading;
  final bool showAccuracy;

  /// Defaults to `settings.mapMarkerScale`.
  final double? scale;

  @override
  Widget build(BuildContext context) {
    final markerScale = normalizedMapMarkerScale(
      scale ??
          context.select<SettingsStore, double>(
            (store) => store.settings.mapMarkerScale,
          ),
    );
    final colors = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, ?heading]),
      builder: (context, _) {
        final position = controller.position;
        if (position == null) return const SizedBox.shrink();
        final accuracy = controller.accuracyMeters;
        final stale = controller.isStale;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (showAccuracy && accuracy != null && !stale)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: position,
                    radius: accuracy,
                    useRadiusInMeter: true,
                    color: colors.info.withValues(alpha: 0.10),
                    borderColor: colors.info.withValues(alpha: 0.35),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                LocationPuck.marker(
                  key: const ValueKey('map-location-puck'),
                  point: position,
                  scale: markerScale,
                  child: LocationPuck(
                    stale: stale,
                    headingTurns: heading?.value,
                    tooltip: controller.error ?? '当前位置',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
