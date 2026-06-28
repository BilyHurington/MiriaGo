String normalizeAssetPathSeparators(String path) {
  return path.replaceAll(r'\', '/');
}

bool isSafeRelativeAssetPath(String? path) {
  if (path == null || path.isEmpty) {
    return false;
  }
  final normalized = normalizeAssetPathSeparators(path);
  if (!normalized.startsWith('assets/') || normalized.endsWith('/')) {
    return false;
  }
  return !normalized
      .split('/')
      .any((segment) => segment.isEmpty || segment == '.' || segment == '..');
}

bool isRuntimeManagedAssetPath(String path) {
  final normalized = normalizeAssetPathSeparators(path);
  return normalized.startsWith('assets/imported_plan_assets/') ||
      normalized.startsWith('assets/reference_full/') ||
      normalized.startsWith('assets/reference_thumbnails/') ||
      normalized.startsWith('assets/user_reference_images/') ||
      normalized.startsWith('assets/user_references/');
}

bool isImagePackageAssetPath(String path) {
  final normalized = normalizeAssetPathSeparators(path);
  return normalized.startsWith('assets/thumbnails/') ||
      normalized.startsWith('assets/full_references/') ||
      normalized.startsWith('assets/user_references/') ||
      normalized.startsWith('assets/visit_photos/') ||
      normalized.startsWith('assets/graded_photos/');
}
