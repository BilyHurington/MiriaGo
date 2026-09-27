import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'bounded_image_decoder.dart';
import 'bounded_image_file_io.dart';
import 'image_bytes.dart';

class StoredUserReferenceImage {
  const StoredUserReferenceImage({
    required this.thumbnailPath,
    required this.fullImagePath,
  }) : _ownedDirectory = null;

  const StoredUserReferenceImage._owned(
    this._ownedDirectory, {
    required this.thumbnailPath,
    required this.fullImagePath,
  });

  final String thumbnailPath;
  final String fullImagePath;
  final String? _ownedDirectory;

  Future<void> retain() async {}
}

Future<StoredUserReferenceImage?> storeUserReferenceImage({
  required String sourcePath,
  required String pointId,
}) async {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    return null;
  }

  final bytes = await readBoundedImageFile(sourcePath);
  final thumbnailBytes = await _buildThumbnail(bytes);
  final documents = await getApplicationDocumentsDirectory();
  final root = Directory(p.join(documents.path, 'user_reference_images'));
  await root.create(recursive: true);
  final safePointId = _safeFileName(pointId);
  final extension = _extensionForImage(sourcePath, bytes);
  final owned = await root.createTemp('$safePointId-');
  final fullPath = p.join(owned.path, 'full$extension');
  final thumbPath = p.join(owned.path, 'thumb.jpg');
  try {
    await File(fullPath).writeAsBytes(bytes, flush: true);
    await File(thumbPath).writeAsBytes(thumbnailBytes, flush: true);
    return StoredUserReferenceImage._owned(
      owned.path,
      thumbnailPath: thumbPath,
      fullImagePath: fullPath,
    );
  } catch (error) {
    try {
      await owned.delete(recursive: true);
    } catch (cleanup) {
      throw FileSystemException(
        'Reference save failed: $error; cleanup failed: $cleanup',
        owned.path,
      );
    }
    rethrow;
  }
}

Future<void> deleteStoredUserReferenceImage(
  StoredUserReferenceImage? image,
) async {
  if (image == null) {
    return;
  }

  for (final path in {image.thumbnailPath, image.fullImagePath}) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup for abandoned reference selections.
    }
  }
  final ownedDirectory = image._ownedDirectory;
  if (ownedDirectory != null) {
    try {
      // Only remove the now-empty directory created by this store call.
      await Directory(ownedDirectory).delete();
    } catch (_) {
      // A replaced/nonempty directory must never be recursively removed here.
    }
  }
}

Future<Uint8List> _buildThumbnail(Uint8List bytes) async {
  final image = await decodeBoundedImage(
    bytes,
    target: const ImageDecodeTarget(maxEdge: 360, maxPixels: 360 * 360),
  );
  try {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) {
      throw StateError('Cannot read reference thumbnail pixels');
    }
    return await compute(_encodeThumbnail, {
      'width': image.width,
      'height': image.height,
      'bytes': data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    });
  } finally {
    image.dispose();
  }
}

Uint8List _encodeThumbnail(Map<String, Object> input) {
  final bytes = input['bytes']! as Uint8List;
  final image = img.Image.fromBytes(
    width: input['width']! as int,
    height: input['height']! as int,
    bytes: bytes.buffer,
    bytesOffset: bytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: 82));
}

String _extensionForImage(String sourcePath, List<int> bytes) {
  if (isPngBytes(bytes)) return '.png';
  if (isJpegBytes(bytes)) return '.jpg';
  if (isWebpBytes(bytes)) return '.webp';
  if (bytes.length >= 6 &&
      String.fromCharCodes(bytes.take(6)).startsWith('GIF8')) {
    return '.gif';
  }
  final extension = p.extension(sourcePath).toLowerCase();
  if (const {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
    '.gif',
  }.contains(extension)) {
    return extension == '.jpeg' ? '.jpg' : extension;
  }

  return '.jpg';
}

String _safeFileName(String value) {
  final safe = value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
  return safe.length <= 64 ? safe : safe.substring(0, 64);
}
