import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../desktop/tauri_bridge.dart';
import 'anitabi_client.dart';

class AnitabiStaticDataReader {
  AnitabiStaticDataReader({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<String> read(String fileName, {String? version}) async {
    _validateFileName(fileName);

    if (isTauriLauncherAvailable) {
      return fetchDesktopAnitabiStaticJson(
        fileName: fileName,
        version: version,
      );
    }

    if (kIsWeb) {
      final proxyUri = _withVersion(
        Uri.base.resolve('/__anitabi_static__/$fileName'),
        version,
      );
      try {
        return (await _checkedGet(proxyUri)).body;
      } catch (error) {
        throw AnitabiStaticDataUnavailableException(error);
      }
    }

    final primaryUri = _withVersion(
      Uri.parse('https://www.anitabi.cn/d/$fileName'),
      version,
    );
    try {
      return (await _checkedGet(primaryUri)).body;
    } catch (error) {
      final fallbackUri = _withVersion(
        Uri.parse('https://anitabi.cn/d/$fileName'),
        version,
      );
      try {
        return (await _checkedGet(fallbackUri)).body;
      } catch (_) {
        throw AnitabiStaticDataUnavailableException(error);
      }
    }
  }

  Uri _withVersion(Uri uri, String? version) {
    if (version == null || version.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: {'v': version});
  }

  Future<http.Response> _checkedGet(Uri uri) async {
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AnitabiException(response.statusCode, response.body);
    }
    return response;
  }

  void _validateFileName(String fileName) {
    final valid = RegExp(r'^g\d*\.json$').hasMatch(fileName);
    if (!valid) {
      throw ArgumentError.value(fileName, 'fileName', 'Invalid Anitabi file');
    }
  }
}
