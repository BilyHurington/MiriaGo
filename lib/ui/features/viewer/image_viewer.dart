import 'dart:typed_data';

import 'package:flutter/material.dart';

/// One image in the full-screen viewer. Exactly one source should be set.
@immutable
class ViewerImage {
  const ViewerImage({this.bytes, this.path, this.url, this.label});

  final Uint8List? bytes;

  /// Local file path, desktop asset path, or bundled `docs/sample_images/…`.
  final String? path;

  /// Remote URL (loaded through the Anitabi image source).
  final String? url;

  /// e.g. 「参考图」「巡礼图」.
  final String? label;
}

/// Opens the full-screen image viewer (zoom, save/share original).
/// OWNER: feature agent F (settings/transfer/viewer).
Future<void> openImageViewer(
  BuildContext context, {
  required List<ViewerImage> images,
  int initialIndex = 0,
  Object? heroTag,
}) async {}
