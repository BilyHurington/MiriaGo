import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/capture/capture_session.dart';
import '../../../camera_reference/native_camera_controller.dart';
import '../../components/components.dart';
import 'camera_controls.dart';

/// The viewfinder: only the preview and the reference (overlay or the
/// upper frame of 上下). Controls never go in here.
///
/// [preview] must keep the same key in every configuration so a platform
/// view is reparented, not recreated, when the mode or layout changes.
class CameraStage extends StatelessWidget {
  const CameraStage({
    required this.mode,
    required this.reference,
    required this.overlayOpacity,
    required this.captureAspectRatio,
    required this.referenceScale,
    required this.preview,
    this.padding = 6,
    this.gap = 6,
    this.transparentPreview = false,
    super.key,
  });

  final CaptureReferenceMode mode;
  final CaptureReferenceSource reference;
  final ValueListenable<double> overlayOpacity;
  final double captureAspectRatio;
  final double referenceScale;
  final Widget preview;
  final double padding;
  final double gap;

  /// The preview is drawn behind this widget (CameraAwesome); keep the
  /// preview frame see-through.
  final bool transparentPreview;

  @override
  Widget build(BuildContext context) {
    if (mode == CaptureReferenceMode.split && reference.hasImage) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxFrameHeight = math.max(
              (constraints.maxHeight - gap) / 2,
              0.0,
            );
            var frameWidth = math.max(constraints.maxWidth, 0.0);
            var frameHeight = frameWidth / captureAspectRatio;
            if (frameHeight > maxFrameHeight) {
              frameHeight = maxFrameHeight;
              frameWidth = frameHeight * captureAspectRatio;
            }
            return Center(
              child: SizedBox(
                width: frameWidth,
                height: frameHeight * 2 + gap,
                child: Column(
                  children: [
                    SizedBox(
                      width: frameWidth,
                      height: frameHeight,
                      child: AspectStageFrame(
                        aspectRatio: captureAspectRatio,
                        child: CameraReferenceImage(
                          source: reference,
                          scale: referenceScale,
                        ),
                      ),
                    ),
                    SizedBox(height: gap),
                    SizedBox(
                      width: frameWidth,
                      height: frameHeight,
                      child: AspectStageFrame(
                        aspectRatio: captureAspectRatio,
                        transparent: transparentPreview,
                        child: preview,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(padding),
      child: AspectStageFrame(
        aspectRatio: captureAspectRatio,
        transparent: transparentPreview,
        child: Stack(
          fit: StackFit.expand,
          children: [
            preview,
            if (reference.hasImage)
              // Touches pass through to the preview.
              IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: overlayOpacity,
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: CameraReferenceImage(
                    source: reference,
                    scale: referenceScale,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A frame of [aspectRatio] fitted into the available space.
class AspectStageFrame extends StatelessWidget {
  const AspectStageFrame({
    required this.aspectRatio,
    required this.child,
    this.transparent = false,
    super.key,
  });

  final double aspectRatio;
  final Widget child;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final ratio = aspectRatio <= 0 ? 16 / 9 : aspectRatio;
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        var height = width / ratio;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * ratio;
        }
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: transparent ? null : c.darkroom,
                borderRadius: Radii.xsAll,
                border: transparent
                    ? null
                    : Border.all(color: c.onDarkroom.withValues(alpha: 0.12)),
              ),
              child: ClipRRect(borderRadius: Radii.xsAll, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// Hosts the native preview platform view
/// (`seichi/native_camera_preview`). Always built with
/// [NativeCameraController.previewKey].
class NativeCameraPreview extends StatelessWidget {
  const NativeCameraPreview({required this.controller, super.key});

  final NativeCameraController controller;

  static const viewType = 'seichi/native_camera_preview';

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: viewType,
        onPlatformViewCreated: controller.attach,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: viewType,
        onPlatformViewCreated: controller.attach,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return const SizedBox.expand();
  }
}
