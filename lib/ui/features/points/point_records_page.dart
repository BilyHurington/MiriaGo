import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class PointRecordsPage extends StatelessWidget {
  const PointRecordsPage({required this.pointId, super.key});
  final String pointId;

  @override
  Widget build(BuildContext context) =>
      const FeaturePlaceholder(title: '点位拍摄记录');
}
