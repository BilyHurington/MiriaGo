import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class GradingPage extends StatelessWidget {
  const GradingPage({required this.recordId, super.key});
  final String recordId;

  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(title: '自动调色');
}
