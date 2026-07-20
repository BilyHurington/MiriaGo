import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miriago/data/bangumi_api_client.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  test(
    'uses small Bangumi cover and normalizes protocol-relative URL',
    () async {
      final client = _clientWithImages({
        'small': '//lain.bgm.tv/r/200/pic/cover/demo.jpg',
        'common': 'https://lain.bgm.tv/r/400/pic/cover/demo.jpg',
      });

      final works = await client.searchSubjects(
        '测试作品',
        types: const {BangumiSubjectType.anime},
      );

      expect(
        works.single.coverImageUrl,
        'https://lain.bgm.tv/r/200/pic/cover/demo.jpg',
      );
    },
  );

  test('falls back through supported Bangumi cover sizes', () async {
    final client = _clientWithImages({
      'small': '',
      'common': 'http://lain.bgm.tv/r/400/pic/cover/demo.jpg',
      'large': 'https://lain.bgm.tv/pic/cover/demo.jpg',
    });

    final works = await client.searchAnime('测试作品');

    expect(
      works.single.coverImageUrl,
      'https://lain.bgm.tv/r/400/pic/cover/demo.jpg',
    );
  });

  test('keeps cover null when Bangumi images are unavailable', () async {
    final client = _clientWithImages(null);

    final works = await client.searchAnime('测试作品');

    expect(works.single.coverImageUrl, isNull);
  });
}

BangumiApiClient _clientWithImages(Object? images) {
  return BangumiApiClient(
    httpClient: MockClient((request) async {
      expect(request.method, 'POST');
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 326,
              'type': BangumiSubjectType.anime.code,
              'name': 'Test Work',
              'name_cn': '测试作品',
              'date': '2026-07-20',
              'images': images,
            },
          ],
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }),
  );
}
