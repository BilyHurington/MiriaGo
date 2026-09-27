import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/theme.dart';
import '../layout/window_class.dart';
import 'plan_map.dart';

/// Round translucent ("glass") button floating over a map.
class MapControlButton extends StatelessWidget {
  const MapControlButton({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.child,
    this.selected = false,
    this.busy = false,
    this.iconColor,
    this.size = 44,
    super.key,
  }) : assert(icon != null || child != null);

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? child;
  final bool selected;

  /// Shows a small spinner instead of the icon and disables the button.
  final bool busy;
  final Color? iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = selected ? c.onPrimary : (iconColor ?? c.textPrimary);
    final content = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: selected ? c.onPrimary : c.primary,
            ),
          )
        : child ??
              Icon(icon, size: 22, fill: selected ? 1 : 0, color: foreground);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: Elevations.level2(c),
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: selected ? c.primary : c.surfaceOverlay,
                shape: CircleBorder(
                  side: BorderSide(
                    color: selected ? c.primary : c.hairline,
                    width: 1,
                  ),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: busy ? null : onPressed,
                  child: SizedBox.square(
                    dimension: size,
                    child: Center(
                      child: IconTheme.merge(
                        data: IconThemeData(color: foreground),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One switch in the map layers popover.
@immutable
class MapLayerToggle {
  const MapLayerToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.description,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final String? description;
}

/// Floating vertical stack of map buttons: layers, locate (with spinner),
/// back to the current target, and zoom +/- (only when the last input on
/// the map was a mouse or trackpad, or [showZoom] is true).
///
/// Place it with [MapPanelLayout.controls] so it floats above the bottom
/// sheet. Button keys: `map-control-layers`, `map-control-locate`,
/// `map-control-target`, `map-control-zoom-in`, `map-control-zoom-out`.
class MapControls extends StatelessWidget {
  const MapControls({
    this.mapController,
    this.onLocate,
    this.locating = false,
    this.locationError,
    this.onCurrentTarget,
    this.layerToggles,
    this.layersTitle = '图层',
    this.showZoom,
    this.leading = const [],
    this.trailing = const [],
    super.key,
  });

  /// For zoom buttons and pointer-kind detection. Defaults to the
  /// enclosing [PlanMap]'s controller when the controls are inside it.
  final PlanMapController? mapController;
  final VoidCallback? onLocate;
  final bool locating;

  /// Last location error; tints the locate button and becomes its tooltip.
  final String? locationError;
  final VoidCallback? onCurrentTarget;

  /// When set, a layers button opens [MapLayersPopover] with these toggles.
  final List<MapLayerToggle> Function(BuildContext context)? layerToggles;
  final String layersTitle;

  /// Null = automatic (pointer devices only).
  final bool? showZoom;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final controller = mapController ?? PlanMapScope.maybeOf(context);
    final c = context.colors;
    final buttons = <Widget>[
      ...leading,
      if (layerToggles != null)
        MapLayersButton(
          key: const ValueKey('map-control-layers'),
          toggles: layerToggles!,
          title: layersTitle,
        ),
      if (onLocate != null)
        MapControlButton(
          key: const ValueKey('map-control-locate'),
          tooltip: locationError ?? '定位',
          icon: Symbols.my_location_rounded,
          iconColor: locationError == null ? null : c.warning,
          busy: locating,
          onPressed: onLocate,
        ),
      if (onCurrentTarget != null)
        MapControlButton(
          key: const ValueKey('map-control-target'),
          tooltip: '当前目标',
          icon: Symbols.flag_rounded,
          onPressed: onCurrentTarget,
        ),
      if (controller != null)
        _ZoomButtons(controller: controller, showZoom: showZoom),
      ...trailing,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: Space.x2),
          buttons[i],
        ],
      ],
    );
  }
}

bool _defaultPointerPlatform() {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };
}

class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({required this.controller, required this.showZoom});

  final PlanMapController controller;
  final bool? showZoom;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PointerDeviceKind?>(
      valueListenable: controller.lastPointerKind,
      builder: (context, kind, _) {
        final visible =
            showZoom ??
            switch (kind) {
              PointerDeviceKind.mouse || PointerDeviceKind.trackpad => true,
              null => _defaultPointerPlatform(),
              _ => false,
            };
        if (!visible) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MapControlButton(
              key: const ValueKey('map-control-zoom-in'),
              tooltip: '放大',
              icon: Symbols.add_rounded,
              onPressed: () => unawaited(controller.zoomBy(1)),
            ),
            const SizedBox(height: Space.x2),
            MapControlButton(
              key: const ValueKey('map-control-zoom-out'),
              tooltip: '缩小',
              icon: Symbols.remove_rounded,
              onPressed: () => unawaited(controller.zoomBy(-1)),
            ),
          ],
        );
      },
    );
  }
}

/// A [MapControlButton] that opens [MapLayersPopover] anchored to itself
/// (bottom sheet on compact windows).
class MapLayersButton extends StatelessWidget {
  const MapLayersButton({required this.toggles, this.title = '图层', super.key});

  final List<MapLayerToggle> Function(BuildContext context) toggles;
  final String title;

  @override
  Widget build(BuildContext context) {
    return MapControlButton(
      tooltip: title,
      icon: Symbols.layers_rounded,
      onPressed: () => unawaited(
        showMapLayersPopover(context, toggles: toggles, title: title),
      ),
    );
  }
}

/// Opens the layers popover. [toggles] is called inside the popover's own
/// context, so values read from providers (e.g. `SettingsStore`) stay live;
/// values held elsewhere update optimistically when switched.
///
/// On compact windows it is a bottom sheet; otherwise a card anchored to
/// [context]'s render box.
Future<void> showMapLayersPopover(
  BuildContext context, {
  required List<MapLayerToggle> Function(BuildContext context) toggles,
  String title = '图层',
}) {
  final layout = context.layout;
  if (!layout.usesSidePanel) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Builder(
          builder: (inner) => MapLayersPopover(
            title: title,
            toggles: toggles(inner),
            framed: false,
          ),
        ),
      ),
    );
  }

  final box = context.findRenderObject() as RenderBox?;
  final overlay =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  Rect? anchor;
  if (box != null && overlay != null && box.hasSize) {
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    anchor = topLeft & box.size;
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x00000000),
    transitionDuration: Motion.of(context, Motion.standard),
    pageBuilder: (dialogContext, _, _) {
      final size = MediaQuery.sizeOf(dialogContext);
      const width = 300.0;
      final a = anchor;
      double left;
      double top;
      if (a == null) {
        left = (size.width - width) / 2;
        top = size.height / 4;
      } else if (a.center.dx > size.width / 2) {
        // Button on the right: open to its left.
        left = a.left - width - Space.x2;
        top = a.top;
      } else {
        left = a.right + Space.x2;
        top = a.top;
      }
      left = left.clamp(Space.x2, size.width - width - Space.x2).toDouble();
      top = top.clamp(Space.x2, size.height - 120).toDouble();
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Builder(
              builder: (inner) =>
                  MapLayersPopover(title: title, toggles: toggles(inner)),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Motion.emphasized),
      child: child,
    ),
  );
}

/// The layers popover content: a title and a list of switches.
class MapLayersPopover extends StatefulWidget {
  const MapLayersPopover({
    required this.toggles,
    this.title = '图层',
    this.framed = true,
    super.key,
  });

  final List<MapLayerToggle> toggles;
  final String title;

  /// Draws the floating card chrome (off inside a bottom sheet).
  final bool framed;

  @override
  State<MapLayersPopover> createState() => _MapLayersPopoverState();
}

class _MapLayersPopoverState extends State<MapLayersPopover> {
  /// Optimistic values for toggles whose source does not rebuild us.
  final Map<String, bool> _local = {};

  @override
  void didUpdateWidget(covariant MapLayersPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final toggle in widget.toggles) {
      if (_local[toggle.label] == toggle.value) _local.remove(toggle.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.x4,
            Space.x3,
            Space.x4,
            Space.x1,
          ),
          child: Text(widget.title, style: context.text.titleMedium),
        ),
        for (final toggle in widget.toggles)
          SwitchListTile(
            key: ValueKey('map-layer-toggle-${toggle.label}'),
            value: _local[toggle.label] ?? toggle.value,
            onChanged: toggle.onChanged == null
                ? null
                : (value) {
                    setState(() => _local[toggle.label] = value);
                    toggle.onChanged!(value);
                  },
            secondary: toggle.icon == null
                ? null
                : Icon(toggle.icon, color: c.textSecondary),
            title: Text(toggle.label),
            subtitle: toggle.description == null
                ? null
                : Text(toggle.description!),
          ),
        const SizedBox(height: Space.x2),
      ],
    );
    if (!widget.framed) return content;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.lgAll,
        side: BorderSide(color: c.hairline),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(boxShadow: Elevations.level3(c)),
        child: content,
      ),
    );
  }
}

/// 「‹ 重合点位 i / n ›」 pager for browsing overlapping points (old
/// `MapOverlapPointPager`, restyled). Keys: `map-overlap-point-pager`,
/// `map-overlap-previous`, `map-overlap-next`.
class MapOverlapPager extends StatelessWidget {
  const MapOverlapPager({
    required this.currentIndex,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final int currentIndex;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      key: const ValueKey('map-overlap-point-pager'),
      children: [
        IconButton(
          key: const ValueKey('map-overlap-previous'),
          tooltip: '上一个重合点位',
          onPressed: onPrevious,
          icon: const Icon(Symbols.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            '重合点位  ${currentIndex + 1} / $total',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: c.textSecondary,
              fontFeatures: MiriaFonts.tabular,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('map-overlap-next'),
          tooltip: '下一个重合点位',
          onPressed: onNext,
          icon: const Icon(Symbols.chevron_right_rounded),
        ),
      ],
    );
  }
}
