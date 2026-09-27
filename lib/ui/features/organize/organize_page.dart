import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class OrganizePage extends StatelessWidget {
  const OrganizePage({this.initialGroupId, super.key});
  final String? initialGroupId;

  @override
  Widget build(BuildContext context) =>
      const FeaturePlaceholder(title: '片区与点位');
}
