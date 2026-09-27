import 'dart:io';

import '../data/app_managed_file_paths_io.dart';
import '../desktop/desktop_asset_image.dart';

bool referenceImageLocalPathCanDisplay(String? path) {
  if (path == null || path.isEmpty) {
    return false;
  }
  if (isDesktopAssetPath(path)) {
    return true;
  }
  final resolvedPath = resolveExistingAppManagedFilePathSync(path) ?? path;
  final file = File(resolvedPath);
  return file.existsSync() && file.lengthSync() > 0;
}
