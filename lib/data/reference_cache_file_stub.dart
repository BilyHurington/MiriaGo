import '../desktop/tauri_bridge.dart' as tauri;

bool get isReferenceCacheCleanupSupported => tauri.isTauriLauncherAvailable;

bool referenceCacheFileExists(String? path) => path != null && path.isNotEmpty;

bool referenceFullCacheFileIsCurrent({
  required String? path,
  required String? imageUrl,
}) =>
    path != null && path.isNotEmpty && imageUrl != null && imageUrl.isNotEmpty;

Future<int> referenceCacheFileSize(String path) async {
  if (!tauri.isTauriLauncherAvailable) return 0;
  final result = await tauri.inspectDesktopReferenceCacheAsset(path: path);
  return result.existed ? result.byteLength : 0;
}

Future<int> deleteReferenceCacheFile(String path) async {
  if (!tauri.isTauriLauncherAvailable) return 0;
  final result = await tauri.deleteDesktopReferenceCacheAsset(path: path);
  return result.existed ? result.byteLength : 0;
}
