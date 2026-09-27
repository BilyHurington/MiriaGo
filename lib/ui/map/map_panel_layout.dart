import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../design/theme.dart';
import '../layout/window_class.dart';

/// Resting positions of the compact bottom sheet.
enum MapPanelSnap { peek, half, full }

/// Width of the floating left panel (DESIGN §5.3).
const double kMapSidePanelWidth = 380;

/// Width of the left panel on short (landscape phone) windows.
const double kMapSidePanelShortWidth = 320;

/// Width of the right inspector.
const double kMapInspectorWidth = 360;

/// Fraction of the available height at the half snap.
const double kMapSheetHalfFraction = 0.45;

/// Fraction of the available height at the full snap.
const double kMapSheetFullFraction = 0.92;

/// Controls a [MapPanelLayout]: which snap the bottom sheet rests at (kept
/// across rebuilds and layout switches, so rotating a phone or resizing a
/// window keeps the user's choice) and the live sheet height.
class MapPanelController extends ChangeNotifier {
  MapPanelController({MapPanelSnap initialSnap = MapPanelSnap.half})
    : _snap = initialSnap;

  MapPanelSnap _snap;
  final SheetController _sheet = SheetController();
  final ValueNotifier<double> _extent = ValueNotifier(0);
  _MapPanelLayoutState? _layout;
  bool _disposed = false;

  /// The snap the sheet rests at (or will rest at once shown).
  MapPanelSnap get snap => _snap;

  /// Live visible height of the bottom sheet in logical pixels; 0 while the
  /// side-panel layout is used.
  ValueListenable<double> get sheetExtent => _extent;

  /// Whether the attached layout currently shows a side panel.
  bool get usesSidePanel => _layout?._sidePanel ?? false;

  /// Moves the sheet to [snap]. In the side-panel layout the choice is only
  /// remembered for when the bottom sheet comes back.
  Future<void> snapTo(MapPanelSnap snap, {bool animate = true}) async {
    _setSnap(snap);
    final layout = _layout;
    if (layout == null) return;
    await layout._animateToSnap(snap, animate: animate);
  }

  void _setSnap(MapPanelSnap snap) {
    if (_snap == snap || _disposed) return;
    _snap = snap;
    notifyListeners();
  }

  void _setExtent(double value) {
    if (_disposed) return;
    _extent.value = value;
  }

  @override
  void dispose() {
    _disposed = true;
    _sheet.dispose();
    _extent.dispose();
    super.dispose();
  }
}

/// Tells descendants (usually [PlanMap]) which part of the map is covered
/// by the panel so camera moves and the attribution avoid it.
class MapPanelScope extends InheritedWidget {
  const MapPanelScope({
    required this.obscured,
    required this.usesSidePanel,
    required this.controller,
    required super.child,
    super.key,
  });

  /// Map area covered by panels at rest (not following a drag in progress).
  final EdgeInsets obscured;
  final bool usesSidePanel;
  final MapPanelController controller;

  static MapPanelScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MapPanelScope>();

  @override
  bool updateShouldNotify(MapPanelScope oldWidget) =>
      obscured != oldWidget.obscured ||
      usesSidePanel != oldWidget.usesSidePanel ||
      !identical(controller, oldWidget.controller);
}

/// The "map + panel" page layout (DESIGN §5.3, §8.2).
///
/// - Compact (not `context.layout.usesSidePanel`): the [map] fills the
///   area; [panel] lives in a persistent bottom sheet with three snaps
///   (peek = [peekHeight], half ≈ 45%, full ≈ 92%). Drag the handle /
///   header, or scroll the panel's primary scroll view: at full it
///   scrolls, at the top it drags the sheet. [controls] float just above
///   the sheet and fade out when it is pulled high.
/// - Wide or short: a floating rounded panel on the left (380, or 320 when
///   short) over the map, plus an optional right [inspector] (360) that
///   slides in while non-null (on short windows it covers the left panel).
///
/// The [map] sees the covered area through [MapPanelScope] (PlanMap reads
/// it automatically), so camera helpers centre content in the free part.
///
/// [panel] should be a vertical scroll view that uses the primary scroll
/// controller (the default for `ListView`/`CustomScrollView` without a
/// controller); [panelHeader] is a fixed area above it that always drags
/// the sheet.
class MapPanelLayout extends StatefulWidget {
  const MapPanelLayout({
    required this.map,
    required this.panel,
    this.panelHeader,
    this.inspector,
    this.controls,
    this.topOverlay,
    this.peekHeight = 160,
    this.controller,
    this.mapPadding = EdgeInsets.zero,
    super.key,
  });

  final Widget map;
  final Widget panel;
  final Widget? panelHeader;

  /// Right-hand detail panel (wide layouts). Slides in when non-null.
  final Widget? inspector;

  /// Floating map buttons (e.g. [MapControls]), bottom-right of the map.
  final Widget? controls;

  /// Floating widget at the top of the map area (plan switcher chip,
  /// summary, toolbar). Stays out from under the side panel.
  final Widget? topOverlay;

  /// Visible sheet height at the peek snap, including the drag handle and
  /// [panelHeader] but excluding the bottom safe-area inset.
  final double peekHeight;
  final MapPanelController? controller;

  /// Extra map area covered by page chrome (e.g. `top` for a
  /// [topOverlay]), added to the panel insets.
  final EdgeInsets mapPadding;

  @override
  State<MapPanelLayout> createState() => _MapPanelLayoutState();
}

class _SnapHeights {
  const _SnapHeights(this.peek, this.half, this.full);

  final double peek;
  final double? half;
  final double full;

  double of(MapPanelSnap snap) => switch (snap) {
    MapPanelSnap.peek => peek,
    MapPanelSnap.half => half ?? (peek + full) / 2,
    MapPanelSnap.full => full,
  };

  List<double> get values => [peek, ?half, full];

  MapPanelSnap nearest(double offset) {
    var best = MapPanelSnap.peek;
    var bestDistance = double.infinity;
    for (final snap in MapPanelSnap.values) {
      if (snap == MapPanelSnap.half && half == null) continue;
      final distance = (of(snap) - offset).abs();
      if (distance < bestDistance) {
        best = snap;
        bestDistance = distance;
      }
    }
    return best;
  }

  @override
  bool operator ==(Object other) =>
      other is _SnapHeights &&
      other.peek == peek &&
      other.half == half &&
      other.full == full;

  @override
  int get hashCode => Object.hash(peek, half, full);
}

class _MapPanelLayoutState extends State<MapPanelLayout> {
  MapPanelController? _ownController;
  MapPanelController? _attached;
  bool _sidePanel = false;
  _SnapHeights? _heights;
  bool _resnapScheduled = false;

  MapPanelController get _controller =>
      widget.controller ?? (_ownController ??= MapPanelController());

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant MapPanelLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(_attached, _controller)) _attach();
  }

  void _attach() {
    final old = _attached;
    if (old != null) {
      old.removeListener(_onControllerChanged);
      old._sheet.removeListener(_onSheetChanged);
      if (identical(old._layout, this)) old._layout = null;
    }
    final controller = _controller;
    controller._layout = this;
    controller.addListener(_onControllerChanged);
    controller._sheet.addListener(_onSheetChanged);
    _attached = controller;
  }

  @override
  void dispose() {
    final controller = _attached;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      controller._sheet.removeListener(_onSheetChanged);
      if (identical(controller._layout, this)) controller._layout = null;
    }
    _ownController?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onSheetChanged() {
    final offset = _controller._sheet.value;
    final heights = _heights;
    if (offset == null || heights == null || _sidePanel) return;
    _controller._setExtent(offset);
    final nearest = heights.nearest(offset);
    if ((heights.of(nearest) - offset).abs() < 1) {
      _controller._setSnap(nearest);
    }
  }

  Future<void> _animateToSnap(MapPanelSnap snap, {required bool animate}) {
    final heights = _heights;
    final sheet = _controller._sheet;
    if (_sidePanel || heights == null || !sheet.hasClient || !mounted) {
      return Future.value();
    }
    final reduced = Motion.reduced(context);
    return sheet.animateTo(
      SheetOffset.absolute(heights.of(snap)),
      duration: !animate || reduced
          ? const Duration(milliseconds: 1)
          : Motion.emphasis,
      curve: Motion.emphasized,
    );
  }

  _SnapHeights _computeHeights(double height, EdgeInsets safe) {
    final full = math.max(
      0.0,
      math.min(height * kMapSheetFullFraction, height - safe.top - Space.x3),
    );
    final peek = (widget.peekHeight + safe.bottom)
        .clamp(math.min(56.0, full), full)
        .toDouble();
    double? half = height * kMapSheetHalfFraction;
    if (half < peek + 48 || half > full - 48) half = null;
    return _SnapHeights(peek, half, full);
  }

  void _scheduleResnap() {
    if (_resnapScheduled) return;
    _resnapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resnapScheduled = false;
      if (!mounted || _sidePanel) return;
      unawaited(_animateToSnap(_controller.snap, animate: false));
    });
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    _sidePanel = layout.usesSidePanel;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final safe = MediaQuery.paddingOf(context);
        if (_sidePanel) {
          if (_controller.sheetExtent.value != 0) {
            scheduleMicrotask(() {
              if (mounted && _sidePanel) _controller._setExtent(0);
            });
          }
          return _buildSide(context, size, safe, layout);
        }
        return _buildSheet(context, size, safe);
      },
    );
  }

  // -------------------------------------------------------------------------
  // Compact: bottom sheet
  // -------------------------------------------------------------------------

  Widget _buildSheet(BuildContext context, Size size, EdgeInsets safe) {
    final colors = context.colors;
    final heights = _computeHeights(size.height, safe);
    if (_heights != null && _heights != heights) _scheduleResnap();
    _heights = heights;
    final snap = _controller.snap;
    final resting = heights.of(snap);
    if (_controller._sheet.value == null) {
      // Before the sheet reports metrics, controls follow the resting height.
      scheduleMicrotask(() {
        if (mounted && _controller._sheet.value == null) {
          _controller._setExtent(resting);
        }
      });
    }
    final obscured = widget.mapPadding + EdgeInsets.only(bottom: resting);
    final fadeStart = (heights.half ?? heights.peek) + 24;
    final fadeEnd = math.max(fadeStart + 1, heights.full - 64);

    return MapPanelScope(
      obscured: obscured,
      usesSidePanel: false,
      controller: _controller,
      child: Stack(
        fit: StackFit.expand,
        children: [
          KeyedSubtree(key: const ValueKey('map-panel-map'), child: widget.map),
          if (widget.topOverlay case final overlay?)
            Positioned(
              left: Space.x3 + safe.left,
              right: Space.x3 + safe.right,
              top: Space.x2 + safe.top,
              child: overlay,
            ),
          if (widget.controls case final controls?)
            ValueListenableBuilder<double>(
              valueListenable: _controller.sheetExtent,
              child: controls,
              builder: (context, extent, child) {
                final effective = extent <= 0 ? resting : extent;
                final opacity =
                    (1 - (effective - fadeStart) / (fadeEnd - fadeStart)).clamp(
                      0.0,
                      1.0,
                    );
                final bottom = math.min(
                  effective + Space.x3,
                  size.height - safe.top - 160,
                );
                return Positioned(
                  right: Space.x3 + safe.right,
                  bottom: math.max(Space.x3, bottom),
                  child: IgnorePointer(
                    ignoring: opacity < 0.5,
                    child: Opacity(opacity: opacity, child: child),
                  ),
                );
              },
            ),
          SheetViewport(
            key: const ValueKey('map-panel-sheet'),
            child: Sheet(
              controller: _controller._sheet,
              initialOffset: SheetOffset.absolute(resting),
              snapGrid: SheetSnapGrid(
                snaps: [
                  for (final value in heights.values)
                    SheetOffset.absolute(value),
                ],
              ),
              scrollConfiguration: const SheetScrollConfiguration(),
              dragConfiguration: SheetDragConfiguration(
                deviceKinds: PointerDeviceKind.values.toSet(),
              ),
              decoration: SheetDecorationBuilder(
                size: SheetSize.fit,
                builder: (context, child) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: Radii.sheetTop,
                    boxShadow: Elevations.level3(colors),
                  ),
                  child: Material(
                    color: colors.surface,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: Radii.sheetTop,
                      side: BorderSide(color: colors.hairline),
                    ),
                    child: child,
                  ),
                ),
              ),
              child: SizedBox(
                height: heights.full,
                width: size.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DragHandle(),
                    ?widget.panelHeader,
                    Expanded(child: _SheetPrimaryScroll(child: widget.panel)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Wide / short: floating side panel + inspector
  // -------------------------------------------------------------------------

  Widget _buildSide(
    BuildContext context,
    Size size,
    EdgeInsets safe,
    WindowLayout layout,
  ) {
    const margin = Space.x3;
    final short = layout.isShort;
    final panelWidth = math.min(
      short ? kMapSidePanelShortWidth : kMapSidePanelWidth,
      size.width - safe.left - margin * 2 - 120,
    );
    final inspector = widget.inspector;
    final inspectorWidth = math.min(
      kMapInspectorWidth,
      size.width - safe.right - margin * 2,
    );
    // The inspector covers the left panel when there is no room beside it.
    final inspectorOverPanel =
        short ||
        size.width - panelWidth - inspectorWidth - margin * 4 <
            240 + safe.horizontal;
    final panelLeft = safe.left + margin;
    final panelRight = panelLeft + panelWidth;
    final top = safe.top + margin;
    final bottom = safe.bottom + margin;
    final rightCovered = inspector != null && !inspectorOverPanel
        ? inspectorWidth + margin * 2 + safe.right
        : 0.0;
    final obscured =
        widget.mapPadding +
        EdgeInsets.only(left: panelRight + margin, right: rightCovered);
    final reduced = Motion.reduced(context);

    return MapPanelScope(
      obscured: obscured,
      usesSidePanel: true,
      controller: _controller,
      child: Stack(
        fit: StackFit.expand,
        children: [
          KeyedSubtree(key: const ValueKey('map-panel-map'), child: widget.map),
          if (widget.topOverlay case final overlay?)
            Positioned(
              left: panelRight + margin,
              right: margin + safe.right + rightCovered,
              top: top,
              child: overlay,
            ),
          if (widget.controls case final controls?)
            AnimatedPositioned(
              duration: reduced ? Duration.zero : Motion.standard,
              curve: Motion.emphasized,
              right: margin + safe.right + rightCovered,
              bottom: bottom,
              child: controls,
            ),
          Positioned(
            key: const ValueKey('map-panel-side'),
            left: panelLeft,
            top: top,
            bottom: bottom,
            width: panelWidth,
            child: _FloatingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?widget.panelHeader,
                  Expanded(
                    child: PrimaryScrollController.none(child: widget.panel),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: inspectorOverPanel ? panelLeft : null,
            right: inspectorOverPanel ? null : margin + safe.right,
            top: top,
            bottom: bottom,
            width: inspectorOverPanel ? panelWidth : inspectorWidth,
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.emphasis),
              reverseDuration: Motion.of(context, Motion.standard),
              switchInCurve: Motion.emphasized,
              switchOutCurve: Motion.exit,
              transitionBuilder: (child, animation) {
                final fade = FadeTransition(opacity: animation, child: child);
                if (reduced) return fade;
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(inspectorOverPanel ? -0.08 : 0.12, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: fade,
                );
              },
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: inspector == null
                  ? const SizedBox.shrink(key: ValueKey('map-inspector-none'))
                  : KeyedSubtree(
                      key: const ValueKey('map-panel-inspector'),
                      child: _FloatingCard(
                        child: PrimaryScrollController.none(child: inspector),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Re-provides the sheet's primary scroll controller for every platform so
/// panel lists drive the sheet on desktop compact windows too (by default
/// only mobile platforms inherit the primary controller).
class _SheetPrimaryScroll extends StatelessWidget {
  const _SheetPrimaryScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = PrimaryScrollController.maybeOf(context);
    if (controller == null) return child;
    return PrimaryScrollController(
      controller: controller,
      automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
      child: child,
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: '拖动以调整面板高度',
      child: SizedBox(
        height: 20,
        child: Center(
          child: Container(
            key: const ValueKey('map-panel-handle'),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.hairlineStrong,
              borderRadius: Radii.pillAll,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.lgAll,
        boxShadow: Elevations.level2(colors),
      ),
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: BorderSide(color: colors.hairline),
        ),
        child: child,
      ),
    );
  }
}
