import 'package:flutter/material.dart';

import 'tauri_bridge.dart' as tauri;

final Map<String, Future<String?>> _assetDataUrlCache = {};

bool isDesktopAssetPath(String? path) {
  if (path == null || path.isEmpty || !path.startsWith('assets/')) {
    return false;
  }
  if (path.contains('\\')) {
    return false;
  }
  return !path
      .split('/')
      .any((segment) => segment.isEmpty || segment == '.' || segment == '..');
}

Future<String?> loadDesktopAssetDataUrl(String path) {
  return _assetDataUrlCache.putIfAbsent(path, () async {
    if (!tauri.isTauriLauncherAvailable || !isDesktopAssetPath(path)) {
      return null;
    }
    final asset = await tauri.readDesktopAsset(path: path);
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
