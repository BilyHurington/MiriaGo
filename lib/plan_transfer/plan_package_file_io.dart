import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'plan_package.dart';

Future<String?> exportPlanPackageToFile(PlanPackage package) async {
  final directory = await getTemporaryDirectory();
  final safeName = package.plan.name
      .replaceAll(RegExp(r'[\\/:*?"<>|\\s]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileName =
      '${safeName.isEmpty ? 'miriago_plan' : safeName}_$timestamp.$seichiPlanFileExtension';
  final file = File(p.join(directory.path, fileName));
  await file.writeAsString(package.toJsonString(), flush: true);
  return file.path;
}

Future<PlanPackage> readPlanPackageFromPath(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw FileSystemException('Plan package file does not exist.', path);
  }
  return PlanPackage.fromJsonString(await file.readAsString());
}
