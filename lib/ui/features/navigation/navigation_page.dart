import 'package:flutter/material.dart';

import '../../app/placeholder.dart';

class NavigationPage extends StatelessWidget {
  const NavigationPage({required this.args, super.key});

  /// Opaque arguments produced by RoutePreviewPage.
  final Object args;

  @override
  Widget build(BuildContext context) =>
      const FeaturePlaceholder(title: '应用内导航');
}
