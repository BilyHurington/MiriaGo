import 'package:flutter/services.dart';

import 'gallery_save_result.dart';

export 'gallery_save_result.dart';

Future<bool> saveImageToGallery(String filePath) async =>
    await saveImageToGalleryWithResult(filePath) == GallerySaveResult.saved;

Future<GallerySaveResult> saveImageToGalleryWithResult(String filePath) async {
  try {
    final result = await const MethodChannel(
      'seichi/gallery_saver',
    ).invokeMethod<String>('saveToGallery', {'filePath': filePath});
    return result != null ? GallerySaveResult.saved : GallerySaveResult.failed;
  } on PlatformException catch (error) {
    return galleryPermissionDeniedCodes.contains(error.code)
        ? GallerySaveResult.permissionDenied
        : GallerySaveResult.failed;
  } catch (_) {
    return GallerySaveResult.failed;
  }
}
