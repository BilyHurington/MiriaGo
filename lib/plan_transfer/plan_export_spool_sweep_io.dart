import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Prefix of the temporary folders `PlanExportAssetSpool` creates.
const planExportSpoolPrefix = 'miriago_export_';

/// Startup sweep for export spool folders left behind when the app was
/// killed mid-export. Only folders older than [maxAge] are removed, so an
/// export running in another window (desktop) is never touched.
Future<void> sweepStaleExportSpools({
  Duration maxAge = const Duration(hours: 1),
}) async {
  try {
    final cutoff = DateTime.now().subtract(maxAge);
    await for (final entry in Directory.systemTemp.list(followLinks: false)) {
      if (entry is! Directory ||
          !p.basename(entry.path).startsWith(planExportSpoolPrefix)) {
        continue;
      }
      if (!(await entry.stat()).modified.isBefore(cutoff)) {
        continue;
      }
      try {
        await entry.delete(recursive: true);
      } on FileSystemException {
        // Try again on a later start.
      }
    }
  } on Object catch (error) {
    debugPrint('Export spool sweep skipped: $error');
  }
}
