import 'package:flutter/material.dart';

import '../desktop/desktop_asset_image.dart';
import 'reference_image_placeholder.dart';

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
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return _sizedPlaceholder(
            const ReferenceImagePlaceholder(
              state: ReferenceImagePlaceholderState.loading,
            ),
          );
        },
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return placeholder;
  }

  Widget _sizedPlaceholder(Widget child) {
    if (width == null && height == null) {
      return child;
    }
    return SizedBox(width: width, height: height, child: child);
  }
}
