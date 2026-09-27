import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class RecordDetailPage extends StatelessWidget {
  const RecordDetailPage({required this.recordId, super.key});
  final String recordId;

  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(title: '记录详情');
}
