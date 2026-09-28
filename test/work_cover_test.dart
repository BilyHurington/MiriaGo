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
  _BangumiCovers(this.covers, {this.unreachable = const {}});

  final Map<int, String> covers;
  final Set<int> unreachable;
  final lookups = <int>[];

  @override
  Future<String?> fetchSubjectCover(int bangumiId) async {
    lookups.add(bangumiId);
    if (unreachable.contains(bangumiId)) {
      throw const BangumiApiException(503, '');
    }
    return covers[bangumiId];
  }
}

/// Deletes the work while its cover is being looked up.
class _DeletingBangumi extends BangumiApiClient {
  _DeletingBangumi(this.repository);

  final SamplePilgrimageRepository repository;

  @override
  Future<String?> fetchSubjectCover(int bangumiId) async {
    final plan = (await repository.loadPlans()).single;
    await repository.deleteWorkFromPlan(planId: plan.id, workId: 'gone');
    return 'https://lain.bgm.tv/1.jpg';
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

    WorkCoverBackfill backfill(
      SamplePilgrimageRepository repository,
      _AnitabiCovers anitabi,
      BangumiApiClient bangumi,
    ) => WorkCoverBackfill(
      repository: repository,
      anitabiClient: () => anitabi,
      bangumiApiClient: () => bangumi,
    );

    test('fills missing covers without replacing existing ones', () async {
      final repository = SamplePilgrimageRepository(
        plans: [
          _plan('a', [
            _work('bangumi', bangumiId: 1),
            _work('offline-bangumi', bangumiId: 2),
            _work('kept', bangumiId: 3, cover: 'https://example.com/mine.jpg'),
            _work('manual'),
          ]),
          _plan('b', [_work('same-work', bangumiId: 1)]),
        ],
      );
      final anitabi = _AnitabiCovers({2: _anitabiCover});
      final bangumi = _BangumiCovers(
        {1: 'https://lain.bgm.tv/1.jpg'},
        unreachable: {2},
      );

      final updated = await backfill(repository, anitabi, bangumi).run();

      expect(bangumi.lookups, [1, 2]);
      // The 2 MB Anitabi index is only for works Bangumi could not answer.
      expect(anitabi.lookups, [2]);
      expect(updated.keys, unorderedEquals(['a', 'b']));
      expect(
        updated['a']!.map((work) => work.coverImageUrl),
        unorderedEquals(['https://lain.bgm.tv/1.jpg', _anitabiCover]),
      );
      final plans = {
        for (final plan in await repository.loadPlans()) plan.id: plan,
      };
      String? cover(String planId, String workId) => plans[planId]!.works
          .singleWhere((work) => work.id == workId)
          .coverImageUrl;
      expect(cover('a', 'bangumi'), 'https://lain.bgm.tv/1.jpg');
      expect(cover('a', 'offline-bangumi'), _anitabiCover);
      expect(cover('a', 'kept'), 'https://example.com/mine.jpg');
      expect(cover('a', 'manual'), isNull);
      expect(cover('b', 'same-work'), 'https://lain.bgm.tv/1.jpg');
    });

    test('each work is looked up once per session', () async {
      final repository = SamplePilgrimageRepository(
        plans: [
          _plan('a', [_work('w', bangumiId: 1)]),
        ],
      );
      final anitabi = _AnitabiCovers({});
      final bangumi = _BangumiCovers({});

      expect(await backfill(repository, anitabi, bangumi).run(), isEmpty);
      expect(await backfill(repository, anitabi, bangumi).run(), isEmpty);
      expect(bangumi.lookups, [1]);
      expect(anitabi.lookups, isEmpty);
    });

    test('works beyond the per-run limit are looked up next run', () async {
      final repository = SamplePilgrimageRepository(
        plans: [
          _plan('a', [
            for (var id = 1; id <= WorkCoverBackfill.maxLookupsPerRun + 2; id++)
              _work('w$id', bangumiId: id),
          ]),
        ],
      );
      final bangumi = _BangumiCovers({});
      await backfill(repository, _AnitabiCovers({}), bangumi).run();
      expect(bangumi.lookups, hasLength(WorkCoverBackfill.maxLookupsPerRun));
      await backfill(repository, _AnitabiCovers({}), bangumi).run();
      expect(
        bangumi.lookups,
        hasLength(WorkCoverBackfill.maxLookupsPerRun + 2),
      );
    });

    test('offline lookups keep the work and retry next session', () async {
      final repository = SamplePilgrimageRepository(
        plans: [
          _plan('a', [_work('w', bangumiId: 1)]),
        ],
      );

      final offline = await backfill(
        repository,
        _AnitabiCovers({}, fail: true),
        _BangumiCovers({}, unreachable: {1}),
      ).run();
      expect(offline, isEmpty);
      expect(
        (await repository.loadPlans()).single.works.single.coverImageUrl,
        isNull,
      );

      WorkCoverBackfill.resetSession();
      await backfill(
        repository,
        _AnitabiCovers({}),
        _BangumiCovers({1: 'https://lain.bgm.tv/1.jpg'}),
      ).run();
      expect(
        (await repository.loadPlans()).single.works.single.coverImageUrl,
        'https://lain.bgm.tv/1.jpg',
      );
    });

    test('a work deleted during the lookup is not brought back', () async {
      final repository = SamplePilgrimageRepository(
        plans: [
          _plan('a', [_work('gone', bangumiId: 1)]),
        ],
      );
      final bangumi = _DeletingBangumi(repository);

      final updated = await backfill(
        repository,
        _AnitabiCovers({}),
        bangumi,
      ).run();

      expect(updated, isEmpty);
      expect((await repository.loadPlans()).single.works, isEmpty);
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
