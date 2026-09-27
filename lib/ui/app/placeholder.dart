import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/theme.dart';

/// Temporary page used while a feature is under construction.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({required this.title, this.detail, super.key});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.construction_rounded, size: 40, color: c.textTertiary),
            const SizedBox(height: 12),
            Text(title, style: context.text.titleMedium),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(detail!, style: context.text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
