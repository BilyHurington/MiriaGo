import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';

/// One switch in the map 图层 panel.
class MapLayerToggle {
  const MapLayerToggle({
    required this.id,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.description,
  });

  /// Stable id, used for the switch key (`map-layer-toggle-<id>`).
  final String id;
  final String label;
  final IconData icon;
  final bool value;
  final String? description;

  /// Applies and stores the new value; resolves to false when it could not
  /// be saved, and the switch flips back.
  final Future<bool> Function(bool value) onChanged;
}

/// Width below which the panel opens as a bottom sheet.
const mapLayersSheetBreakpoint = 600.0;

/// Opens the 图层 panel for [toggles]. [anchorContext] is the button that
/// opened it: on wide windows the panel is a card next to it, so the map
/// stays visible while switching; on phones it is a bottom sheet.
Future<void> showMapLayersPanel(
  BuildContext anchorContext, {
  required List<MapLayerToggle> toggles,
  required AppSettings settings,
  String title = '图层',
}) {
  final screenSize = MediaQuery.sizeOf(anchorContext);
  if (screenSize.width < mapLayersSheetBreakpoint) {
    return showModalBottomSheet<void>(
      context: anchorContext,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.overlaySurface,
      builder: (context) => _PanelTextScale(
        settings: settings,
        child: MapLayersPanel(title: title, toggles: toggles),
      ),
    );
  }

  final anchorBox = anchorContext.findRenderObject() as RenderBox?;
  final anchor = anchorBox == null || !anchorBox.hasSize
      ? Rect.fromLTWH(screenSize.width - 56, 96, 40, 40)
      : anchorBox.localToGlobal(Offset.zero) & anchorBox.size;
  return showGeneralDialog<void>(
    context: anchorContext,
    barrierDismissible: true,
    barrierLabel: '关闭$title',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, _, _) {
      const width = 300.0;
      const gap = 8.0;
      final size = MediaQuery.sizeOf(context);
      final padding = MediaQuery.paddingOf(context);
      // Opens towards the middle of the screen, next to the button.
      final left = anchor.center.dx > size.width / 2
          ? anchor.left - gap - width
          : anchor.right + gap;
      final top = anchor.top
          .clamp(
            padding.top + gap,
            math.max(padding.top + gap, size.height - 120),
          )
          .toDouble();
      return Stack(
        children: [
          Positioned(
            left: left.clamp(gap, math.max(gap, size.width - width - gap)),
            top: top,
            width: width,
            // Short windows and large text: the card scrolls instead of
            // running off the bottom of the screen.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(
                  120,
                  size.height - top - padding.bottom - gap,
                ),
              ),
              child: _PanelTextScale(
                settings: settings,
                child: MapLayersPanel(
                  title: title,
                  toggles: toggles,
                  framed: true,
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Routes opened from the map sit outside the app's scaled view; keep the
/// app's font size there. (AppScaledOverlayContent needs bounded
/// constraints, which a floating card of natural height does not have.)
class _PanelTextScale extends StatelessWidget {
  const _PanelTextScale({required this.settings, required this.child});

  final AppSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: appTextScalerFor(context, settings.fontScale)),
      child: child,
    );
  }
}

class MapLayersPanel extends StatefulWidget {
  const MapLayersPanel({
    required this.title,
    required this.toggles,
    this.framed = false,
    super.key,
  });

  final String title;
  final List<MapLayerToggle> toggles;

  /// A floating card (wide windows) rather than bottom sheet content.
  final bool framed;

  @override
  State<MapLayersPanel> createState() => _MapLayersPanelState();
}

class _MapLayersPanelState extends State<MapLayersPanel> {
  /// The values shown; the screen behind applies each change right away, but
  /// this route does not rebuild with it.
  late final Map<String, bool> _values = {
    for (final toggle in widget.toggles) toggle.id: toggle.value,
  };

  /// Latest change per switch: a failed save only flips the switch back
  /// when no newer change was made to it since.
  final Map<String, int> _changeSerial = {};

  /// The last value stored per switch, which a failed save goes back to.
  late final Map<String, bool> _stored = {
    for (final toggle in widget.toggles) toggle.id: toggle.value,
  };

  Future<void> _change(MapLayerToggle toggle, bool value) async {
    final serial = (_changeSerial[toggle.id] ?? 0) + 1;
    _changeSerial[toggle.id] = serial;
    setState(() => _values[toggle.id] = value);
    final saved = await toggle.onChanged(value);
    if (saved) {
      _stored[toggle.id] = value;
    }
    if (!saved && mounted && _changeSerial[toggle.id] == serial) {
      setState(() => _values[toggle.id] = _stored[toggle.id] ?? !value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      key: const ValueKey('map-layers-panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, widget.framed ? 16 : 0, 20, 4),
          child: Text(
            widget.title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        for (final toggle in widget.toggles)
          SwitchListTile(
            key: ValueKey('map-layer-toggle-${toggle.id}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            value: _values[toggle.id] ?? toggle.value,
            onChanged: (value) => _change(toggle, value),
            secondary: Icon(toggle.icon, color: AppColors.textSecondary),
            title: Text(
              toggle.label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            subtitle: toggle.description == null
                ? null
                : Text(
                    toggle.description!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      letterSpacing: 0,
                    ),
                  ),
          ),
        SizedBox(height: widget.framed ? 8 : 16),
      ],
    );
    if (!widget.framed) {
      return SingleChildScrollView(child: content);
    }
    return Material(
      color: AppColors.overlaySurface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(child: content),
    );
  }
}
