import 'package:flutter/material.dart';

import '../data/reference_asset_paths.dart';
import 'tauri_bridge.dart' as tauri;

final Map<String, Future<String?>> _assetDataUrlCache = {};

String normalizeDesktopAssetPath(String path) {
  return normalizeAssetPathSeparators(path.trim());
}

bool isDesktopAssetPath(String? path) {
  return isSafeRelativeAssetPath(path);
}

Future<String?> loadDesktopAssetDataUrl(String path) {
  final normalizedPath = normalizeDesktopAssetPath(path);
  return _assetDataUrlCache.putIfAbsent(normalizedPath, () async {
    if (!tauri.isTauriLauncherAvailable ||
        !isDesktopAssetPath(normalizedPath)) {
      return null;
    }
    final asset = await tauri.readDesktopAsset(path: normalizedPath);
    if (asset.dataBase64.isEmpty) {
      return null;
    }
    return 'data:${asset.mimeType};base64,${asset.dataBase64}';
  });
}

class DesktopAssetImage extends StatelessWidget {
  const DesktopAssetImage({
    required this.path,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    super.key,
  });

  final String path;
  final Widget placeholder;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: loadDesktopAssetDataUrl(path),
      builder: (context, snapshot) {
        final dataUrl = snapshot.data;
        if (dataUrl == null || dataUrl.isEmpty) {
          return placeholder;
        }
        return Image.network(
          dataUrl,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => placeholder,
        );
      },
    );
  }
}
