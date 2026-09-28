import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import '../data/bounded_image_decoder.dart';
import '../widgets/bounded_image.dart';
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
  final managedPath = resolveExistingAppManagedFilePathSync(value);
  if (managedPath != null) {
    return managedPath;
  }
  return File(value).existsSync() ? value : null;
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
  const VisitRecordPhoto({
    this.path,
    this.fit = BoxFit.cover,
    this.target = ImageDecodeTarget.list,
    super.key,
  });

  final String? path;
  final BoxFit fit;
  final ImageDecodeTarget target;

  @override
  Widget build(BuildContext context) {
    final resolvedPath = path?.trim();
    if (resolvedPath == null || resolvedPath.isEmpty) {
      return _placeholder();
    }

    return BoundedImage(path: resolvedPath, fit: fit, target: target);
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(LucideIcons.imageOff, color: AppColors.accentDark),
      ),
    );
  }
}
