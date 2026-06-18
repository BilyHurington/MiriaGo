import 'dart:io';

Future<int?> localAssetSize(String? path) async {
  if (path == null || path.isEmpty) {
    return null;
  }
  try {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final length = await file.length();
    return length <= 0 ? null : length;
  } catch (_) {
    return null;
  }
}
