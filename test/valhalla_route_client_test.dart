import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/map/valhalla_route_client.dart';

void main() {
  test('requests pedestrian polyline6 route and parses maneuvers', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://route.example/route');
      expect(request.headers['X-Client-Id'], 'MiriaGo');
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(
          _routeResponse(const [LatLng(35.0, 139.0), LatLng(35.001, 139.002)]),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final route = await ValhallaRouteClient(client: client).route(
      baseUrl: 'https://route.example/',
      locations: const [LatLng(35.0, 139.0), LatLng(35.001, 139.002)],
    );

    expect(requestBody['costing'], 'pedestrian');
    expect(requestBody['shape_format'], 'polyline6');
    expect(requestBody['language'], 'en-US');
    expect(route.shape, hasLength(2));
    expect(route.shape.last.latitude, closeTo(35.001, 0.000001));
    expect(route.distanceKm, 0.4);
    expect(route.duration, const Duration(minutes: 5));
    expect(route.maneuvers.single.instruction, '向右转，进入测试路');
  });

  test('caches identical route briefly', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response(
        jsonEncode(_routeResponse(const [LatLng(1, 2), LatLng(1.1, 2.1)])),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final routeClient = ValhallaRouteClient(client: client);
    const points = [LatLng(1, 2), LatLng(1.1, 2.1)];
    await routeClient.route(
      baseUrl: 'https://route.example',
      locations: points,
    );
    await routeClient.route(
      baseUrl: 'https://route.example',
      locations: points,
    );
    expect(requests, 1);
  });

  test('reports rate limiting separately', () async {
    final client = MockClient((_) async => http.Response('', 429));
    expect(
      () => ValhallaRouteClient(client: client).route(
        baseUrl: 'https://route.example',
        locations: const [LatLng(1, 2), LatLng(1.1, 2.1)],
      ),
      throwsA(
        isA<ValhallaRouteException>().having(
          (error) => error.message,
          'message',
          contains('频繁'),
        ),
      ),
    );
  });

  test('polyline6 decoder rejects truncated data', () {
    expect(() => decodePolyline6('_'), throwsFormatException);
  });

  test('maps official Valhalla maneuver types to Chinese instructions', () {
    expect(localizedManeuverInstruction(10), '向右转');
    expect(localizedManeuverInstruction(15), '向左转');
    expect(localizedManeuverInstruction(40), '走楼梯');
    expect(localizedManeuverInstruction(4), '到达终点');
    expect(
      localizedManeuverInstruction(99, fallbackInstruction: 'Unknown action'),
      'Unknown action',
    );
  });

  test('prefers local street names over route refs and romanisation', () {
    expect(preferredStreetName(streetNames: ['467', '国道467号']), '国道467号');
    expect(
      preferredStreetName(
        streetNames: ['Sun Sun Street', 'さんさん通り', '52', '沼津停車場線'],
      ),
      'さんさん通り',
    );
    expect(
      preferredStreetName(
        beginStreetNames: ['烏森通り', '405'],
        streetNames: ['新橋駅前'],
      ),
      '烏森通り',
    );
    expect(preferredStreetName(streetNames: ['Main Street']), 'Main Street');
    expect(preferredStreetName(streetNames: ['15', 'R1', 'E1-2']), isNull);
    expect(preferredStreetName(), isNull);
  });

  test('uses begin street names and skips refs in instructions', () async {
    final client = MockClient((_) async {
      final body = _routeResponse(const [LatLng(35, 139), LatLng(35.001, 139)]);
      final maneuver =
          ((body['trip'] as Map)['legs'] as List).first['maneuvers'].first
              as Map<String, dynamic>;
      maneuver['street_names'] = ['467', '国道467号'];
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final route = await ValhallaRouteClient(client: client).route(
      baseUrl: 'https://route.example',
      locations: const [LatLng(35, 139), LatLng(35.001, 139)],
    );
    expect(route.maneuvers.single.instruction, '向右转，进入国道467号');
  });

  test('maps Valhalla error codes to readable messages', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error_code': 154,
          'error': 'Path distance exceeds the max distance limit',
          'status_code': 400,
        }),
        400,
      ),
    );
    await expectLater(
      ValhallaRouteClient(client: client).route(
        baseUrl: 'https://route.example',
        locations: const [LatLng(35.68, 139.76), LatLng(34.69, 135.5)],
      ),
      throwsA(
        isA<ValhallaRouteException>().having(
          (error) => error.message,
          'message',
          '距离超过路径服务的步行路线上限',
        ),
      ),
    );
    expect(valhallaErrorMessage('{"error_code":171}'), contains('没有可步行的道路'));
    expect(valhallaErrorMessage('{"error_code":442}'), '找不到可步行的路线');
    expect(valhallaErrorMessage('{"error_code":999}'), isNull);
    expect(valhallaErrorMessage('<html>'), isNull);
  });

  test('parses per-leg ranges and summaries for chained routes', () async {
    final client = MockClient((_) async {
      const first = [LatLng(35, 139), LatLng(35.001, 139)];
      const second = [LatLng(35.001, 139), LatLng(35.001, 139.001)];
      return http.Response(
        jsonEncode({
          'trip': {
            'summary': {'length': 0.3, 'time': 240},
            'legs': [
              for (final (shape, length, time) in [
                (first, 0.1, 80),
                (second, 0.2, 160),
              ])
                {
                  'shape': _encodePolyline6(shape),
                  'summary': {'length': length, 'time': time},
                  'maneuvers': [
                    {
                      'type': 1,
                      'length': length,
                      'begin_shape_index': 0,
                      'end_shape_index': 1,
                    },
                    {
                      'type': 4,
                      'length': 0,
                      'begin_shape_index': 1,
                      'end_shape_index': 1,
                    },
                  ],
                },
            ],
          },
        }),
        200,
      );
    });
    final route = await ValhallaRouteClient(client: client).route(
      baseUrl: 'https://route.example',
      locations: const [
        LatLng(35, 139),
        LatLng(35.001, 139),
        LatLng(35.001, 139.001),
      ],
    );
    expect(route.shape, hasLength(3));
    expect(route.legs, hasLength(2));
    expect(route.legs[0].startShapeIndex, 0);
    expect(route.legs[0].endShapeIndex, 1);
    expect(route.legs[1].startShapeIndex, 1);
    expect(route.legs[1].endShapeIndex, 2);
    expect(route.legs[1].firstManeuverIndex, 2);
    expect(route.legs[1].maneuverCount, 2);
    expect(route.legs[1].duration, const Duration(seconds: 160));
    expect(route.maneuvers[3].beginShapeIndex, 2);
  });
}

Map<String, dynamic> _routeResponse(List<LatLng> points) => {
  'trip': {
    'summary': {'length': 0.4, 'time': 300},
    'legs': [
      {
        'shape': _encodePolyline6(points),
        'maneuvers': [
          {
            'type': 10,
            'length': 0.4,
            'begin_shape_index': 0,
            'end_shape_index': points.length - 1,
            'street_names': ['测试路'],
          },
        ],
      },
    ],
  },
};

String _encodePolyline6(List<LatLng> points) {
  var latitude = 0;
  var longitude = 0;
  final output = StringBuffer();
  for (final point in points) {
    final nextLatitude = (point.latitude * 1e6).round();
    final nextLongitude = (point.longitude * 1e6).round();
    _writeCoordinate(output, nextLatitude - latitude);
    _writeCoordinate(output, nextLongitude - longitude);
    latitude = nextLatitude;
    longitude = nextLongitude;
  }
  return output.toString();
}

void _writeCoordinate(StringBuffer output, int delta) {
  var value = delta < 0 ? ~(delta << 1) : delta << 1;
  while (value >= 0x20) {
    output.writeCharCode((0x20 | (value & 0x1f)) + 63);
    value >>= 5;
  }
  output.writeCharCode(value + 63);
}
