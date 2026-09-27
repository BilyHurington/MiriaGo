import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../desktop/tauri_bridge.dart' as tauri;
import 'bounded_image_decoder.dart';
import 'image_bytes.dart';

class StoredUserReferenceImage {
  const StoredUserReferenceImage({
    required this.thumbnailPath,
    required this.fullImagePath,
  }) : _ownership = null;

  const StoredUserReferenceImage._owned(
    this._ownership, {
    required this.thumbnailPath,
    required this.fullImagePath,
  });

  final String thumbnailPath;
  final String fullImagePath;
  final _ReferenceOwnership? _ownership;

  Future<void> retain() async => _ownership?.retain();
}

class _ReferenceOwnership {
  _ReferenceOwnership(this.token);
  String? token;
  Future<void>? pending;
  bool retained = false;
  Future<void> retain() {
    retained = true;
    return pending ??= _finalize();
  }

  Future<void> _finalize() async {
    try {
      final value = token;
      if (value != null) {
        await tauri.finalizeDesktopImportAssets(restoreToken: value);
      }
      token = null;
    } finally {
      pending = null;
    }
  }

  Future<void> discard() => retained ? Future.value() : pending ??= _discard();
  Future<void> _discard() async {
    try {
      final value = token;
      if (value != null) {
        await tauri.cleanupDesktopImportAssets(restoreToken: value);
      }
      token = null;
    } finally {
      pending = null;
    }
  }
}

Future<StoredUserReferenceImage?> storeUserReferenceImage({
  required String sourcePath,
  required String pointId,
}) async {
  if (!tauri.isTauriLauncherAvailable) {
    return null;
  }

  final source = XFile(sourcePath);
  final length = await source.length();
  checkImageEncodedLength(length);
  // Web XFile.openRead converts one Blob slice, not streaming chunks. Check
  // length first and cap the slice itself before allocating Dart bytes.
  final bytes = await readImageStreamBounded(
    source.openRead(0, maxImageEncodedBytes + 1),
    declaredLength: length,
  );
  if (bytes.isEmpty) {
    return null;
  }

  final extension = _extensionForImage(sourcePath, bytes);
  final fullKey = 'assets/user_reference_images/full$extension';
  const thumbKey = 'assets/user_reference_images/thumb.jpg';
  final thumbnailBytes = await _buildThumbnail(bytes);
  // Existing Rust restore owns an exclusive directory and rolls back partial
  // writes. Neither pointId nor a caller-supplied path authorizes deletion.
  final restored = await tauri.restoreDesktopImportAssets(
    packageId: null,
    sourceName: pointId,
    assetsBase64: {
      fullKey: base64Encode(bytes),
      thumbKey: base64Encode(thumbnailBytes),
    },
  );
  final token = restored.restoreToken;
  final ownership = token == null ? null : _ReferenceOwnership(token);
  try {
    final fullPath = restored.restoredPaths[fullKey];
    final thumbPath = restored.restoredPaths[thumbKey];
    if (ownership == null || fullPath == null || thumbPath == null) {
      throw StateError(
        'Reference restore returned incomplete ownership or paths',
      );
    }
    return StoredUserReferenceImage._owned(
      ownership,
      thumbnailPath: thumbPath,
      fullImagePath: fullPath,
    );
  } catch (_) {
    await ownership?.discard();
    rethrow;
  }
}

Future<void> deleteStoredUserReferenceImage(
  StoredUserReferenceImage? image,
) async {
  await image?._ownership?.discard();
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
  if (isJpegBytes(bytes)) return '.jpg';
  if (isPngBytes(bytes)) return '.png';
  if (isWebpBytes(bytes)) return '.webp';
  if (bytes.length >= 6 &&
      String.fromCharCodes(bytes.take(6)).startsWith('GIF8')) {
    return '.gif';
  }
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
