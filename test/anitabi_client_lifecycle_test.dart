import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miriago/data/anitabi_client.dart';
import 'package:miriago/data/anitabi_static_data_reader.dart';

const _index =
    '[[[115908,"吹响吧！上低音号",0,"響け！ユーフォニアム","宇治市","#02a7bd",'
    '"/images/bangumi/115908.jpg",8.0,"TV",34.9,135.8,12,'
    '["p1",34.9,135.8,1,"p2",34.9,135.8,1]]],1,"v1"]';

class _CountingReader extends AnitabiStaticDataReader {
  _CountingReader(this.responses);

  final List<Future<String> Function()> responses;
  var reads = 0;

  @override
  Future<String> read(String fileName, {String? version}) {
    return responses[reads++]();
  }
}

void main() {
  test('concurrent callers share one index download', () async {
    final gate = Completer<String>();
    final reader = _CountingReader([() => gate.future]);
    final client = AnitabiClient(staticDataReader: reader);

    final counts = client.fetchStaticPointCounts();
    final lite = client.fetchBangumiLiteFromStatic(115908);
    gate.complete(_index);

    expect(await counts, {115908: 2});
    expect((await lite)?.coverImageUrl, isNotNull);
    expect(reader.reads, 1);
  });

  test('a failed index download is not kept', () async {
    final reader = _CountingReader([
      () async => throw const AnitabiStaticDataUnavailableException('offline'),
      () async => _index,
    ]);
    final client = AnitabiClient(staticDataReader: reader);

    await expectLater(
      client.fetchStaticPointCounts(),
      throwsA(isA<AnitabiStaticDataUnavailableException>()),
    );
    expect(await client.fetchStaticPointCounts(), {115908: 2});
    expect(reader.reads, 2);
  });

  testWidgets('a stalled static data request times out', (tester) async {
    final reader = AnitabiStaticDataReader(
      httpClient: MockClient((_) => Completer<http.Response>().future),
      reportFailures: false,
    );
    Object? failure;
    unawaited(
      reader.read('g.json').catchError((Object error) {
        failure = error;
        return '';
      }),
    );

    await tester.pump(AnitabiStaticDataReader.requestTimeout);
    await tester.pump();
    expect(failure, isA<AnitabiStaticDataUnavailableException>());
    expect(
      (failure! as AnitabiStaticDataUnavailableException).cause,
      isA<TimeoutException>(),
    );
  });

  testWidgets('a stalled API request times out', (tester) async {
    final client = AnitabiClient(
      httpClient: MockClient((_) => Completer<http.Response>().future),
    );
    Object? failure;
    unawaited(
      client
          .fetchBangumiLite(1)
          .then<void>(
            (_) {},
            onError: (Object error) {
              failure = error;
            },
          ),
    );

    await tester.pump(AnitabiClient.apiTimeout);
    await tester.pump();
    expect(failure, isA<TimeoutException>());
  });

  group('shared index', () {
    tearDown(() => AnitabiClient.sharedHttpClientForTesting = null);

    test('a failed shared download reaches callers only', () async {
      AnitabiClient.sharedHttpClientForTesting = MockClient(
        (_) async => http.Response('', 503),
      );
      await expectLater(
        AnitabiClient().fetchStaticPointCounts(),
        throwsA(isA<AnitabiStaticDataUnavailableException>()),
      );
    });

    test('closing the client that started it does not abort it', () async {
      final gate = Completer<http.Response>();
      var downloads = 0;
      AnitabiClient.sharedHttpClientForTesting = MockClient((_) {
        downloads++;
        return gate.future;
      });
      final first = AnitabiClient();
      final second = AnitabiClient();

      final firstCounts = first.fetchStaticPointCounts();
      final secondCounts = second.fetchStaticPointCounts();
      first.close();
      gate.complete(http.Response.bytes(utf8.encode(_index), 200));

      expect(await secondCounts, {115908: 2});
      expect(await firstCounts, {115908: 2});
      expect(await AnitabiClient().fetchStaticPointCounts(), {115908: 2});
      expect(downloads, 1);
    });
  });
}
