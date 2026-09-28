import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('miriago/backup_exclusion');
final _excludedDirectories = <String>{};

/// Marks a directory of re-downloadable data as excluded from iCloud backup
/// (iOS only; Android uses backup rules in the manifest). Only caches that
/// can be fetched again belong here — never user photos or imported assets.
Future<void> excludeDirectoryFromBackup(String path) async {
  if (!Platform.isIOS || !_excludedDirectories.add(path)) return;
  try {
    await _channel.invokeMethod<bool>('excludeFromBackup', {'path': path});
  } on Object catch (error) {
    // Allow a retry on the next cache write.
    _excludedDirectories.remove(path);
    debugPrint('Could not exclude $path from backup: $error');
  }
}
