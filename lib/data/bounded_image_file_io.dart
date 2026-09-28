import 'dart:io';
import 'dart:typed_data';

import 'app_managed_file_paths_io.dart';
import 'bounded_image_decoder.dart';

String resolveBoundedImagePath(String path) =>
    resolveExistingAppManagedFilePathSync(path) ?? path;

Future<Uint8List> readBoundedImageFile(
  String path, {
  int maxBytes = maxImageEncodedBytes,
}) async {
  final file = File(resolveBoundedImagePath(path));
  if (!file.existsSync()) {
    throw FileSystemException('Image file is unavailable', path);
  }
  checkImageEncodedLength(await file.length(), maxBytes: maxBytes);
  return readImageStreamBounded(file.openRead(), maxBytes: maxBytes);
}
