import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:miriago/main.dart';
import 'package:miriago/data/anitabi_client.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/point_detail/point_detail_sheet.dart';
import 'package:miriago/plan/anitabi_map_import_screen.dart';
import 'package:miriago/plan/plan_group_manager_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/widgets/constrained_menu_anchor.dart';
import 'package:miriago/widgets/reference_image_placeholder.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(MiriaGoApp(repository: SamplePilgrimageRepository()));
  await tester.pumpAndSettle();
}

Future<void> _pumpAppWithEmptyPlan(WidgetTester tester) async {
  final repository = SamplePilgrimageRepository();
  await repository.createPlan(name: '新巡礼计划 2', area: '未设置区域');
  await tester.pumpWidget(MiriaGoApp(repository: repository));
  await tester.pumpAndSettle();
}

Future<void> _openPlanMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('计划操作').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reference image placeholder explains loading states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            ReferenceImagePlaceholder(
              state: ReferenceImagePlaceholderState.loading,
            ),
            ReferenceImagePlaceholder(),
            ReferenceImagePlaceholder(
              state: ReferenceImagePlaceholderState.empty,
            ),
          ],
        ),
      ),
    );

    expect(find.text('参考图加载中'), findsOneWidget);
    expect(find.text('参考图暂不可用'), findsOneWidget);
    expect(find.text('暂无参考图'), findsOneWidget);
  });

  testWidgets('constrained menu handles many long options on small screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 170,
                child: ConstrainedMenuAnchor(
                  builder: (context, controller, child) {
                    return OutlinedButton(
                      onPressed: controller.open,
                      child: const Text('选择片区'),
                    );
                  },
                  menuChildrenBuilder: (context, itemWidth) => [
                    for (var index = 0; index < 16; index++)
                      MenuItemButton(
                        onPressed: () {},
                        child: SizedBox(
                          width: itemWidth,
                          child: Text(
                            '很长很长的片区名称 $index 号方向需要省略显示',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('选择片区'));
    await tester.pumpAndSettle();

    expect(find.textContaining('很长很长的片区名称'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the pilgrimage plan workflow shell', (tester) async {
    await _pumpApp(tester);

    expect(find.text('计划'), findsWidgets);
    expect(find.text('地图'), findsWidgets);
    expect(find.text('记录'), findsWidgets);
    expect(find.text('示例计划'), findsWidgets);
    expect(find.text('宇治站附近'), findsWidgets);
    expect(find.text('默认计划'), findsOneWidget);
    expect(find.text('井用机前步行道'), findsWidgets);
    expect(find.textContaining('1 部作品'), findsOneWidget);
  });

  testWidgets('opens camera reference from current target', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.photo_camera_outlined).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('叠影'), findsWidgets);
    expect(find.text('上下'), findsWidgets);
    expect(find.text('小窗'), findsNothing);
  });

  testWidgets('opens shared point detail sheet from plan list', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('井用机前步行道').first);
    await tester.pumpAndSettle();

    expect(find.text('当前目标'), findsWidgets);
    expect(find.text('坐标'), findsOneWidget);
    expect(find.text('来源'), findsOneWidget);
    expect(find.text('导航'), findsOneWidget);
    expect(find.text('拍摄参考'), findsWidgets);
    expect(find.text('标记完成'), findsWidgets);
    expect(find.text('编辑点位'), findsOneWidget);
  });

  testWidgets('point detail move sheet follows plan group order', (
    tester,
  ) async {
    final createdAt = DateTime.utc(2026);
    const work = PilgrimageWork(
      id: 'work',
      title: '作品',
      subtitle: '动画',
      city: '京都',
      source: WorkSource.manual,
    );
    final lateGroup = PilgrimagePlanGroup(
      id: 'late',
      name: '后访问',
      orderIndex: 2,
      createdAt: createdAt,
    );
    final earlyGroup = PilgrimagePlanGroup(
      id: 'early',
      name: '先访问',
      orderIndex: 0,
      createdAt: createdAt,
    );
    final middleGroup = PilgrimagePlanGroup(
      id: 'middle',
      name: '中间',
      orderIndex: 1,
      createdAt: createdAt,
    );
    const point = PilgrimagePoint(
      id: 'point',
      work: work,
      name: '测试点位',
      subtitle: '场景',
      position: LatLng(35, 135),
      episodeLabel: 'EP 1',
      referenceLabel: '手动',
      groupId: 'late',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () => PointDetailSheet.show(
                  context,
                  point: point,
                  status: VisitStatus.pending,
                  onReplaceReference: (_, _) async {},
                  groups: [lateGroup, earlyGroup, middleGroup],
                  onMoveToGroup: (_, _) async {},
                ),
                child: const Text('打开详情'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '更改'));
    await tester.pumpAndSettle();

    Finder optionText(String text) {
      return find.descendant(
        of: find.byType(ListTile),
        matching: find.text(text),
      );
    }

    final earlyTop = tester.getTopLeft(optionText('先访问')).dy;
    final middleTop = tester.getTopLeft(optionText('中间')).dy;
    final lateTop = tester.getTopLeft(optionText('后访问')).dy;

    expect(earlyTop, lessThan(middleTop));
    expect(middleTop, lessThan(lateTop));
  });

  testWidgets('edits point details from the shared detail sheet', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('井用机前步行道').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('编辑点位'));
    await tester.tap(find.text('编辑点位'));
    await tester.pumpAndSettle();

    expect(find.text('编辑点位'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '点位名称'),
      '井用机前步行道 改',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, '备注'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(find.widgetWithText(TextFormField, '备注'), '测试备注');
    await tester.scrollUntilVisible(
      find.text('保存修改'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '点位名称'), findsNothing);
    expect(find.text('井用机前步行道 改'), findsWidgets);
    await tester.tap(find.text('井用机前步行道 改').first);
    await tester.pumpAndSettle();
    expect(find.text('测试备注'), findsOneWidget);
  });

  testWidgets('shows group filters on the map', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.map_outlined).last);
    await tester.pumpAndSettle();

    expect(find.textContaining('宇治站附近'), findsWidgets);
    expect(find.byTooltip('当前目标'), findsOneWidget);
    expect(find.text('井用机前步行道'), findsWidgets);
    expect(find.text('吹响吧！上低音号 / EP 1 / 2:08'), findsOneWidget);
    expect(find.textContaining('あじろぎの道 / 34.'), findsNothing);
  });

  testWidgets('plan map marker opens detail after selecting the point', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, '地图'));
    await tester.pumpAndSettle();
    const markerKey = ValueKey('plan-map-marker-anitabi-115908-7gs3o1mm');

    await tester.tap(find.byKey(markerKey));
    await tester.pumpAndSettle();

    expect(find.text('宇治桥'), findsWidgets);

    await tester.tap(find.byKey(markerKey));
    await tester.pumpAndSettle();

    expect(find.text('坐标'), findsOneWidget);
    expect(find.text('来源'), findsOneWidget);
    expect(find.text('导航'), findsOneWidget);
  });

  testWidgets('shows plan manager', (tester) async {
    await _pumpApp(tester);

    await _openPlanMenu(tester);
    await tester.tap(find.text('管理计划'));
    await tester.pumpAndSettle();

    expect(find.text('管理计划'), findsOneWidget);
    expect(find.textContaining('关键点'), findsWidgets);
    expect(find.text('无序'), findsWidgets);
    expect(find.text('井用机前步行道'), findsOneWidget);
  });

  testWidgets('new plan group requires a non-empty name', (tester) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '片区测试', area: '京都');

    await tester.pumpWidget(
      MaterialApp(
        home: PlanGroupManagerScreen(plan: plan, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建片区'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(find.text('片区名不能为空'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('新建片区'),
      ),
      findsOneWidget,
    );

    await tester.enterText(find.widgetWithText(TextField, '片区名称'), '新片区');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(find.text('片区名不能为空'), findsNothing);
    expect(find.text('新片区'), findsOneWidget);
  });

  testWidgets('hides desktop launcher status outside web builds', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsWidgets);
    expect(find.text('桌面端'), findsNothing);
    expect(find.textContaining('桌面启动器'), findsNothing);
  });

  testWidgets('creates empty plan and shows add-points shell', (tester) async {
    await _pumpAppWithEmptyPlan(tester);

    expect(find.textContaining('新巡礼计划 2'), findsWidgets);
    expect(find.text('还没有点位'), findsOneWidget);
    expect(find.text('添加点位'), findsOneWidget);

    await tester.tap(find.text('添加点位'));
    await tester.pumpAndSettle();

    expect(find.text('添加内容'), findsOneWidget);
    expect(find.text('作品管理'), findsOneWidget);
    expect(find.text('手动添加点位'), findsOneWidget);
  });

  testWidgets('creates a new plan from the plan manager', (tester) async {
    await _pumpApp(tester);

    await _openPlanMenu(tester);
    await tester.tap(find.text('切换计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '新建计划'));
    await tester.pumpAndSettle();

    expect(find.text('新巡礼计划 2'), findsOneWidget);
    expect(find.textContaining('未设置区域'), findsOneWidget);
  });

  testWidgets('adds a manual work to an empty plan', (tester) async {
    await _pumpAppWithEmptyPlan(tester);

    await tester.tap(find.text('添加点位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('作品管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动添加'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '作品名称'), '原创短片');
    await tester.enterText(
      find.widgetWithText(TextFormField, '作品原名'),
      'Original',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '主要地区'), '京都市');
    await tester.tap(find.text('保存作品'));
    await tester.pumpAndSettle();

    expect(find.text('手动添加作品'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('原创短片'), findsOneWidget);
    expect(find.textContaining('0 个点位'), findsOneWidget);
  });

  testWidgets('adds a manual point to an empty plan', (tester) async {
    await _pumpAppWithEmptyPlan(tester);

    await tester.tap(find.text('添加点位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动添加点位'));
    await tester.pumpAndSettle();

    expect(find.text('备注'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '动画/作品名称'),
      '轻音少女',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '点位名称'), '鸭川三条');
    await tester.enterText(find.widgetWithText(TextFormField, '位置说明'), '鸭川沿岸');
    await tester.enterText(
      find.widgetWithText(TextFormField, '集数/场景标签'),
      '自定义场景 1',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '参考来源'), '手动录入');
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, '纬度'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.widgetWithText(TextFormField, '纬度'), '35.0089');
    await tester.enterText(
      find.widgetWithText(TextFormField, '经度'),
      '135.7711',
    );
    await tester.ensureVisible(find.text('保存点位'));
    await tester.tap(find.text('保存点位'));
    await tester.pumpAndSettle();

    expect(find.text('未分组'), findsWidgets);
    expect(find.text('鸭川三条'), findsWidgets);
    expect(find.text('轻音少女 / 鸭川沿岸 / 自定义场景 1'), findsWidgets);
  });

  testWidgets('manual point map picker requires explicit pick mode', (
    tester,
  ) async {
    await _pumpAppWithEmptyPlan(tester);

    await tester.tap(find.text('添加点位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动添加点位'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('从地图选择坐标'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('从地图选择坐标'));
    await tester.tap(find.text('从地图选择坐标'));
    await tester.pumpAndSettle();

    expect(find.text('选择点位坐标'), findsOneWidget);
    expect(find.text('先点击右上角选点按钮，再点击地图设置坐标'), findsOneWidget);
    expect(find.text('35.000000, 135.000000'), findsNothing);

    await tester.tap(find.byTooltip('在地图上选点'));
    await tester.pumpAndSettle();
    expect(find.text('点击地图任意位置设置点位坐标'), findsOneWidget);
    expect(find.textContaining('点击地图可继续调整位置'), findsNothing);
  });

  testWidgets('Anitabi point ID import adds missing work on import', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '点位 ID 测试', area: '京都');
    final anitabiClient = _FakeAnitabiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: plan,
          repository: repository,
          initialPointId: 'point-1',
          anitabiClient: anitabiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    var updatedPlan = await repository.loadActivePlan();
    expect(updatedPlan.works, isEmpty);
    expect(anitabiClient.lookedUpPointIds, contains('point-1'));

    await tester.tap(find.text('加入计划'));
    await tester.pumpAndSettle();

    updatedPlan = await repository.loadActivePlan();
    expect(
      updatedPlan.works.where((work) => work.bangumiId == 12345),
      hasLength(1),
    );
    expect(updatedPlan.points, hasLength(1));
  });

  testWidgets('Anitabi point ID import reuses existing work', (tester) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '点位 ID 测试', area: '京都');
    final existingWork = PilgrimageWork(
      id: 'existing-work',
      bangumiId: 12345,
      title: '已有作品',
      subtitle: 'Existing',
      city: '京都',
      source: WorkSource.bangumi,
    );
    final planWithWork = await repository.addWorkToPlan(
      planId: plan.id,
      work: existingWork,
    );
    final anitabiClient = _FakeAnitabiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: planWithWork,
          repository: repository,
          initialPointId: 'point-1',
          anitabiClient: anitabiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final updatedPlan = await repository.loadActivePlan();
    final works = updatedPlan.works
        .where((work) => work.bangumiId == 12345)
        .toList(growable: false);
    expect(works, hasLength(1));
    expect(works.single.id, existingWork.id);
    expect(anitabiClient.lookedUpPointIds, contains('point-1'));
  });

  testWidgets('Anitabi map import explains manual works', (tester) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '手动作品测试', area: '京都');
    final manualWork = PilgrimageWork(
      id: 'manual-work',
      title: '原创短片',
      subtitle: 'Original',
      city: '京都',
      source: WorkSource.manual,
    );
    final planWithWork = await repository.addWorkToPlan(
      planId: plan.id,
      work: manualWork,
    );
    final anitabiClient = _FakeAnitabiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: planWithWork,
          repository: repository,
          anitabiClient: anitabiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('从作品地图导入'), findsOneWidget);
    expect(find.textContaining('手动添加的作品没有 Bangumi ID'), findsOneWidget);
    expect(anitabiClient.fetchedPointPids, isEmpty);
    expect(anitabiClient.lookedUpPointIds, isEmpty);
  });

  testWidgets('Anitabi map import ignores stale work load results', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '切换作品测试', area: '京都');
    final planWithFirstWork = await repository.addWorkToPlan(
      planId: plan.id,
      work: const PilgrimageWork(
        id: 'work-slow',
        bangumiId: 1001,
        title: '慢作品',
        subtitle: '',
        city: '京都',
        source: WorkSource.bangumi,
      ),
    );
    final planWithWorks = await repository.addWorkToPlan(
      planId: planWithFirstWork.id,
      work: const PilgrimageWork(
        id: 'work-fast',
        bangumiId: 1002,
        title: '快作品',
        subtitle: '',
        city: '京都',
        source: WorkSource.bangumi,
      ),
    );
    final anitabiClient = _FakeAnitabiClient(
      pointDelays: const {1001: Duration(milliseconds: 80)},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: planWithWorks,
          repository: repository,
          anitabiClient: anitabiClient,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<PilgrimageWork>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('快作品').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('1002 点位'), findsOneWidget);
    expect(find.text('1002 场景 / EP 1002'), findsOneWidget);
    expect(find.text('1001 点位'), findsNothing);
    expect(find.text('1001 场景 / EP 1001'), findsNothing);
  });

  testWidgets('Anitabi initial Bangumi load failure does not add work', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '失败导入测试', area: '京都');
    final anitabiClient = _FakeAnitabiClient(failingPointPids: {12345});

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: plan,
          repository: repository,
          initialBangumiId: 12345,
          anitabiClient: anitabiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final updatedPlan = await repository.loadActivePlan();
    expect(updatedPlan.works, isEmpty);
    expect(anitabiClient.fetchedPointPids, contains(12345));
  });
}

class _FakeAnitabiClient extends AnitabiClient {
  _FakeAnitabiClient({
    this.pointDelays = const {},
    this.failingPointPids = const {},
  });

  final fetchedPointPids = <int>[];
  final lookedUpPointIds = <String>[];
  final Map<int, Duration> pointDelays;
  final Set<int> failingPointPids;

  @override
  Future<AnitabiBangumiLite> fetchBangumiLite(int bangumiId) async {
    return AnitabiBangumiLite(
      bangumiId: bangumiId,
      title: switch (bangumiId) {
        1001 => '慢作品',
        1002 => '快作品',
        _ => 'PID 作品',
      },
      subtitle: 'Pid Work',
      city: '京都',
      center: const LatLng(35, 135),
      zoom: 14,
      pointsLength: 1,
    );
  }

  @override
  Future<List<AnitabiPoint>> fetchPoints(
    int bangumiId, {
    AnitabiBangumiLite? lite,
  }) async {
    final delay = pointDelays[bangumiId];
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    fetchedPointPids.add(bangumiId);
    if (failingPointPids.contains(bangumiId)) {
      throw AnitabiStaticDataUnavailableException(
        'fixture failure for $bangumiId',
      );
    }
    return [
      AnitabiPoint(
        bangumiId: bangumiId,
        id: 'point-1',
        name: '$bangumiId 点位',
        subtitle: '$bangumiId 场景',
        position: const LatLng(35, 135),
        episodeLabel: 'EP $bangumiId',
        referenceImageUrl: null,
        origin: 'Anitabi',
        originUrl: 'https://anitabi.cn/',
      ),
    ];
  }

  @override
  Future<AnitabiPointLookupResult?> findPointById(String pointId) async {
    lookedUpPointIds.add(pointId);
    return AnitabiPointLookupResult(
      work: await fetchBangumiLite(12345),
      point: (await fetchPoints(12345)).single,
    );
  }
}
