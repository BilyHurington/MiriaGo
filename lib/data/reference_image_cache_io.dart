import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../plan/pilgrimage_models.dart';
import 'anitabi_image_fetcher.dart';
import 'anitabi_image_url.dart';
import 'app_managed_file_paths_io.dart';
import 'image_bytes.dart';

Future<String?> cacheReferenceThumbnail(
  PilgrimagePoint point, {
  AnitabiImageSource imageSource = AnitabiImageSource.auto,
}) async {
  final url = point.referenceImageUrl;
  if (url == null || url.isEmpty) {
    return null;
  }

  final thumbnailUrl = anitabiThumbnailImageUrl(url);
  if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
    return null;
  }
  return _cacheImage(
    url: thumbnailUrl,
    imageSource: imageSource,
    namespace: 'reference_thumbnails',
    filename:
        '${_stableUrlHash(thumbnailUrl)}${_extensionFromUrl(thumbnailUrl)}',
  );
}

Future<String?> ensureReferenceThumbnailCached(
  PilgrimagePoint point, {
  AnitabiImageSource imageSource = AnitabiImageSource.auto,
}) async {
  final thumbnailUrl = anitabiThumbnailImageUrl(point.referenceImageUrl);
  final existingPath = resolveExistingAppManagedFilePathSync(
    point.referenceThumbnailPath,
  );
  if (existingPath != null &&
      thumbnailUrl != null &&
      (_cachedPathMatchesUrl(existingPath, thumbnailUrl) ||
          _isImportedThumbnailPath(existingPath))) {
    final file = File(existingPath);
    if (file.existsSync() && file.lengthSync() > 0) {
      return existingPath;
    }
  }
  return cacheReferenceThumbnail(point, imageSource: imageSource);
}

Future<String?> cacheReferenceFullImage(
  PilgrimagePoint point, {
  AnitabiImageSource imageSource = AnitabiImageSource.auto,
}) async {
  final url = anitabiFullResolutionImageUrl(point.referenceImageUrl);
  if (url == null || url.isEmpty) {
    return null;
  }

  return _cacheImage(
    url: url,
    imageSource: imageSource,
    namespace: 'reference_full',
    filename: '${_stableUrlHash(url)}${_extensionFromUrl(url)}',
  );
}

Future<String?> _cacheImage({
  required String url,
  required AnitabiImageSource imageSource,
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
  final cachedFile = await _findValidCachedFile(
    cacheDirectory,
    urlHash: _stableUrlHash(url),
    preferredFile: file,
  );
  if (cachedFile != null) {
    return cachedFile.path;
  }

  final bytes = await fetchAnitabiImageBytes(url, source: imageSource);
  if (bytes == null || !isSupportedImageBytes(bytes)) {
    return null;
  }

  await file.writeAsBytes(bytes, flush: true);
  return path;
}

Future<File?> _findValidCachedFile(
  Directory directory, {
  required String urlHash,
  required File preferredFile,
}) async {
  final candidates = <File>[
    preferredFile,
    if (directory.existsSync())
      ...directory
          .listSync(followLinks: false)
          .whereType<File>()
          .where((file) => p.basename(file.path).contains(urlHash)),
  ];
  final visited = <String>{};
  for (final candidate in candidates) {
    if (!visited.add(candidate.path) || !candidate.existsSync()) {
      continue;
    }
    final bytes = await candidate.readAsBytes();
    if (bytes.isNotEmpty && isSupportedImageBytes(bytes)) {
      return candidate;
    }
    await candidate.delete();
  }
  return null;
}

String _stableUrlHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

bool _cachedPathMatchesUrl(String path, String url) {
  return p.basename(path).contains(_stableUrlHash(url));
}

bool _isImportedThumbnailPath(String path) {
  final normalized = path.replaceAll(r'\', '/').toLowerCase();
  return normalized.contains('/imported_plan_assets/') &&
      normalized.contains('/assets/thumbnails/');
}

String _extensionFromUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? '';
  final extension = p.extension(path).toLowerCase();
  return extension.isEmpty ? '.jpg' : extension;
}
