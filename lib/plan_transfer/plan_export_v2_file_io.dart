import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'plan_export_v2.dart';

Future<String?> exportPlanV2PackageToFile(PlanExportV2Result package) async {
  final directory = await getTemporaryDirectory();
  final file = File(p.join(directory.path, package.fileName));
  await file.writeAsBytes(package.bytes, flush: true);
  return file.path;
}
