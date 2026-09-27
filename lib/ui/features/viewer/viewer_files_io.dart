import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<Uint8List?> readLocalViewerFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  return file.readAsBytes();
}

bool localViewerFileExists(String path) {
  try {
    return path.isNotEmpty && File(path).existsSync();
  } catch (_) {
    return false;
  }
}

Future<String?> writeTemporaryViewerImage(
  Uint8List bytes, {
  required String extension,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/seichi_image_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

Future<void> shareViewerFile(String path) async {
  await Share.shareXFiles([XFile(path)]);
}
