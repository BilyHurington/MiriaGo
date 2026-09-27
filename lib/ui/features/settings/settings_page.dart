import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({this.section, super.key});

  /// Selected section id (see settings routes); null → overview.
  final String? section;

  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(title: '设置');
}
