import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'image_bytes.dart';

const maxImageEncodedBytes = 32 * 1024 * 1024;
const maxImageSourcePixels = 16000000;
const maxImageSourceEdge = 16384;

@visibleForTesting
void Function()? debugOnImageRasterDecode;

enum ImageBudgetFailure {
  encodedBytes,
  sourcePixels,
  targetPixels,
  unsupported,
  invalidData,
}

class ImageBudgetException implements Exception {
  const ImageBudgetException(this.kind, this.message);
  final ImageBudgetFailure kind;
  final String message;
  @override
  String toString() => message;
}

class BoundedImageInfo {
  const BoundedImageInfo(this.width, this.height);
  final int width;
  final int height;
}

class ImageDecodeTarget {
  const ImageDecodeTarget({required this.maxEdge, required this.maxPixels});
  final int maxEdge;
  final int maxPixels;
  static const list = ImageDecodeTarget(maxEdge: 512, maxPixels: 262144);
  static const panel = ImageDecodeTarget(maxEdge: 1600, maxPixels: 2000000);
  static const preview = ImageDecodeTarget(maxEdge: 2560, maxPixels: 4000000);
  static const sample = ImageDecodeTarget(maxEdge: 256, maxPixels: 65536);
  static const grading = ImageDecodeTarget(maxEdge: 4096, maxPixels: 12000000);

  BoundedImageInfo dimensions(BoundedImageInfo source) {
    if (maxEdge <= 0 || maxPixels <= 0) {
      throw ArgumentError('Invalid decode target');
    }
    final scale = math.min(
      1.0,
      math.min(
        maxEdge / math.max(source.width, source.height),
        math.sqrt(maxPixels / (source.width * source.height)),
      ),
    );
    final width = math.min(
      maxPixels,
      math.max(1, (source.width * scale).floor()),
    );
    final height = math.min(
      maxPixels ~/ width,
      math.max(1, (source.height * scale).floor()),
    );
    return BoundedImageInfo(width, height);
  }
}

void checkImageEncodedLength(
  int length, {
  int maxBytes = maxImageEncodedBytes,
}) {
  if (length > maxBytes) {
    throw ImageBudgetException(
      ImageBudgetFailure.encodedBytes,
      '图片文件 $length 字节超过读取预算 $maxBytes 字节；原件未更改，可保存或导出原件',
    );
  }
}

Future<Uint8List> readImageStreamBounded(
  Stream<List<int>> stream, {
  int maxBytes = maxImageEncodedBytes,
  int? declaredLength,
}) async {
  if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
  if (declaredLength != null && declaredLength > maxBytes) {
    await stream.listen(null).cancel();
    checkImageEncodedLength(declaredLength, maxBytes: maxBytes);
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    checkImageEncodedLength(builder.length + chunk.length, maxBytes: maxBytes);
    builder.add(chunk);
  }
  return builder.takeBytes();
}

BoundedImageInfo _checked(int width, int height) {
  if (width <= 0 || height <= 0) {
    throw const ImageBudgetException(
      ImageBudgetFailure.invalidData,
      '无法读取图片尺寸',
    );
  }
  if (width > maxImageSourceEdge ||
      height > maxImageSourceEdge ||
      width > maxImageSourcePixels ~/ height) {
    throw ImageBudgetException(
      ImageBudgetFailure.sourcePixels,
      '图片 $width x $height 超过来源预算（16000000 像素，单边 16384）；原件未更改，可保存或导出原件',
    );
  }
  return BoundedImageInfo(width, height);
}

// No raster decoder is used for header probing. In particular, image's JPEG
// startDecode/readInfo allocates DCT blocks and must not be used here.
BoundedImageInfo? _header(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  Never invalid() => throw const ImageBudgetException(
    ImageBudgetFailure.invalidData,
    '图片尺寸元数据无效或不一致；原件未更改',
  );
  int le24(int n) => bytes[n] | bytes[n + 1] << 8 | bytes[n + 2] << 16;
  if (isPngBytes(bytes)) {
    if (bytes.length < 33 ||
        data.getUint32(8) != 13 ||
        data.getUint32(12) != 0x49484452) {
      invalid();
    }
    final info = _checked(data.getUint32(16), data.getUint32(20));
    var ended = false;
    var chunks = 0;
    for (var offset = 8; offset < bytes.length;) {
      if (++chunks > 65536) invalid();
      if (offset + 12 > bytes.length) invalid();
      final size = data.getUint32(offset);
      if (size > bytes.length - offset - 12) invalid();
      final type = data.getUint32(offset + 4);
      if (type == 0x49484452 && offset != 8) invalid();
      if (type == 0x6163544c &&
          (size != 8 || data.getUint32(offset + 8) == 0)) {
        invalid();
      }
      if (type == 0x6663544c) {
        if (size != 26) invalid();
        final frame = _checked(
          data.getUint32(offset + 12),
          data.getUint32(offset + 16),
        );
        if (frame.width + data.getUint32(offset + 20) > info.width ||
            frame.height + data.getUint32(offset + 24) > info.height) {
          invalid();
        }
      }
      offset += size + 12;
      if (type == 0x49454e44) {
        if (size != 0 || offset != bytes.length) invalid();
        ended = true;
      }
    }
    if (!ended) invalid();
    return info;
  }
  if (isJpegBytes(bytes)) {
    BoundedImageInfo? info;
    var offset = 2;
    var scan = false;
    var ended = false;
    while (offset < bytes.length) {
      if (scan) {
        while (offset < bytes.length && bytes[offset] != 0xff) {
          offset++;
        }
      }
      if (offset >= bytes.length || bytes[offset++] != 0xff) invalid();
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset >= bytes.length) invalid();
      final marker = bytes[offset++];
      if (scan && (marker == 0 || (marker >= 0xd0 && marker <= 0xd7))) continue;
      scan = false;
      if (marker == 0xd9) {
        ended = true;
        break;
      }
      if (marker == 0x01) continue;
      if (marker == 0xdc || marker == 0xd8) {
        invalid(); // No deferred dimensions or second image.
      }
      if (offset + 2 > bytes.length) invalid();
      final size = data.getUint16(offset);
      if (size < 2 || size > bytes.length - offset) invalid();
      if (marker >= 0xc0 &&
          marker <= 0xcf &&
          ![0xc4, 0xc8, 0xcc].contains(marker)) {
        if (size < 8 || info != null) invalid();
        info = _checked(data.getUint16(offset + 5), data.getUint16(offset + 3));
      }
      if (marker == 0xda) {
        if (info == null) invalid();
        scan = true;
      }
      offset += size;
    }
    if (info == null || !ended) invalid();
    final orientation = img.decodeJpgExif(bytes)?.imageIfd.orientation ?? 1;
    return orientation >= 5 && orientation <= 8
        ? BoundedImageInfo(info.height, info.width)
        : info;
  }
  if (isWebpBytes(bytes)) {
    if (data.getUint32(4, Endian.little) != bytes.length - 8) invalid();
    BoundedImageInfo? canvas;
    var payloads = 0;
    var animated = false;
    BoundedImageInfo payload(int type, int start, int size) {
      if (type == 0x5650384c && size >= 5 && bytes[start] == 0x2f) {
        final bits = data.getUint32(start + 1, Endian.little);
        return _checked((bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1);
      }
      if (type == 0x56503820 && size >= 10 && le24(start + 3) == 0x2a019d) {
        return _checked(
          data.getUint16(start + 6, Endian.little) & 0x3fff,
          data.getUint16(start + 8, Endian.little) & 0x3fff,
        );
      }
      invalid();
    }

    for (var offset = 12; offset < bytes.length;) {
      if (offset + 8 > bytes.length) invalid();
      final size = data.getUint32(offset + 4, Endian.little);
      if (size > bytes.length - offset - 8) invalid();
      final type = data.getUint32(offset);
      final start = offset + 8;
      if (type == 0x56503858) {
        if (size != 10 || offset != 12 || canvas != null) invalid();
        canvas = _checked(le24(start + 4) + 1, le24(start + 7) + 1);
        animated = bytes[start] & 2 != 0;
      } else if (type == 0x5650384c || type == 0x56503820) {
        if (animated || payloads++ != 0) invalid();
        final dims = payload(type, start, size);
        if (canvas != null &&
            (canvas.width != dims.width || canvas.height != dims.height)) {
          invalid();
        }
        canvas = dims;
      } else if (type == 0x414e4d46) {
        if (!animated || canvas == null || size < 16) invalid();
        final frame = _checked(le24(start + 6) + 1, le24(start + 9) + 1);
        if (le24(start) * 2 + frame.width > canvas.width ||
            le24(start + 3) * 2 + frame.height > canvas.height) {
          invalid();
        }
        var found = false;
        for (var sub = start + 16; sub < start + size;) {
          if (sub + 8 > start + size) invalid();
          final length = data.getUint32(sub + 4, Endian.little);
          if (length > start + size - sub - 8) invalid();
          final tag = data.getUint32(sub);
          if (tag == 0x5650384c || tag == 0x56503820) {
            if (found) invalid();
            final dims = payload(tag, sub + 8, length);
            if (dims.width != frame.width || dims.height != frame.height) {
              invalid();
            }
            found = true;
          }
          sub += 8 + length + (length & 1);
        }
        if (!found) invalid();
        payloads++;
      }
      offset += 8 + size + (size & 1);
      if (offset > bytes.length) invalid();
    }
    if (canvas == null || payloads == 0) invalid();
    return canvas;
  }
  if (bytes.length >= 13 &&
      String.fromCharCodes(bytes.sublist(0, 6)).startsWith('GIF8')) {
    final info = _checked(
      data.getUint16(6, Endian.little),
      data.getUint16(8, Endian.little),
    );
    var offset = 13;
    if (bytes[10] & 128 != 0) offset += 3 * (1 << ((bytes[10] & 7) + 1));
    void blocks() {
      while (true) {
        if (offset >= bytes.length) invalid();
        final length = bytes[offset++];
        if (length == 0) return;
        offset += length;
        if (offset > bytes.length) invalid();
      }
    }

    while (offset < bytes.length) {
      final tag = bytes[offset++];
      if (tag == 0x3b) return info;
      if (tag == 0x21) {
        if (offset >= bytes.length) invalid();
        offset++;
        blocks();
      } else if (tag == 0x2c) {
        if (offset + 9 > bytes.length) invalid();
        final frame = _checked(
          data.getUint16(offset + 4, Endian.little),
          data.getUint16(offset + 6, Endian.little),
        );
        if (frame.width + data.getUint16(offset, Endian.little) > info.width ||
            frame.height + data.getUint16(offset + 2, Endian.little) >
                info.height) {
          invalid();
        }
        final packed = bytes[offset + 8];
        offset += 9;
        if (packed & 128 != 0) offset += 3 * (1 << ((packed & 7) + 1));
        if (offset >= bytes.length) invalid();
        offset++; // LZW code size, followed by bounded sub-blocks.
        blocks();
      } else {
        invalid();
      }
    }
    invalid();
  }
  return null;
}

Future<BoundedImageInfo> probeBoundedImage(Uint8List bytes) async {
  checkImageEncodedLength(bytes.length);
  final info = _header(bytes);
  if (info != null) return info;
  // Apple's ImageIO generator reads properties before creating a raster image.
  // Do not assume the same metadata-only contract on Web/other platforms.
  final apple =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  final heif =
      bytes.length >= 12 &&
      ByteData.sublistView(bytes).getUint32(4) == 0x66747970 &&
      [
        'heic',
        'heix',
        'hevc',
        'hevx',
        'mif1',
        'msf1',
      ].contains(String.fromCharCodes(bytes.sublist(8, 12)));
  if (!apple || !heif) {
    throw const ImageBudgetException(
      ImageBudgetFailure.unsupported,
      '此平台暂不能安全预览此图片格式；原件未更改',
    );
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return _checked(descriptor.width, descriptor.height);
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// Caller owns the returned image. Targets bound retained output, not native
/// decoder peak memory; the separate source gate is mandatory on every call.
Future<ui.Image> decodeBoundedImage(
  Uint8List bytes, {
  required ImageDecodeTarget target,
}) async {
  final info = await probeBoundedImage(bytes);
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    // Web's encoded ImageDescriptor does not expose dimensions. Its source
    // gate is the strict complete header/animation-frame validation above.
    final actual = kIsWeb
        ? info
        : _checked(descriptor.width, descriptor.height);
    if (!((actual.width == info.width && actual.height == info.height) ||
        (actual.width == info.height && actual.height == info.width))) {
      throw const ImageBudgetException(
        ImageBudgetFailure.invalidData,
        '图片尺寸元数据不一致；原件未更改',
      );
    }
    // Header dimensions already include EXIF display orientation. A descriptor
    // may expose either storage or display dimensions; neither permits rotating
    // the pixels a second time or choosing the wrong target aspect ratio.
    final size = target.dimensions(info);
    codec = await descriptor.instantiateCodec(
      targetWidth: size.width,
      targetHeight: size.height,
    );
    // Flutter's multi-frame codec ignores target dimensions. Reject before the
    // first raster frame rather than decoding a full canvas then resizing it.
    if (codec.frameCount > 1 &&
        (actual.width > size.width || actual.height > size.height)) {
      throw const ImageBudgetException(
        ImageBudgetFailure.targetPixels,
        '动画首帧尺寸超过此处理预算；原件未更改',
      );
    }
    assert(() {
      debugOnImageRasterDecode?.call();
      return true;
    }());
    final frame = await codec.getNextFrame();
    if (frame.image.width > target.maxEdge ||
        frame.image.height > target.maxEdge ||
        frame.image.width * frame.image.height > target.maxPixels) {
      frame.image.dispose();
      throw const ImageBudgetException(
        ImageBudgetFailure.targetPixels,
        '平台无法满足图片处理尺寸预算',
      );
    }
    return frame.image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}
