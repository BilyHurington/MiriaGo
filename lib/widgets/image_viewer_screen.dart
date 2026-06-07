import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../desktop/desktop_asset_image.dart';
import '../records/gallery_saver_stub.dart'
    if (dart.library.io) '../records/gallery_saver_io.dart';

class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({
    this.filePath,
    this.imageUrl,
    this.bytes,
    super.key,
  });

  final String? filePath;
  final String? imageUrl;
  final Uint8List? bytes;

  static Future<void> show(
    BuildContext context, {
    String? filePath,
    String? imageUrl,
    Uint8List? bytes,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerScreen(
          filePath: filePath,
          imageUrl: imageUrl,
          bytes: bytes,
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
                  child: _buildImage(),
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white),
              title: const Text('分享', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final savePath = await _resolveLocalImagePath();
                if (savePath == null) {
                  _showSnackBar(messenger, '图片读取失败');
                  return;
                }
                Share.shareXFiles([XFile(savePath)]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_outlined, color: Colors.white),
              title: const Text('保存到相册', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final savePath = await _resolveLocalImagePath();
                if (savePath == null) {
                  _showSnackBar(messenger, '图片读取失败');
                  return;
                }
                final success = await saveImageToGallery(savePath);
                _showSnackBar(messenger, success ? '已保存到相册' : '保存失败');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF2C2C2E),
    );
  }

  Future<String?> _resolveLocalImagePath() async {
    final path = filePath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        return path;
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

  void _showSnackBar(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildImage() {
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
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            return Image.network(
              dataUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                );
              },
            );
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
      return Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          );
        },
      );
    }

    return const Center(
      child: Icon(Icons.image_outlined, color: Colors.white54, size: 48),
    );
  }
}
