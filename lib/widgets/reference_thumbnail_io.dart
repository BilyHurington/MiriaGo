import 'dart:io';

import 'package:flutter/material.dart';

import '../data/anitabi_image_url.dart';
import '../plan/pilgrimage_models.dart';
import 'anitabi_network_image.dart';
import 'image_load_limiter.dart';

class ReferenceThumbnail extends StatelessWidget {
  const ReferenceThumbnail({
    required this.localPath,
    required this.imageUrl,
    required this.placeholder,
    this.imageSource = AnitabiImageSource.auto,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.loadLimiter,
    super.key,
  });

  final String? localPath;
  final String? imageUrl;
  final Widget placeholder;
  final AnitabiImageSource imageSource;
  final BoxFit fit;
  final double? width;
  final double? height;
  final ImageLoadLimiter? loadLimiter;

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, width: width, height: height, fit: fit);
      }
    }

    final url = imageUrl;
    if (url != null) {
      final thumbnailUrl = anitabiThumbnailImageUrl(url) ?? url;
      return AnitabiNetworkImage(
        url: thumbnailUrl,
        imageSource: imageSource,
        width: width,
        height: height,
        fit: fit,
        loadLimiter: loadLimiter,
        errorBuilder: (_) => placeholder,
      );
    }

    return placeholder;
  }
}
