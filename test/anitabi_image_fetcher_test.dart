import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miriago/data/anitabi_image_fetcher.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test('falls back to mirror when official host returns html', () async {
    final requested = <Uri>[];
    final bytes = await fetchAnitabiImageBytes(
      'https://image.anitabi.cn/points/115908/id.jpg',
      get: (uri, {timeout}) async {
        requested.add(uri);
        if (uri.host == 'image.anitabi.cn') {
          return http.Response('<html>blocked</html>', 403);
        }
        return http.Response.bytes([0xff, 0xd8, 0xff, 0x00], 200);
      },
    );

    expect(bytes, [0xff, 0xd8, 0xff, 0x00]);
    expect(requested.map((uri) => uri.host), [
      'image.anitabi.cn',
      'img-tc.anitabi.cn',
    ]);
  });

  test('honors fixed mirror image source', () async {
    final requested = <Uri>[];
    final bytes = await fetchAnitabiImageBytes(
      'https://image.anitabi.cn/points/115908/id.jpg?plan=h160',
      source: AnitabiImageSource.mirror,
      get: (uri, {timeout}) async {
        requested.add(uri);
        return http.Response.bytes([
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
        ], 200);
      },
    );

    expect(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    expect(requested.single.host, 'img-tc.anitabi.cn');
    expect(requested.single.queryParameters['plan'], 'h160');
  });

  test('rejects non-image responses from every candidate', () async {
    final bytes = await fetchAnitabiImageBytes(
      'https://image.anitabi.cn/points/115908/id.jpg',
      get: (uri, {timeout}) async => http.Response('not image', 200),
    );

    expect(bytes, isNull);
  });
}
