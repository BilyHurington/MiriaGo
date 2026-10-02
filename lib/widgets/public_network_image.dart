import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import '../data/bounded_image_decoder.dart';
import '../data/public_http.dart';

/// A network image for URLs that come from plan data. On native platforms
/// every redirect is checked, so a public address cannot bounce the request
/// into this device or the local network ([NetworkImage] follows redirects
/// unchecked). Browsers apply their own rules, so the web keeps
/// [NetworkImage].
ImageProvider publicNetworkImage(String url, {int? cacheWidth}) {
  if (kIsWeb) {
    return ResizeImage.resizeIfNeeded(cacheWidth, null, NetworkImage(url));
  }
  return PublicNetworkImage(url, cacheWidth: cacheWidth);
}

@immutable
class PublicNetworkImage extends ImageProvider<PublicNetworkImage> {
  const PublicNetworkImage(this.url, {this.cacheWidth});

  static const timeout = Duration(seconds: 20);

  final String url;

  /// Decodes at most this wide (keeping the aspect ratio). Handled here
  /// rather than by wrapping in [ResizeImage], so a failed load evicts the
  /// very cache entry it was stored under.
  final int? cacheWidth;

  @override
  Future<PublicNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    PublicNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1,
      debugLabel: url,
      informationCollector: () => [DiagnosticsProperty('URL', url)],
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final uri = Uri.parse(url);
    final client = http.Client();
    try {
      final response = await sendPublicGet(
        client,
        uri,
        allowHttp: true,
      ).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.listen(null).cancel();
        throw NetworkImageLoadException(
          statusCode: response.statusCode,
          uri: uri,
        );
      }
      final bytes = await readImageStreamBounded(
        response.stream.timeout(timeout),
        declaredLength: response.contentLength,
      );
      final width = cacheWidth;
      return decode(
        await ui.ImmutableBuffer.fromUint8List(bytes),
        getTargetSize: width == null
            ? null
            : (intrinsicWidth, intrinsicHeight) => width >= intrinsicWidth
                  ? ui.TargetImageSize(
                      width: intrinsicWidth,
                      height: intrinsicHeight,
                    )
                  : ui.TargetImageSize(width: width),
      );
    } catch (_) {
      // Let a later build try again instead of caching the failure.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(this);
      });
      rethrow;
    } finally {
      client.close();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PublicNetworkImage &&
      other.url == url &&
      other.cacheWidth == cacheWidth;

  @override
  int get hashCode => Object.hash(url, cacheWidth);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'PublicNetworkImage')}("$url", '
      'cacheWidth: $cacheWidth)';
}
