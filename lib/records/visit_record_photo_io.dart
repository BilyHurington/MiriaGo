import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/app_managed_file_paths_io.dart';
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
  return _displayableVisitRecordPath(path) != null;
}

String? _displayableVisitRecordPath(String? path) {
  final value = path?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  if (value.startsWith('docs/sample_images/')) {
    return value;
  }
  return resolveExistingAppManagedFilePathSync(value);
}

String? _firstDisplayableVisitRecordPath(Iterable<String?> paths) {
  for (final path in paths) {
    final displayablePath = _displayableVisitRecordPath(path);
    if (displayablePath != null) {
      return displayablePath;
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
      return _placeholder();
    }

    if (resolvedPath.startsWith('docs/sample_images/')) {
      return Image.asset(
        resolvedPath,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }

    final resolvedFilePath =
        resolveExistingAppManagedFilePathSync(resolvedPath) ?? resolvedPath;
    final file = File(resolvedFilePath);
    if (!file.existsSync()) {
      return _placeholder();
    }

    return Image.file(file, fit: fit);
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.accentDark),
      ),
    );
  }
}
