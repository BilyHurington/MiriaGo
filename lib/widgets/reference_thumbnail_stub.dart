import 'package:flutter/material.dart';

import '../desktop/desktop_asset_image.dart';

class ReferenceThumbnail extends StatelessWidget {
  const ReferenceThumbnail({
    required this.localPath,
    required this.imageUrl,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    super.key,
  });

  final String? localPath;
  final String? imageUrl;
  final Widget placeholder;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    if (isDesktopAssetPath(path)) {
      return DesktopAssetImage(
        path: path!,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder,
      );
    }

    final url = imageUrl;
    if (url != null) {
      return Image.network(url, width: width, height: height, fit: fit);
    }
    return placeholder;
  }
}
