import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class AnchorPickerPage extends StatelessWidget {
  const AnchorPickerPage({required this.groupId, super.key});
  final String groupId;

  @override
  Widget build(BuildContext context) =>
      const FeaturePlaceholder(title: '选择关键点');
}
