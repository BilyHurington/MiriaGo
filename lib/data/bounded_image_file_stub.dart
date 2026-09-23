import 'dart:typed_data';
import 'bounded_image_decoder.dart';

String resolveBoundedImagePath(String path) => path;
Future<Uint8List> readBoundedImageFile(
  String path, {
  int maxBytes = maxImageEncodedBytes,
}) async {
  throw const ImageBudgetException(
    ImageBudgetFailure.unsupported,
    '此平台无法读取此本地图片；原件未更改',
  );
}
