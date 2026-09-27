import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miriago/config/bangumi_config.dart';
import 'package:miriago/data/bangumi_api_client.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

http.Response _response(Object? data) => http.Response(
  jsonEncode({'data': data}),
  200,
  headers: const {'content-type': 'application/json'},
);

Map<String, Object?> _subject(int id) => {
  'id': id,
  'type': 2,
  'name': 'Original title',
  'name_cn': 'Display title',
  'date': '2026-01-01',
  'nsfw': false,
  'images': {'small': '//lain.bgm.tv/r/200/pic/cover/demo.jpg'},
};

void _expectConfiguredAuthentication(http.Request request) {
  // Compare as a boolean so assertion failures cannot print the credential.
  expect(
    request.headers['authorization'] == 'Bearer ${BangumiConfig.apiToken}',
    isTrue,
  );
  expect(
    request.headers.keys.any((key) => key.toLowerCase() == 'cookie'),
    isFalse,
  );
  expect(request.url.userInfo.isEmpty, isTrue);
  expect(request.url.queryParameters.keys, ['limit']);
}

void main() {
  for (final types in <Set<BangumiSubjectType>>[
    {},
    {BangumiSubjectType.anime},
    {BangumiSubjectType.book, BangumiSubjectType.game},
  ]) {
    test(
      'configured authentication still excludes nsfw with ${types.length} type filters',
      () async {
        final transport = MockClient((request) async {
          _expectConfiguredAuthentication(request);
          expect(request.method, 'POST');
          expect(request.url.origin, BangumiConfig.apiBaseUrl);
          expect(request.url.path, '/v0/search/subjects');
          expect(request.url.queryParameters['limit'], '12');
          expect(
            request.headers['content-type'],
            startsWith('application/json'),
          );
          expect(
            request.headers['user-agent'],
            kIsWeb ? isNull : BangumiConfig.userAgent,
          );
          expect(jsonDecode(request.body), {
            'keyword': 'test',
            'sort': 'match',
            'filter': {
              'nsfw': false,
              if (types.isNotEmpty)
                'type': types.map((type) => type.code).toList(),
            },
          });
          return _response([]);
        });
        addTearDown(transport.close);
        expect(
          await BangumiApiClient(
            httpClient: transport,
          ).searchSubjects('  test  ', types: types),
          isEmpty,
        );
      },
    );
  }

  test('searchAnime retains its type authentication and safe filter', () async {
    final transport = MockClient((request) async {
      _expectConfiguredAuthentication(request);
      expect((jsonDecode(request.body) as Map)['filter'], {
        'type': [2],
        'nsfw': false,
      });
      return _response([_subject(326)]);
    });
    addTearDown(transport.close);
    final work = (await BangumiApiClient(
      httpClient: transport,
    ).searchAnime('test')).single;
    expect(work.bangumiId, 326);
    expect(work.id, 'bangumi-326');
    expect(work.bangumiSubjectType, BangumiSubjectType.anime);
    expect(work.title, 'Display title');
    expect(work.subtitle, 'Original title');
    expect(work.city, '动画 / 2026-01-01');
    expect(work.coverImageUrl, 'https://lain.bgm.tv/r/200/pic/cover/demo.jpg');
    expect(work.source, WorkSource.bangumi);
  });

  test('empty keyword performs no request', () async {
    var calls = 0;
    final transport = MockClient((request) async {
      calls++;
      return _response([]);
    });
    addTearDown(transport.close);
    final client = BangumiApiClient(httpClient: transport);
    expect(await client.searchAnime(' \n\t '), isEmpty);
    expect(calls, 0);
  });

  test(
    'mixed results keep only explicit safe flags before parsing work fields',
    () async {
      final transport = MockClient(
        (request) async => _response([
          _subject(1),
          {'nsfw': true, 'id': 'must not parse'},
          {'nsfw': false, 'adult': true, 'id': 'must not parse'},
          {..._subject(2), 'adult': false, 'type': 4},
          {'adult': false, 'id': 'missing nsfw'},
          null,
          'not a subject',
        ]),
      );
      addTearDown(transport.close);
      final works = await BangumiApiClient(
        httpClient: transport,
      ).searchSubjects('test', types: {});
      expect(works.map((work) => work.bangumiId), [1, 2]);
      expect(works.last.bangumiSubjectType, BangumiSubjectType.game);
    },
  );

  const unsafeValues = <Object?>[null, true, 0, 1, 'false', 'true', [], {}];
  for (final field in ['nsfw', 'adult']) {
    for (var index = 0; index < unsafeValues.length; index++) {
      test('rejects $field malformed or unsafe variant $index', () async {
        final transport = MockClient(
          (request) async => _response([
            {'nsfw': false, field: unsafeValues[index]},
          ]),
        );
        addTearDown(transport.close);
        expect(
          await BangumiApiClient(httpClient: transport).searchAnime('test'),
          isEmpty,
        );
      });
    }
  }

  test(
    'missing safety flag and entirely unsafe response produce an empty list',
    () async {
      final transport = MockClient(
        (request) async => _response([
          <String, Object?>{},
          {'adult': false},
          {'nsfw': true},
          {'nsfw': false, 'adult': true},
        ]),
      );
      addTearDown(transport.close);
      expect(
        await BangumiApiClient(httpClient: transport).searchAnime('test'),
        isEmpty,
      );
    },
  );

  for (final data in [null, 'invalid', <String, Object?>{}]) {
    test(
      'non-list data ${data.runtimeType} preserves empty result behavior',
      () async {
        final transport = MockClient((request) async => _response(data));
        addTearDown(transport.close);
        expect(
          await BangumiApiClient(httpClient: transport).searchAnime('test'),
          isEmpty,
        );
      },
    );
  }

  for (final status in [401, 403, 429, 500]) {
    test('HTTP $status remains an error without fallback or retry', () async {
      var calls = 0;
      final transport = MockClient((request) async {
        calls++;
        _expectConfiguredAuthentication(request);
        return http.Response('fixture error', status);
      });
      addTearDown(transport.close);
      await expectLater(
        BangumiApiClient(httpClient: transport).searchAnime('test'),
        throwsA(
          isA<BangumiApiException>()
              .having((error) => error.statusCode, 'status', status)
              .having((error) => error.body, 'body', 'fixture error'),
        ),
      );
      expect(calls, 1);
    });
  }

  test(
    'invalid JSON remains an error, not a successful empty search',
    () async {
      final transport = MockClient(
        (request) async => http.Response('not json', 200),
      );
      addTearDown(transport.close);
      await expectLater(
        BangumiApiClient(httpClient: transport).searchAnime('test'),
        throwsFormatException,
      );
    },
  );

  test('transport failure propagates without retrying', () async {
    var calls = 0;
    final transport = MockClient((request) async {
      calls++;
      _expectConfiguredAuthentication(request);
      throw http.ClientException('fixture network failure');
    });
    addTearDown(transport.close);
    await expectLater(
      BangumiApiClient(httpClient: transport).searchAnime('test'),
      throwsA(isA<http.ClientException>()),
    );
    expect(calls, 1);
  });
}
