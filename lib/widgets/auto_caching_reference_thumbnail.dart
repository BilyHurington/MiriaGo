import 'package:flutter/material.dart';

import '../data/anitabi_image_source_scope.dart';
import '../data/pilgrimage_repository.dart';
import '../data/reference_image_cache_stub.dart'
    if (dart.library.io) '../data/reference_image_cache_io.dart'
    as reference_image_cache;
import '../plan/pilgrimage_models.dart';
import '../plan/reference_image_status.dart';
import 'reference_thumbnail_stub.dart'
    if (dart.library.io) 'reference_thumbnail_io.dart';

class AutoCachingReferenceThumbnail extends StatefulWidget {
  const AutoCachingReferenceThumbnail({
    required this.planId,
    required this.point,
    required this.repository,
    required this.placeholder,
    this.onPlanUpdated,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    super.key,
  });

  final String planId;
  final PilgrimagePoint point;
  final PilgrimageRepository repository;
  final ValueChanged<PilgrimagePlan>? onPlanUpdated;
  final Widget placeholder;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  State<AutoCachingReferenceThumbnail> createState() =>
      _AutoCachingReferenceThumbnailState();
}

class _AutoCachingReferenceThumbnailState
    extends State<AutoCachingReferenceThumbnail> {
  static final Map<String, Future<String?>> _inFlight = {};

  String? _thumbnailPath;
  int _requestVersion = 0;
  AnitabiImageSource? _imageSource;

  @override
  void initState() {
    super.initState();
    _thumbnailPath = widget.point.referenceThumbnailPath;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final imageSource = AnitabiImageSourceScope.of(context);
    if (_imageSource != imageSource) {
      _imageSource = imageSource;
      _maybeCacheThumbnail();
    }
  }

  @override
  void didUpdateWidget(covariant AutoCachingReferenceThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point.id != widget.point.id ||
        oldWidget.point.referenceThumbnailPath !=
            widget.point.referenceThumbnailPath ||
        oldWidget.point.referenceImageUrl != widget.point.referenceImageUrl) {
      _thumbnailPath = widget.point.referenceThumbnailPath;
      _maybeCacheThumbnail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageSource = AnitabiImageSourceScope.of(context);
    return ReferenceThumbnail(
      localPath: _thumbnailPath,
      imageUrl: hasRemoteReferenceImage(widget.point)
          ? widget.point.referenceImageUrl
          : null,
      imageSource: imageSource,
      placeholder: widget.placeholder,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
    );
  }

  void _maybeCacheThumbnail() {
    final version = ++_requestVersion;
    if (!hasRemoteReferenceImage(widget.point)) {
      return;
    }

    final point = widget.point;
    final planId = widget.planId;
    final repository = widget.repository;
    final imageSource = _imageSource ?? AnitabiImageSource.auto;
    final key = '${point.referenceImageUrl}:${imageSource.name}';

    Future<void>(() async {
      if (!mounted || version != _requestVersion) return;
      try {
        final path = await _inFlight.putIfAbsent(key, () async {
          try {
            return await reference_image_cache.ensureReferenceThumbnailCached(
              point,
              imageSource: imageSource,
            );
          } finally {
            _inFlight.remove(key);
          }
        });
        if (path == null || path.isEmpty) {
          return;
        }
        if (!mounted || version != _requestVersion) {
          return;
        }
        if (path == _thumbnailPath) {
          return;
        }

        final updatedPlan = await repository.updatePointImageCaches(
          planId: planId,
          updatesByPointId: {
            point.id: PointImageCacheUpdate(
              referenceThumbnailPath: path,
              expectedReferenceImageUrl: point.referenceImageUrl,
              preserveFullImagePath: true,
            ),
          },
        );
        if (!mounted || version != _requestVersion) return;
        final updatedPoint = updatedPlan.points
            .where((p) => p.id == point.id)
            .firstOrNull;
        if (updatedPoint?.referenceImageUrl != point.referenceImageUrl ||
            updatedPoint?.referenceThumbnailPath != path) {
          return;
        }
        setState(() => _thumbnailPath = path);
        widget.onPlanUpdated?.call(updatedPlan);
      } catch (_) {
        // Thumbnail self-healing is best-effort. The UI can still use the
        // normalized network thumbnail fallback.
      }
    });
  }
}
