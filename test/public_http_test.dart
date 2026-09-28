import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miriago/data/anitabi_image_url.dart';
import 'package:miriago/data/anitabi_service_config.dart';
import 'package:miriago/data/public_http.dart';

void main() {
  test('local, private and reserved hosts in every spelling', () {
    for (final host in [
      'localhost',
      'localhost.',
      'printer.local',
      'app.localhost',
      '127.0.0.1',
      '127.1',
      '2130706433',
      '0x7f.1',
      '0177.0.0.1',
      '10.0.0.8',
      '100.64.1.1',
      '169.254.169.254',
      '172.20.0.1',
      '192.168.1.1',
      '198.18.0.1',
      '224.0.0.251',
      '255.255.255.255',
      '0.0.0.0',
      '::1',
      '[::1]',
      '0:0:0:0:0:0:0:1',
      '::',
      '::ffff:127.0.0.1',
      '::ffff:c0a8:101',
      '64:ff9b::a00:1',
      'fd12:3456::1',
      'fe80::1',
      'fe80::1%en0',
      'ff02::1',
    ]) {
      expect(isLocalOrPrivateHost(host), isTrue, reason: host);
    }
    for (final host in [
      'www.anitabi.cn',
      'image.anitabi.cn',
      '1.1.1.1',
      '8.8.8.8',
      '2606:4700::1111',
      '::ffff:8.8.8.8',
      '123.example.com',
      'cafe.be',
    ]) {
      expect(isLocalOrPrivateHost(host), isFalse, reason: host);
    }
  });

  test('Anitabi addresses must be public HTTPS', () {
    expect(validateAnitabiBaseUrl('https://[::1]/d'), isNotNull);
    expect(validateAnitabiBaseUrl('https://2130706433/d'), isNotNull);
    expect(validateAnitabiBaseUrl('https://www.anitabi.cn/d'), isNull);
  });

  test('image URLs from plan data never reach the local network', () {
    expect(candidateAnitabiImageUrls('http://192.168.1.2/a.jpg'), isEmpty);
    expect(candidateAnitabiImageUrls('file:///etc/passwd'), isEmpty);
    expect(candidateAnitabiImageUrls('https://example.com/a.jpg'), [
      'https://example.com/a.jpg',
    ]);
  });

  group('sendPublicGet', () {
    MockClient redirecting(Map<String, String> redirects, List<String> seen) =>
        MockClient((request) async {
          seen.add(request.url.toString());
          expect(request.followRedirects, isFalse);
          final target = redirects[request.url.toString()];
          return target == null
              ? http.Response('ok', 200)
              : http.Response('', 302, headers: {'location': target});
        });

    test('follows redirects between public hosts', () async {
      final seen = <String>[];
      final response = await getPublic(
        redirecting({
          'https://a.example/x': '/y',
          'https://a.example/y': 'https://b.example/z',
        }, seen),
        Uri.parse('https://a.example/x'),
      );
      expect(response.body, 'ok');
      expect(seen, [
        'https://a.example/x',
        'https://a.example/y',
        'https://b.example/z',
      ]);
    });

    test('refuses a redirect into the local network', () async {
      final seen = <String>[];
      await expectLater(
        getPublic(
          redirecting({
            'https://a.example/x': 'https://169.254.169.254/latest',
          }, seen),
          Uri.parse('https://a.example/x'),
        ),
        throwsA(isA<http.ClientException>()),
      );
      expect(seen, ['https://a.example/x']);
    });

    test('refuses a downgrade to HTTP unless allowed', () async {
      final seen = <String>[];
      final client = redirecting({
        'https://a.example/x': 'http://a.example/y',
      }, seen);
      await expectLater(
        getPublic(client, Uri.parse('https://a.example/x')),
        throwsA(isA<http.ClientException>()),
      );
      expect(
        (await getPublic(
          client,
          Uri.parse('https://a.example/x'),
          allowHttp: true,
        )).body,
        'ok',
      );
    });

    test('stops redirect loops', () async {
      await expectLater(
        getPublic(
          redirecting({'https://a.example/x': '/x'}, []),
          Uri.parse('https://a.example/x'),
        ),
        throwsA(isA<http.ClientException>()),
      );
    });
  });
}
