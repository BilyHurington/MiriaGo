import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../desktop/tauri_bridge.dart';
import 'anitabi_client.dart';
import 'anitabi_service_config.dart';

class AnitabiStaticDataReader {
  AnitabiStaticDataReader({http.Client? httpClient, this.serviceConfig})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final AnitabiServiceConfig? serviceConfig;

  Future<String> read(String fileName, {String? version}) async {
    _validateFileName(fileName);
    final config = serviceConfig ?? AnitabiServiceConfig.current;

    if (isTauriLauncherAvailable) {
      return fetchDesktopAnitabiStaticJson(
        fileName: fileName,
        version: version,
        baseUrl: config.staticDataBaseUrl,
      );
    }

    if (kIsWeb) {
      final proxyUri = Uri.base
          .resolve('/__anitabi_static__/$fileName')
          .replace(
            queryParameters: {
              if (version != null && version.isNotEmpty) 'v': version,
              'upstream': config.staticDataBaseUrl,
            },
          );
      try {
        return (await _checkedGet(proxyUri)).body;
      } catch (error) {
        throw AnitabiStaticDataUnavailableException(error);
      }
    }

    final primaryUri = config.staticDataUri(fileName, version: version);
    try {
      return (await _checkedGet(primaryUri)).body;
    } catch (error) {
      throw AnitabiStaticDataUnavailableException(error);
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
