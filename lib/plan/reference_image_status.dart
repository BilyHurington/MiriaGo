import 'pilgrimage_models.dart';

enum ReferenceImageStatus { none, localUpload, fullCached, remote }

bool hasRemoteReferenceImage(PilgrimagePoint point) {
  final url = point.referenceImageUrl?.trim();
  return url != null && url.isNotEmpty && !isLocalUploadedReference(point);
}

bool hasAnyReferenceImage(PilgrimagePoint point) {
  return hasRemoteReferenceImage(point) ||
      isLocalUploadedReference(point) ||
      _hasNonEmptyPath(point.referenceThumbnailPath) ||
      _hasNonEmptyPath(point.referenceFullImagePath);
}

bool isLocalUploadedReference(PilgrimagePoint point) {
  if (point.source == PointSource.manual &&
      (_hasNonEmptyPath(point.referenceThumbnailPath) ||
          _hasNonEmptyPath(point.referenceFullImagePath))) {
    return true;
  }

  return _isLocalUploadPath(point.referenceThumbnailPath) ||
      _isLocalUploadPath(point.referenceFullImagePath);
}

ReferenceImageStatus referenceImageStatusForPoint(
  PilgrimagePoint point, {
  required bool fullCacheIsCurrent,
}) {
  if (isLocalUploadedReference(point)) {
    return ReferenceImageStatus.localUpload;
  }
  if (!hasAnyReferenceImage(point)) {
    return ReferenceImageStatus.none;
  }
  if (fullCacheIsCurrent) {
    return ReferenceImageStatus.fullCached;
  }
  return ReferenceImageStatus.remote;
}

bool _hasNonEmptyPath(String? path) {
  return path != null && path.trim().isNotEmpty;
}

bool _isLocalUploadPath(String? path) {
  final normalized = path?.replaceAll(r'\', '/').toLowerCase();
  if (normalized == null || normalized.trim().isEmpty) {
    return false;
  }

  return normalized.contains('/user_reference_images/') ||
      normalized.startsWith('assets/user_reference_images/') ||
      normalized.contains('/user_references/') ||
      normalized.startsWith('assets/user_references/');
}
