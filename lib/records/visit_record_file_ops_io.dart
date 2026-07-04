import 'dart:io';

import '../data/app_managed_file_paths_io.dart';

bool visitRecordLocalFileExists(String path) {
  final resolvedPath = resolveExistingAppManagedFilePathSync(path) ?? path;
  return File(resolvedPath).existsSync();
}

void deleteVisitRecordLocalFile(String path) {
  try {
    final resolvedPath = resolveExistingAppManagedFilePathSync(path) ?? path;
    File(resolvedPath).deleteSync();
  } catch (_) {}
}
