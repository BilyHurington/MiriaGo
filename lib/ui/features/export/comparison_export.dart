import 'package:flutter/material.dart';

import '../../../plan/pilgrimage_models.dart';

/// Opens the 「导出对比图」 adaptive panel for [record].
/// OWNER: feature agent E (records).
Future<void> showComparisonExport(
  BuildContext context, {
  required PilgrimageVisitRecord record,
}) async {}

/// Self-contained comparison export settings editor (loads and saves the
/// settings itself). Embedded by the 对比图设置 page.
/// OWNER: feature agent E (records).
class ComparisonExportSettingsPanel extends StatelessWidget {
  const ComparisonExportSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
