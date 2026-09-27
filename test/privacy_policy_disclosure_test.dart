import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/valhalla_service_config.dart';
import 'package:miriago/map/valhalla_route_client.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/settings/privacy_policy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled bilingual policy includes sensitive flows and qualified defaults',
    () async {
      final policy = await rootBundle.loadString(PrivacyPolicyScreen.assetPath);
      for (final text in [
        defaultValhallaBaseUrl,
        'start, destination, and intermediate stop coordinates',
        '起点、终点及途经点坐标',
        'current position and the remaining stops',
        '当前位置及剩余站点',
        'Custom service addresses change the recipient',
        '自定义服务地址会改变对应请求的接收方',
        'some providers also a destination name',
        '部分服务还会收到目的地名称',
        'does not strip GPS',
        '并不会剥离原始照片已有的 GPS',
        'cloud services according to your device',
        '将文件同步或备份到云服务',
        'exporting is not always fully offline',
        '导出并不总是完全离线',
        'older databases gain this setting during migration',
        '部分旧数据库迁移新增该设置时也是如此',
        'does not specify or guarantee their retention periods',
        '不说明或保证其数据留存期限',
      ]) {
        expect(policy, contains(text));
      }
      const defaults = AppSettings();
      expect(defaults.saveVisitPhotoToGallery, isTrue);
      expect(defaults.autoSaveComparisonToGallery, isFalse);
      expect(
        defaults.photoLocationStrategy,
        PhotoLocationStrategy.askOnFirstCapture,
      );
    },
  );

  test(
    'routing disclosure matches exact coordinate payload and custom recipient',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://custom.example/service/route');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['locations'], [
          {'lat': 35.1, 'lon': 139.1, 'type': 'break'},
          {'lat': 35.2, 'lon': 139.2, 'type': 'break'},
          {'lat': 35.3, 'lon': 139.3, 'type': 'break'},
        ]);
        return http.Response(
          jsonEncode({
            'trip': {
              'summary': {'length': 1, 'time': 60},
              'legs': [
                {'shape': '??AA', 'maneuvers': []},
              ],
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      await ValhallaRouteClient(client: client).route(
        baseUrl: 'https://custom.example/service/',
        locations: const [
          LatLng(35.1, 139.1),
          LatLng(35.2, 139.2),
          LatLng(35.3, 139.3),
        ],
      );
    },
  );

  test(
    'connection check sends neither route coordinates nor a request body',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://custom.example/status');
        expect(request.body, isEmpty);
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      await ValhallaRouteClient(
        client: client,
      ).testConnection('https://custom.example');
    },
  );
}
