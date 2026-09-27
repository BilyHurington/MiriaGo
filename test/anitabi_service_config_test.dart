import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/anitabi_service_config.dart';

void main() {
  test('builds every Anitabi endpoint from configurable base URLs', () {
    const config = AnitabiServiceConfig(
      siteBaseUrl: 'https://site.example/anitabi',
      staticDataBaseUrl: 'https://static.example/data',
      apiBaseUrl: 'https://api.example/v1',
      officialImageBaseUrl: 'https://images.example/official',
      mirrorImageBaseUrl: 'https://images.example/mirror',
    );

    expect(
      config.siteUri('map', queryParameters: {'bangumiId': '115908'}),
      Uri.parse('https://site.example/anitabi/map?bangumiId=115908'),
    );
    expect(
      config.staticDataUri('g0.json', version: '123'),
      Uri.parse('https://static.example/data/g0.json?v=123'),
    );
    expect(
      config.apiUri('bangumi/115908/lite'),
      Uri.parse('https://api.example/v1/bangumi/115908/lite'),
    );
    final original = Uri.parse(
      'https://image.anitabi.cn/points/115908/id.jpg?plan=h160',
    );
    expect(
      config.officialImageUrl(original),
      'https://images.example/official/points/115908/id.jpg?plan=h160',
    );
    expect(
      config.mirrorImageUrl(original),
      'https://images.example/mirror/points/115908/id.jpg?plan=h160',
    );
  });

  test('normalizes valid base URLs and rejects unsafe targets', () {
    expect(
      normalizeAnitabiBaseUrl(
        ' https://ww.anitabi.cn/d/// ',
        fallback: defaultAnitabiStaticDataBaseUrl,
      ),
      defaultAnitabiStaticDataBaseUrl,
    );
    expect(validateAnitabiBaseUrl('http://ww.anitabi.cn'), isNotNull);
    expect(validateAnitabiBaseUrl('https://localhost:8080'), isNotNull);
    expect(validateAnitabiBaseUrl('https://192.168.1.2/data'), isNotNull);
    expect(
      validateAnitabiBaseUrl('https://example.com/data?token=x'),
      isNotNull,
    );
    expect(validateAnitabiBaseUrl('https://static.example/data'), isNull);
  });
}
