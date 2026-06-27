import 'package:flutter/material.dart';

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
  static final Set<String> _inFlightPointIds = <String>{};

  String? _thumbnailPath;
  bool _isAttempting = false;

  @override
  void initState() {
    super.initState();
    _thumbnailPath = widget.point.referenceThumbnailPath;
    _maybeCacheThumbnail();
  }

  @override
  void didUpdateWidget(covariant AutoCachingReferenceThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.point.id != widget.point.id ||
        oldWidget.point.referenceThumbnailPath !=
            widget.point.referenceThumbnailPath ||
        oldWidget.point.referenceImageUrl != widget.point.referenceImageUrl) {
      _thumbnailPath =
          oldWidget.point.referenceImageUrl == widget.point.referenceImageUrl
          ? widget.point.referenceThumbnailPath
          : null;
      _maybeCacheThumbnail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReferenceThumbnail(
      localPath: _thumbnailPath,
      imageUrl: hasRemoteReferenceImage(widget.point)
          ? widget.point.referenceImageUrl
          : null,
      placeholder: widget.placeholder,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
    );
  }

  void _maybeCacheThumbnail() {
    if (!hasRemoteReferenceImage(widget.point)) {
      return;
    }

    final key = '${widget.planId}:${widget.point.id}';
    if (_isAttempting || !_inFlightPointIds.add(key)) {
      return;
    }
    _isAttempting = true;

    Future<void>(() async {
      try {
        final path = await reference_image_cache.ensureReferenceThumbnailCached(
          widget.point,
        );
        if (path == null || path.isEmpty) {
          return;
        }
        if (!mounted) {
          return;
        }
        if (path == _thumbnailPath) {
          return;
        }

        setState(() {
          _thumbnailPath = path;
        });
        final updatedPlan = await widget.repository.updatePointImageCache(
          planId: widget.planId,
          pointId: widget.point.id,
          referenceThumbnailPath: path,
          referenceFullImagePath: widget.point.referenceFullImagePath,
        );
        widget.onPlanUpdated?.call(updatedPlan);
      } catch (_) {
        // Thumbnail self-healing is best-effort. The UI can still use the
        // normalized network thumbnail fallback.
      } finally {
        _inFlightPointIds.remove(key);
        if (mounted) {
          _isAttempting = false;
        }
      }
    });
  }
}
