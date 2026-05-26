import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    return null;
  }

  final documents = await getApplicationDocumentsDirectory();
  final fullDirectory = Directory(
    p.join(documents.path, 'user_reference_images', 'full'),
  );
  final thumbDirectory = Directory(
    p.join(documents.path, 'user_reference_images', 'thumb'),
  );
  fullDirectory.createSync(recursive: true);
  thumbDirectory.createSync(recursive: true);

  final bytes = await sourceFile.readAsBytes();
  final safePointId = _safeFileName(pointId);
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final extension = _extensionForImage(sourcePath, bytes);
  final fullPath = p.join(fullDirectory.path, '$safePointId-$stamp$extension');
  final thumbPath = p.join(thumbDirectory.path, '$safePointId-$stamp.jpg');

  await File(fullPath).writeAsBytes(bytes, flush: true);
  final thumbnailBytes = _buildThumbnail(bytes);
  await File(thumbPath).writeAsBytes(thumbnailBytes, flush: true);

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
  final extension = p.extension(sourcePath).toLowerCase();
  if (const {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)) {
    return extension == '.jpeg' ? '.jpg' : extension;
  }

  return '.jpg';
}

String _safeFileName(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
}
