import 'package:flutter/material.dart';

import '../desktop/desktop_asset_image.dart';

class VisitRecordPhoto extends StatelessWidget {
  const VisitRecordPhoto({
    required this.path,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (isDesktopAssetPath(path)) {
      return DesktopAssetImage(
        path: path,
        fit: fit,
        placeholder: const _PhotoPlaceholder(),
      );
    }

    if (path.startsWith('docs/sample_images/')) {
      return Image.asset(
        path,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => const _PhotoPlaceholder(),
      );
    }

    return const _PhotoPlaceholder();
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEEF1F4),
      child: Center(child: Icon(Icons.photo_outlined)),
    );
  }
}
