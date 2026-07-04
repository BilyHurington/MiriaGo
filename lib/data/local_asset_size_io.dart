import 'dart:io';

import 'app_managed_file_paths_io.dart';

Future<int?> localAssetSize(String? path) async {
  if (path == null || path.isEmpty) {
    return null;
  }
  try {
    final resolvedPath =
        await resolveAppManagedFilePath(
          path,
        ).then((resolution) => resolution.resolvedPath) ??
        path;
    final file = File(resolvedPath);
    if (!file.existsSync()) {
      return null;
    }
    final length = await file.length();
    return length <= 0 ? null : length;
  } catch (_) {
    return null;
  }
}
