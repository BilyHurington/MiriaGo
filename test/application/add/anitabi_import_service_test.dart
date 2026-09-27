import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/add/add_dependencies.dart';
import 'package:miriago/application/add/anitabi_import_service.dart';
import 'package:miriago/application/plan_session.dart';
import 'package:miriago/data/anitabi_client.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

import 'fakes.dart';

void main() {
  late ScriptedRepository repository;
  late PlanSession session;
  late List<AddNotice> notices;
  late List<String> cached;

  setUp(() async {
    repository = ScriptedRepository();
    session = PlanSession(repository: repository);
    await session.load();
    notices = [];
    cached = [];
  });

  tearDown(() => session.dispose());

  AnitabiImportController create(
    FakeAnitabiClient client, {
    int? bangumiId,
    String? pointId,
    Set<String> failCacheFor = const {},
  }) {
    final controller = AnitabiImportController(
      session: session,
      client: client,
      readSettings: () => const AppSettings(),
      initialBangumiId: bangumiId,
      initialPointId: pointId,
      cacheThumbnail: (point, _) async {
        if (failCacheFor.contains(point.sourceId)) return null;
        cached.add(point.id);
        return '/cache/${point.id}.jpg';
      },
      onNotice: notices.add,
    );
    addTearDown(() {
      if (!controller.isDisposed) controller.dispose();
    });
    return controller;
  }

  test('without ids the first Bangumi work of the plan is loaded', () async {
    final client = FakeAnitabiClient();
    final controller = create(client);
    await controller.start();
    expect(controller.selectedWork?.bangumiId, sampleBangumiId);
    expect(controller.visiblePoints, hasLength(3));
    expect(controller.availablePoints, hasLength(3));
    // Valid lite centre → the first point is pre-selected.
    expect(controller.selectedPoint?.id, 'a1');
    expect(controller.cameraTarget?.center, const LatLng(34.89, 135.80));
    expect(controller.isLoading, isFalse);
  });

  test('point link: global lookup first, then the work, zoom ≥ 15', () async {
    final client = FakeAnitabiClient()..globalLookupFinds = false;
    final controller = create(
      client,
      bangumiId: sampleBangumiId,
      pointId: 'a2',
    );
    await controller.start();
    expect(controller.selectedPoint?.id, 'a2');
    expect(controller.cameraTarget?.zoom, 15);
    expect(controller.cameraTarget?.center, const LatLng(34.891, 135.80));
  });

  test('unknown point link reports 没有找到这个 Anitabi 点位', () async {
    final controller = create(
      FakeAnitabiClient(),
      bangumiId: sampleBangumiId,
      pointId: 'missing',
    );
    await controller.start();
    expect(controller.error, isA<AnitabiPointNotFoundException>());
    expect(anitabiErrorMessageFor(controller.error), '没有找到这个 Anitabi 点位');
  });

  test('a Bangumi id outside the plan builds a bangumi-<id> work', () async {
    final client = FakeAnitabiClient(
      points: {
        1424: [anitabiPoint('k1', bangumiId: 1424)],
      },
    );
    final controller = create(client, bangumiId: 1424);
    await controller.start();
    expect(controller.selectedWork?.id, 'bangumi-1424');
    expect(controller.works.last.id, 'bangumi-1424');
    expect(controller.visiblePoints.single.id, 'k1');
  });

  test('manual works show the 没有 Bangumi ID notice', () async {
    final controller = create(FakeAnitabiClient());
    const manual = PilgrimageWork(
      id: 'manual-work-1',
      title: 'M',
      subtitle: '',
      city: '',
      source: WorkSource.manual,
    );
    await controller.loadPoints(manual);
    expect(controller.visiblePoints, isEmpty);
    expect(notices.single.title, AnitabiImportTexts.manualWork);
  });

  test('errors map to the old titles and details', () {
    expect(
      anitabiErrorMessageFor(const AnitabiStaticDataUnavailableException('x')),
      'Anitabi 地图数据无法加载',
    );
    expect(
      anitabiErrorDetailFor(
        const AnitabiStaticDataUnavailableException('x'),
        isWeb: false,
      ),
      startsWith('无法读取 Anitabi 地图索引'),
    );
    expect(
      anitabiErrorMessageFor(const AnitabiWorkNotFoundException(1)),
      'Anitabi 中没有找到这个作品',
    );
    expect(
      anitabiErrorMessageFor(const AnitabiNoPointsException(1)),
      '当前作品暂无 Anitabi 点位',
    );
    expect(
      anitabiErrorDetailFor(
        const AnitabiPartialPointsException(loadedCount: 2, expectedCount: 5),
      ),
      contains('2 / 共 5'),
    );
    expect(
      anitabiErrorMessageFor(const AnitabiException(404, '')),
      '这个 Bangumi 条目暂无 Anitabi 地图数据',
    );
    expect(anitabiErrorMessageFor(Exception()), 'Anitabi 点位加载失败');
    expect(anitabiErrorDetailFor(Exception()), '请检查网络后重试，或稍后再重新加载。');
  });

  test('load errors surface and refresh clears the static cache', () async {
    final client = FakeAnitabiClient(
      fetchError: const AnitabiNoPointsException(sampleBangumiId),
    );
    final controller = create(client);
    await controller.start();
    expect(controller.error, isA<AnitabiNoPointsException>());
    client.fetchError = null;
    await controller.refresh();
    expect(client.clearCount, 1);
    expect(notices.first.title, '正在清除缓存并重新加载 Anitabi 点位...');
    expect(controller.error, isNull);
    expect(controller.visiblePoints, hasLength(3));
  });

  test('import all writes points, caches thumbnails and reports', () async {
    final controller = create(FakeAnitabiClient());
    await controller.start();
    final before = session.plan.points.length;
    final revision = session.revision;
    final outcome = await controller.importAll();
    expect(outcome, isNotNull);
    expect(outcome!.points, hasLength(3));
    expect(outcome.showOrganizeGuide, isTrue);
    expect(session.plan.points.length, before + 3);
    expect(session.revision, greaterThan(revision));
    expect(cached, hasLength(3));
    final imported = session.plan.points.firstWhere(
      (p) => p.id == 'anitabi-$sampleBangumiId-a1',
    );
    expect(imported.referenceThumbnailPath, '/cache/${imported.id}.jpg');
    expect(imported.source, PointSource.anitabi);
    expect(imported.groupId, isNull);
    expect(controller.availablePoints, isEmpty);
    expect(controller.importedCount, 3);
    expect(controller.isImporting, isFalse);
    expect(notices.first.title, '正在导入 3 个点位...');
    expect(notices.map((n) => n.title), contains('正在缓存缩略图 3/3，成功 3'));
    expect(
      notices.last,
      const AddNotice(AddNoticeKind.success, '已添加所有未加入的点位。'),
    );
    // Nothing left to import: no second write.
    expect(await controller.importAll(), isNull);
  });

  test('partial thumbnail caching reports the warning text', () async {
    final controller = create(FakeAnitabiClient(), failCacheFor: {'a2'});
    await controller.start();
    await controller.importAll();
    expect(
      notices.last,
      const AddNotice(AddNoticeKind.warning, '已导入 3 个点位，缩略图缓存 2/3，其余稍后会自动补齐。'),
    );
  });

  test('single import skips the organize guide', () async {
    final controller = create(FakeAnitabiClient());
    await controller.start();
    final outcome = await controller.importSelectedPoint();
    expect(outcome?.showOrganizeGuide, isFalse);
    expect(notices.last.title, '已加入计划，可继续选择点位。');
    expect(controller.isImported(controller.selectedPoint!), isTrue);
    expect(await controller.importSelectedPoint(), isNull);
  });

  test('import failure uses the failure message', () async {
    repository.failAdd = true;
    final controller = create(FakeAnitabiClient());
    await controller.start();
    final outcome = await controller.importBox(controller.availablePoints);
    expect(outcome, isNull);
    expect(
      notices.last,
      const AddNotice(AddNoticeKind.error, '框选点位导入失败，请稍后重试。'),
    );
    expect(controller.isImporting, isFalse);
  });

  test('box selection only counts points not in the plan', () async {
    final controller = create(FakeAnitabiClient());
    await controller.start();
    await controller.importSelectedPoint();
    final inBox = controller.availablePointsWhere((p) => p.latitude < 34.8915);
    expect(inBox.map((p) => p.id), ['a2']);
  });

  test('overlap browsing cycles through the group', () async {
    final controller = create(FakeAnitabiClient());
    await controller.start();
    controller.openOverlap(controller.visiblePoints);
    expect(controller.overlapIds, ['a1', 'a2', 'a3']);
    expect(controller.overlapIndex, 0);
    controller.moveOverlap(1);
    expect(controller.selectedPoint?.id, 'a2');
    controller.moveOverlap(-1);
    controller.moveOverlap(-1);
    expect(controller.selectedPoint?.id, 'a3');
    controller.selectPoint(controller.visiblePoints.first);
    expect(controller.overlapIds, isEmpty);
  });

  test('assignToGroup moves the points and names the group', () async {
    final controller = create(FakeAnitabiClient());
    await controller.start();
    final outcome = await controller.importAll();
    final ids = outcome!.points.map((p) => p.id).toSet();
    final group = session.plan.groups.first;
    final notice = await controller.assignToGroup(ids, group.id);
    expect(notice.title, '已将 3 个点位分配到「${group.name}」');
    expect(
      session.plan.points
          .where((p) => ids.contains(p.id))
          .map((p) => p.groupId),
      everyElement(group.id),
    );
    final back = await controller.assignToGroup(ids, null);
    expect(back.title, '已将 3 个点位分配到「未分入片区」');
    repository.failMove = true;
    final failed = await controller.assignToGroup(ids, group.id);
    expect(failed, const AddNotice(AddNoticeKind.error, '点位分配失败，请稍后重试。'));
  });

  test('thumbnail URLs request the h160 plan on Anitabi hosts', () {
    expect(
      anitabiPreviewThumbnailUrl('https://image.anitabi.cn/points/1/a.jpg'),
      'https://image.anitabi.cn/points/1/a.jpg?plan=h160',
    );
    expect(anitabiPreviewThumbnailUrl(null), isNull);
  });
}
