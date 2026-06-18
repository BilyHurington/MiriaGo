import 'dart:convert';

import '../desktop/desktop_asset_image.dart';
import '../desktop/tauri_bridge.dart' as tauri;

Future<int?> localAssetSize(String? path) async {
  if (!tauri.isTauriLauncherAvailable || !isDesktopAssetPath(path)) {
    return null;
  }
  try {
    final asset = await tauri.readDesktopAsset(path: path!);
    if (asset.dataBase64.isEmpty) {
      return null;
    }
    return base64Decode(asset.dataBase64).length;
  } catch (_) {
    return null;
  }
}
