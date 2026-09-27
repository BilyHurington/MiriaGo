import 'package:flutter/services.dart';

Future<bool> saveImageToGallery(String filePath) async {
  try {
    final result = await const MethodChannel(
      'seichi/gallery_saver',
    ).invokeMethod<String>('saveToGallery', {'filePath': filePath});
    return result != null;
  } catch (_) {
    return false;
  }
}
