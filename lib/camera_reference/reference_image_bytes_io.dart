import 'dart:io';
import 'dart:typed_data';
import '../data/bounded_image_file_io.dart';

Future<Uint8List?> readReferenceImageBytes(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  return readBoundedImageFile(path);
}
