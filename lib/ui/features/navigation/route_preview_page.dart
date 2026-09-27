import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class RoutePreviewPage extends StatelessWidget {
  const RoutePreviewPage({required this.pointId, super.key});
  final String pointId;

  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(title: '确认路线');
}
