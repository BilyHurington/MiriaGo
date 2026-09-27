import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class PointFormPage extends StatelessWidget {
  const PointFormPage({this.pointId, super.key});

  /// Null → create a new point; otherwise edit this point.
  final String? pointId;

  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(title: '添加点位');
}
