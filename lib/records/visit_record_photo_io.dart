import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';

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
    if (path.startsWith('docs/sample_images/')) {
      return Image.asset(
        path,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          color: AppColors.surfaceMuted,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.accentDark,
            ),
          ),
        ),
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      return ColoredBox(
        color: AppColors.surfaceMuted,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.accentDark),
        ),
      );
    }

    return Image.file(file, fit: fit);
  }
}
