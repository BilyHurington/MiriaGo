import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miriago/data/anitabi_client.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  group('formatAnitabiSceneTime', () {
    test('formats seconds below one hour as minutes and seconds', () {
      expect(formatAnitabiSceneTime(0), '0:00');
      expect(formatAnitabiSceneTime(7), '0:07');
      expect(formatAnitabiSceneTime(125), '2:05');
    });

    test('formats seconds above one hour as hours minutes and seconds', () {
      expect(formatAnitabiSceneTime(3723), '1:02:03');
      expect(formatAnitabiSceneTime('7322'), '2:02:02');
    });

    test('ignores invalid values', () {
      expect(formatAnitabiSceneTime(null), isNull);
      expect(formatAnitabiSceneTime(-1), isNull);
      expect(formatAnitabiSceneTime('not-a-time'), isNull);
    });
  });

  test('formats legacy episode labels that already contain raw seconds', () {
    expect(formatEpisodeLabelForDisplay('EP 4 / 125s'), 'EP 4 / 2:05');
    expect(formatEpisodeLabelForDisplay('EP 12 / 3723s'), 'EP 12 / 1:02:03');
    expect(formatEpisodeLabelForDisplay('手动录入'), '手动录入');
  });

  test('parses Anitabi points with numeric text fields', () {
    final point = AnitabiPoint.fromJson({
      'id': '2ehwpjt',
      'name': 278,
      'cn': '',
      'geo': [36.1169, 139.3049],
      'image': 'https://image.anitabi.cn/points/531159/2ehwpjt.jpg?plan=h160',
      'origin': 531159,
      'originURL': null,
      'ep': 1,
      's': 125,
    }, bangumiId: 531159);

    expect(point.id, '2ehwpjt');
    expect(point.name, '278');
    expect(point.subtitle, '278');
    expect(point.origin, '531159');
    expect(point.episodeLabel, 'EP 1 / 2:05');
    expect(point.referenceImageUrl, endsWith('/2ehwpjt.jpg'));
  });

  test('finds a point by compact Anitabi map point ID', () async {
    final client = AnitabiClient(
      httpClient: _FixtureHttpClient({
        'https://www.anitabi.cn/d/g.json':
            '[[[8290,"头文字D",0,"頭文字D","日本","#d8101b","/images/bangumi/8290.jpg",7.7,"TV",36.098525,139.518473,7.1,["qdmnf6iqj",36.335315,138.738551,15644]]],250,1780488405409]',
        'https://www.anitabi.cn/d/g0.json':
            '[[8290,0,[["qdmnf6iqj","峠の釜めしや看板",0,0,0,1073,"/images/points/8290/qdmnf6iqj_1732560149766.jpg",0,null,"",0,0,0,"碓氷峠",3134]],1771771832628]]',
      }),
    );

    final result = await client.findPointById('qdmnf6iqj');

    expect(result, isNotNull);
    expect(result!.work.bangumiId, 8290);
    expect(result.work.title, '头文字D');
    expect(result.point.id, 'qdmnf6iqj');
    expect(result.point.name, '峠の釜めしや看板');
    expect(result.point.position.latitude, 36.335315);
    expect(result.point.position.longitude, 138.738551);
    expect(
      result.point.referenceImageUrl,
      'https://image.anitabi.cn/points/8290/qdmnf6iqj_1732560149766.jpg',
    );
  });
}

class _FixtureHttpClient extends http.BaseClient {
  _FixtureHttpClient(this.responses);

  final Map<String, String> responses;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = responses[request.url.toString()];
    if (body == null) {
      return http.StreamedResponse(Stream.value(const <int>[]), 404);
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}
