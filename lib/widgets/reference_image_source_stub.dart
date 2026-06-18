import '../desktop/desktop_asset_image.dart';

bool referenceImageLocalPathCanDisplay(String? path) {
  if (path == null || path.isEmpty) {
    return false;
  }
  return isDesktopAssetPath(path);
}
