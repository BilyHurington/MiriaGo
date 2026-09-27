import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/go/go_completion.dart';
import '../../../application/plan_session.dart';
import '../../../application/settings_store.dart';
import '../../../data/anitabi_image_source_scope.dart';
import '../../../map/map_navigation_launcher.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/reference_image_status.dart';
import '../../../widgets/auto_caching_reference_thumbnail.dart';
import '../../../widgets/bounded_image.dart';
import '../../../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../../../widgets/reference_thumbnail_io.dart';
import '../../app/toast.dart';
import '../../components/components.dart';
import '../viewer/image_viewer.dart';

/// Picks an image for 「替换参考图」 and returns its path (null = cancelled).
typedef ReferenceImagePicker = Future<String?> Function();

Future<String?> _pickFromGallery() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  return picked?.path;
}

/// Dependencies of the 巡礼 page and point details that tests replace:
/// map tiles (no network), the external navigation launcher and the image
/// picker. Wrap the app (or a page) in it; defaults are used otherwise.
class PointFeatureOverrides extends InheritedWidget {
  const PointFeatureOverrides({
    required super.child,
    this.disableMapTiles = false,
    this.navigationLauncher = const MapNavigationLauncher(),
    this.pickReferenceImage = _pickFromGallery,
    super.key,
  });

  final bool disableMapTiles;
  final MapNavigationLauncher navigationLauncher;
  final ReferenceImagePicker pickReferenceImage;

  static const _defaults = PointFeatureOverrides(child: SizedBox.shrink());

  static PointFeatureOverrides of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PointFeatureOverrides>() ??
      _defaults;

  @override
  bool updateShouldNotify(PointFeatureOverrides oldWidget) =>
      disableMapTiles != oldWidget.disableMapTiles ||
      navigationLauncher != oldWidget.navigationLauncher ||
      pickReferenceImage != oldWidget.pickReferenceImage;
}

// ---------------------------------------------------------------------------
// Actions shared by the 巡礼 page and point details
// ---------------------------------------------------------------------------

/// Opens walking directions in the configured external map app; toasts
/// 「无法打开{app}。」 when that fails (old `_openExternalNavigation`).
Future<void> openPointInExternalMap(
  BuildContext context,
  PilgrimagePoint point,
) async {
  if (!point.hasCoordinate) return;
  final app = context.read<SettingsStore>().settings.navigationApp;
  final launcher = PointFeatureOverrides.of(context).navigationLauncher;
  final toasts = context.read<ToastController>();
  var opened = false;
  try {
    opened = await launcher.openWalking(point, app);
  } catch (_) {
    // Platform launchers can throw instead of returning false.
  }
  if (!opened) {
    toasts.show(ToastData(kind: ToastKind.error, title: '无法打开${app.label}。'));
  }
}

/// 「标记完成」 with an 「撤销」 action in the result toast (DESIGN Δ15).
void completePointWithToast(BuildContext context, PilgrimagePoint point) {
  final controller = context.read<PlanSession>().controller;
  final toasts = context.read<ToastController>();
  final undo = completePointWithUndo(controller, point);
  toasts.show(
    ToastData(
      kind: ToastKind.success,
      title: '已完成「${point.name}」。',
      action: ToastAction(
        label: '撤销',
        onPressed: () => undoPointCompletion(controller, undo),
      ),
    ),
  );
}

/// 标记完成 / 取消完成 depending on the point's status.
void togglePointCompletion(BuildContext context, PilgrimagePoint point) {
  final controller = context.read<PlanSession>().controller;
  if (controller.statusFor(point) == VisitStatus.completed) {
    controller.reopenPoint(point);
  } else {
    completePointWithToast(context, point);
  }
}

/// Label / icon of the completion toggle (DESIGN Δ8).
String completionLabel(VisitStatus status) =>
    status == VisitStatus.completed ? '取消完成' : '标记完成';

IconData completionIcon(VisitStatus status) => status == VisitStatus.completed
    ? Symbols.undo_rounded
    : Symbols.check_circle_rounded;

// ---------------------------------------------------------------------------
// Images
// ---------------------------------------------------------------------------

/// Remote reference URL of [point], if it has one that is not a local upload.
String? remoteReferenceUrl(PilgrimagePoint point) =>
    hasRemoteReferenceImage(point) ? point.referenceImageUrl : null;

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Best source for a large reference image: the cached / uploaded full
/// image, the remote URL, then the thumbnail.
String? largeReferenceSource(PilgrimagePoint point) =>
    _nonEmpty(point.referenceFullImagePath) ??
    remoteReferenceUrl(point) ??
    _nonEmpty(point.referenceThumbnailPath);

/// The viewer entry for [point]'s reference image, or null without one.
ViewerImage? referenceViewerImage(PilgrimagePoint point) {
  final full = _nonEmpty(point.referenceFullImagePath);
  if (full != null) return ViewerImage(path: full, label: '参考图');
  final url = remoteReferenceUrl(point);
  if (url != null) return ViewerImage(url: url, label: '参考图');
  final thumb = _nonEmpty(point.referenceThumbnailPath);
  if (thumb != null) return ViewerImage(path: thumb, label: '参考图');
  return null;
}

/// Opens [point]'s reference image in the full-screen viewer.
void openReferenceViewer(BuildContext context, PilgrimagePoint point) {
  final image = referenceViewerImage(point);
  if (image == null) return;
  unawaited(openImageViewer(context, images: [image]));
}

/// Brand placeholder for points without a reference image (DESIGN §6.7):
/// warm paper with the route motif.
class ReferencePlaceholder extends StatelessWidget {
  const ReferencePlaceholder({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.surfaceMuted,
      child: Center(
        child: compact
            ? Icon(Symbols.image_rounded, size: 20, color: c.textTertiary)
            : const FittedBox(child: RouteMotif(width: 96, height: 36)),
      ),
    );
  }
}

/// Square-ish reference thumbnail of a plan point that caches remote
/// thumbnails and writes the cached path back to the plan (old
/// `_PlanPointThumbnail`).
class PointThumbnail extends StatelessWidget {
  const PointThumbnail({
    required this.point,
    this.size = 44,
    this.borderRadius = Radii.smAll,
    super.key,
  });

  final PilgrimagePoint point;
  final double size;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final session = context.read<PlanSession>();
    const placeholder = ReferencePlaceholder(compact: true);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox.square(
        dimension: size,
        child: session.isReady
            ? AutoCachingReferenceThumbnail(
                planId: session.plan.id,
                point: point,
                repository: session.repository,
                onPlanUpdated: session.publish,
                placeholder: placeholder,
                width: size,
                height: size,
              )
            : ReferenceThumbnail(
                localPath: point.referenceThumbnailPath,
                imageUrl: remoteReferenceUrl(point),
                placeholder: placeholder,
                width: size,
                height: size,
              ),
      ),
    );
  }
}

/// Large reference image (16:9 area): the image contained on top of a
/// blurred, enlarged copy of itself (DESIGN §8.3). Uses the bounded
/// decoding pipeline.
class PointReferenceImage extends StatelessWidget {
  const PointReferenceImage({
    required this.point,
    this.blurredBackdrop = true,
    this.fit = BoxFit.contain,
    super.key,
  });

  final PilgrimagePoint point;
  final bool blurredBackdrop;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final source = largeReferenceSource(point);
    if (source == null) return const ReferencePlaceholder();
    final provider = BoundedImageProvider(
      path: source,
      source: AnitabiImageSourceScope.of(context),
    );
    Widget image(BoxFit fit) => Image(
      image: provider,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, synchronous) => frame == null
          ? ColoredBox(color: context.colors.surfaceMuted)
          : child,
      errorBuilder: (context, error, stack) => const ReferencePlaceholder(),
    );
    if (!blurredBackdrop || fit == BoxFit.cover) return image(fit);
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Transform.scale(scale: 1.2, child: image(BoxFit.cover)),
          ),
        ),
        image(fit),
      ],
    );
  }
}

/// Small 「📷 N」 tag with the number of visit records of a point.
class RecordCountTag extends StatelessWidget {
  const RecordCountTag({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Tag(
    label: '$count',
    icon: count > 1
        ? Symbols.photo_library_rounded
        : Symbols.photo_camera_rounded,
    tone: MiriaTone.primary,
  );
}

/// Lays out a navigation button, secondary buttons and an optional
/// trailing icon button: one row when there is room, otherwise navigation
/// on its own row above the rest (buttons shrink full → short → icon).
class PointActionLayout extends StatelessWidget {
  const PointActionLayout({
    required this.navigation,
    this.buttons = const [],
    this.trailing,
    this.oneRowMinWidth = 440,
    super.key,
  });

  final Widget navigation;
  final List<Widget> buttons;
  final Widget? trailing;

  /// Width (at text scale 1) from which everything fits on one row.
  final double oneRowMinWidth;

  @override
  Widget build(BuildContext context) {
    return FontAwareLayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final oneRow =
            constraints.maxWidth >= oneRowMinWidth * scale.clamp(1.0, 2.0);
        final trailing = this.trailing;
        if (oneRow || buttons.isEmpty) {
          return Row(
            children: [
              Expanded(flex: 5, child: navigation),
              for (final button in buttons) ...[
                const SizedBox(width: Space.x2),
                Expanded(flex: 3, child: button),
              ],
              if (trailing != null) ...[
                const SizedBox(width: Space.x2),
                trailing,
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            navigation,
            const SizedBox(height: Space.x2),
            Row(
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(width: Space.x2),
                  Expanded(child: buttons[i]),
                ],
                if (trailing != null) ...[
                  const SizedBox(width: Space.x2),
                  trailing,
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
