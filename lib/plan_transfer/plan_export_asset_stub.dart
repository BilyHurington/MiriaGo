import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../data/anitabi_image_fetcher.dart';
import '../data/anitabi_image_url.dart';
import '../data/image_bytes.dart';
import '../data/reference_asset_paths.dart';
import '../desktop/desktop_asset_image.dart';
import '../desktop/tauri_bridge.dart' as tauri;

const _exportNetworkTimeout = Duration(seconds: 8);

Future<List<int>?> readExportAssetBytes(String path) async {
  final normalizedPath = normalizeAssetPathSeparators(path.trim());
  if (normalizedPath.isEmpty || _isNetworkUrl(normalizedPath)) {
    return null;
  }
  if (tauri.isTauriLauncherAvailable && isDesktopAssetPath(normalizedPath)) {
    try {
      final asset = await tauri.readDesktopAsset(path: normalizedPath);
      final bytes = base64Decode(asset.dataBase64);
      return isSupportedImageBytes(bytes) ? bytes : null;
    } on Object {
      return null;
    }
  }
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
    final response = await http.get(uri).timeout(_exportNetworkTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    return isSupportedImageBytes(response.bodyBytes)
        ? response.bodyBytes
        : null;
  } on Object {
    return null;
  }
}

bool _isNetworkUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}
