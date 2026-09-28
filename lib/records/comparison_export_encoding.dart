import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'comparison_export_config.dart';

class EncodedComparisonImage {
  const EncodedComparisonImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.encoding,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final ComparisonImageEncoding encoding;
  String get extension => encoding.extension;
  String get mimeType => encoding.mimeType;
}

// Ownership transfers here; release the engine raster before CPU encoding.
Future<EncodedComparisonImage> encodeAndDisposeComparisonImage(
  ui.Image image,
  ComparisonImageEncoding encoding,
) async {
  final png = encoding == ComparisonImageEncoding.png;
  final width = image.width;
  final height = image.height;
  ByteData? data;
  try {
    data = await image.toByteData(
      format: png ? ui.ImageByteFormat.png : ui.ImageByteFormat.rawStraightRgba,
    );
  } finally {
    image.dispose();
  }
  if (data == null) throw StateError('Could not read comparison pixels');
  final pixels = data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  final bytes = png
      ? pixels
      : await compute(_encodeJpeg, (
          pixels,
          width,
          height,
          encoding.jpegQuality!,
        ));
  return EncodedComparisonImage(
    bytes: bytes,
    width: width,
    height: height,
    encoding: encoding,
  );
}

Uint8List _encodeJpeg((Uint8List, int, int, int) request) {
  final (pixels, width, height, quality) = request;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: pixels.buffer,
    bytesOffset: pixels.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  image.backgroundColor = img.ColorRgb8(255, 255, 255);
  return img.encodeJpg(image, quality: quality);
}
