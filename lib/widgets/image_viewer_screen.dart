import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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
    final savePath = filePath;
    if (savePath == null) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white),
              title: const Text(
                '分享',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                Share.shareXFiles([XFile(savePath)]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_outlined, color: Colors.white),
              title: const Text(
                '保存到相册',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final success = await saveImageToGallery(savePath);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '已保存到相册' : '保存失败'),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF2C2C2E),
    );
  }

  Widget _buildImage() {
    final imageBytes = bytes;
    if (imageBytes != null) {
      return Image.memory(imageBytes, fit: BoxFit.contain);
    }

    final path = filePath;
    if (path != null) {
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
            child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
          );
        },
      );
    }

    return const Center(
      child: Icon(Icons.image_outlined, color: Colors.white54, size: 48),
    );
  }
}
