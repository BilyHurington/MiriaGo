import 'package:flutter/material.dart';

import '../desktop/desktop_asset_image.dart';
import '../plan/pilgrimage_models.dart';

String? resolveVisitRecordDisplayPhotoPath(PilgrimageVisitRecord record) {
  return _firstDisplayableVisitRecordPath([
    record.gradedPhotoPath,
    record.photoPath,
    record.originalPhotoPath,
  ]);
}

String? resolveVisitRecordSourcePhotoPath(PilgrimageVisitRecord record) {
  return _firstDisplayableVisitRecordPath([
    record.originalPhotoPath,
    record.photoPath,
    record.gradedPhotoPath,
  ]);
}

bool visitRecordPhotoPathCanDisplay(String? path) {
  final value = path?.trim();
  if (value == null || value.isEmpty) {
    return false;
  }
  return isDesktopAssetPath(value) || value.startsWith('docs/sample_images/');
}

String? _firstDisplayableVisitRecordPath(Iterable<String?> paths) {
  for (final path in paths) {
    if (visitRecordPhotoPathCanDisplay(path)) {
      return path;
    }
  }
  return null;
}

class VisitRecordPhoto extends StatelessWidget {
  const VisitRecordPhoto({this.path, this.fit = BoxFit.cover, super.key});

  final String? path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final resolvedPath = path?.trim();
    if (resolvedPath == null || resolvedPath.isEmpty) {
      return const _PhotoPlaceholder();
    }

    if (isDesktopAssetPath(resolvedPath)) {
      return DesktopAssetImage(
        path: resolvedPath,
        fit: fit,
        placeholder: const _PhotoPlaceholder(),
      );
    }

    if (resolvedPath.startsWith('docs/sample_images/')) {
      return Image.asset(
        resolvedPath,
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
