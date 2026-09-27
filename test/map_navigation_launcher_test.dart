import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/map/map_navigation_launcher.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

void main() {
  const work = PilgrimageWork(
    id: 'work-1',
    title: '测试作品',
    subtitle: '',
    city: '东京',
    source: WorkSource.manual,
  );
  const point = PilgrimagePoint(
    id: 'point-1',
    work: work,
    name: '涩谷路口',
    subtitle: '场景说明',
    position: LatLng(35.659521, 139.700476),
    episodeLabel: 'EP 1',
    referenceLabel: '手动',
  );

  group('walkingNavigationUri', () {
    test('builds Google Maps walking URL', () {
      final uri = walkingNavigationUri(point, NavigationApp.googleMaps);

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '35.659521,139.700476');
      expect(uri.queryParameters['travelmode'], 'walking');
    });

    test('builds Apple Maps walking URL', () {
      final uri = walkingNavigationUri(point, NavigationApp.appleMaps);

      expect(uri.scheme, 'https');
      expect(uri.host, 'maps.apple.com');
      expect(uri.path, '/');
      expect(uri.queryParameters['daddr'], '35.659521,139.700476');
      expect(uri.queryParameters['dirflg'], 'w');
    });

    test('builds Amap walking URL with WGS84 coordinates', () {
      final uri = walkingNavigationUri(point, NavigationApp.amap);

      expect(uri.scheme, 'https');
      expect(uri.host, 'uri.amap.com');
      expect(uri.path, '/navigation');
      expect(uri.queryParameters['to'], '139.700476,35.659521,涩谷路口');
      expect(uri.queryParameters['mode'], 'walk');
      expect(uri.queryParameters['coordinate'], 'wgs84');
      expect(uri.queryParameters['callnative'], '1');
      expect(uri.queryParameters['src'], 'MiriaGo');
    });

    test('builds Baidu walking URL with WGS84 coordinates', () {
      final uri = walkingNavigationUri(point, NavigationApp.baiduMaps);

      expect(uri.scheme, 'http');
      expect(uri.host, 'api.map.baidu.com');
      expect(uri.path, '/direction');
      expect(
        uri.queryParameters['destination'],
        'latlng:35.659521,139.700476|name:涩谷路口',
      );
      expect(uri.queryParameters['mode'], 'walking');
      expect(uri.queryParameters['coord_type'], 'wgs84');
      expect(uri.queryParameters['output'], 'html');
      expect(uri.queryParameters['src'], 'webapp.miriago.miriago');
    });

    test(
      'falls back to point subtitle then work title for destination name',
      () {
        final subtitleUri = walkingNavigationUri(
          point.copyWith(name: ''),
          NavigationApp.amap,
        );
        final workTitleUri = walkingNavigationUri(
          point.copyWith(name: '', subtitle: ''),
          NavigationApp.amap,
        );

        expect(subtitleUri.queryParameters['to'], '139.700476,35.659521,场景说明');
        expect(workTitleUri.queryParameters['to'], '139.700476,35.659521,测试作品');
      },
    );

    test('rejects a point whose coordinate is still pending', () {
      final pendingPoint = point.copyWith(
        position: PilgrimagePoint.pendingPosition,
      );

      expect(
        () => walkingNavigationUri(pendingPoint, NavigationApp.googleMaps),
        throwsArgumentError,
      );
    });
  });

  group('MapNavigationLauncher', () {
    test(
      'uses the Android Google Maps intent before the universal URL',
      () async {
        var nativeCalls = 0;
        final openedUrls = <Uri>[];
        final launcher = MapNavigationLauncher(
          useAndroidGoogleMapsIntent: true,
          androidGoogleMapsLauncher: (_) async {
            nativeCalls += 1;
            return true;
          },
          externalNavigationLauncher: (uri) async {
            openedUrls.add(uri);
            return true;
          },
        );

        final opened = await launcher.openWalking(
          point,
          NavigationApp.googleMaps,
        );

        expect(opened, isTrue);
        expect(nativeCalls, 1);
        expect(openedUrls, isEmpty);
      },
    );

    test(
      'falls back to the Google Maps URL when the Android app is unavailable',
      () async {
        final openedUrls = <Uri>[];
        final launcher = MapNavigationLauncher(
          useAndroidGoogleMapsIntent: true,
          androidGoogleMapsLauncher: (_) async => false,
          externalNavigationLauncher: (uri) async {
            openedUrls.add(uri);
            return true;
          },
        );

        final opened = await launcher.openWalking(
          point,
          NavigationApp.googleMaps,
        );

        expect(opened, isTrue);
        expect(openedUrls, hasLength(1));
        expect(openedUrls.single.host, 'www.google.com');
        expect(openedUrls.single.queryParameters['travelmode'], 'walking');
      },
    );

    test('falls back when the Android platform channel fails', () async {
      var fallbackCalls = 0;
      final launcher = MapNavigationLauncher(
        useAndroidGoogleMapsIntent: true,
        androidGoogleMapsLauncher: (_) async {
          throw PlatformException(code: 'unavailable');
        },
        externalNavigationLauncher: (_) async {
          fallbackCalls += 1;
          return true;
        },
      );

      final opened = await launcher.openWalking(
        point,
        NavigationApp.googleMaps,
      );

      expect(opened, isTrue);
      expect(fallbackCalls, 1);
    });

    test('keeps other navigation apps on their existing URL flow', () async {
      var nativeCalls = 0;
      final openedUrls = <Uri>[];
      final launcher = MapNavigationLauncher(
        useAndroidGoogleMapsIntent: true,
        androidGoogleMapsLauncher: (_) async {
          nativeCalls += 1;
          return true;
        },
        externalNavigationLauncher: (uri) async {
          openedUrls.add(uri);
          return true;
        },
      );

      final opened = await launcher.openWalking(point, NavigationApp.amap);

      expect(opened, isTrue);
      expect(nativeCalls, 0);
      expect(openedUrls.single.host, 'uri.amap.com');
    });

    test(
      'does not launch navigation for a point without coordinates',
      () async {
        var nativeCalls = 0;
        var externalCalls = 0;
        final launcher = MapNavigationLauncher(
          useAndroidGoogleMapsIntent: true,
          androidGoogleMapsLauncher: (_) async {
            nativeCalls += 1;
            return true;
          },
          externalNavigationLauncher: (_) async {
            externalCalls += 1;
            return true;
          },
        );

        final opened = await launcher.openWalking(
          point.copyWith(position: PilgrimagePoint.pendingPosition),
          NavigationApp.googleMaps,
        );

        expect(opened, isFalse);
        expect(nativeCalls, 0);
        expect(externalCalls, 0);
      },
    );
  });
}
