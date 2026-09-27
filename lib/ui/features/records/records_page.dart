import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({this.selectedRecordId, super.key});
  final String? selectedRecordId;

  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(title: '记录');
}
