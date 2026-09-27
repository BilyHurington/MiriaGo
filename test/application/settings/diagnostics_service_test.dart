import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miriago/application/settings/diagnostics_service.dart';
import 'package:miriago/application/settings/settings_options.dart';
import 'package:miriago/data/anitabi_service_config.dart';

void main() {
  test('probes every service with a 2 KB range request', () async {
    final requests = <http.BaseRequest>[];
    final service = DiagnosticsService(
      clientFactory: () => MockClient((request) async {
        requests.add(request);
        if (request.url.host == 'api.anitabi.cn') {
          return http.Response('nope', 503);
        }
        if (request.url.host == 'img-tc.anitabi.cn') {
          throw const SocketExceptionLike();
        }
        return http.Response('ok', 206);
      }),
    );
    final progress = <int>[];
    final results = await service.testAnitabiConnections(
      const AnitabiServiceConfig(),
      onResult: (partial) => progress.add(partial.length),
    );
    expect(progress, [1, 2, 3, 4, 5]);
    expect(requests.map((r) => r.headers['range']).toSet(), {'bytes=0-2047'});
    expect(
      requests.first.url.toString(),
      startsWith(defaultAnitabiSiteBaseUrl),
    );
    expect(results[AnitabiService.site], startsWith('连接成功 · '));
    expect(results[AnitabiService.site], endsWith(' ms'));
    expect(results[AnitabiService.api], '失败 · HTTP 503');
    expect(results[AnitabiService.mirrorImage], '连接失败');
    expect(
      requests[3].url.toString(),
      'https://image.anitabi.cn/points/115908/qys7fu.jpg?plan=h160',
    );
  });

  test('a stalled probe times out as 连接失败', () async {
    final service = DiagnosticsService(
      timeout: const Duration(milliseconds: 20),
    );
    final result = await service.probe(
      MockClient((request) => Completer<http.Response>().future),
      Uri.parse('https://ww.anitabi.cn/'),
    );
    expect(result, '连接失败');
  });

  test('compact status keeps the latency', () {
    expect(compactAnitabiProbeStatus('连接成功 · 123 ms'), '成功 · 123ms');
    expect(compactAnitabiProbeStatus('连接成功'), '成功');
    expect(compactAnitabiProbeStatus('失败 · HTTP 404'), '失败');
    expect(anitabiProbeSucceeded('连接成功 · 1 ms'), isTrue);
    expect(anitabiProbeSucceeded('连接失败'), isFalse);
    expect(anitabiProbeSucceeded(null), isFalse);
  });

  test('connection test notifies progress and can be cleared', () async {
    final test = AnitabiConnectionTest(
      service: DiagnosticsService(
        clientFactory: () =>
            MockClient((request) async => http.Response('ok', 200)),
      ),
    );
    var notifications = 0;
    test.addListener(() => notifications++);
    final run = test.run(const AnitabiServiceConfig());
    expect(test.testing, isTrue);
    expect(test.isPending(AnitabiService.site), isTrue);
    await run;
    expect(test.testing, isFalse);
    expect(test.results, hasLength(5));
    expect(notifications, greaterThanOrEqualTo(6));
    test.clear();
    expect(test.results, isEmpty);
    test.dispose();
  });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
