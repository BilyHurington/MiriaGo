import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class CameraPage extends StatelessWidget {
  const CameraPage({required this.pointId, super.key});
  final String pointId;

  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(title: '拍摄参考');
}
