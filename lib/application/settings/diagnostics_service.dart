import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/anitabi_service_config.dart';
import '../../map/valhalla_route_client.dart';
import 'settings_options.dart';

typedef HttpClientFactory = http.Client Function();

/// Sample image used to probe both Anitabi image services.
final _probeImage = Uri.parse(
  'https://image.anitabi.cn/points/115908/qys7fu.jpg?plan=h160',
);

/// Connection tests of the 数据源 settings (ported from
/// `_AnitabiServiceSettingsPageState` and `_DataSourceSettingsPageState`).
class DiagnosticsService {
  DiagnosticsService({
    HttpClientFactory? clientFactory,
    this.timeout = const Duration(seconds: 12),
    ValhallaRouteClient Function()? valhallaClientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _valhallaClientFactory =
           valhallaClientFactory ?? ValhallaRouteClient.new;

  final HttpClientFactory _clientFactory;
  final ValhallaRouteClient Function() _valhallaClientFactory;
  final Duration timeout;

  /// Probe URL of every service for [config].
  static Map<AnitabiService, Uri> anitabiProbes(AnitabiServiceConfig config) {
    return {
      AnitabiService.site: config.siteUri('/'),
      AnitabiService.staticData: config.staticDataUri('g.json'),
      AnitabiService.api: config.apiUri('bangumi/115908/lite'),
      AnitabiService.officialImage: Uri.parse(
        config.officialImageUrl(_probeImage),
      ),
      AnitabiService.mirrorImage: Uri.parse(config.mirrorImageUrl(_probeImage)),
    };
  }

  /// Tests every Anitabi service in order. [onResult] is called after each
  /// probe with the results so far (for progressive UI updates).
  Future<Map<AnitabiService, String>> testAnitabiConnections(
    AnitabiServiceConfig config, {
    void Function(Map<AnitabiService, String> results)? onResult,
  }) async {
    final results = <AnitabiService, String>{};
    final client = _clientFactory();
    try {
      for (final entry in anitabiProbes(config).entries) {
        results[entry.key] = await probe(client, entry.value);
        onResult?.call(Map.unmodifiable(results));
      }
    } finally {
      client.close();
    }
    return results;
  }

  /// Range GET of the first 2 KB. 「连接成功 · N ms」「失败 · HTTP code」
  /// or 「连接失败」.
  Future<String> probe(http.Client client, Uri uri) async {
    final stopwatch = Stopwatch()..start();
    try {
      final request = http.Request('GET', uri)
        ..headers['range'] = 'bytes=0-2047';
      final response = await client.send(request).timeout(timeout);
      await response.stream.timeout(timeout).drain<void>();
      stopwatch.stop();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return '失败 · HTTP ${response.statusCode}';
      }
      return '连接成功 · ${stopwatch.elapsedMilliseconds} ms';
    } catch (_) {
      return '连接失败';
    }
  }

  /// Tests the Valhalla `/status` endpoint. Throws on failure.
  Future<void> testValhalla(String baseUrl) {
    return _valhallaClientFactory().testConnection(baseUrl);
  }
}

/// Short status shown next to a service row.
String compactAnitabiProbeStatus(String result) {
  if (result.startsWith('连接成功')) {
    final match = RegExp(r'(\d+)\s*ms').firstMatch(result);
    if (match != null) {
      return '成功 · ${match.group(1)}ms';
    }
    return '成功';
  }
  return '失败';
}

bool anitabiProbeSucceeded(String? result) =>
    result?.startsWith('连接成功') ?? false;

/// Tracks the progress of 「测试全部连接」 for the page.
class AnitabiConnectionTest extends ChangeNotifier {
  AnitabiConnectionTest({DiagnosticsService? service})
    : _service = service ?? DiagnosticsService();

  final DiagnosticsService _service;
  bool _testing = false;
  bool _disposed = false;
  Map<AnitabiService, String> _results = const {};

  bool get testing => _testing;
  Map<AnitabiService, String> get results => _results;

  bool isPending(AnitabiService service) =>
      _testing && !_results.containsKey(service);

  /// Old behaviour: results are cleared whenever an address changes.
  void clear() {
    if (_results.isEmpty) return;
    _results = const {};
    _notify();
  }

  Future<void> run(AnitabiServiceConfig config) async {
    if (_testing) return;
    _testing = true;
    _results = const {};
    _notify();
    try {
      await _service.testAnitabiConnections(
        config,
        onResult: (results) {
          _results = results;
          _notify();
        },
      );
    } finally {
      _testing = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
