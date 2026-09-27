import 'package:flutter/material.dart';
import '../../../plan_transfer/plan_import_package.dart';
import '../../app/placeholder.dart';

class ImportPreviewPage extends StatelessWidget {
  const ImportPreviewPage({required this.package, super.key});
  final PlanImportPackage package;

  @override
  Widget build(BuildContext context) => const FeaturePlaceholder(title: '导入内容');
}

/// Shows the import preview for [package]. Returns true when imported.
/// OWNER: feature agent F.
Future<bool> openImportPreview(
  BuildContext context,
  PlanImportPackage package,
) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => ImportPreviewPage(package: package),
    ),
  );
  return result == true;
}
