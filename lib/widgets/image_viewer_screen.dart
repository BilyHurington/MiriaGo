import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/anitabi_image_fetcher.dart';
import '../data/anitabi_image_source_scope.dart';
import '../desktop/desktop_asset_image.dart';
import '../plan/pilgrimage_models.dart';
import '../plan_transfer/plan_export_delivery.dart';
import '../plan_transfer/plan_export_delivery_result.dart';
import '../records/gallery_saver_stub.dart'
    if (dart.library.io) '../records/gallery_saver_io.dart';
import 'anitabi_network_image.dart';

class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({
    this.filePath,
    this.imageUrl,
    this.bytes,
    this.imageSource = AnitabiImageSource.auto,
    super.key,
  });

  final String? filePath;
  final String? imageUrl;
  final Uint8List? bytes;
  final AnitabiImageSource imageSource;

  static Future<void> show(
    BuildContext context, {
    String? filePath,
    String? imageUrl,
    Uint8List? bytes,
  }) {
    final imageSource = AnitabiImageSourceScope.of(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerScreen(
          filePath: filePath,
          imageUrl: imageUrl,
          bytes: bytes,
          imageSource: imageSource,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: GestureDetector(
                  onLongPress: () => _showSaveSheet(context),
                  child: _buildImage(context),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: MediaQuery.paddingOf(context).top + 8,
            child: Material(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSaveSheet(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => kIsWeb
          ? _WebSaveSheet(onSave: () => _saveImageFile(ctx, messenger))
          : _MobileSaveSheet(
              onShare: () async {
                Navigator.of(ctx).pop();
                final savePath = await _resolveLocalImagePath(context);
                if (savePath == null) {
                  _showSnackBar(messenger, '图片读取失败');
                  return;
                }
                Share.shareXFiles([XFile(savePath)]);
              },
              onSaveToGallery: () async {
                Navigator.of(ctx).pop();
                final savePath = await _resolveLocalImagePath(context);
                if (savePath == null) {
                  _showSnackBar(messenger, '图片读取失败');
                  return;
                }
                final success = await saveImageToGallery(savePath);
                _showSnackBar(messenger, success ? '已保存到相册' : '保存失败');
              },
            ),
      backgroundColor: const Color(0xFF2C2C2E),
    );
  }

  Future<void> _saveImageFile(
    BuildContext sheetContext,
    ScaffoldMessengerState messenger,
  ) async {
    Navigator.of(sheetContext).pop();
    try {
      final imageBytes = await _resolveImageBytes(sheetContext);
      if (imageBytes == null || imageBytes.isEmpty) {
        _showSnackBar(messenger, '图片读取失败');
        return;
      }
      final extension = _preferredExtension();
      final result = await deliverPlanExport(
        bytes: imageBytes,
        fileName:
            'miriago_image_${DateTime.now().microsecondsSinceEpoch}.$extension',
        mimeType: _mimeTypeForExtension(extension),
        shareSubject: 'MiriaGo 图片',
        shareText: 'MiriaGo 图片',
        extension: extension,
      );
      if (result.action == PlanExportDeliveryAction.canceled) {
        _showSnackBar(messenger, '已取消保存');
        return;
      }
      _showSnackBar(messenger, '图片已保存');
    } catch (_) {
      _showSnackBar(messenger, '保存失败');
    }
  }

  Future<Uint8List?> _resolveImageBytes(BuildContext context) async {
    final imageBytes = bytes;
    if (imageBytes != null) {
      return imageBytes;
    }

    final path = filePath;
    if (path != null) {
      if (isDesktopAssetPath(path)) {
        final dataUrl = await loadDesktopAssetDataUrl(path);
        return _bytesFromDataUrl(dataUrl);
      }

      if (_isBundledSampleAssetPath(path)) {
        final data = await rootBundle.load(path);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }

      if (!kIsWeb) {
        final file = File(path);
        if (file.existsSync()) {
          return file.readAsBytes();
        }
      }
    }

    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return null;
    }

    final anitabiBytes = await fetchAnitabiImageBytes(url, source: imageSource);
    if (anitabiBytes != null) {
      return Uint8List.fromList(anitabiBytes);
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    return response.bodyBytes;
  }

  Future<String?> _resolveLocalImagePath(BuildContext context) async {
    final path = filePath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        return path;
      }
      if (_isBundledSampleAssetPath(path)) {
        final data = await rootBundle.load(path);
        return _writeTemporaryImage(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          extension: _extensionFromUrl(path),
        );
      }
    }

    final imageBytes = bytes;
    if (imageBytes != null) {
      return _writeTemporaryImage(imageBytes, extension: 'jpg');
    }

    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return null;
    }

    try {
      final anitabiBytes = await fetchAnitabiImageBytes(
        url,
        source: imageSource,
      );
      if (anitabiBytes != null) {
        return _writeTemporaryImage(
          Uint8List.fromList(anitabiBytes),
          extension: _extensionFromUrl(url),
        );
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return _writeTemporaryImage(
        response.bodyBytes,
        extension: _extensionFromUrl(url),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _writeTemporaryImage(
    Uint8List imageBytes, {
    required String extension,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/seichi_image_${DateTime.now().microsecondsSinceEpoch}.$extension';
      final file = File(path);
      await file.writeAsBytes(imageBytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  String _extensionFromUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.png')) return 'png';
    if (path.endsWith('.webp')) return 'webp';
    if (path.endsWith('.jpeg')) return 'jpg';
    return 'jpg';
  }

  String _preferredExtension() {
    final path = filePath ?? Uri.tryParse(imageUrl ?? '')?.path;
    final lowerPath = path?.toLowerCase() ?? '';
    if (lowerPath.endsWith('.png')) return 'png';
    if (lowerPath.endsWith('.webp')) return 'webp';
    if (lowerPath.endsWith('.jpeg')) return 'jpg';
    return 'jpg';
  }

  String _mimeTypeForExtension(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  Uint8List? _bytesFromDataUrl(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) {
      return null;
    }
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex == -1) {
      return null;
    }
    final metadata = dataUrl.substring(0, commaIndex);
    final payload = dataUrl.substring(commaIndex + 1);
    if (!metadata.contains(';base64')) {
      return null;
    }
    return base64Decode(payload);
  }

  void _showSnackBar(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildImage(BuildContext context) {
    final imageBytes = bytes;
    if (imageBytes != null) {
      return Image.memory(imageBytes, fit: BoxFit.contain);
    }

    final path = filePath;
    if (path != null) {
      if (isDesktopAssetPath(path)) {
        return FutureBuilder<String?>(
          future: loadDesktopAssetDataUrl(path),
          builder: (context, snapshot) {
            final dataUrl = snapshot.data;
            if (dataUrl == null || dataUrl.isEmpty) {
              return const _ImageViewerPlaceholder(
                state: _ImageViewerPlaceholderState.loading,
              );
            }
            return Image.network(
              dataUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const _ImageViewerPlaceholder();
              },
            );
          },
        );
      }

      if (_isBundledSampleAssetPath(path)) {
        return Image.asset(
          path,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const _ImageViewerPlaceholder();
          },
        );
      }

      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.contain);
      }
    }

    final url = imageUrl;
    if (url != null) {
      return AnitabiNetworkImage(
        url: url,
        imageSource: imageSource,
        fit: BoxFit.contain,
        loadingBuilder: (_) {
          return const _ImageViewerPlaceholder(
            state: _ImageViewerPlaceholderState.loading,
          );
        },
        errorBuilder: (_) {
          return const _ImageViewerPlaceholder();
        },
      );
    }

    return const _ImageViewerPlaceholder(
      state: _ImageViewerPlaceholderState.empty,
    );
  }

  bool _isBundledSampleAssetPath(String path) {
    return path.startsWith('docs/sample_images/');
  }
}

enum _ImageViewerPlaceholderState { loading, unavailable, empty }

class _ImageViewerPlaceholder extends StatelessWidget {
  const _ImageViewerPlaceholder({
    this.state = _ImageViewerPlaceholderState.unavailable,
  });

  final _ImageViewerPlaceholderState state;

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      _ImageViewerPlaceholderState.loading => Icons.hourglass_empty_rounded,
      _ImageViewerPlaceholderState.empty => Icons.image_outlined,
      _ImageViewerPlaceholderState.unavailable => Icons.broken_image_outlined,
    };
    final label = switch (state) {
      _ImageViewerPlaceholderState.loading => '图片加载中',
      _ImageViewerPlaceholderState.empty => '暂无图片',
      _ImageViewerPlaceholderState.unavailable => '图片暂不可用',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == _ImageViewerPlaceholderState.loading)
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 3,
              ),
            )
          else
            Icon(icon, color: Colors.white54, size: 48),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebSaveSheet extends StatelessWidget {
  const _WebSaveSheet({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.save_alt_outlined, color: Colors.white),
            title: const Text('保存图片', style: TextStyle(color: Colors.white)),
            onTap: onSave,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _MobileSaveSheet extends StatelessWidget {
  const _MobileSaveSheet({
    required this.onShare,
    required this.onSaveToGallery,
  });

  final VoidCallback onShare;
  final VoidCallback onSaveToGallery;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.share_outlined, color: Colors.white),
            title: const Text('分享', style: TextStyle(color: Colors.white)),
            onTap: onShare,
          ),
          ListTile(
            leading: const Icon(Icons.save_alt_outlined, color: Colors.white),
            title: const Text('保存到相册', style: TextStyle(color: Colors.white)),
            onTap: onSaveToGallery,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
