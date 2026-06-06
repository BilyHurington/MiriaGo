import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

Future<List<int>?> readExportAssetBytes(String path) async {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty || _isNetworkUrl(normalizedPath)) {
    return null;
  }
  final file = File(normalizedPath);
  if (!await file.exists()) {
    try {
      final data = await rootBundle.load(normalizedPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on FlutterError {
      return null;
    }
  }
  return file.readAsBytes();
}

Future<List<int>?> readExportNetworkBytes(String url) async {
  final normalizedUrl = url.trim();
  if (!_isNetworkUrl(normalizedUrl)) {
    return null;
  }
  try {
    final response = await http.get(Uri.parse(normalizedUrl));
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
