import 'dart:io';

import '../desktop/desktop_asset_image.dart';

bool referenceImageLocalPathCanDisplay(String? path) {
  if (path == null || path.isEmpty) {
    return false;
  }
  if (isDesktopAssetPath(path)) {
    return true;
  }
  final file = File(path);
  return file.existsSync() && file.lengthSync() > 0;
}
