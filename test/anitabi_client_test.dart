import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/anitabi_client.dart';
import 'package:miriago/data/anitabi_static_data_reader.dart';
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

  test('finds a compact Anitabi point inside a specific bangumi', () async {
    final client = AnitabiClient(
      httpClient: _FixtureHttpClient({
        'https://www.anitabi.cn/d/g.json':
            '[[[8290,"头文字D",0,"頭文字D","日本","#d8101b","/images/bangumi/8290.jpg",7.7,"TV",36.098525,139.518473,7.1,["qdmnf6iqj",36.335315,138.738551,15644]],[999001,"其他作品",0,"Other","日本","#61a4d8","/images/bangumi/999001.jpg",7.5,"TV",34.421,134.057,11,["other",34.1,134.1,1]]],1,1780488405409]',
        'https://www.anitabi.cn/d/g0.json':
            '[[8290,0,[["qdmnf6iqj","峠の釜めしや看板",0,0,0,1073,"/images/points/8290/qdmnf6iqj_1732560149766.jpg",0,null,"",0,0,0,"碓氷峠",3134]],1771771832628]]',
        'https://www.anitabi.cn/d/g1.json':
            '[[999001,0,[["other","其他地点",0,0,0,0,"/images/points/999001/other.jpg",0,1,125,0,"Anitabi","https://anitabi.cn/map?bangumi=999001"]],1771771832628]]',
      }),
    );

    final result = await client.findPointInBangumi(
      bangumiId: 8290,
      pointId: 'qdmnf6iqj',
    );

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

  test('finds a compact Anitabi point globally across related works', () async {
    final client = AnitabiClient(
      httpClient: _FixtureHttpClient({
        'https://www.anitabi.cn/d/g.json':
            '[[[282923,"上伊那牡丹，酒醉身姿似百合花般",0,"上伊那ぼたん、酔へる姿は百合の花","秩父市","#476347","/images/bangumi/282923.jpg",7.6,"漫画系列",37.238036,138.957161,6.3,["ttr1hpv2a",35.648102,139.703165,1]],[543360,"上伊那牡丹，酒醉身姿似百合花般",0,"上伊那ぼたん、酔へる姿は百合の花","秩父市","#ff9a8a","/images/bangumi/543360.jpg",0,"TV",0,0,0,["djnfcvo",35.647974,139.70287,1]]],1,1783421160481]',
        'https://www.anitabi.cn/d/g0.json':
            '[[282923,0,[["ttr1hpv2a","代官山",0,0,0,1099,"/images/points/282923/ttr1hpv2a.jpg",0,4,"",0,0,0,"EP4",133]],1783421160481]]',
        'https://www.anitabi.cn/d/g1.json':
            '[[543360,0,[["djnfcvo","代官山駅",0,0,0,1099,"/images/user/1099/bangumi/543360/points/djnfcvo-1776496761302.jpg",0,2,1021,0,0,0,"EP2",133]],1783421160481]]',
      }),
    );

    final result = await client.findPointGlobally(pointId: 'djnfcvo');

    expect(result, isNotNull);
    expect(result!.work.bangumiId, 543360);
    expect(result.work.title, '上伊那牡丹，酒醉身姿似百合花般');
    expect(result.point.id, 'djnfcvo');
    expect(result.point.name, '代官山駅');
    expect(result.point.position.latitude, 35.647974);
    expect(result.point.position.longitude, 139.70287);
    expect(
      result.point.referenceImageUrl,
      'https://image.anitabi.cn/user/1099/bangumi/543360/points/djnfcvo-1776496761302.jpg',
    );
  });

  test('fetches complete points from static Anitabi map data first', () async {
    final client = AnitabiClient(
      httpClient: _FixtureHttpClient({
        'https://www.anitabi.cn/d/g.json':
            '[[[999001,"测试作品",0,"Fixture Work","测试市","#61a4d8","/images/bangumi/999001.jpg",7.5,"TV",34.421,134.057,11,["p1",34.1,134.1,1,"p2",34.2,134.2,2,"p3",34.3,134.3,3]]],250,1780488405409]',
        'https://www.anitabi.cn/d/g0.json':
            '[[999001,0,[["p1","地点一",0,0,0,0,"/images/points/999001/p1.jpg",0,1,125,"备注一","Anitabi","https://anitabi.cn/map?bangumi=999001"],["p2","地点二",0,0,0,0,"/images/points/999001/p2.jpg",0,2,130,0,"Anitabi","https://anitabi.cn/map?bangumi=999001"],["p3","地点三",0,0,0,0,"/images/points/999001/p3.jpg",0,3,135,0,"Anitabi","https://anitabi.cn/map?bangumi=999001"]],1771771832628]]',
        'https://api.anitabi.cn/bangumi/999001/points/detail?haveImage=true':
            '[{"id":"p1","name":"地点一","geo":[34.1,134.1],"image":"https://image.anitabi.cn/points/999001/p1.jpg?plan=h160","ep":1,"s":125}]',
      }),
    );

    final points = await client.fetchPoints(999001);

    expect(points.map((point) => point.id), ['p1', 'p2', 'p3']);
    expect(points.first.note, '备注一');
    expect(points[1].position.latitude, 34.2);
    expect(
      points[2].referenceImageUrl,
      'https://image.anitabi.cn/points/999001/p3.jpg',
    );
  });

  test('fetches static points through injected static data reader', () async {
    final client = AnitabiClient(
      httpClient: _FixtureHttpClient({
        'https://api.anitabi.cn/bangumi/999001/points/detail?haveImage=true':
            '[{"id":"p1","name":"地点一","geo":[34.1,134.1],"image":"https://image.anitabi.cn/points/999001/p1.jpg?plan=h160","ep":1,"s":125}]',
      }),
      staticDataReader: _FixtureStaticDataReader({
        'g.json':
            '[[[999001,"测试作品",0,"Fixture Work","测试市","#61a4d8","/images/bangumi/999001.jpg",7.5,"TV",34.421,134.057,11,["p1",34.1,134.1,1,"p2",34.2,134.2,2]]],250,1780488405409]',
        'g0.json':
            '[[999001,0,[["p1","地点一",0,0,0,0,"/images/points/999001/p1.jpg",0,1,125,0,"Anitabi","https://anitabi.cn/map?bangumi=999001"],["p2","地点二",0,0,0,0,"/images/points/999001/p2.jpg",0,2,130,0,"Anitabi","https://anitabi.cn/map?bangumi=999001"]],1771771832628]]',
      }),
    );

    final points = await client.fetchPoints(
      999001,
      lite: const AnitabiBangumiLite(
        bangumiId: 999001,
        title: '测试作品',
        subtitle: 'Fixture Work',
        city: '测试市',
        center: LatLng(34.421, 134.057),
        zoom: 11,
        pointsLength: 2,
      ),
    );

    expect(points.map((point) => point.id), ['p1', 'p2']);
  });

  test('uses static index timestamp when fetching point pages', () async {
    final reader = _FixtureStaticDataReader({
      'g.json':
          '[[[999001,"测试作品",0,"Fixture Work","测试市","#61a4d8","/images/bangumi/999001.jpg",7.5,"TV",34.421,134.057,11,["p1",34.1,134.1,1]]],250,1782816540092]',
      'g0.json?v=1782816540092':
          '[[999001,0,[["p1","地点一",0,0,0,0,"/images/points/999001/p1.jpg",0,1,125,0,"Anitabi","https://anitabi.cn/map?bangumi=999001"]],1782816540092]]',
    });
    final client = AnitabiClient(staticDataReader: reader);

    final points = await client.fetchPoints(999001);

    expect(points.single.id, 'p1');
    expect(reader.requests[0], startsWith('g.json?v='));
    expect(reader.requests[1], 'g0.json?v=1782816540092');
  });

  test('clearStaticCache refreshes the static index timestamp', () async {
    final reader = _FixtureStaticDataReader({
      'g.json':
          '[[[999001,"测试作品",0,"Fixture Work","测试市","#61a4d8","/images/bangumi/999001.jpg",7.5,"TV",34.421,134.057,11,["p1",34.1,134.1,1]]],250,111]',
      'g0.json?v=111':
          '[[999001,0,[["p1","旧地点",0,0,0,0,"/images/points/999001/p1-old.jpg",0,1,125,0,"Anitabi","https://anitabi.cn/map?bangumi=999001"]],111]]',
      'g.json#2':
          '[[[999001,"测试作品",0,"Fixture Work","测试市","#61a4d8","/images/bangumi/999001.jpg",7.5,"TV",34.421,134.057,11,["p1",34.1,134.1,1]]],250,222]',
      'g0.json?v=222':
          '[[999001,0,[["p1","新地点",0,0,0,0,"/images/points/999001/p1-new.jpg",0,1,125,0,"Anitabi","https://anitabi.cn/map?bangumi=999001"]],222]]',
    });
    final client = AnitabiClient(staticDataReader: reader);

    final oldPoints = await client.fetchPoints(999001);
    client.clearStaticCache();
    final newPoints = await client.fetchPoints(999001);

    expect(oldPoints.single.name, '旧地点');
    expect(newPoints.single.name, '新地点');
    expect(reader.requests[0], startsWith('g.json?v='));
    expect(reader.requests[1], 'g0.json?v=111');
    expect(reader.requests[2], startsWith('g.json?v='));
    expect(reader.requests[3], 'g0.json?v=222');
  });

  test('throws when static Anitabi map data is unavailable', () async {
    final client = AnitabiClient(
      httpClient: _FixtureHttpClient({
        'https://api.anitabi.cn/bangumi/999001/points/detail?haveImage=true':
            '[{"id":"p1","name":"地点一","geo":[34.1,134.1],"image":"https://image.anitabi.cn/points/999001/p1.jpg?plan=h160","ep":1,"s":125}]',
      }),
    );

    expect(
      () => client.fetchPoints(999001),
      throwsA(isA<AnitabiStaticDataUnavailableException>()),
    );
  });

  test('does not use detail API when lite total is available', () async {
    final client = AnitabiClient(
      httpClient: _FixtureHttpClient({
        'https://api.anitabi.cn/bangumi/999001/points/detail?haveImage=true':
            '[{"id":"p1","name":"地点一","geo":[34.1,134.1],"image":"https://image.anitabi.cn/points/999001/p1.jpg?plan=h160","ep":1,"s":125}]',
      }),
    );

    expect(
      () => client.fetchPoints(
        999001,
        lite: const AnitabiBangumiLite(
          bangumiId: 999001,
          title: '测试作品',
          subtitle: 'Fixture Work',
          city: '测试市',
          center: LatLng(34.421, 134.057),
          zoom: 11,
          pointsLength: 3,
        ),
      ),
      throwsA(isA<AnitabiStaticDataUnavailableException>()),
    );
  });
}

class _FixtureHttpClient extends http.BaseClient {
  _FixtureHttpClient(this.responses);

  final Map<String, String> responses;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var body = responses[request.url.toString()];
    if (body == null && request.url.hasQuery) {
      body = responses[request.url.toString().split('?').first];
    }
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

class _FixtureStaticDataReader extends AnitabiStaticDataReader {
  _FixtureStaticDataReader(this.responses);

  final Map<String, String> responses;
  final List<String> requests = [];
  int _indexReads = 0;

  @override
  Future<String> read(String fileName, {String? version}) async {
    final request = version == null ? fileName : '$fileName?v=$version';
    requests.add(request);
    final key = fileName == 'g.json' && responses.containsKey('g.json#2')
        ? _nextIndexKey()
        : fileName == 'g.json'
        ? 'g.json'
        : request;
    final body = responses[key] ?? responses[fileName];
    if (body == null) {
      throw AnitabiStaticDataUnavailableException(request);
    }
    return body;
  }

  String _nextIndexKey() {
    _indexReads += 1;
    return _indexReads == 1 ? 'g.json' : 'g.json#$_indexReads';
  }
}
