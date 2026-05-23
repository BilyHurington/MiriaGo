import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'camera_reference/camera_reference_screen.dart';

void main() {
  runApp(const SeichiJunreiHelperApp());
}

class SeichiJunreiHelperApp extends StatelessWidget {
  const SeichiJunreiHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '圣地巡礼助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const CameraReferenceScreen(),
    );
  }
}
