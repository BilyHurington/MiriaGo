import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miriago/data/anitabi_image_fetcher.dart';
import 'package:miriago/data/bounded_image_decoder.dart';

class _Client extends http.BaseClient {
  _Client(this.response);
  final Future<http.StreamedResponse> Function() response;
  var calls = 0;
  var closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    calls++;
    return response();
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  test('declared overflow is explicit and does not retry mirrors', () async {
    final client = _Client(
      () async =>
          http.StreamedResponse(Stream.value([1]), 200, contentLength: 100),
    );
    await expectLater(
      fetchAnitabiImageBytes(
        'https://image.anitabi.cn/a.jpg',
        client: client,
        maxBytes: 10,
      ),
      throwsA(isA<ImageBudgetException>()),
    );
    expect(client.calls, 1);
    expect(client.closed, false);
  });
  test('actual overflow cancels body and does not retry mirrors', () async {
    var canceled = false;
    final stream = StreamController<List<int>>(
      onCancel: () {
        canceled = true;
      },
    );
    final client = _Client(
      () async => http.StreamedResponse(stream.stream, 200),
    );
    final future = fetchAnitabiImageBytes(
      'https://image.anitabi.cn/a.jpg',
      client: client,
      maxBytes: 3,
    );
    final expectation = expectLater(
      future,
      throwsA(isA<ImageBudgetException>()),
    );
    stream.add([1, 2, 3, 4]);
    await expectation;
    expect(client.calls, 1);
    expect(canceled, true);
    await stream.close();
  });
  test('bounded successful read keeps caller client open', () async {
    final client = _Client(
      () async => http.StreamedResponse(Stream.value([255, 216, 255]), 200),
    );
    expect(
      await fetchAnitabiImageBytes(
        'https://example.com/a.jpg',
        client: client,
        maxBytes: 3,
      ),
      [255, 216, 255],
    );
    expect(client.closed, false);
  });
  test('buffered injection cannot masquerade as bounded read', () async {
    await expectLater(
      fetchAnitabiImageBytes(
        'https://example.com/a.jpg',
        maxBytes: 3,
        get: (uri, {timeout}) async => http.Response('', 200),
      ),
      throwsArgumentError,
    );
  });
}
