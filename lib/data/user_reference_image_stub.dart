import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../desktop/tauri_bridge.dart' as tauri;

class StoredUserReferenceImage {
  const StoredUserReferenceImage({
    required this.thumbnailPath,
    required this.fullImagePath,
  });

  final String thumbnailPath;
  final String fullImagePath;
}

Future<StoredUserReferenceImage?> storeUserReferenceImage({
  required String sourcePath,
  required String pointId,
}) async {
  if (!tauri.isTauriLauncherAvailable) {
    return null;
  }

  final bytes = await XFile(sourcePath).readAsBytes();
  if (bytes.isEmpty) {
    return null;
  }

  final safePointId = _safeFileName(pointId);
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final extension = _extensionForImage(sourcePath, bytes);
  final fullPath =
      'assets/user_reference_images/full/$safePointId-$stamp$extension';
  final thumbPath =
      'assets/user_reference_images/thumb/$safePointId-$stamp.jpg';
  final thumbnailBytes = _buildThumbnail(bytes);

  await tauri.writeDesktopAsset(
    path: fullPath,
    dataBase64: base64Encode(bytes),
  );
  await tauri.writeDesktopAsset(
    path: thumbPath,
    dataBase64: base64Encode(thumbnailBytes),
  );

  return StoredUserReferenceImage(
    thumbnailPath: thumbPath,
    fullImagePath: fullPath,
  );
}

List<int> _buildThumbnail(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return bytes;
  }

  final thumbnail = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? 360 : null,
    height: decoded.height > decoded.width ? 360 : null,
    interpolation: img.Interpolation.average,
  );
  return img.encodeJpg(thumbnail, quality: 82);
}

String _extensionForImage(String sourcePath, List<int> bytes) {
  final path = Uri.tryParse(sourcePath)?.path ?? sourcePath;
  final dotIndex = path.lastIndexOf('.');
  if (dotIndex >= 0 && dotIndex < path.length - 1) {
    final extension = path.substring(dotIndex).toLowerCase();
    if (const {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)) {
      return extension == '.jpeg' ? '.jpg' : extension;
    }
  }

  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return '.webp';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return '.png';
  }
  return '.jpg';
}

String _safeFileName(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
}
