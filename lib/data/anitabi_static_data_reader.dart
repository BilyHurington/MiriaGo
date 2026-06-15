import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../desktop/tauri_bridge.dart';
import 'anitabi_client.dart';

class AnitabiStaticDataReader {
  AnitabiStaticDataReader({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<String> read(String fileName) async {
    _validateFileName(fileName);

    if (isTauriLauncherAvailable) {
      return fetchDesktopAnitabiStaticJson(fileName: fileName);
    }

    final primaryUri = Uri.parse('https://www.anitabi.cn/d/$fileName');
    try {
      return (await _checkedGet(primaryUri)).body;
    } catch (error) {
      if (!kIsWeb) {
        final fallbackUri = Uri.parse('https://anitabi.cn/d/$fileName');
        try {
          return (await _checkedGet(fallbackUri)).body;
        } catch (_) {
          rethrow;
        }
      }

      final proxyUri = Uri.base.resolve('/__anitabi_static__/$fileName');
      try {
        return (await _checkedGet(proxyUri)).body;
      } catch (_) {
        throw AnitabiStaticDataUnavailableException(error);
      }
    }
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
