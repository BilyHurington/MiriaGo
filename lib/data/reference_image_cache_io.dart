import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../plan/pilgrimage_models.dart';
import 'anitabi_image_url.dart';

Future<String?> cacheReferenceThumbnail(PilgrimagePoint point) async {
  final url = point.referenceImageUrl;
  if (url == null || url.isEmpty) {
    return null;
  }

  final thumbnailUrl = _thumbnailUrl(url);
  return _cacheImage(
    url: thumbnailUrl,
    namespace: 'reference_thumbnails',
    filename:
        '${_safeFileName(point.id)}_${_stableUrlHash(thumbnailUrl)}${_extensionFromUrl(thumbnailUrl)}',
  );
}

Future<String?> cacheReferenceFullImage(PilgrimagePoint point) async {
  final url = anitabiFullResolutionImageUrl(point.referenceImageUrl);
  if (url == null || url.isEmpty) {
    return null;
  }

  return _cacheImage(
    url: url,
    namespace: 'reference_full',
    filename:
        '${_safeFileName(point.id)}_${_stableUrlHash(url)}${_extensionFromUrl(url)}',
  );
}

Future<String?> _cacheImage({
  required String url,
  required String namespace,
  required String filename,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final cacheDirectory = Directory(p.join(directory.path, namespace));
  if (!cacheDirectory.existsSync()) {
    cacheDirectory.createSync(recursive: true);
  }

  final path = p.join(cacheDirectory.path, filename);
  final file = File(path);
  if (file.existsSync() && file.lengthSync() > 0) {
    return path;
  }

  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return null;
  }

  await file.writeAsBytes(response.bodyBytes, flush: true);
  return path;
}

String _thumbnailUrl(String url) {
  final fullUrl = anitabiFullResolutionImageUrl(url);
  if (fullUrl == null || fullUrl.isEmpty) {
    return url;
  }

  final uri = Uri.tryParse(fullUrl);
  if (uri == null || uri.host != 'image.anitabi.cn') {
    return fullUrl;
  }

  return uri
      .replace(queryParameters: {...uri.queryParameters, 'plan': 'h160'})
      .toString();
}

String _safeFileName(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
}

String _stableUrlHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _extensionFromUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? '';
  final extension = p.extension(path).toLowerCase();
  return extension.isEmpty ? '.jpg' : extension;
}
