import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../desktop/desktop_asset_image.dart';
import '../desktop/tauri_bridge.dart' as tauri;

const _exportNetworkTimeout = Duration(seconds: 8);

Future<List<int>?> readExportAssetBytes(String path) async {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty || _isNetworkUrl(normalizedPath)) {
    return null;
  }
  if (tauri.isTauriLauncherAvailable && isDesktopAssetPath(normalizedPath)) {
    try {
      final asset = await tauri.readDesktopAsset(path: normalizedPath);
      return base64Decode(asset.dataBase64);
    } on Object {
      return null;
    }
  }
  try {
    final data = await rootBundle.load(normalizedPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
    final response = await http
        .get(Uri.parse(normalizedUrl))
        .timeout(_exportNetworkTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    return response.bodyBytes;
  } on Object {
    return null;
  }
}

bool _isNetworkUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}
