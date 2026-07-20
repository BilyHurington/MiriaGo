import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
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

Future<void> _openAddPointsFromEmptyPlan(WidgetTester tester) async {
  _invokeKeyedAction(tester, 'plan-add-points');
  await tester.pumpAndSettle();
}

void _invokeKeyedAction(WidgetTester tester, String key) {
  final finder = find.byKey(ValueKey(key));
  final widget = tester.widget(finder);
  if (widget is ButtonStyleButton) {
    widget.onPressed!();
    return;
  }
  if (widget is InkWell) {
    widget.onTap!();
    return;
  }
  final inkWell = find.descendant(of: finder, matching: find.byType(InkWell));
  tester.widget<InkWell>(inkWell.first).onTap!();
}

void _mockClipboardRead(WidgetTester tester, String text) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') {
      return <String, dynamic>{'text': text};
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
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

  testWidgets('restores the last selected plan group', (tester) async {
    final group = samplePilgrimagePlan.groups.last;
    final repository = SamplePilgrimageRepository(
      plans: [samplePilgrimagePlan.copyWith(currentGroupId: group.id)],
    );
    await tester.pumpWidget(MiriaGoApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, group.name), findsOneWidget);
  });

  testWidgets('opens and edits plan memo from plan menu', (tester) async {
    await _pumpApp(tester);

    await _openPlanMenu(tester);
    await tester.tap(find.text('计划备忘录'));
    await tester.pumpAndSettle();

    expect(find.text('计划备忘录'), findsOneWidget);
    expect(find.text('还没有计划备忘'), findsOneWidget);
    expect(find.text('开始记录'), findsOneWidget);

    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '第一天先去宇治站，下午整理补拍点。');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('计划备忘录已保存'), findsOneWidget);
    expect(find.text('第一天先去宇治站，下午整理补拍点。'), findsOneWidget);
  });

  testWidgets('plan memo toolbar inserts markdown and preview renders it', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _openPlanMenu(tester);
    await tester.tap(find.text('计划备忘录'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('标题'));
    await tester.pumpAndSettle();
    expect(find.text('## 标题'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byTooltip('待办'));
    await tester.pumpAndSettle();
    expect(find.textContaining('- [ ] 待办事项'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      '# 第一天\n\n- [ ] 预约咖啡店\n\n> 下雨时改室内点位\n\n![参考图](https://example.com/a.jpg)',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('第一天'), findsOneWidget);
    expect(find.text('预约咖啡店'), findsOneWidget);
    expect(find.textContaining('备忘录不支持图片'), findsOneWidget);
  });

  testWidgets('plan memo quote renders and task checkbox toggles markdown', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _openPlanMenu(tester);
    await tester.tap(find.text('计划备忘录'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '> 备用路线\n\n- [ ] 预约咖啡店\n- [x] 下载参考图',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('备用路线'), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_box_outline_blank));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_box), findsNWidgets(2));

    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    expect(find.textContaining('- [x] 预约咖啡店'), findsOneWidget);
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
    _invokeKeyedAction(tester, 'point-detail-edit');
    await tester.pumpAndSettle();

    expect(find.text('编辑点位'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('point-form-name')),
      '井用机前步行道 改',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('point-form-note')),
      '测试备注',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    _invokeKeyedAction(tester, 'point-form-save');
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

    await _openAddPointsFromEmptyPlan(tester);

    expect(find.text('添加内容'), findsOneWidget);
    expect(find.text('管理作品'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-points-manual-point')),
      findsOneWidget,
    );
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

    await _openAddPointsFromEmptyPlan(tester);
    _invokeKeyedAction(tester, 'add-points-work-manager');
    await tester.pumpAndSettle();
    _invokeKeyedAction(tester, 'work-manager-manual-work');
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '原创短片');
    await tester.enterText(fields.at(1), 'Original');
    await tester.enterText(fields.at(2), '京都市');
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

    await _openAddPointsFromEmptyPlan(tester);
    _invokeKeyedAction(tester, 'add-points-manual-point');
    await tester.pumpAndSettle();

    expect(find.text('备注'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '轻音少女');
    await tester.enterText(fields.at(3), '鸭川三条');
    await tester.enterText(fields.at(4), '鸭川沿岸');
    await tester.enterText(fields.at(5), '自定义场景 1');
    await tester.enterText(fields.at(6), '手动录入');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('point-form-latitude')),
      '35.0089',
    );
    await tester.enterText(
      find.byKey(const ValueKey('point-form-longitude')),
      '135.7711',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    _invokeKeyedAction(tester, 'point-form-save');
    await tester.pumpAndSettle();

    expect(find.text('未分组'), findsWidgets);
    expect(find.text('鸭川三条'), findsWidgets);
    expect(find.text('轻音少女 / 鸭川沿岸 / 自定义场景 1'), findsWidgets);
  });

  testWidgets('manual point map picker requires explicit pick mode', (
    tester,
  ) async {
    await _pumpAppWithEmptyPlan(tester);

    await _openAddPointsFromEmptyPlan(tester);
    _invokeKeyedAction(tester, 'add-points-manual-point');
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    _invokeKeyedAction(tester, 'point-form-map-picker');
    await tester.pumpAndSettle();

    expect(find.text('选择点位坐标'), findsOneWidget);
    expect(find.text('先点击右上角选点按钮，再点击地图设置坐标'), findsOneWidget);
    expect(find.text('35.000000, 135.000000'), findsNothing);

    await tester.tap(find.byTooltip('在地图上选点'));
    await tester.pumpAndSettle();
    expect(find.text('点击地图任意位置设置点位坐标'), findsOneWidget);
    expect(find.textContaining('点击地图可继续调整位置'), findsNothing);
  });

  testWidgets('Anitabi link import adds missing work on import', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '链接导入测试', area: '京都');
    final anitabiClient = _FakeAnitabiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: plan,
          repository: repository,
          initialBangumiId: 12345,
          initialPointId: 'point-1',
          anitabiClient: anitabiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    var updatedPlan = await repository.loadActivePlan();
    expect(updatedPlan.works, isEmpty);
    expect(anitabiClient.lookedUpPoints, contains((12345, 'point-1')));
    expect(anitabiClient.fetchedPointPids, contains(12345));

    await tester.tap(find.text('加入计划'));
    await tester.pumpAndSettle();

    updatedPlan = await repository.loadActivePlan();
    expect(
      updatedPlan.works.where((work) => work.bangumiId == 12345),
      hasLength(1),
    );
    expect(updatedPlan.points, hasLength(1));
  });

  testWidgets('Anitabi link import uses global pid owner work', (tester) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '跨作品链接测试', area: '东京');
    final anitabiClient = _FakeAnitabiClient(
      globalPointBangumiIds: const {'cross-point': 543360},
      pointIdsByBangumi: const {543360: 'cross-point'},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: plan,
          repository: repository,
          initialBangumiId: 282923,
          initialPointId: 'cross-point',
          anitabiClient: anitabiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(anitabiClient.globalLookedUpPoints, contains('cross-point'));
    expect(anitabiClient.lookedUpPoints, isEmpty);

    await tester.tap(find.text('加入计划'));
    await tester.pumpAndSettle();

    final updatedPlan = await repository.loadActivePlan();
    expect(
      updatedPlan.works.where((work) => work.bangumiId == 282923),
      isEmpty,
    );
    final works = updatedPlan.works
        .where((work) => work.bangumiId == 543360)
        .toList(growable: false);
    expect(works, hasLength(1));
    expect(works.single.title, '真实动画作品');
    expect(updatedPlan.points.single.id, 'anitabi-543360-cross-point');
  });

  testWidgets('Anitabi link import shows loading while resolving global pid', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '加载态测试', area: '东京');
    final anitabiClient = _FakeAnitabiClient(
      globalLookupDelay: const Duration(milliseconds: 80),
      globalPointBangumiIds: const {'slow-point': 543360},
      pointIdsByBangumi: const {543360: 'slow-point'},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: plan,
          repository: repository,
          initialBangumiId: 282923,
          initialPointId: 'slow-point',
          anitabiClient: anitabiClient,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('正在加载 Anitabi 作品和点位'), findsOneWidget);
    expect(find.textContaining('手动添加的作品没有 Bangumi ID'), findsNothing);
    expect(find.textContaining('当前作品没有可导入'), findsNothing);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('543360 点位'), findsOneWidget);
  });

  testWidgets('Anitabi link import reuses existing work', (tester) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '链接导入测试', area: '京都');
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
          initialBangumiId: 12345,
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
    expect(anitabiClient.lookedUpPoints, contains((12345, 'point-1')));
  });

  testWidgets('Anitabi bangumi link opens full work points', (tester) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '作品链接测试', area: '京都');
    final anitabiClient = _FakeAnitabiClient();

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

    expect(find.text('12345 点位'), findsOneWidget);
    expect(anitabiClient.lookedUpPoints, isEmpty);
    expect(anitabiClient.fetchedPointPids, contains(12345));
  });

  testWidgets('Anitabi work with zero center selects point near point bounds', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '零中心测试', area: '东京');
    final anitabiClient = _FakeAnitabiClient(
      liteByBangumi: const {
        543360: AnitabiBangumiLite(
          bangumiId: 543360,
          title: '零中心作品',
          subtitle: 'Zero Center',
          city: '东京',
          center: LatLng(0, 0),
          zoom: 1,
          pointsLength: 3,
        ),
      },
      pointsByBangumi: const {
        543360: [
          AnitabiPoint(
            bangumiId: 543360,
            id: 'west',
            name: '西侧点位',
            subtitle: 'west',
            position: LatLng(35, 139),
            episodeLabel: 'EP 1',
            referenceImageUrl: null,
            origin: 'Anitabi',
            originUrl: 'https://anitabi.cn/',
          ),
          AnitabiPoint(
            bangumiId: 543360,
            id: 'center',
            name: '中心点位',
            subtitle: 'center',
            position: LatLng(35.5, 139.5),
            episodeLabel: 'EP 2',
            referenceImageUrl: null,
            origin: 'Anitabi',
            originUrl: 'https://anitabi.cn/',
          ),
          AnitabiPoint(
            bangumiId: 543360,
            id: 'east',
            name: '东侧点位',
            subtitle: 'east',
            position: LatLng(36, 140),
            episodeLabel: 'EP 3',
            referenceImageUrl: null,
            origin: 'Anitabi',
            originUrl: 'https://anitabi.cn/',
          ),
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: plan,
          repository: repository,
          initialBangumiId: 543360,
          anitabiClient: anitabiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter.latitude, 35.5);
    expect(map.options.initialCenter.longitude, 139.5);
    expect(map.options.initialZoom, 15);
    expect(find.text('中心点位'), findsOneWidget);
    expect(find.text('西侧点位'), findsNothing);
    expect(find.text('东侧点位'), findsNothing);
  });

  testWidgets('Anitabi import locks point switching and clears stale message', (
    tester,
  ) async {
    final repository = _DelayedAddPointRepository(plans: const []);
    final plan = await repository.createPlan(name: '导入锁定测试', area: '东京');
    final anitabiClient = _FakeAnitabiClient(
      liteByBangumi: const {
        12345: AnitabiBangumiLite(
          bangumiId: 12345,
          title: '导入锁定作品',
          subtitle: 'Import Lock',
          city: '东京',
          center: LatLng(35, 135),
          zoom: 15,
          pointsLength: 2,
        ),
      },
      pointsByBangumi: const {
        12345: [
          AnitabiPoint(
            bangumiId: 12345,
            id: 'first',
            name: '第一个点位',
            subtitle: 'first',
            position: LatLng(35, 135),
            episodeLabel: 'EP 1',
            referenceImageUrl: null,
            origin: 'Anitabi',
            originUrl: 'https://anitabi.cn/',
          ),
          AnitabiPoint(
            bangumiId: 12345,
            id: 'second',
            name: '第二个点位',
            subtitle: 'second',
            position: LatLng(35.0005, 135.0005),
            episodeLabel: 'EP 2',
            referenceImageUrl: null,
            origin: 'Anitabi',
            originUrl: 'https://anitabi.cn/',
          ),
        ],
      },
    );

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

    expect(find.text('第一个点位'), findsOneWidget);

    await tester.tap(find.text('加入计划'));
    await repository.addPointStarted.future;
    await tester.pump();

    final importingMarkers = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .where((button) => button.tooltip == '可导入点位')
        .toList(growable: false);
    expect(importingMarkers, isNotEmpty);
    expect(importingMarkers.every((button) => button.onPressed == null), true);

    expect(find.text('第一个点位'), findsOneWidget);
    expect(find.text('第二个点位'), findsNothing);

    repository.finishAddPoint();
    await tester.pumpAndSettle();

    expect(find.textContaining('已导入 1 个点位'), findsOneWidget);
    final availableMarkers = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .where(
          (button) => button.tooltip == '可导入点位' && button.onPressed != null,
        )
        .toList(growable: false);
    expect(availableMarkers, isNotEmpty);
    availableMarkers.last.onPressed!();
    await tester.pump();

    expect(find.text('第二个点位'), findsOneWidget);
    expect(find.textContaining('已导入 1 个点位'), findsNothing);
  });

  testWidgets('Anitabi link import requires bangumi ID before opening map', (
    tester,
  ) async {
    await _pumpAppWithEmptyPlan(tester);

    await _openAddPointsFromEmptyPlan(tester);
    _invokeKeyedAction(tester, 'add-points-anitabi-link');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField),
      'https://www.anitabi.cn/map?pid=qdmnf6iqj',
    );
    await tester.tap(find.text('打开 Anitabi 点位'));
    await tester.pumpAndSettle();

    expect(find.textContaining('链接缺少作品 ID'), findsOneWidget);
    expect(find.text('从作品地图导入'), findsNothing);
  });

  testWidgets('Anitabi link import pastes clipboard without opening map', (
    tester,
  ) async {
    await _pumpAppWithEmptyPlan(tester);
    await _openAddPointsFromEmptyPlan(tester);
    _invokeKeyedAction(tester, 'add-points-anitabi-link');
    await tester.pumpAndSettle();
    const link = 'https://www.anitabi.cn/map?bangumiId=282923&pid=djnfcvo';
    _mockClipboardRead(tester, link);

    await tester.tap(find.byTooltip('粘贴'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, link);
    expect(find.text('Anitabi 地图导入'), findsNothing);
  });

  testWidgets('Anitabi link import explains empty clipboard', (tester) async {
    await _pumpAppWithEmptyPlan(tester);
    await _openAddPointsFromEmptyPlan(tester);
    _invokeKeyedAction(tester, 'add-points-anitabi-link');
    await tester.pumpAndSettle();
    _mockClipboardRead(tester, '');

    await tester.tap(find.byTooltip('粘贴'));
    await tester.pumpAndSettle();

    expect(find.textContaining('剪贴板中没有可用'), findsOneWidget);
  });

  testWidgets('Anitabi link import validates pasted text', (tester) async {
    await _pumpAppWithEmptyPlan(tester);
    await _openAddPointsFromEmptyPlan(tester);
    _invokeKeyedAction(tester, 'add-points-anitabi-link');
    await tester.pumpAndSettle();
    _mockClipboardRead(tester, 'not an Anitabi URL');

    await tester.tap(find.byTooltip('粘贴'));
    await tester.pumpAndSettle();

    expect(find.textContaining('请输入有效的 Anitabi'), findsOneWidget);
    expect(find.text('Anitabi 地图导入'), findsNothing);
  });

  testWidgets('Anitabi link import handles clipboard read failure', (
    tester,
  ) async {
    await _pumpAppWithEmptyPlan(tester);
    await _openAddPointsFromEmptyPlan(tester);
    _invokeKeyedAction(tester, 'add-points-anitabi-link');
    await tester.pumpAndSettle();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        throw PlatformException(code: 'clipboard-unavailable');
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.tap(find.byTooltip('粘贴'));
    await tester.pumpAndSettle();

    expect(find.textContaining('无法读取剪贴板'), findsOneWidget);
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
    expect(anitabiClient.lookedUpPoints, isEmpty);
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

  testWidgets('Anitabi import explains empty works and missing points', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '错误文案测试', area: '京都');
    final emptyClient = _FakeAnitabiClient(noPointPids: {12345});

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: plan,
          repository: repository,
          initialBangumiId: 12345,
          anitabiClient: emptyClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前作品暂无 Anitabi 点位'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final missingPointClient = _FakeAnitabiClient(missingPointIds: {'missing'});
    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: plan,
          repository: repository,
          initialBangumiId: 12345,
          initialPointId: 'missing',
          anitabiClient: missingPointClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('没有找到这个 Anitabi 点位'), findsOneWidget);
  });
}

class _DelayedAddPointRepository extends SamplePilgrimageRepository {
  _DelayedAddPointRepository({super.plans});

  final Completer<void> addPointStarted = Completer<void>();
  final Completer<void> _finishAddPoint = Completer<void>();

  void finishAddPoint() {
    if (!_finishAddPoint.isCompleted) {
      _finishAddPoint.complete();
    }
  }

  @override
  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  }) async {
    if (!addPointStarted.isCompleted) {
      addPointStarted.complete();
    }
    await _finishAddPoint.future;
    return super.addPointToPlan(planId: planId, point: point);
  }
}

class _FakeAnitabiClient extends AnitabiClient {
  _FakeAnitabiClient({
    this.pointDelays = const {},
    this.globalLookupDelay,
    this.failingPointPids = const {},
    this.noPointPids = const {},
    this.missingPointIds = const {},
    this.globalPointBangumiIds = const {},
    this.pointIdsByBangumi = const {},
    this.liteByBangumi = const {},
    this.pointsByBangumi = const {},
  });

  final fetchedPointPids = <int>[];
  final lookedUpPoints = <(int, String)>[];
  final globalLookedUpPoints = <String>[];
  final Map<int, Duration> pointDelays;
  final Duration? globalLookupDelay;
  final Set<int> failingPointPids;
  final Set<int> noPointPids;
  final Set<String> missingPointIds;
  final Map<String, int> globalPointBangumiIds;
  final Map<int, String> pointIdsByBangumi;
  final Map<int, AnitabiBangumiLite> liteByBangumi;
  final Map<int, List<AnitabiPoint>> pointsByBangumi;

  @override
  Future<AnitabiBangumiLite> fetchBangumiLite(int bangumiId) async {
    final lite = liteByBangumi[bangumiId];
    if (lite != null) {
      return lite;
    }
    return AnitabiBangumiLite(
      bangumiId: bangumiId,
      title: switch (bangumiId) {
        1001 => '慢作品',
        1002 => '快作品',
        282923 => '系列作品',
        543360 => '真实动画作品',
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
    if (noPointPids.contains(bangumiId)) {
      throw AnitabiNoPointsException(bangumiId);
    }
    final points = pointsByBangumi[bangumiId];
    if (points != null) {
      return points;
    }
    final pointId = pointIdsByBangumi[bangumiId] ?? 'point-1';
    return [
      AnitabiPoint(
        bangumiId: bangumiId,
        id: pointId,
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
  Future<AnitabiPointLookupResult?> findPointGlobally({
    required String pointId,
  }) async {
    if (globalLookupDelay != null) {
      await Future<void>.delayed(globalLookupDelay!);
    }
    globalLookedUpPoints.add(pointId);
    if (missingPointIds.contains(pointId)) {
      return null;
    }
    final bangumiId = globalPointBangumiIds[pointId];
    if (bangumiId == null) {
      return null;
    }
    final points = await fetchPoints(bangumiId);
    final point = points.where((point) => point.id == pointId).firstOrNull;
    if (point == null) {
      return null;
    }
    return AnitabiPointLookupResult(
      work: await fetchBangumiLite(bangumiId),
      point: point,
      points: points,
    );
  }

  @override
  Future<AnitabiPointLookupResult?> findPointInBangumi({
    required int bangumiId,
    required String pointId,
  }) async {
    lookedUpPoints.add((bangumiId, pointId));
    if (missingPointIds.contains(pointId)) {
      return null;
    }
    final points = await fetchPoints(bangumiId);
    return AnitabiPointLookupResult(
      work: await fetchBangumiLite(bangumiId),
      point: points.single,
      points: points,
    );
  }
}
