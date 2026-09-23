import 'dart:typed_data';
import '../widgets/bounded_image.dart';

Future<Uint8List?> readReferenceImageBytes(String path) async {
  return readBoundedImageSource(path);
}
