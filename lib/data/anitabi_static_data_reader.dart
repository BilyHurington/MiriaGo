import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../desktop/tauri_bridge.dart';
import 'anitabi_client.dart';
import 'anitabi_endpoint_sync.dart';
import 'anitabi_service_config.dart';
import 'public_http.dart';

class AnitabiStaticDataReader {
  AnitabiStaticDataReader({
    http.Client? httpClient,
    this.serviceConfig,
    this.reportFailures = true,
  }) : _httpClient = httpClient ?? http.Client();

  /// Per static file; the index is about 2 MB, so allow slow networks.
  static const requestTimeout = Duration(seconds: 120);

  var _closed = false;

  /// Requests failing because the owner closed the HTTP client are not a
  /// sign that Anitabi moved.
  void markClosed() => _closed = true;

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
          _closed ||
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
      final body = await _fetchBody(
        fileName,
        version: version,
        config: config,
      ).timeout(requestTimeout);
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

  Future<String> _fetchBody(
    String fileName, {
    required String? version,
    required AnitabiServiceConfig config,
  }) async {
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
      // Same-origin dev proxy; it checks the upstream itself.
      return (await _checkedGet(proxyUri, publicOnly: false)).body;
    }
    return (await _checkedGet(
      config.staticDataUri(fileName, version: version),
    )).body;
  }

  Future<http.Response> _checkedGet(Uri uri, {bool publicOnly = true}) async {
    final response = publicOnly
        ? await getPublic(_httpClient, uri)
        : await _httpClient.get(uri);
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
