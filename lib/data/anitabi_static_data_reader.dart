import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../desktop/tauri_bridge.dart';
import 'anitabi_client.dart';
import 'anitabi_endpoint_sync.dart';
import 'anitabi_service_config.dart';

class AnitabiStaticDataReader {
  AnitabiStaticDataReader({
    http.Client? httpClient,
    this.serviceConfig,
    this.reportFailures = true,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final AnitabiServiceConfig? serviceConfig;

  /// Whether a failure that suggests Anitabi moved may trigger the remote
  /// address check. Off for the check's own verification requests.
  final bool reportFailures;

  Future<String> read(String fileName, {String? version}) async {
    _validateFileName(fileName);
    final config = serviceConfig ?? AnitabiServiceConfig.current;
    try {
      return await _read(fileName, version: version, config: config);
    } on AnitabiStaticDataUnavailableException catch (error) {
      final recovery = AnitabiEndpointRecovery.handler;
      if (!reportFailures ||
          recovery == null ||
          !isSuspectedAnitabiAddressFailure(error.cause)) {
        rethrow;
      }
      if (!await recovery()) rethrow;
      // Retry the original request once with the updated addresses.
      return _read(
        fileName,
        version: version,
        config: AnitabiServiceConfig.current,
      );
    }
  }

  Future<String> _read(
    String fileName, {
    required String? version,
    required AnitabiServiceConfig config,
  }) async {
    try {
      final String body;
      if (isTauriLauncherAvailable) {
        body = await fetchDesktopAnitabiStaticJson(
          fileName: fileName,
          version: version,
          baseUrl: config.staticDataBaseUrl,
        );
      } else if (kIsWeb) {
        final proxyUri = Uri.base
            .resolve('/__anitabi_static__/$fileName')
            .replace(
              queryParameters: {
                if (version != null && version.isNotEmpty) 'v': version,
                'upstream': config.staticDataBaseUrl,
              },
            );
        body = (await _checkedGet(proxyUri)).body;
      } else {
        body = (await _checkedGet(
          config.staticDataUri(fileName, version: version),
        )).body;
      }
      // An error or landing page served in place of the data file means the
      // address no longer serves Anitabi data.
      final trimmed = body.trimLeft();
      if (!trimmed.startsWith('[') && !trimmed.startsWith('{')) {
        throw const FormatException('Anitabi static data is not JSON');
      }
      return body;
    } on AnitabiStaticDataUnavailableException {
      rethrow;
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
