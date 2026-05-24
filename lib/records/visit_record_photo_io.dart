import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';

class VisitRecordPhoto extends StatelessWidget {
  const VisitRecordPhoto({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const ColoredBox(
        color: AppColors.surfaceMuted,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.accentDark),
        ),
      );
    }

    return Image.file(file, fit: BoxFit.cover);
  }
}
