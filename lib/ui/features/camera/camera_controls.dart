import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../application/capture/capture_aspect_ratio.dart';
import '../../../application/capture/capture_session.dart';
import '../../../camera_reference/native_camera_controller.dart';
import '../../../data/bounded_image_decoder.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../widgets/bounded_image.dart';
import '../../components/components.dart';

/// What the camera rails need from a live camera, so the native preview and
/// the CameraAwesome fallback share one set of controls.
abstract class CameraDeviceControls implements Listenable {
  /// 'auto' | 'on' | 'torch' | 'off'.
  String get flashMode;
  Future<void> cycleFlash();

  /// Shows the T badge on the lens button.
  bool get telephoto;
  String get lensTooltip;
  Future<void> switchLens();

  /// Real zoom ratios; [hasZoomRange] is false until the device reported.
  bool get hasZoomRange;
  double get deviceMinZoom;
  double get deviceMaxZoom;
  double get zoom;
  Future<void> setZoom(double realZoom);

  /// The shutter looks busy and ignores taps.
  bool get shutterBusy;
}

/// [CameraDeviceControls] for the native CameraX / AVFoundation preview.
class NativeCameraDeviceControls implements CameraDeviceControls {
  NativeCameraDeviceControls(this.controller);

  final NativeCameraController controller;

  @override
  void addListener(VoidCallback listener) => controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      controller.removeListener(listener);

  @override
  String get flashMode => controller.flashMode;

  @override
  Future<void> cycleFlash() => controller.cycleFlashMode();

  @override
  bool get telephoto => controller.lensMode == 'backTelephoto';

  @override
  String get lensTooltip => '切换镜头';

  @override
  Future<void> switchLens() => controller.switchLens();

  @override
  bool get hasZoomRange => true;

  @override
  double get deviceMinZoom => controller.minZoomRatio;

  @override
  double get deviceMaxZoom => controller.maxZoomRatio;

  @override
  double get zoom => controller.zoomRatio;

  @override
  Future<void> setZoom(double realZoom) => controller.setZoomRatio(realZoom);

  @override
  bool get shutterBusy => controller.shutterBusy;
}

/// Colours of the always-dark camera chrome.
extension DarkroomColors on MiriaColors {
  Color get railButton => darkroomSurface.withValues(alpha: 0.92);
  Color get railText => onDarkroom;
  Color get railMuted => onDarkroom.withValues(alpha: 0.64);
}

/// Round camera button (44 px by default) with an optional corner badge.
class DarkroomButton extends StatelessWidget {
  const DarkroomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.iconSize,
    this.badge,
    this.selected = false,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double? iconSize;
  final String? badge;
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.darkroom : c.onDarkroom;
    final bg = selected ? c.onDarkroom : c.railButton;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: MiriaPressable(
            onTap: onPressed,
            enabled: onPressed != null,
            selected: selected,
            borderRadius: Radii.pillAll,
            semanticLabel: semanticLabel ?? tooltip,
            excludeSemantics: true,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: iconSize ?? size * 0.5,
                  color: onPressed == null ? fg.withValues(alpha: 0.4) : fg,
                ),
                if (badge != null)
                  Positioned(
                    right: size * 0.14,
                    bottom: size * 0.12,
                    child: Text(
                      badge!,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: fg,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1,
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

/// Flash cycles auto → on → torch → off; the auto state shows an A badge.
class CameraFlashButton extends StatelessWidget {
  const CameraFlashButton({required this.device, this.size = 44, super.key});

  final CameraDeviceControls device;
  final double size;

  static String labelFor(String mode) => switch (mode) {
    'off' => '闪光灯：关闭',
    'on' => '闪光灯：开启',
    'torch' => '闪光灯：常亮',
    _ => '闪光灯：自动',
  };

  @override
  Widget build(BuildContext context) {
    final mode = device.flashMode;
    final icon = switch (mode) {
      'off' => Symbols.flash_off_rounded,
      'torch' => Symbols.flashlight_on_rounded,
      _ => Symbols.flash_on_rounded,
    };
    return DarkroomButton(
      key: const ValueKey('camera-flash'),
      icon: icon,
      tooltip: labelFor(mode),
      badge: mode == 'auto' ? 'A' : null,
      size: size,
      onPressed: () => unawaited(device.cycleFlash()),
    );
  }
}

/// Lens switch; telephoto shows a T badge.
class CameraLensButton extends StatelessWidget {
  const CameraLensButton({required this.device, this.size = 44, super.key});

  final CameraDeviceControls device;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DarkroomButton(
      key: const ValueKey('camera-lens'),
      icon: device.telephoto
          ? Symbols.center_focus_strong_rounded
          : Symbols.cameraswitch_rounded,
      tooltip: device.lensTooltip,
      badge: device.telephoto ? 'T' : null,
      size: size,
      onPressed: () => unawaited(device.switchLens()),
    );
  }
}

/// The shutter. Busy from the tap until the confirmation page closes.
class CameraShutterButton extends StatelessWidget {
  const CameraShutterButton({
    required this.busy,
    required this.onPressed,
    this.size = 72,
    super.key,
  });

  final bool busy;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = !busy && onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '拍摄',
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.onDarkroom.withValues(alpha: 0.24),
            border: Border.all(color: c.onDarkroom, width: size >= 64 ? 4 : 3),
          ),
          child: MiriaPressable(
            key: const ValueKey('camera-shutter'),
            onTap: enabled ? onPressed : null,
            enabled: enabled,
            borderRadius: Radii.pillAll,
            excludeSemantics: true,
            child: Center(
              child: busy
                  ? ProgressRing(
                      size: size * 0.34,
                      strokeWidth: 2.5,
                      color: c.onDarkroom,
                      trackColor: c.onDarkroom.withValues(alpha: 0.2),
                    )
                  : Container(
                      width: size * 0.72,
                      height: size * 0.72,
                      decoration: BoxDecoration(
                        color: c.onDarkroom,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 叠影 / 上下 as a vertical pair (landscape left rail).
class CameraModeColumn extends StatelessWidget {
  const CameraModeColumn({
    required this.mode,
    required this.onChanged,
    this.buttonSize = 44,
    super.key,
  });

  final CaptureReferenceMode mode;
  final ValueChanged<CaptureReferenceMode> onChanged;
  final double buttonSize;

  static IconData iconFor(CaptureReferenceMode mode) => switch (mode) {
    CaptureReferenceMode.overlay => Symbols.layers_rounded,
    CaptureReferenceMode.split => Symbols.splitscreen_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in CaptureReferenceMode.values) ...[
          if (option != CaptureReferenceMode.values.first)
            const SizedBox(height: Space.x2),
          DarkroomButton(
            key: ValueKey('camera-mode-${option.name}'),
            icon: iconFor(option),
            tooltip: option.label,
            selected: option == mode,
            size: buttonSize,
            onPressed: () => onChanged(option),
          ),
          const SizedBox(height: 2),
          Text(
            option.label,
            style: context.text.labelSmall?.copyWith(
              color: option == mode ? c.railText : c.railMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Reference image (session bytes → cached full image → remote URL), with
/// the reference scale and the budget error text.
class CameraReferenceImage extends StatelessWidget {
  const CameraReferenceImage({
    required this.source,
    this.fit = BoxFit.contain,
    this.scale = 1,
    this.target = ImageDecodeTarget.preview,
    super.key,
  });

  final CaptureReferenceSource source;
  final BoxFit fit;
  final double scale;
  final ImageDecodeTarget target;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bytes = source.bytes;
    final ImageProvider provider;
    if (bytes != null) {
      provider = BoundedImageProvider(bytes: bytes, target: target);
    } else if (source.localPath != null) {
      provider = BoundedImageProvider(path: source.localPath, target: target);
    } else if (source.displayUrl != null) {
      provider = BoundedImageProvider(
        path: source.displayUrl,
        source: source.imageSource,
        target: target,
      );
    } else {
      return const SizedBox.shrink();
    }
    final image = Image(
      image: provider,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (context, error, _) {
        final message = error is ImageBudgetException
            ? error.message
            : '图片暂不可用';
        return Center(
          child: Tooltip(
            message: message,
            child: Padding(
              padding: const EdgeInsets.all(Space.x2),
              child: target.maxEdge <= 512
                  ? Icon(
                      Symbols.broken_image_rounded,
                      color: c.railMuted,
                      size: 20,
                    )
                  : Text(
                      message,
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(
                        color: c.railMuted,
                      ),
                    ),
            ),
          ),
        );
      },
    );
    final safeScale = scale.clamp(0.8, 1.0);
    if (safeScale >= 0.999) return image;
    return FractionallySizedBox(
      widthFactor: safeScale,
      heightFactor: safeScale,
      alignment: Alignment.center,
      child: image,
    );
  }
}

/// Small reference preview; tapping picks another reference for this
/// session.
class CameraReferenceThumb extends StatelessWidget {
  const CameraReferenceThumb({
    required this.source,
    required this.onPressed,
    this.size = 52,
    super.key,
  });

  final CaptureReferenceSource source;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: '参考图',
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.railButton,
            borderRadius: Radii.smAll,
            border: Border.all(color: c.onDarkroom.withValues(alpha: 0.28)),
          ),
          child: ClipRRect(
            borderRadius: Radii.smAll,
            child: MiriaPressable(
              key: const ValueKey('camera-reference-thumb'),
              onTap: onPressed,
              borderRadius: Radii.smAll,
              semanticLabel: '参考图',
              excludeSemantics: true,
              child: source.hasImage
                  ? CameraReferenceImage(
                      source: source,
                      fit: BoxFit.cover,
                      target: ImageDecodeTarget.list,
                    )
                  : Icon(Symbols.image_rounded, color: c.onDarkroom),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical zoom control: quick stops from the usable range (Δ11) plus the
/// log slider with 1× at the midpoint.
class CameraZoomColumn extends StatelessWidget {
  const CameraZoomColumn({
    required this.device,
    required this.settings,
    required this.sliderHeight,
    this.showPresets = true,
    super.key,
  });

  final CameraDeviceControls device;
  final AppSettings settings;
  final double sliderHeight;
  final bool showPresets;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final range = cameraZoomRangeFor(device, settings);
    final presets = showPresets && range != null
        ? cameraZoomPresets(minZoom: range.$1, maxZoom: range.$2)
        : const <double>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final preset in presets.reversed) ...[
          CameraZoomChip(
            zoom: preset,
            selected: (device.zoom - preset).abs() < 0.05,
            onPressed: () => unawaited(device.setZoom(preset)),
          ),
          const SizedBox(height: Space.x1),
        ],
        if (presets.isNotEmpty) const SizedBox(height: Space.x1),
        MiriaVerticalSlider(
          key: const ValueKey('camera-zoom-slider'),
          value: range == null
              ? 0.5
              : zoomSliderValue(
                  minZoom: range.$1,
                  maxZoom: range.$2,
                  realZoom: device.zoom,
                ),
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
          height: sliderHeight,
          width: 40,
          semanticLabel: '变焦',
          format: (value) => range == null
              ? formatCameraZoom(device.zoom)
              : formatCameraZoom(
                  realZoomForSlider(
                    minZoom: range.$1,
                    maxZoom: range.$2,
                    sliderValue: value,
                  ),
                ),
        ),
        const SizedBox(height: Space.x1),
        Text(
          formatCameraZoom(device.zoom),
          style: context.text.labelSmall?.copyWith(
            color: c.railText,
            fontFeatures: MiriaFonts.tabular,
          ),
        ),
      ],
    );
  }
}

/// Usable zoom range, or null before the device reported one.
(double, double)? cameraZoomRangeFor(
  CameraDeviceControls device,
  AppSettings settings,
) {
  if (!device.hasZoomRange || device.deviceMaxZoom <= device.deviceMinZoom) {
    return null;
  }
  return effectiveCameraZoomRange(
    deviceMinZoom: device.deviceMinZoom,
    deviceMaxZoom: device.deviceMaxZoom,
    settings: settings,
  );
}

/// One quick zoom stop.
class CameraZoomChip extends StatelessWidget {
  const CameraZoomChip({
    required this.zoom,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final double zoom;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = formatZoomPreset(zoom);
    return Tooltip(
      message: '变焦 $label',
      child: SizedBox(
        width: 44,
        height: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? c.onDarkroom : c.railButton,
            borderRadius: Radii.pillAll,
          ),
          child: MiriaPressable(
            key: ValueKey('camera-zoom-preset-$label'),
            onTap: onPressed,
            selected: selected,
            borderRadius: Radii.pillAll,
            semanticLabel: '变焦 $label',
            excludeSemantics: true,
            child: Center(
              child: Text(
                label,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? c.darkroom : c.onDarkroom,
                  fontFeatures: MiriaFonts.tabular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay opacity (叠影 only), default 46 %.
class CameraOpacityColumn extends StatelessWidget {
  const CameraOpacityColumn({
    required this.opacity,
    required this.onChanged,
    required this.sliderHeight,
    super.key,
  });

  final ValueNotifier<double> opacity;
  final ValueChanged<double> onChanged;
  final double sliderHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<double>(
      valueListenable: opacity,
      builder: (context, value, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.opacity_rounded, size: 18, color: c.railMuted),
          const SizedBox(height: Space.x1),
          MiriaVerticalSlider(
            key: const ValueKey('camera-opacity-slider'),
            value: value,
            onChanged: onChanged,
            height: sliderHeight,
            width: 40,
            semanticLabel: '叠影不透明度',
            format: (v) => '${(v * 100).round()}%',
          ),
          const SizedBox(height: Space.x1),
          Text(
            '${(value * 100).round()}%',
            style: context.text.labelSmall?.copyWith(
              color: c.railText,
              fontFeatures: MiriaFonts.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays children out top to bottom, spreading them over the available
/// height and scaling the whole column down when it does not fit. The
/// builder receives the available height (for slider sizes).
class CameraRailColumn extends StatelessWidget {
  const CameraRailColumn({
    required this.builder,
    required this.width,
    this.alignment = MainAxisAlignment.spaceBetween,
    super.key,
  });

  final List<Widget> Function(double height) builder;
  final double width;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: height,
              minWidth: width,
              maxWidth: width,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: alignment,
              children: builder(height),
            ),
          ),
        );
      },
    );
  }
}
