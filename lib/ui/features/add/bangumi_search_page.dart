import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class BangumiSearchPage extends StatelessWidget {
  const BangumiSearchPage({this.continueToImport = false, super.key});

  /// After adding a work, continue into its Anitabi map import.
  final bool continueToImport;

  @override
  Widget build(BuildContext context) =>
      const FeaturePlaceholder(title: '搜索 Bangumi');
}
