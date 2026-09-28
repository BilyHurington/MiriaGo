import 'package:flutter/material.dart';

import '../data/reference_asset_paths.dart';
import 'desktop_asset_data_url_cache.dart';
import 'tauri_bridge.dart' as tauri;

export 'desktop_asset_data_url_cache.dart'
    show invalidateDesktopAssetDataUrl, clearDesktopAssetDataUrlCache;

String normalizeDesktopAssetPath(String path) {
  return normalizeAssetPathSeparators(path.trim());
}

bool isDesktopAssetPath(String? path) {
  return isSafeRelativeAssetPath(path);
}

Future<String?> loadDesktopAssetDataUrl(String path) {
  final normalizedPath = normalizeDesktopAssetPath(path);
  if (!tauri.isTauriLauncherAvailable || !isDesktopAssetPath(normalizedPath)) {
    return Future.value();
  }
  return desktopAssetDataUrlCache.load(normalizedPath, () async {
    final asset = await tauri.readDesktopAsset(path: normalizedPath);
    if (asset.dataBase64.isEmpty) {
      return null;
    }
    return 'data:${asset.mimeType};base64,${asset.dataBase64}';
  });
}

class DesktopAssetImage extends StatefulWidget {
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
  State<DesktopAssetImage> createState() => _DesktopAssetImageState();
}

class _DesktopAssetImageState extends State<DesktopAssetImage> {
  // Held per widget: failures are not cached globally, so requesting a new
  // future on every build would retry in a loop.
  late Future<String?> _dataUrl;

  @override
  void initState() {
    super.initState();
    _dataUrl = loadDesktopAssetDataUrl(widget.path);
  }

  @override
  void didUpdateWidget(DesktopAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _dataUrl = loadDesktopAssetDataUrl(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _dataUrl,
      builder: (context, snapshot) {
        final dataUrl = snapshot.data;
        if (dataUrl == null || dataUrl.isEmpty) {
          return widget.placeholder;
        }
        return Image.network(
          dataUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => widget.placeholder,
        );
      },
    );
  }
}
