import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miriago/data/anitabi_client.dart';
import 'package:miriago/data/anitabi_endpoint_sync.dart';
import 'package:miriago/data/anitabi_remote_state.dart';
import 'package:miriago/data/anitabi_service_config.dart';
import 'package:miriago/data/anitabi_static_data_reader.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

Map<String, Object?> _document({
  int version = 2,
  String staticData = 'https://new.example/d',
  String api = defaultAnitabiApiBaseUrl,
}) => {
  'schema': 1,
  'version': version,
  'updatedAt': '2026-09-28',
  'services': {
    'site': defaultAnitabiSiteBaseUrl,
    'staticData': staticData,
    'api': api,
    'officialImage': defaultAnitabiOfficialImageBaseUrl,
    'mirrorImage': defaultAnitabiMirrorImageBaseUrl,
  },
};

class _Harness {
  _Harness({
    this.settings = const AppSettings(),
    Object? document,
    this.verified = true,
    Set<String> unreachable = const {},
  }) {
    client = MockClient((request) async {
      requests.add(request.url.toString());
      if (unreachable.contains(request.url.toString())) {
        throw http.ClientException('Connection refused');
      }
      final body = document ?? _document();
      return http.Response(
        body is String ? body : jsonEncode(body),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });
    sync = AnitabiEndpointSync(
      loadSettings: () async => settings,
      saveSettings: (value) async => settings = value,
      httpClient: client,
      now: () => now,
      verifier: (candidate, changed) async {
        verifications.add(changed);
        return verified;
      },
      configUrls: const [
        'https://a.example/c.json',
        'https://b.example/c.json',
      ],
    );
  }

  AppSettings settings;
  bool verified;
  DateTime now = DateTime.utc(2026, 9, 28, 12);
  final requests = <String>[];
  final verifications = <Set<AnitabiServiceField>>[];
  late final MockClient client;
  late final AnitabiEndpointSync sync;

  AnitabiRemoteState get state => settings.anitabiRemoteState;
}

void main() {
  group('AnitabiRemoteServices.tryParse', () {
    test('accepts a complete document and normalizes addresses', () {
      final services = AnitabiRemoteServices.tryParse({
        ..._document(),
        'services': {
          ...(_document()['services']! as Map),
          'staticData': 'https://new.example/d/',
        },
      });
      expect(services, isNotNull);
      expect(services!.version, 2);
      expect(services.staticData, 'https://new.example/d');
    });

    test('rejects unknown schemas, missing fields and unsafe addresses', () {
      expect(
        AnitabiRemoteServices.tryParse({..._document(), 'schema': 2}),
        isNull,
      );
      expect(
        AnitabiRemoteServices.tryParse({..._document(), 'version': 0}),
        isNull,
      );
      final services = Map<String, Object?>.of(
        _document()['services']! as Map<String, Object?>,
      )..remove('api');
      expect(
        AnitabiRemoteServices.tryParse({..._document(), 'services': services}),
        isNull,
      );
      expect(
        AnitabiRemoteServices.tryParse(
          _document(staticData: 'http://new.example/d'),
        ),
        isNull,
      );
      expect(
        AnitabiRemoteServices.tryParse(_document(api: 'https://127.0.0.1')),
        isNull,
      );
    });
  });

  group('AnitabiRemoteState', () {
    test('round trips through JSON', () {
      final state = AnitabiRemoteState(
        autoUpdate: false,
        lastGood: AnitabiRemoteServices.tryParse(_document()),
        recentAutoChecks: [DateTime.utc(2026, 9, 28, 10)],
        lastCheckAt: DateTime.utc(2026, 9, 28, 10),
        lastSuccessAt: DateTime.utc(2026, 9, 28, 10),
        lastResult: 'updated',
      );
      final decoded = AnitabiRemoteState.decode(state.encode());
      expect(decoded.autoUpdate, isFalse);
      expect(decoded.lastGood!.staticData, 'https://new.example/d');
      expect(decoded.recentAutoChecks, [DateTime.utc(2026, 9, 28, 10)]);
      expect(decoded.lastResult, 'updated');
    });

    test('treats empty or damaged state as defaults', () {
      for (final raw in ['', 'not json', '[1]']) {
        final state = AnitabiRemoteState.decode(raw);
        expect(state.autoUpdate, isTrue);
        expect(state.lastGood, isNull);
      }
    });
  });

  group('resolveAnitabiAddress', () {
    final remote = AnitabiRemoteServices.tryParse(_document())!;

    test('custom address wins over the remote configuration', () {
      final resolved = resolveAnitabiAddress(
        AnitabiServiceField.staticData,
        stored: 'https://mine.example/d/',
        remote: remote,
      );
      expect(resolved.value, 'https://mine.example/d');
      expect(resolved.source, AnitabiServiceSource.custom);
    });

    test('built-in address follows the remote configuration', () {
      final resolved = resolveAnitabiAddress(
        AnitabiServiceField.staticData,
        stored: defaultAnitabiStaticDataBaseUrl,
        remote: remote,
      );
      expect(resolved.value, 'https://new.example/d');
      expect(resolved.source, AnitabiServiceSource.remote);
    });

    test('remote value equal to the built-in one reports built-in', () {
      final resolved = resolveAnitabiAddress(
        AnitabiServiceField.api,
        stored: defaultAnitabiApiBaseUrl,
        remote: remote,
      );
      expect(resolved.source, AnitabiServiceSource.builtIn);
    });

    test('settings expose the effective configuration', () {
      final settings = AppSettings(
        anitabiRemoteStateJson: AnitabiRemoteState(lastGood: remote).encode(),
      );
      expect(
        settings.anitabiServiceConfig.staticDataBaseUrl,
        'https://new.example/d',
      );
      expect(
        settings.anitabiServiceConfig.apiBaseUrl,
        defaultAnitabiApiBaseUrl,
      );
    });
  });

  group('AnitabiEndpointSync', () {
    test(
      'falls back to the next source and applies a verified update',
      () async {
        final harness = _Harness(unreachable: {'https://a.example/c.json'});

        expect(await harness.sync.recoverAfterFailure(), isTrue);

        expect(harness.requests, [
          'https://a.example/c.json',
          'https://b.example/c.json',
        ]);
        expect(harness.verifications.single, {AnitabiServiceField.staticData});
        expect(harness.state.lastGood!.version, 2);
        expect(harness.state.lastResult, 'updated');
        expect(harness.state.recentAutoChecks, hasLength(1));
        expect(
          harness.settings.anitabiServiceConfig.staticDataBaseUrl,
          'https://new.example/d',
        );
      },
    );

    test('offline checks are not counted against the limit', () async {
      final harness = _Harness(
        unreachable: {'https://a.example/c.json', 'https://b.example/c.json'},
      );

      for (var i = 0; i < 5; i++) {
        expect(await harness.sync.recoverAfterFailure(), isFalse);
      }

      expect(harness.requests, hasLength(10));
      expect(harness.state.recentAutoChecks, isEmpty);
      expect(harness.state.lastResult, 'offline');
    });

    test('rate limits automatic checks', () async {
      final harness = _Harness(document: 'not json');

      await harness.sync.recoverAfterFailure();
      expect(harness.state.lastResult, 'invalid');
      final afterFirst = harness.requests.length;

      // Less than an hour later: skipped without touching the network.
      harness.now = harness.now.add(const Duration(minutes: 30));
      await harness.sync.recoverAfterFailure();
      expect(harness.requests, hasLength(afterFirst));

      harness.now = harness.now.add(const Duration(hours: 1));
      await harness.sync.recoverAfterFailure();
      harness.now = harness.now.add(const Duration(hours: 1));
      await harness.sync.recoverAfterFailure();
      expect(harness.state.recentAutoChecks, hasLength(3));

      // Three checks within 24 hours use up the day.
      final afterThird = harness.requests.length;
      harness.now = harness.now.add(const Duration(hours: 2));
      await harness.sync.recoverAfterFailure();
      expect(harness.requests, hasLength(afterThird));

      harness.now = harness.now.add(const Duration(hours: 24));
      await harness.sync.recoverAfterFailure();
      expect(harness.requests.length, greaterThan(afterThird));
    });

    test('stays quiet for a day after a successful check', () async {
      final harness = _Harness();
      expect(await harness.sync.recoverAfterFailure(), isTrue);
      final requests = harness.requests.length;

      harness.now = harness.now.add(const Duration(hours: 12));
      expect(await harness.sync.recoverAfterFailure(), isFalse);
      expect(harness.requests, hasLength(requests));
    });

    test('keeps the current addresses when verification fails', () async {
      final harness = _Harness(verified: false);

      expect(await harness.sync.recoverAfterFailure(), isFalse);

      expect(harness.state.lastGood, isNull);
      expect(harness.state.lastResult, 'verificationFailed');
      expect(
        harness.settings.anitabiServiceConfig.staticDataBaseUrl,
        defaultAnitabiStaticDataBaseUrl,
      );
    });

    test('ignores a configuration that is not newer', () async {
      final harness = _Harness(
        settings: AppSettings(
          anitabiRemoteStateJson: AnitabiRemoteState(
            lastGood: AnitabiRemoteServices.tryParse(_document(version: 3)),
          ).encode(),
        ),
      );

      expect(await harness.sync.checkNow(), AnitabiSyncOutcome.unchanged);

      expect(harness.verifications, isEmpty);
      expect(harness.state.lastGood!.version, 3);
    });

    test('never replaces a custom address', () async {
      final harness = _Harness(
        settings: const AppSettings(
          anitabiStaticDataBaseUrl: 'https://mine.example/d',
        ),
      );

      expect(await harness.sync.checkNow(), AnitabiSyncOutcome.unchanged);

      expect(harness.verifications, isEmpty);
      expect(harness.state.lastGood!.version, 2);
      expect(
        harness.settings.anitabiServiceConfig.staticDataBaseUrl,
        'https://mine.example/d',
      );
    });

    test(
      'automatic updates can be switched off; manual checks still run',
      () async {
        final harness = _Harness();
        await harness.sync.setAutoUpdate(false);

        expect(await harness.sync.recoverAfterFailure(), isFalse);
        expect(harness.requests, isEmpty);

        expect(await harness.sync.checkNow(), AnitabiSyncOutcome.updated);
        expect(harness.state.autoUpdate, isFalse);
        expect(harness.state.recentAutoChecks, isEmpty);
      },
    );

    test('manual checks have a short cooldown', () async {
      final harness = _Harness();
      expect(await harness.sync.checkNow(), AnitabiSyncOutcome.updated);
      harness.now = harness.now.add(const Duration(seconds: 20));
      expect(await harness.sync.checkNow(), AnitabiSyncOutcome.rateLimited);
      harness.now = harness.now.add(const Duration(minutes: 1));
      expect(await harness.sync.checkNow(), AnitabiSyncOutcome.unchanged);
    });

    test('concurrent failures share one check', () async {
      final harness = _Harness();
      final results = await Future.wait([
        harness.sync.recoverAfterFailure(),
        harness.sync.recoverAfterFailure(),
        harness.sync.recoverAfterFailure(),
      ]);
      expect(results, [isTrue, isTrue, isTrue]);
      expect(harness.requests, hasLength(1));
    });

    test('does not overwrite settings changed while it ran', () async {
      final harness = _Harness();
      final gate = Completer<void>();
      final sync = AnitabiEndpointSync(
        loadSettings: () async => harness.settings,
        saveSettings: (value) async => harness.settings = value,
        httpClient: MockClient((request) async {
          await gate.future;
          return http.Response(jsonEncode(_document()), 200);
        }),
        now: () => harness.now,
        verifier: (_, _) async => true,
        configUrls: const ['https://a.example/c.json'],
      );

      final check = sync.checkNow();
      await Future<void>.delayed(Duration.zero);
      harness.settings = harness.settings.copyWith(mapMaxZoom: 21);
      gate.complete();
      await check;

      expect(harness.settings.mapMaxZoom, 21);
      expect(harness.state.lastGood!.version, 2);
    });
  });

  group('isSuspectedAnitabiAddressFailure', () {
    test('classifies failures', () {
      expect(
        isSuspectedAnitabiAddressFailure(const AnitabiException(503, '')),
        isTrue,
      );
      expect(
        isSuspectedAnitabiAddressFailure(const AnitabiException(404, '')),
        isTrue,
      );
      expect(
        isSuspectedAnitabiAddressFailure(
          const AnitabiException(404, ''),
          notFoundMeansMoved: false,
        ),
        isFalse,
      );
      expect(
        isSuspectedAnitabiAddressFailure(const AnitabiException(429, '')),
        isFalse,
      );
      expect(
        isSuspectedAnitabiAddressFailure(const AnitabiException(400, '')),
        isFalse,
      );
      expect(
        isSuspectedAnitabiAddressFailure('request failed: 404 Not Found'),
        isTrue,
      );
      // Numbers inside connection errors are not HTTP statuses.
      expect(
        isSuspectedAnitabiAddressFailure(
          http.ClientException(
            'Connection failed (OS Error: refused, errno = 111), '
            'address = 192.168.1.1, port = 443',
          ),
        ),
        isTrue,
      );
      expect(
        isSuspectedAnitabiAddressFailure(TimeoutException('slow')),
        isFalse,
      );
    });
  });

  group('recovery retries', () {
    const oldConfig = AnitabiServiceConfig(
      staticDataBaseUrl: 'https://old.example/d',
      apiBaseUrl: 'https://old-api.example',
    );
    const newConfig = AnitabiServiceConfig(
      staticDataBaseUrl: 'https://new.example/d',
      apiBaseUrl: 'https://new-api.example',
    );
    late int recoveries;

    setUp(() {
      recoveries = 0;
      AnitabiServiceConfig.current = oldConfig;
      AnitabiEndpointRecovery.handler = () async {
        recoveries++;
        AnitabiServiceConfig.current = newConfig;
        return true;
      };
    });

    tearDown(() {
      AnitabiEndpointRecovery.handler = null;
      AnitabiServiceConfig.current = const AnitabiServiceConfig();
    });

    MockClient serving(Map<String, http.Response> responses) =>
        MockClient((request) async {
          final url = request.url;
          return responses['${url.scheme}://${url.host}${url.path}'] ??
              http.Response('<html>gone</html>', 404);
        });

    test('static data retries once on the updated address', () async {
      final reader = AnitabiStaticDataReader(
        httpClient: serving({
          'https://new.example/d/g.json': http.Response('[1]', 200),
        }),
      );

      expect(await reader.read('g.json'), '[1]');
      expect(recoveries, 1);
    });

    test('an HTML page served as data counts as moved', () async {
      final reader = AnitabiStaticDataReader(
        httpClient: serving({
          'https://old.example/d/g.json': http.Response('<html></html>', 200),
          'https://new.example/d/g.json': http.Response('[2]', 200),
        }),
      );

      expect(await reader.read('g.json'), '[2]');
      expect(recoveries, 1);
    });

    test('rate limiting does not trigger a check', () async {
      final reader = AnitabiStaticDataReader(
        httpClient: serving({
          'https://old.example/d/g.json': http.Response('', 429),
        }),
      );

      await expectLater(
        reader.read('g.json'),
        throwsA(isA<AnitabiStaticDataUnavailableException>()),
      );
      expect(recoveries, 0);
    });

    test('verification reads never trigger a check', () async {
      final reader = AnitabiStaticDataReader(
        httpClient: serving({}),
        reportFailures: false,
      );

      await expectLater(
        reader.read('g.json'),
        throwsA(isA<AnitabiStaticDataUnavailableException>()),
      );
      expect(recoveries, 0);
    });

    test('API 404 means an unknown work, not a moved service', () async {
      final client = AnitabiClient(httpClient: serving({}));

      await expectLater(
        client.fetchBangumiLite(1),
        throwsA(isA<AnitabiException>()),
      );
      expect(recoveries, 0);
    });

    test('API server errors retry on the updated address', () async {
      final client = AnitabiClient(
        serviceConfig: oldConfig,
        httpClient: serving({
          'https://old-api.example/bangumi/1/lite': http.Response('', 502),
          'https://new-api.example/bangumi/1/lite': http.Response(
            '{"id":1,"cn":"Work","title":"Work","city":"","litePoints":[],"pointsLength":0}',
            200,
          ),
        }),
      );

      final work = await client.fetchBangumiLite(1);
      expect(work.bangumiId, 1);
      expect(recoveries, 1);
    });
  });
}
