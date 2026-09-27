import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class AnitabiImportPage extends StatelessWidget {
  const AnitabiImportPage({this.bangumiId, this.pointId, super.key});
  final int? bangumiId;
  final String? pointId;

  @override
  Widget build(BuildContext context) =>
      const FeaturePlaceholder(title: '从作品地图导入');
}
