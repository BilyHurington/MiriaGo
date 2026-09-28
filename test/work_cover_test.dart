import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/anitabi_client.dart';
import 'package:miriago/data/bangumi_api_client.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/data/work_cover_backfill.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_work_cover.dart';
import 'package:miriago/widgets/anitabi_network_image.dart';

const _anitabiCover = 'https://image.anitabi.cn/bangumi/115908.jpg?plan=h160';

PilgrimageWork _work(String id, {int? bangumiId, String? cover}) =>
    PilgrimageWork(
      id: id,
      bangumiId: bangumiId,
      coverImageUrl: cover,
      title: id,
      subtitle: '',
      city: '京都',
      source: bangumiId == null ? WorkSource.manual : WorkSource.bangumi,
    );

PilgrimagePlan _plan(String id, List<PilgrimageWork> works) => PilgrimagePlan(
  id: id,
  name: id,
  area: '京都',
  works: works,
  points: const [],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _AnitabiCovers extends AnitabiClient {
  _AnitabiCovers(this.covers, {this.fail = false});

  final Map<int, String> covers;
  final bool fail;
  final lookups = <int>[];

  @override
  Future<AnitabiBangumiLite?> fetchBangumiLiteFromStatic(int bangumiId) async {
    lookups.add(bangumiId);
    if (fail) {
      throw const AnitabiStaticDataUnavailableException('offline');
    }
    final cover = covers[bangumiId];
    if (cover == null) {
      return null;
    }
    return AnitabiBangumiLite(
      bangumiId: bangumiId,
      title: '',
      subtitle: '',
      city: '',
      center: const LatLng(35, 135),
      zoom: 12,
      pointsLength: 1,
      coverImageUrl: cover,
    );
  }
}

class _BangumiCovers extends BangumiApiClient {
  _BangumiCovers(this.covers, {this.fail = false});

  final Map<int, String> covers;
  final bool fail;
  final lookups = <int>[];

  @override
  Future<String?> fetchSubjectCover(int bangumiId) async {
    lookups.add(bangumiId);
    if (fail) {
      throw const BangumiApiException(503, '');
    }
    return covers[bangumiId];
  }
}

void main() {
  group('Anitabi covers', () {
    test('static index path becomes an official thumbnail URL', () {
      expect(anitabiCoverImageUrl('/images/bangumi/115908.jpg'), _anitabiCover);
      expect(anitabiCoverImageUrl(_anitabiCover), _anitabiCover);
      expect(
        anitabiCoverImageUrl('https://img-tc.anitabi.cn/bangumi/1.jpg'),
        'https://image.anitabi.cn/bangumi/1.jpg?plan=h160',
      );
    });

    test('missing or unusable covers are ignored', () {
      expect(anitabiCoverImageUrl(null), isNull);
      expect(anitabiCoverImageUrl(''), isNull);
      expect(anitabiCoverImageUrl(0), isNull);
      expect(anitabiCoverImageUrl('http://example.com/a.jpg'), isNull);
    });

    test('API and static index expose the cover', () {
      final lite = AnitabiBangumiLite.fromJson({
        'id': 115908,
        'cn': '吹响吧！上低音号',
        'title': '響け！ユーフォニアム',
        'cover': _anitabiCover,
      });
      expect(lite.coverImageUrl, _anitabiCover);

      final work = AnitabiMapWorkLite.fromCompactJson([
        115908,
        '吹响吧！上低音号',
        0,
        '響け！ユーフォニアム',
        '宇治市',
        '#02a7bd',
        '/images/bangumi/115908.jpg',
        8.0,
        'TV',
        34.9,
        135.8,
        12,
        [],
      ]);
      expect(work.coverImageUrl, _anitabiCover);
      expect(work.toBangumiLite().coverImageUrl, _anitabiCover);
    });
  });

  group('WorkCoverBackfill', () {
    setUp(WorkCoverBackfill.resetSession);

    test('fills missing covers without replacing existing ones', () async {
      final repository = SamplePilgrimageRepository(
        plans: [
          _plan('a', [
            _work('anitabi', bangumiId: 1),
            _work('bangumi', bangumiId: 2),
            _work('kept', bangumiId: 3, cover: 'https://example.com/mine.jpg'),
            _work('manual'),
          ]),
          _plan('b', [_work('same-work', bangumiId: 1)]),
        ],
      );
      final anitabi = _AnitabiCovers({1: _anitabiCover, 3: _anitabiCover});
      final bangumi = _BangumiCovers({2: 'https://lain.bgm.tv/2.jpg'});

      final updated = await WorkCoverBackfill(
        repository: repository,
        anitabiClient: anitabi,
        bangumiApiClient: bangumi,
      ).run();

      expect(anitabi.lookups, [1, 2]);
      expect(bangumi.lookups, [2]);
      expect(updated.keys, unorderedEquals(['a', 'b']));
      final plans = {
        for (final plan in await repository.loadPlans()) plan.id: plan,
      };
      String? cover(String planId, String workId) => plans[planId]!.works
          .singleWhere((work) => work.id == workId)
          .coverImageUrl;
      expect(cover('a', 'anitabi'), _anitabiCover);
      expect(cover('a', 'bangumi'), 'https://lain.bgm.tv/2.jpg');
      expect(cover('a', 'kept'), 'https://example.com/mine.jpg');
      expect(cover('a', 'manual'), isNull);
      expect(cover('b', 'same-work'), _anitabiCover);
    });

    test('each work is looked up once per session', () async {
      final repository = SamplePilgrimageRepository(
        plans: [
          _plan('a', [_work('w', bangumiId: 1)]),
        ],
      );
      final anitabi = _AnitabiCovers({});
      final bangumi = _BangumiCovers({});
      WorkCoverBackfill backfill() => WorkCoverBackfill(
        repository: repository,
        anitabiClient: anitabi,
        bangumiApiClient: bangumi,
      );

      expect(await backfill().run(), isEmpty);
      expect(await backfill().run(), isEmpty);
      expect(anitabi.lookups, [1]);
      expect(bangumi.lookups, [1]);
    });

    test('offline lookups keep the work and retry next session', () async {
      final repository = SamplePilgrimageRepository(
        plans: [
          _plan('a', [_work('w', bangumiId: 1)]),
        ],
      );

      final offline = await WorkCoverBackfill(
        repository: repository,
        anitabiClient: _AnitabiCovers({}, fail: true),
        bangumiApiClient: _BangumiCovers({}, fail: true),
      ).run();
      expect(offline, isEmpty);
      expect(
        (await repository.loadPlans()).single.works.single.coverImageUrl,
        isNull,
      );

      WorkCoverBackfill.resetSession();
      await WorkCoverBackfill(
        repository: repository,
        anitabiClient: _AnitabiCovers({1: _anitabiCover}),
        bangumiApiClient: _BangumiCovers({}),
      ).run();
      expect(
        (await repository.loadPlans()).single.works.single.coverImageUrl,
        _anitabiCover,
      );
    });
  });

  group('PilgrimageWorkCover', () {
    testWidgets('Anitabi covers use the Anitabi image services', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PilgrimageWorkCover(
            work: _work('w', bangumiId: 1, cover: _anitabiCover),
          ),
        ),
      );
      expect(find.byType(AnitabiNetworkImage), findsOneWidget);
    });

    testWidgets('other covers load directly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PilgrimageWorkCover(
            work: _work('w', bangumiId: 1, cover: 'https://lain.bgm.tv/1.jpg'),
          ),
        ),
      );
      expect(find.byType(AnitabiNetworkImage), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
