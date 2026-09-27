import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../application/capture/capture_aspect_ratio.dart';
import '../../../application/capture/capture_session.dart';
import '../../components/components.dart';
import 'camera_controls.dart';

/// Callbacks shared by both camera layouts.
@immutable
class CameraActions {
  const CameraActions({
    required this.onBack,
    required this.onPickReference,
    required this.onPickGallery,
    required this.onCapture,
    required this.onPreferPortraitUi,
    required this.onPreferLandscapeUi,
  });

  final VoidCallback onBack;
  final VoidCallback onPickReference;
  final VoidCallback onPickGallery;
  final VoidCallback onCapture;
  final VoidCallback onPreferPortraitUi;
  final VoidCallback onPreferLandscapeUi;
}

/// Landscape (primary) camera: left rail | stage | zoom rail + controls.
class CameraLandscapeLayout extends StatelessWidget {
  const CameraLandscapeLayout({
    required this.session,
    required this.device,
    required this.stage,
    required this.actions,
    this.background,
    super.key,
  });

  final CaptureSession session;
  final CameraDeviceControls device;
  final Widget stage;
  final CameraActions actions;

  /// Defaults to the darkroom colour; transparent when the preview is drawn
  /// behind the layout (CameraAwesome).
  final Color? background;

  static const leftRailWidth = 64.0;
  static const zoomRailWidth = 52.0;
  static const controlRailWidth = 100.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overlay = session.mode == CaptureReferenceMode.overlay;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: ColoredBox(
        color: background ?? c.darkroom,
        child: SafeArea(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.x2),
                child: CameraRailColumn(
                  width: leftRailWidth,
                  builder: (_) => [
                    DarkroomButton(
                      key: const ValueKey('camera-back'),
                      icon: Symbols.arrow_back_rounded,
                      tooltip: '返回',
                      onPressed: actions.onBack,
                    ),
                    CameraReferenceThumb(
                      source: session.reference,
                      onPressed: actions.onPickReference,
                    ),
                    CameraModeColumn(
                      mode: session.mode,
                      onChanged: session.setMode,
                    ),
                    DarkroomButton(
                      key: const ValueKey('camera-portrait-ui'),
                      icon: Symbols.screen_rotation_rounded,
                      tooltip: '切换竖屏 UI',
                      onPressed: actions.onPreferPortraitUi,
                    ),
                  ],
                ),
              ),
              Expanded(child: stage),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.x2),
                child: ListenableBuilder(
                  listenable: device,
                  builder: (context, _) => CameraRailColumn(
                    width: zoomRailWidth,
                    alignment: MainAxisAlignment.center,
                    builder: (height) {
                      final range = cameraZoomRangeFor(
                        device,
                        session.settings,
                      );
                      final presets = range == null
                          ? 0
                          : cameraZoomPresets(
                              minZoom: range.$1,
                              maxZoom: range.$2,
                            ).length;
                      return [
                        CameraZoomColumn(
                          device: device,
                          settings: session.settings,
                          sliderHeight: (height - presets * 34 - 36)
                              .clamp(96.0, 280.0)
                              .toDouble(),
                        ),
                      ];
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, Space.x2, Space.x1, 0),
                child: ListenableBuilder(
                  listenable: device,
                  builder: (context, _) => CameraRailColumn(
                    width: controlRailWidth,
                    builder: (height) => [
                      if (overlay)
                        CameraOpacityColumn(
                          opacity: session.overlayOpacity,
                          onChanged: session.setOverlayOpacity,
                          sliderHeight:
                              (height - 44 * 2 - 72 - 4 * Space.x2 - 60)
                                  .clamp(72.0, 220.0)
                                  .toDouble(),
                        )
                      else
                        const SizedBox(height: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CameraFlashButton(device: device),
                          const SizedBox(width: Space.x2),
                          CameraLensButton(device: device),
                        ],
                      ),
                      CameraShutterButton(
                        busy: device.shutterBusy,
                        onPressed: actions.onCapture,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.x2),
                        child: DarkroomButton(
                          key: const ValueKey('camera-gallery'),
                          icon: Symbols.photo_library_rounded,
                          tooltip: '从相册导入',
                          onPressed: actions.onPickGallery,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Portrait (simplified) camera: top bar | stage | bottom panel.
class CameraPortraitLayout extends StatelessWidget {
  const CameraPortraitLayout({
    required this.session,
    required this.device,
    required this.stage,
    required this.actions,
    this.background,
    super.key,
  });

  final CaptureSession session;
  final CameraDeviceControls device;
  final Widget stage;
  final CameraActions actions;

  /// See [CameraLandscapeLayout.background].
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: ColoredBox(
        color: background ?? c.darkroom,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                CameraTopBar(
                  title: session.point.name,
                  onBack: actions.onBack,
                  trailing: [
                    DarkroomButton(
                      key: const ValueKey('camera-reference-button'),
                      icon: Symbols.image_rounded,
                      tooltip: '参考图',
                      onPressed: actions.onPickReference,
                    ),
                    ListenableBuilder(
                      listenable: device,
                      builder: (context, _) =>
                          CameraFlashButton(device: device),
                    ),
                    DarkroomButton(
                      key: const ValueKey('camera-landscape-ui'),
                      icon: Symbols.screen_rotation_rounded,
                      tooltip: '切换横屏 UI',
                      onPressed: actions.onPreferLandscapeUi,
                    ),
                  ],
                ),
                Expanded(child: stage),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(constraints.maxHeight * 0.5, 160),
                  ),
                  child: SingleChildScrollView(
                    child: _PortraitBottomPanel(
                      session: session,
                      device: device,
                      actions: actions,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back, a one-line title and trailing buttons on the darkroom background.
class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    required this.title,
    required this.onBack,
    this.trailing = const [],
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.x3,
        Space.x2,
        Space.x3,
        Space.x2,
      ),
      child: Row(
        children: [
          DarkroomButton(
            key: const ValueKey('camera-back'),
            icon: Symbols.arrow_back_rounded,
            tooltip: '返回',
            onPressed: onBack,
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              locale: MiriaFonts.japanese,
              style: context.text.titleSmall?.copyWith(color: c.onDarkroom),
            ),
          ),
          for (final button in trailing) ...[
            const SizedBox(width: Space.x2),
            button,
          ],
        ],
      ),
    );
  }
}

class _PortraitBottomPanel extends StatelessWidget {
  const _PortraitBottomPanel({
    required this.session,
    required this.device,
    required this.actions,
  });

  final CaptureSession session;
  final CameraDeviceControls device;
  final CameraActions actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.darkroomSurface,
        border: Border(
          top: BorderSide(color: c.onDarkroom.withValues(alpha: 0.12)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.x4,
          Space.x3,
          Space.x4,
          Space.x3,
        ),
        child: ListenableBuilder(
          listenable: device,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedControl<CaptureReferenceMode>(
                semanticLabel: '参考模式',
                options: [
                  for (final mode in CaptureReferenceMode.values)
                    SegmentOption(
                      value: mode,
                      label: mode.label,
                      icon: CameraModeColumn.iconFor(mode),
                    ),
                ],
                value: session.mode,
                onChanged: session.setMode,
              ),
              const SizedBox(height: Space.x2),
              _HorizontalZoomControls(device: device, session: session),
              if (session.mode == CaptureReferenceMode.overlay)
                ValueListenableBuilder<double>(
                  valueListenable: session.overlayOpacity,
                  builder: (context, value, _) => _SliderLine(
                    icon: Symbols.opacity_rounded,
                    semanticLabel: '叠影不透明度',
                    value: value,
                    label: '${(value * 100).round()}%',
                    onChanged: session.setOverlayOpacity,
                  ),
                ),
              const SizedBox(height: Space.x2),
              Row(
                children: [
                  DarkroomButton(
                    key: const ValueKey('camera-gallery'),
                    icon: Symbols.photo_library_rounded,
                    tooltip: '从相册导入',
                    size: 52,
                    onPressed: actions.onPickGallery,
                  ),
                  const Spacer(),
                  CameraShutterButton(
                    busy: device.shutterBusy,
                    onPressed: actions.onCapture,
                  ),
                  const Spacer(),
                  CameraLensButton(device: device, size: 52),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalZoomControls extends StatelessWidget {
  const _HorizontalZoomControls({required this.device, required this.session});

  final CameraDeviceControls device;
  final CaptureSession session;

  @override
  Widget build(BuildContext context) {
    final range = cameraZoomRangeFor(device, session.settings);
    final presets = range == null
        ? const <double>[]
        : cameraZoomPresets(minZoom: range.$1, maxZoom: range.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (presets.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.x2,
            runSpacing: Space.x1,
            children: [
              for (final preset in presets)
                CameraZoomChip(
                  zoom: preset,
                  selected: (device.zoom - preset).abs() < 0.05,
                  onPressed: () => unawaited(device.setZoom(preset)),
                ),
            ],
          ),
        _SliderLine(
          icon: Symbols.zoom_in_rounded,
          semanticLabel: '变焦',
          value: range == null
              ? 0.5
              : zoomSliderValue(
                  minZoom: range.$1,
                  maxZoom: range.$2,
                  realZoom: device.zoom,
                ),
          label: formatCameraZoom(device.zoom),
          onChanged: range == null
              ? null
              : (value) => unawaited(
                  device.setZoom(
                    realZoomForSlider(
                      minZoom: range.$1,
                      maxZoom: range.$2,
                      sliderValue: value,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SliderLine extends StatelessWidget {
  const _SliderLine({
    required this.icon,
    required this.semanticLabel,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final IconData icon;
  final String semanticLabel;
  final double value;
  final String label;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, size: 20, color: c.railMuted),
        Expanded(
          child: Semantics(
            label: semanticLabel,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: c.onDarkroom,
                inactiveTrackColor: c.onDarkroom.withValues(alpha: 0.24),
                thumbColor: c.onDarkroom,
                overlayColor: c.onDarkroom.withValues(alpha: 0.12),
              ),
              child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            label,
            textAlign: TextAlign.end,
            style: context.text.labelMedium?.copyWith(
              color: c.onDarkroom,
              fontFeatures: MiriaFonts.tabular,
            ),
          ),
        ),
      ],
    );
  }
}
