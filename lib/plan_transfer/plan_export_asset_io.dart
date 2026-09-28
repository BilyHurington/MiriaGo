import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../data/anitabi_image_fetcher.dart';
import '../data/anitabi_image_url.dart';
import '../data/app_managed_file_paths_io.dart';
import '../data/image_bytes.dart';
import '../data/public_http.dart';
import '../data/reference_asset_paths.dart';
import 'plan_export_spool_sweep_io.dart';
import 'plan_export_zip_source.dart';

const _exportNetworkTimeout = Duration(seconds: 8);

Future<List<int>?> readExportAssetBytes(String path) async {
  final normalizedPath = normalizeAssetPathSeparators(path.trim());
  if (normalizedPath.isEmpty || _isNetworkUrl(normalizedPath)) {
    return null;
  }
  final localPath =
      await resolveAppManagedFilePath(
        normalizedPath,
      ).then((resolution) => resolution.resolvedPath) ??
      normalizedPath;
  final file = File(localPath);
  if (!await file.exists()) {
    if (isRuntimeManagedAssetPath(normalizedPath)) {
      return null;
    }
    try {
      final data = await rootBundle.load(normalizedPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      return isSupportedImageBytes(bytes) ? bytes : null;
    } on FlutterError {
      return null;
    }
  }
  final bytes = await file.readAsBytes();
  return isSupportedImageBytes(bytes) ? bytes : null;
}

/// Locates an export asset without loading it: a local file is checked by its
/// header only and handed to the ZIP worker by path. Bundled assets (small
/// sample thumbnails) are returned as bytes.
Future<PlanExportZipSource?> readExportAssetSource(String path) async {
  final normalizedPath = normalizeAssetPathSeparators(path.trim());
  if (normalizedPath.isEmpty || _isNetworkUrl(normalizedPath)) {
    return null;
  }
  final localPath =
      await resolveAppManagedFilePath(
        normalizedPath,
      ).then((resolution) => resolution.resolvedPath) ??
      normalizedPath;
  final file = File(localPath);
  if (!await file.exists()) {
    final bytes = await readExportAssetBytes(normalizedPath);
    return bytes == null
        ? null
        : PlanExportZipSource.bytes(Uint8List.fromList(bytes));
  }
  final handle = await file.open();
  final Uint8List header;
  try {
    header = await handle.read(_imageHeaderLength);
  } finally {
    await handle.close();
  }
  return isSupportedImageBytes(header)
      ? PlanExportZipSource.file(file.absolute.path)
      : null;
}

// Enough for the JPEG, PNG and WebP signatures checked by isSupportedImageBytes.
const _imageHeaderLength = 12;

/// Keeps in-memory export assets (downloads, bundled images) on disk until
/// the ZIP worker has read them, so their bytes do not cross isolates.
class PlanExportAssetSpool {
  Directory? _directory;
  var _nextIndex = 0;

  Future<PlanExportZipSource> hold(Uint8List bytes) async {
    final directory = _directory ??= await Directory.systemTemp.createTemp(
      planExportSpoolPrefix,
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}${_nextIndex++}.bin',
    );
    await file.writeAsBytes(bytes, flush: true);
    return PlanExportZipSource.file(file.path);
  }

  Future<void> dispose() async {
    final directory = _directory;
    _directory = null;
    if (directory == null) {
      return;
    }
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // Temporary directory; the OS reclaims it eventually.
    }
  }
}

/// Reads an export asset inside the ZIP worker isolate.
Uint8List readExportZipSourceFile(String path) {
  final bytes = File(path).readAsBytesSync();
  if (!isSupportedImageBytes(bytes)) {
    throw FileSystemException('Export asset changed while exporting.', path);
  }
  return bytes;
}

/// Size of an export asset, used to size the ZIP output buffer up front.
int exportZipSourceFileLength(String path) {
  try {
    return File(path).lengthSync();
  } on FileSystemException {
    return 0;
  }
}

Future<List<int>?> readExportNetworkBytes(String url) async {
  final normalizedUrl = url.trim();
  if (!_isNetworkUrl(normalizedUrl)) {
    return null;
  }
  try {
    final uri = Uri.parse(normalizedUrl);
    if (anitabiImageHosts.contains(uri.host)) {
      final bytes = await fetchAnitabiImageBytes(
        normalizedUrl,
        timeout: _exportNetworkTimeout,
      );
      return bytes == null || !isSupportedImageBytes(bytes) ? null : bytes;
    }
    final client = http.Client();
    try {
      final response = await getPublic(
        client,
        uri,
        allowHttp: true,
      ).timeout(_exportNetworkTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return isSupportedImageBytes(response.bodyBytes)
          ? response.bodyBytes
          : null;
    } finally {
      client.close();
    }
  } on Object {
    return null;
  }
}

bool _isNetworkUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}
