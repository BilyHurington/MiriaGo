import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:miriago/app_theme.dart';
import 'package:miriago/main.dart';
import 'package:miriago/data/anitabi_client.dart';
import 'package:miriago/data/bangumi_api_client.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/map/map_marker_clustering.dart';
import 'package:miriago/point_detail/point_detail_sheet.dart';
import 'package:miriago/plan/add_points_screen.dart';
import 'package:miriago/plan/anitabi_map_import_screen.dart';
import 'package:miriago/plan/nearest_group_assign_screen.dart';
import 'package:miriago/plan/plan_group_manager_screen.dart';
import 'package:miriago/plan/plan_manager_screen.dart';
import 'package:miriago/plan/point_manager_screen.dart';
import 'package:miriago/plan/work_manager_screen.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';
import 'package:miriago/records/records_screen.dart';
import 'package:miriago/records/comparison_export_config.dart';
import 'package:miriago/widgets/constrained_menu_anchor.dart';
import 'package:miriago/widgets/confirm_action_dialog.dart';
import 'package:miriago/widgets/input_dialog.dart';
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
  await tester.tap(find.byKey(const ValueKey('plan-actions-toggle')));
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
    expect(find.text('吹响吧！上低音号'), findsWidgets);
    expect(find.textContaining('あじろぎの道'), findsNothing);
    expect(find.text('已拍 2'), findsNothing);
    expect(find.byKey(const ValueKey('plan-point-shot-badge')), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-point-shot-badge')),
        matching: find.text('2'),
      ),
      findsNothing,
    );
    final planTitle = tester.widget<Text>(
      find.descendant(of: find.byType(AppBar), matching: find.text('示例计划')),
    );
    expect(planTitle.style?.fontSize, 20);
    expect(planTitle.style?.fontWeight, FontWeight.w900);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight,
      kToolbarHeight,
    );
    expect(find.byKey(const ValueKey('plan-meta-strip')), findsNothing);
    expect(find.byKey(const ValueKey('plan-meta-text')), findsNothing);
  });

  testWidgets('plan actions expand inline and keep five actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    final switchButton = find.byKey(const ValueKey('plan-switch-button'));
    final toggleButton = find.byKey(const ValueKey('plan-actions-toggle'));
    final collapsedAppBarRect = tester.getRect(find.byType(AppBar));
    final collapsedToggleRect = tester.getRect(toggleButton);
    expect(switchButton, findsOneWidget);
    expect(toggleButton, findsOneWidget);
    expect(tester.getSize(switchButton), tester.getSize(toggleButton));
    expect(find.byKey(const ValueKey('plan-actions-panel')), findsNothing);
    expect(find.byKey(const ValueKey('plan-group-summary')), findsNothing);
    expect(find.byKey(const ValueKey('plan-meta-strip')), findsNothing);
    expect(
      find.descendant(
        of: switchButton,
        matching: find.byIcon(Icons.swap_horiz),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: toggleButton,
        matching: find.byIcon(Icons.expand_more),
      ),
      findsOneWidget,
    );

    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('plan-actions-panel'));
    expect(panel, findsOneWidget);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight,
      kToolbarHeight,
    );
    expect(tester.getRect(find.byType(AppBar)), collapsedAppBarRect);
    expect(tester.getRect(toggleButton), collapsedToggleRect);
    expect(find.byKey(const ValueKey('plan-group-summary')), findsNothing);
    expect(find.byKey(const ValueKey('plan-meta-strip')), findsNothing);
    expect(
      find.descendant(
        of: toggleButton,
        matching: find.byIcon(Icons.expand_less),
      ),
      findsOneWidget,
    );
    for (final key in const [
      'plan-action-cache-references',
      'plan-action-add-points',
      'plan-action-manage-points',
      'plan-action-memo',
      'plan-action-import-export',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(
      tester.getBottomLeft(panel).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const ValueKey('plan-group-switcher'))).dy,
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-action-cache-references')),
        matching: find.byIcon(Icons.download_for_offline_outlined),
      ),
      findsOneWidget,
    );

    final addPointsRect = tester.getRect(
      find.byKey(const ValueKey('plan-action-add-points')),
    );
    final managePointsRect = tester.getRect(
      find.byKey(const ValueKey('plan-action-manage-points')),
    );
    final cacheReferencesRect = tester.getRect(
      find.byKey(const ValueKey('plan-action-cache-references')),
    );
    expect(addPointsRect.top, closeTo(managePointsRect.top, 0.1));
    expect(addPointsRect.bottom, closeTo(managePointsRect.bottom, 0.1));
    expect(cacheReferencesRect.top, greaterThan(addPointsRect.bottom));
    expect(cacheReferencesRect.left, closeTo(addPointsRect.left, 0.1));

    await tester.tap(find.byKey(const ValueKey('plan-action-add-points')));
    await tester.pumpAndSettle();
    expect(find.byType(AddPointsScreen), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    final addPointsBackButton = tester.widget<IconButton>(
      find
          .descendant(
            of: find.byType(AppBar),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(addPointsBackButton.tooltip, isNull);
    Navigator.of(tester.element(find.byType(AddPointsScreen))).pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-actions-panel')), findsNothing);
    expect(find.byKey(const ValueKey('plan-group-summary')), findsNothing);
    expect(find.byKey(const ValueKey('plan-meta-strip')), findsNothing);

    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    final reopenedPanel = find.byKey(const ValueKey('plan-actions-panel'));
    expect(reopenedPanel, findsOneWidget);
    await tester.tapAt(Offset(5, tester.getCenter(reopenedPanel).dy));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-actions-panel')), findsNothing);
    expect(
      find.descendant(
        of: toggleButton,
        matching: find.byIcon(Icons.expand_more),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight,
      kToolbarHeight,
    );
    expect(find.byKey(const ValueKey('plan-group-summary')), findsNothing);
    expect(find.byKey(const ValueKey('plan-meta-strip')), findsNothing);
    expect(
      find.descendant(
        of: toggleButton,
        matching: find.byIcon(Icons.expand_more),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan action subtitles hide on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('plan-actions-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-actions-panel')), findsOneWidget);
    expect(find.text('添加点位'), findsOneWidget);
    expect(find.text('计划备忘录'), findsOneWidget);
    expect(find.text('加入巡礼场景'), findsNothing);
    expect(find.text('整理片区点位'), findsNothing);
    expect(find.text('保存完整图片'), findsNothing);
    expect(find.text('记录行程要点'), findsNothing);
    expect(find.text('备份迁移计划'), findsNothing);
  });

  testWidgets('plan action subtitles stay visible on a wider screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('plan-actions-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-actions-panel')), findsOneWidget);
    expect(find.text('添加点位'), findsOneWidget);
    expect(find.text('加入巡礼场景'), findsOneWidget);
    expect(find.text('计划备忘录'), findsOneWidget);
    expect(find.text('记录行程要点'), findsOneWidget);
  });

  testWidgets('plan actions can ignore taps outside the panel', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = SamplePilgrimageRepository();
    await repository.saveAppSettings(
      const AppSettings(dismissPlanActionsOnOutsideTap: false),
    );
    await tester.pumpWidget(MiriaGoApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('plan-actions-toggle')));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('plan-actions-panel'));
    expect(panel, findsOneWidget);

    await tester.tapAt(Offset(5, tester.getCenter(panel).dy));
    await tester.pumpAndSettle();

    expect(panel, findsOneWidget);
    expect(find.byKey(const ValueKey('plan-meta-strip')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('plan-action-cache-references')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmActionDialog), findsOneWidget);

    final confirmButton = find
        .descendant(
          of: find.byType(AppDialogActionRow),
          matching: find.byType(FilledButton),
        )
        .last;
    await tester.tap(confirmButton);
    await tester.pump();

    expect(find.byKey(const ValueKey('plan-actions-panel')), findsNothing);
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

  testWidgets('plan group switcher opens the styled region picker', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, '宇治站附近'));
    await tester.pumpAndSettle();

    expect(find.text('选择区域'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-group-picker-create')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-group-picker-option-宇治站附近')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-group-picker-selected-accent')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('plan-group-picker-progress-sample-group-uji-station'),
      ),
      findsOneWidget,
    );
    final planGroupOption = find.byKey(
      const ValueKey('plan-group-picker-option-宇治站附近'),
    );
    expect(
      find.descendant(
        of: planGroupOption,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey(
                'plan-group-picker-progress-sample-group-uji-station',
              ),
            ),
          )
          .height,
      68,
    );
    final planCount = tester.widget<Text>(
      find.byKey(
        const ValueKey('plan-group-picker-count-sample-group-uji-station'),
      ),
    );
    final planCountSpan = planCount.textSpan! as TextSpan;
    expect(planCount.style?.fontSize, 17);
    expect((planCountSpan.children![0] as TextSpan).style?.fontSize, 10);
    expect((planCountSpan.children![1] as TextSpan).style?.fontSize, 10);
    expect(find.textContaining('关键点：'), findsWidgets);
    expect(find.textContaining('关键点：关键点：'), findsNothing);
  });

  testWidgets('completed plan group uses a checked filled folder', (
    tester,
  ) async {
    final group = samplePilgrimagePlan.groups.first;
    final completedPointIds = samplePilgrimagePlan.points
        .where((point) => point.groupId == group.id)
        .map((point) => point.id)
        .toSet();
    final plan = samplePilgrimagePlan.copyWith(
      completedPointIds: completedPointIds,
    );
    await tester.pumpWidget(
      MiriaGoApp(repository: SamplePilgrimageRepository(plans: [plan])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, group.name));
    await tester.pumpAndSettle();

    final completedIcon = find.byKey(
      ValueKey('plan-group-picker-completed-icon-${group.id}'),
    );
    expect(completedIcon, findsOneWidget);
    expect(
      find.descendant(of: completedIcon, matching: find.byIcon(Icons.folder)),
      findsOneWidget,
    );
    final checkIcon = tester.widget<Icon>(
      find.descendant(of: completedIcon, matching: find.byIcon(Icons.check)),
    );
    expect(checkIcon.color, Colors.white);
    expect(
      find.byKey(ValueKey('plan-group-picker-progress-${group.id}')),
      findsNothing,
    );
  });

  testWidgets('box assign uses the integrated region picker', (tester) async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BoxGroupAssignScreen(
          plan: plan,
          repository: repository,
          settings: const AppSettings(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('box-assign-group-picker-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('选择片区'), findsOneWidget);
    expect(find.text('共 ${plan.groups.length} 个片区'), findsOneWidget);
    expect(find.byKey(const ValueKey('box-assign-group-menu')), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('box-assign-group-option-sample-group-uji-station'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('box-assign-create-group')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('box-assign-group-menu'))).width,
      tester
          .getSize(find.byKey(const ValueKey('box-assign-group-picker-button')))
          .width,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('box-assign-group-picker-button')))
          .height,
      AppButtonStyles.compactHeight,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('box-assign-toggle-button'))),
      const Size(112, AppButtonStyles.compactHeight),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('box-assign-submit-button'))),
      tester.getSize(find.byKey(const ValueKey('box-assign-toggle-button'))),
    );
    expect(find.text('已框选 0 / 待分配 1'), findsOneWidget);

    final pickerMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('box-assign-group-picker-button')),
            matching: find.byType(Material),
          )
          .first,
    );
    final pickerShape = pickerMaterial.shape! as RoundedRectangleBorder;
    expect(pickerShape.side.color, AppColors.border);
    final menuDivider = tester.widget<Divider>(
      find.descendant(
        of: find.byKey(const ValueKey('box-assign-group-menu')),
        matching: find.byType(Divider),
      ),
    );
    expect(menuDivider.color, AppColors.border);

    final selectedOption = tester.widget<MenuItemButton>(
      find.byKey(
        const ValueKey('box-assign-group-option-sample-group-uji-station'),
      ),
    );
    final normalOption = tester.widget<MenuItemButton>(
      find.byKey(
        const ValueKey('box-assign-group-option-sample-group-daikichiyama'),
      ),
    );
    final createOption = tester.widget<MenuItemButton>(
      find.byKey(const ValueKey('box-assign-create-group')),
    );
    expect(
      selectedOption.style?.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    expect(
      normalOption.style?.overlayColor?.resolve({WidgetState.hovered}),
      createOption.style?.overlayColor?.resolve({WidgetState.hovered}),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('box-assign-create-group'))),
      tester.getSize(
        find.byKey(
          const ValueKey('box-assign-group-option-sample-group-uji-station'),
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey('box-assign-group-option-sample-group-daikichiyama'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('box-assign-group-picker-button')),
        matching: find.text('大吉山'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('box-assign-group-picker-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('box-assign-create-group')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('box-assign-group-name-field')),
      '框选新片区',
    );
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('box-assign-group-picker-button')),
        matching: find.text('框选新片区'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('box-assign-toggle-button')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.text('结束框选')).height, lessThanOrEqualTo(20));
  });

  testWidgets('shows records dashboard header and summary', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AppBar>(find.byKey(const ValueKey('records-app-bar')))
          .toolbarHeight,
      kToolbarHeight,
    );

    final title = tester.widget<Text>(
      find.descendant(of: find.byType(AppBar), matching: find.text('记录')),
    );
    expect(title.style?.fontSize, 24);
    expect(title.style?.fontWeight, FontWeight.w900);
    expect(find.byTooltip('搜索记录（待接入）'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('records-status-filter'))),
      const Size(124, 44),
    );
    expect(find.byKey(const ValueKey('records-search-field')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('records-search-shell'))).height,
      tester
          .getSize(find.byKey(const ValueKey('records-status-filter')))
          .height,
    );
    expect(
      find.byKey(const ValueKey('records-status-filter-button')),
      findsOneWidget,
    );
    final statusFilterSurface = tester.widget<Material>(
      find.byKey(const ValueKey('records-status-filter-surface')),
    );
    final statusFilterShape =
        statusFilterSurface.shape! as RoundedRectangleBorder;
    expect(statusFilterShape.side.color, AppColors.border);
    expect(statusFilterShape.side.style, BorderStyle.solid);
    expect(statusFilterShape.side.width, 1);
    final scopeFilterButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('records-scope-filter-button')),
    );
    expect(
      scopeFilterButton.style?.backgroundColor?.resolve({}),
      AppColors.surface,
    );
    expect(scopeFilterButton.style?.side?.resolve({})?.color, AppColors.border);
    expect(
      tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((destination) => destination.tooltip),
      everyElement(isEmpty),
    );
    expect(find.text('作品'), findsNothing);
    expect(find.text('片区'), findsNothing);
    expect(find.text('条巡礼记录'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('records-completion-progress')))
          .height,
      4,
    );
    expect(find.byIcon(Icons.collections_bookmark_outlined), findsNothing);
    expect(
      find.byKey(const ValueKey('records-group-sample-group-uji-station')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('record-card-sample-record-jr-uji-01')),
      findsOneWidget,
    );
    final stickyHeaders = tester.widgetList<SliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    expect(stickyHeaders, isNotEmpty);
    expect(stickyHeaders.every((header) => header.pinned), isTrue);
    final expandedGroupIcon = tester.widget<Icon>(
      find.byKey(const ValueKey('records-group-icon-sample-group-uji-station')),
    );
    expect(expandedGroupIcon.icon, Icons.location_on);
    final recordTitle = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('record-card-sample-record-jr-uji-01')),
        matching: find.text('JR 宇治站'),
      ),
    );
    expect(recordTitle.style?.fontSize, 17);
    final recordMeta = tester.widget<Text>(
      find.byKey(const ValueKey('record-meta-text-sample-record-jr-uji-01')),
    );
    expect(recordMeta.data, '吹响吧！上低音号 / EP 8・11:53');
    final recordTitleRect = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('record-card-sample-record-jr-uji-01')),
        matching: find.text('JR 宇治站'),
      ),
    );
    final recordMetaRect = tester.getRect(
      find.byKey(const ValueKey('record-meta-text-sample-record-jr-uji-01')),
    );
    final capturedRowRect = tester.getRect(
      find.byKey(const ValueKey('record-captured-row-sample-record-jr-uji-01')),
    );
    expect(recordMetaRect.top - recordTitleRect.bottom, closeTo(6, 0.1));
    expect(capturedRowRect.top - recordMetaRect.bottom, closeTo(10, 0.1));
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey('records-group-count-sample-group-uji-station'),
        ),
      ),
      const Size.square(30),
    );
    final countDecoration = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey('records-group-count-sample-group-uji-station'),
            ),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (countDecoration.decoration as BoxDecoration).shape,
      BoxShape.circle,
    );
    final groupSurfaceRect = tester.getRect(
      find.byKey(
        const ValueKey('records-group-surface-sample-group-uji-station'),
      ),
    );
    final firstRecordRect = tester.getRect(
      find.byKey(const ValueKey('record-card-sample-record-jr-uji-01')),
    );
    expect(find.byKey(const ValueKey('records-group-divider')), findsNothing);
    expect(firstRecordRect.top - groupSurfaceRect.bottom, closeTo(4, 0.1));
    expect(
      find.ancestor(
        of: find.byKey(
          const ValueKey('records-group-sample-group-uji-station'),
        ),
        matching: find.byType(SliverMainAxisGroup),
      ),
      findsOneWidget,
    );

    final firstGroupHeader = find.byKey(
      const ValueKey('records-group-sample-group-uji-station'),
    );
    expect(tester.getSize(firstGroupHeader).height, 64);
    await tester.tap(firstGroupHeader);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Icon>(
            find.byKey(
              const ValueKey('records-group-icon-sample-group-uji-station'),
            ),
          )
          .icon,
      Icons.location_on_outlined,
    );
    await tester.tap(firstGroupHeader);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('records-scroll-view')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(firstGroupHeader).dy,
      closeTo(
        tester.getBottomLeft(find.byKey(const ValueKey('records-app-bar'))).dy,
        0.1,
      ),
    );
  });

  testWidgets('record groups default expanded across the full list', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();

    const representativeRecordIds = [
      'sample-record-jr-uji-01',
      'sample-record-daikichi-view-02',
      'sample-record-byodoin-02',
      'sample-record-agata-02',
      'sample-record-rokuchizo-01',
      'sample-record-obaku-01',
      'sample-record-kohata-01',
      'sample-record-ungrouped-01',
    ];
    final recordsScrollView = find.byKey(const ValueKey('records-scroll-view'));
    for (final recordId in representativeRecordIds) {
      final card = find.byKey(ValueKey('record-card-$recordId'));
      await tester.dragUntilVisible(
        card,
        recordsScrollView,
        const Offset(0, -360),
      );
      expect(card, findsOneWidget);
    }
  });

  testWidgets('records layout fits a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('records-scroll-view')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('records toolbar filters by status and searches', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('records-status-filter')));
    await tester.pumpAndSettle();
    expect(find.text('选择状态'), findsOneWidget);
    expect(find.textContaining('个状态'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('records-status-menu'))).width,
      tester.getSize(find.byKey(const ValueKey('records-status-filter'))).width,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('records-status-menu')),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
    final selectedStatusOption = tester.widget<MenuItemButton>(
      find.byKey(const ValueKey('records-status-option-all')),
    );
    expect(selectedStatusOption.leadingIcon, isA<Icon>());
    expect((selectedStatusOption.leadingIcon! as Icon).icon, Icons.check);
    expect(
      selectedStatusOption.style?.overlayColor?.resolve({WidgetState.hovered}),
      Colors.transparent,
    );
    await tester.tap(
      find.byKey(const ValueKey('records-status-option-completed')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('records-status-filter')),
        matching: find.text('已完成'),
      ),
      findsOneWidget,
    );
    final searchIconRectBefore = tester.getRect(
      find.byKey(const ValueKey('records-search-prefix-icon')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('records-search-field')),
      '大吉山',
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('records-search-prefix-icon'))),
      searchIconRectBefore,
    );
    expect(
      tester
          .getRect(find.byKey(const ValueKey('records-search-clear-button')))
          .right,
      closeTo(
        tester
                .getRect(find.byKey(const ValueKey('records-search-shell')))
                .right -
            1,
        0.1,
      ),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('records-search-field')))
          .controller
          ?.text,
      '大吉山',
    );
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(
      find.descendant(of: find.byType(AppBar), matching: find.text('记录')),
    );
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets(
    'records search empty state explains no matches and clears search',
    (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.text('记录').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('records-search-field')),
        '不存在的巡礼记录',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('records-empty-state')), findsOneWidget);
      expect(find.text('没有找到相关记录'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.textContaining('点位、作品或场景'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('records-empty-clear-search')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('records-empty-clear-search')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('records-empty-state')), findsNothing);
      expect(
        find.byKey(const ValueKey('record-card-sample-record-jr-uji-01')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('records-search-field')),
            )
            .controller
            ?.text,
        isEmpty,
      );
    },
  );

  testWidgets('records can filter by work and plan group', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('records-scope-filter-button')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
      isTrue,
    );
    expect(find.text('筛选记录'), findsOneWidget);
    expect(find.text('作品'), findsOneWidget);
    expect(find.text('片区'), findsOneWidget);
    expect(find.text('已选：作品 0 · 片区 0'), findsOneWidget);
    expect(find.text('全部作品'), findsOneWidget);
    expect(find.text('全部片区'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('records-scope-work-entry')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet).last).showDragHandle,
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('records-scope-secondary-confirm-work')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('records-scope-secondary-top-confirm-work')),
      findsNothing,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('records-scope-secondary-confirm-work')),
          )
          .width,
      176,
    );
    final workOptionDecoration = tester.widget<AnimatedContainer>(
      find.byKey(
        const ValueKey('records-scope-option-decoration-work-hibike-euphonium'),
      ),
    );
    final unselectedDecoration =
        workOptionDecoration.decoration! as BoxDecoration;
    expect(unselectedDecoration.border, isNull);
    expect(unselectedDecoration.borderRadius, BorderRadius.circular(6));
    expect(unselectedDecoration.color!.a, 0);
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('records-scope-option-work-hibike-euphonium'),
        ),
        matching: find.text('作品'),
      ),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('records-scope-back-work')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('records-scope-group-entry')));
    await tester.pumpAndSettle();
    final daikichiyamaOption = find.byKey(
      const ValueKey('records-scope-option-group-sample-group-daikichiyama'),
    );
    expect(daikichiyamaOption, findsOneWidget);
    await tester.tap(daikichiyamaOption);
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: daikichiyamaOption,
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );
    final selectedDecoration =
        tester
                .widget<AnimatedContainer>(
                  find.byKey(
                    const ValueKey(
                      'records-scope-option-decoration-group-sample-group-daikichiyama',
                    ),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(selectedDecoration.border, isNull);
    expect(selectedDecoration.color!.a, greaterThan(0));
    await tester.tap(
      find.byKey(const ValueKey('records-scope-secondary-confirm-group')),
    );
    await tester.pumpAndSettle();
    expect(find.text('已选：作品 0 · 片区 1'), findsOneWidget);
    expect(find.text('已选 1 个片区'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('records-scope-apply')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('records-group-sample-group-daikichiyama')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('records-group-sample-group-uji-station')),
      findsNothing,
    );
  });

  testWidgets('records clear stale scope filters when the plan changes', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository();
    final initialPlan = await repository.loadActivePlan();
    final controller = PilgrimagePlanController(
      plan: initialPlan,
      visitRepository: repository,
    );
    addTearDown(controller.dispose);

    Widget recordsApp() => MaterialApp(
      theme: AppTheme.light(),
      home: RecordsScreen(
        controller: controller,
        settings: const AppSettings(),
      ),
    );

    await tester.pumpWidget(recordsApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('records-scope-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('records-scope-work-entry')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('records-scope-option-work-hibike-euphonium')),
    );
    await tester.tap(
      find.byKey(const ValueKey('records-scope-secondary-confirm-work')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('records-scope-apply')));
    await tester.pumpAndSettle();

    final nextPlan = await repository.createPlan(name: '新计划', area: '东京');
    controller.replacePlan(nextPlan);
    await controller.loadVisitRecords();
    await tester.pumpWidget(recordsApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('records-scope-filter-button')));
    await tester.pumpAndSettle();

    expect(find.text('已选：作品 0 · 片区 0'), findsOneWidget);
    expect(find.text('全部作品'), findsOneWidget);
    expect(find.text('全部片区'), findsOneWidget);
  });

  testWidgets('records app bar toggles all group sections', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('收起全部片区'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('record-card-sample-record-jr-uji-01')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('records-toggle-all-sections')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('展开全部片区'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('record-card-sample-record-jr-uji-01')),
      findsNothing,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(
              const ValueKey('records-group-icon-sample-group-uji-station'),
            ),
          )
          .icon,
      Icons.location_on_outlined,
    );

    await tester.tap(find.byKey(const ValueKey('records-toggle-all-sections')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('收起全部片区'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('record-card-sample-record-jr-uji-01')),
      findsOneWidget,
    );
  });

  testWidgets('record detail exposes actions and delete file choice', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('record-card-sample-record-jr-uji-01')),
    );
    await tester.pumpAndSettle();

    expect(find.text('记录详情'), findsOneWidget);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight,
      kToolbarHeight,
    );
    final backButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('record-detail-back-button')),
        matching: find.byType(IconButton),
      ),
    );
    expect(backButton.tooltip, isNull);
    expect(
      tester.getSize(
        find.descendant(
          of: find.byKey(const ValueKey('record-detail-back-button')),
          matching: find.byType(IconButton),
        ),
      ),
      const Size.square(40),
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey('record-detail-back-button')),
              matching: find.byType(Icon),
            ),
          )
          .semanticLabel,
      '返回',
    );

    await tester.tap(find.byTooltip('删除记录'));
    await tester.pumpAndSettle();
    expect(find.text('同时删除照片文件'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('同时删除照片文件'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('自动调色'),
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('record-detail-scroll-view')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('自动调色'), findsOneWidget);
    expect(find.text('导出对比图'), findsOneWidget);
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
    expect(find.text('备忘录内容'), findsOneWidget);
    expect(find.text('取消'), findsNothing);
    expect(find.text('可以记录交通、预约、补拍事项、同行安排等。'), findsOneWidget);
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

    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.byTooltip('标题'));
    await tester.pumpAndSettle();
    expect(find.text('## 标题'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);

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

  testWidgets('plan point detail uses the region picker with create action', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('井用机前步行道').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '更改'));
    await tester.pumpAndSettle();

    expect(find.text('移动到片区'), findsOneWidget);
    expect(find.text('选择一个片区作为当前点位所属片区'), findsOneWidget);
    final selectedTile = find.byKey(
      const ValueKey('plan-point-group-option-宇治站附近'),
    );
    final selectedIcon = tester.widget<Icon>(
      find.byKey(const ValueKey('plan-point-group-selection-宇治站附近')),
    );
    expect(selectedTile, findsOneWidget);
    expect(tester.getSize(selectedTile).height, 44);
    expect(selectedIcon.icon, Icons.check_circle);
    expect(
      find.byKey(const ValueKey('plan-group-picker-selected-accent')),
      findsNothing,
    );

    final createEntry = find.byKey(
      const ValueKey('plan-point-group-create-entry'),
    );
    expect(createEntry, findsOneWidget);
    expect(
      tester.getBottomLeft(createEntry).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.byKey(const ValueKey('plan-point-group-options-list')),
            )
            .dy,
      ),
    );
    await tester.tap(createEntry);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('plan-point-group-name-field')),
      '测试新片区',
    );
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    final createdGroup = find.text('测试新片区');
    await tester.dragUntilVisible(
      createdGroup,
      find.byType(ListView).last,
      const Offset(0, -240),
    );
    expect(createdGroup, findsOneWidget);
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

    expect(find.text('移动到片区'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-point-group-create-entry')),
      findsNothing,
    );

    Finder optionText(String text) {
      return find.byKey(ValueKey('plan-point-group-option-$text'));
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
    expect(find.text('已拍 2'), findsNothing);
    expect(find.byKey(const ValueKey('map-point-shot-badge')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byTooltip('拍摄参考'),
        matching: find.byKey(const ValueKey('map-point-shot-badge')),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<PolygonLayer>(find.byType(PolygonLayer))
          .any((layer) => layer.simplificationTolerance == 0),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('map-group-filter-bar')));
    await tester.pumpAndSettle();

    expect(find.text('选择区域'), findsOneWidget);
    expect(find.text('共 8 个区域'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-group-picker-option-宇治站附近')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-group-picker-selected-accent')),
      findsOneWidget,
    );
  });

  testWidgets(
    'map point card content opens detail and keeps navigation actions',
    (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byIcon(Icons.map_outlined).last);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(find.byIcon(Icons.near_me_outlined), findsNWidgets(2));

      await tester.tap(
        find.byKey(
          const ValueKey('map-point-card-content-anitabi-115908-7evkbmy2'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PointDetailSheet), findsOneWidget);
    },
  );

  testWidgets('map large navigation button opens in-app navigation ui', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.map_outlined).last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('map-in-app-navigation-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('navigation-route-confirm-screen')),
      findsOneWidget,
    );
    expect(find.text('确认路线'), findsOneWidget);
    expect(find.text('串联整个片区导航'), findsOneWidget);
    expect(find.text('仅导航到选中点'), findsOneWidget);
    expect(find.textContaining('点击即按顺序连接'), findsNothing);
    expect(
      find.byKey(const ValueKey('in-app-navigation-screen')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('navigation-route-confirm-zone')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('in-app-navigation-screen')),
      findsOneWidget,
    );
    expect(find.text('片区'), findsOneWidget);
    expect(find.text('宇治站附近'), findsOneWidget);
    expect(find.textContaining('井用机前步行道'), findsOneWidget);
    expect(find.text('到达'), findsOneWidget);
    expect(find.text('小时'), findsOneWidget);
    expect(find.text('公里'), findsOneWidget);
    expect(find.text('17 分钟'), findsNothing);
    expect(find.text('结束路线'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-expand')));
    await tester.pumpAndSettle();

    expect(find.text('结束路线'), findsOneWidget);
    expect(find.text('全部点位'), findsOneWidget);
    expect(find.text('详细信息'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-all-stops')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('in-app-navigation-all-stops-sheet')),
      findsOneWidget,
    );
    expect(find.textContaining('宇治桥'), findsOneWidget);
    expect(find.textContaining('下一个:'), findsNothing);
    expect(find.textContaining('终点: 京阪宇治站前'), findsOneWidget);

    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('in-app-navigation-all-stops-sheet')),
      ),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('in-app-navigation-end-route')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('in-app-navigation-screen')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('map-in-app-navigation-button')),
      findsOneWidget,
    );
  });

  testWidgets('map navigation can start only the selected point', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.map_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('map-in-app-navigation-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('navigation-route-confirm-point')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('in-app-navigation-screen')),
      findsOneWidget,
    );
    expect(find.textContaining('终点: 井用机前步行道'), findsOneWidget);
    expect(find.textContaining('下一个:'), findsNothing);
  });

  testWidgets('plan point detail navigation opens in-app navigation ui', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await tester.tap(find.text('井用机前步行道').first);
    await tester.pumpAndSettle();
    _invokeKeyedAction(tester, 'point-detail-in-app-navigation-button');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('navigation-route-confirm-screen')),
      findsOneWidget,
    );
    expect(find.text('串联整个片区导航'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('navigation-route-confirm-zone')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('in-app-navigation-screen')),
      findsOneWidget,
    );
    expect(find.textContaining('井用机前步行道'), findsOneWidget);
    expect(find.byType(PointDetailSheet), findsNothing);
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
    expect(find.byKey(const ValueKey('point-manager-group-switcher')), findsOneWidget);
    expect(
      tester.widget(find.byKey(const ValueKey('point-manager-group-switcher'))),
      isA<FilledButton>(),
    );
    expect(find.text('宇治站附近'), findsOneWidget);
    expect(find.byKey(const ValueKey('point-manager-anchor-row')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('point-manager-anchor-row')),
        matching: find.text('关键点：JR 宇治站'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('point-manager-anchor-row')))
          .height,
      40,
    );
    expect(find.text('更改'), findsOneWidget);
    expect(find.text('无序'), findsWidgets);
    expect(find.text('井用机前步行道'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('point-manager-count-chip-points')),
        matching: find.text('6'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('point-manager-count-chip-points')),
        matching: find.text('点位'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('point-manager-count-chip-points')),
              matching: find.text('6'),
            ),
          )
          .style
          ?.fontSize,
      14,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('point-manager-count-chip-points')),
              matching: find.text('点位'),
            ),
          )
          .style
          ?.fontSize,
      10,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('point-manager-count-chip-completed')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('point-manager-count-chip-completed')),
        matching: find.text('完成'),
      ),
      findsOneWidget,
    );
    expect(find.text('关键点 · JR 宇治站'), findsNothing);
    expect(find.text('1 / 7'), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('point-manager-count-chip-points')))
          .height,
      tester
          .getSize(find.byKey(const ValueKey('point-manager-order-button')))
          .height,
    );

    await tester.tap(find.byKey(const ValueKey('point-manager-order-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('point-manager-order-menu')))
          .width,
      124,
    );
  });

  testWidgets('plan manager reuses plan region drawers', (tester) async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PointManagerScreen(
          plan: plan,
          repository: repository,
          settings: const AppSettings(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('point-manager-group-switcher')));
    await tester.pumpAndSettle();
    expect(find.text('选择区域'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-group-picker-create')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-group-picker-option-宇治站附近')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-group-picker-selected-accent')),
      findsOneWidget,
    );
    final managerGroupOption = find.byKey(
      const ValueKey('plan-group-picker-option-宇治站附近'),
    );
    expect(
      find.descendant(
        of: managerGroupOption,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('plan-group-picker-progress-sample-group-uji-station'),
      ),
      findsNothing,
    );
    final managerCount = tester.widget<Text>(
      find.byKey(
        const ValueKey('plan-group-picker-count-sample-group-uji-station'),
      ),
    );
    final managerCountSpan = managerCount.textSpan! as TextSpan;
    expect(managerCount.style?.fontSize, 10);
    expect((managerCountSpan.children![0] as TextSpan).style?.fontSize, 10);
    expect((managerCountSpan.children![1] as TextSpan).style?.fontSize, 17);

    await tester.tap(
      find.byKey(const ValueKey('plan-group-picker-option-宇治站附近')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('井用机前步行道'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '更改'));
    await tester.pumpAndSettle();

    expect(find.text('移动到片区'), findsOneWidget);
    expect(find.text('选择一个片区作为当前点位所属片区'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-point-group-selection-宇治站附近')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-point-group-create-entry')),
      findsOneWidget,
    );
  });

  testWidgets('ungrouped manager point uses the shared move region sheet', (
    tester,
  ) async {
    final sourceRepository = SamplePilgrimageRepository();
    final sourcePlan = await sourceRepository.loadActivePlan();
    final point = sourcePlan.points.first.copyWith(
      groupId: null,
      groupOrderIndex: null,
    );
    final plan = sourcePlan.copyWith(
      groups: const [],
      points: [point],
      currentPointId: null,
      currentGroupId: null,
    );
    final repository = SamplePilgrimageRepository(plans: [plan]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PointManagerScreen(
          plan: plan,
          repository: repository,
          settings: const AppSettings(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final actions = find.byKey(ValueKey('point-manager-actions-${point.id}'));
    await tester.ensureVisible(actions);
    tester.widget<PopupMenuButton<String>>(actions).onSelected!('move');
    await tester.pumpAndSettle();

    expect(find.text('移动到片区'), findsOneWidget);
    expect(find.text('选择一个片区作为当前点位所属片区'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-point-group-option-未分入片区')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-point-group-selection-未分入片区')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-point-group-create-entry')),
      findsOneWidget,
    );
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

    expect(find.byKey(const ValueKey('plan-group-summary')), findsOneWidget);
    expect(find.byIcon(Icons.account_tree_outlined), findsNothing);
    expect(find.text('未分配点位'), findsOneWidget);
    expect(find.textContaining('个点位等待整理'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-group-create-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(find.text('片区名不能为空'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppInputDialog),
        matching: find.text('新建片区'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('plan-group-name-field')),
      '新片区',
    );
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(find.text('片区名不能为空'), findsNothing);
    expect(find.text('新片区'), findsOneWidget);
    expect(find.text('未设置关键点'), findsOneWidget);
    expect(find.text('空'), findsOneWidget);
    expect(find.text('无序'), findsOneWidget);

    await tester.tap(find.byTooltip('片区操作'));
    await tester.pumpAndSettle();
    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('设置关键点'), findsOneWidget);
    expect(find.text('切换为手动排序'), findsOneWidget);
    expect(find.text('删除片区'), findsOneWidget);
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

  testWidgets('aligns plan, records, and settings root app bars', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(
      tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight,
      kToolbarHeight,
    );
    final planAppBarTop = tester.getTopLeft(find.byType(AppBar)).dy;
    final planActionTop = tester
        .getTopLeft(find.byKey(const ValueKey('plan-actions-toggle')))
        .dy;

    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('records-app-bar'))).dy,
      closeTo(planAppBarTop, 0.1),
    );
    final recordsTitleTop = tester
        .getTopLeft(
          find.descendant(
            of: find.byKey(const ValueKey('records-app-bar')),
            matching: find.text('记录'),
          ),
        )
        .dy;
    final recordsActionTop = tester
        .getTopLeft(find.byKey(const ValueKey('records-toggle-all-sections')))
        .dy;
    expect(recordsActionTop, closeTo(planActionTop, 0.1));

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AppBar>(find.byKey(const ValueKey('settings-app-bar')))
          .toolbarHeight,
      kToolbarHeight,
    );
    expect(
      tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(const ValueKey('settings-app-bar')),
              matching: find.text('设置'),
            ),
          )
          .dy,
      closeTo(recordsTitleTop, 0.1),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('settings-reset-button'))).dy,
      closeTo(recordsActionTop, 0.1),
    );
    expect(
      tester
          .getTopRight(find.byKey(const ValueKey('settings-reset-button')))
          .dx,
      closeTo(
        tester
            .getTopRight(find.byKey(const ValueKey('settings-appearance-card')))
            .dx,
        0.1,
      ),
    );
  });

  testWidgets('restores app and comparison settings together', (tester) async {
    final configured = const ComparisonExportConfig(
      borderWidthPercent: 2,
      outputWidth: ComparisonOutputWidth.w3840,
      showLabels: true,
    ).applyToSettings(const AppSettings(uiScale: 0.85, mapMaxZoom: 24));
    final repository = SamplePilgrimageRepository(settings: configured);
    await tester.pumpWidget(MiriaGoApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('恢复初始设置'));
    await tester.pumpAndSettle();
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '恢复'))
        .onPressed!();
    await tester.pumpAndSettle();

    final settings = await repository.loadAppSettings();
    expect(settings.uiScale, 1);
    expect(settings.mapMaxZoom, 22);
    expect(settings.comparisonExportConfigJson, isEmpty);
    expect(settings.comparisonExportConfigMigrated, isTrue);
    expect(
      ComparisonExportConfig.lastUsed.outputWidth,
      ComparisonOutputWidth.auto,
    );
    expect(ComparisonExportConfig.lastUsed.showLabels, isFalse);
    expect(find.text('已恢复初始设置'), findsOneWidget);
  });

  testWidgets('separates appearance, map display, and data source settings', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('外观设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('显示片区进度条'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('显示片区进度条'), findsOneWidget);
    final progressToggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('plan-group-progress-toggle')),
    );
    expect(progressToggle.value, isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dismiss-plan-actions-on-outside-tap-toggle')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    final dismissToggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('dismiss-plan-actions-on-outside-tap-toggle')),
    );
    expect(dismissToggle.value, isTrue);

    Navigator.of(tester.element(find.text('外观设置').first)).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('数据源设置'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('数据源设置'), findsOneWidget);
    expect(find.text('地图显示'), findsOneWidget);

    await tester.tap(find.text('地图显示'));
    await tester.pumpAndSettle();

    expect(find.text('最大缩放倍率'), findsOneWidget);
    expect(find.text('地图标记大小'), findsOneWidget);
    expect(find.text('隐藏已完成点位'), findsOneWidget);
    expect(find.text('片区范围半径'), findsOneWidget);
    expect(find.text('显示片区进度条'), findsNothing);
    expect(find.text('90%'), findsOneWidget);
    final maxZoomSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('map-max-zoom-slider')),
    );
    expect(maxZoomSlider.value, 22);
    expect(maxZoomSlider.max, 24);
    await tester.scrollUntilVisible(
      find.text('自动聚合密集点位'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('自动聚合密集点位'), findsOneWidget);
    expect(find.text('40 px'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('缩略图显示阈值'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('缩略图显示阈值'), findsOneWidget);
    expect(find.text('图片同时请求数'), findsNothing);

    Navigator.of(tester.element(find.text('地图显示').first)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('数据源设置'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Anitabi 服务地址'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(
      find.byKey(const ValueKey('anitabi-service-settings-entry')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('anitabi-site-base-url')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('anitabi-static-data-base-url')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('anitabi-api-base-url')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('anitabi-official-image-base-url')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.byKey(const ValueKey('anitabi-official-image-base-url')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('anitabi-mirror-image-base-url')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('anitabi-service-test-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('anitabi-service-restore-defaults')),
      findsOneWidget,
    );
    expect(find.text('连接测试'), findsNothing);
    expect(find.text('主站地址'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('anitabi-service-restore-defaults')),
    );
    await tester.pumpAndSettle();
    expect(find.text('将把全部 Anitabi 服务地址恢复为官方默认值。'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.text('Anitabi 服务地址').first)).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('图片同时请求数'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('图片同时请求数'), findsOneWidget);
    expect(find.text('地图标记大小'), findsNothing);
    expect(find.text('片区范围半径'), findsNothing);
    expect(find.text('自动聚合密集点位'), findsNothing);
  });

  testWidgets('appearance settings can switch app theme mode', (tester) async {
    final repository = SamplePilgrimageRepository();
    await tester.pumpWidget(MiriaGoApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('主题色'), findsOneWidget);
    expect(find.text('浅色'), findsWidgets);

    await tester.tap(find.text('外观设置'));
    await tester.pumpAndSettle();
    expect(find.text('影响应用整体浅色或深色显示'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('appearance-theme-mode-dark')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('appearance-theme-mode-dark')));
    await tester.pumpAndSettle();

    expect((await repository.loadAppSettings()).themeMode, AppThemeMode.dark);
    expect(AppColors.isDark, isTrue);
    expect(
      Theme.of(tester.element(find.text('外观设置').first)).brightness,
      Brightness.dark,
    );
    Navigator.of(tester.element(find.text('外观设置').first)).pop();
    await tester.pumpAndSettle();
    expect(find.text('深色'), findsWidgets);
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('settings-app-bar'))),
      ).scaffoldBackgroundColor,
      AppColors.background,
    );
  });

  testWidgets('custom theme palette updates the hex color', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('外观设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();

    final valueControl = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('custom-theme-color-value')),
    );
    valueControl.onTapDown!(TapDownDetails(localPosition: Offset.zero));
    await tester.pump();

    final palette = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('custom-theme-color-palette')),
    );
    palette.onTapDown!(TapDownDetails(localPosition: Offset.zero));
    await tester.pump();

    final hexField = tester.widget<TextField>(
      find.byKey(const ValueKey('custom-theme-color-hex-field')),
    );
    expect(hexField.controller!.text, '#FF0000');
  });

  testWidgets('creates empty plan and shows add-points shell', (tester) async {
    await _pumpAppWithEmptyPlan(tester);

    expect(find.textContaining('新巡礼计划 2'), findsWidgets);
    expect(find.text('还没有点位'), findsOneWidget);
    expect(find.text('添加点位'), findsOneWidget);
    expect(find.text('加作品'), findsOneWidget);
    expect(find.text('选点位'), findsOneWidget);
    expect(find.text('划片区'), findsOneWidget);

    await _openAddPointsFromEmptyPlan(tester);

    expect(find.text('添加内容'), findsOneWidget);
    expect(find.text('管理作品'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-points-manual-point')),
      findsOneWidget,
    );
    final mapImportInkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('add-points-anitabi-map')),
        matching: find.byType(InkWell),
      ),
    );
    final manualPointInkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('add-points-manual-point')),
        matching: find.byType(InkWell),
      ),
    );
    final quickManualPointInkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('add-points-quick-manual-point')),
        matching: find.byType(InkWell),
      ),
    );
    expect(mapImportInkWell.onTap, isNull);
    expect(find.text('请先通过 Bangumi 搜索添加作品'), findsOneWidget);
    expect(quickManualPointInkWell.onTap, isNull);
    expect(manualPointInkWell.onTap, isNotNull);
  });

  testWidgets('empty map guide splits title and supporting copy', (tester) async {
    await _pumpAppWithEmptyPlan(tester);

    await tester.tap(find.text('地图').last);
    await tester.pumpAndSettle();

    expect(find.text('当前计划还没有点位'), findsOneWidget);
    expect(find.text('添加点位后会在地图上显示标记。'), findsOneWidget);
    expect(find.text('当前计划还没有点位。添加点位后会在地图上显示标记。'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('map-empty-card'))).height,
      lessThan(120),
    );
  });

  testWidgets('quick manual point page keeps only the lightweight fields', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository();
    final initialPlan = await repository.loadActivePlan();
    await tester.pumpWidget(MiriaGoApp(repository: repository));
    await tester.pumpAndSettle();

    await _openPlanMenu(tester);
    await tester.tap(find.text('添加点位').last);
    await tester.pumpAndSettle();
    _invokeKeyedAction(tester, 'add-points-quick-manual-point');
    await tester.pumpAndSettle();

    expect(find.text('快速手动添加点位'), findsOneWidget);
    expect(find.textContaining('所属作品'), findsOneWidget);
    expect(find.textContaining('点位名称'), findsOneWidget);
    expect(find.text('坐标位置'), findsOneWidget);
    expect(find.text('选填'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-point-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-point-latitude')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-point-longitude')), findsOneWidget);
    expect(find.text('位置说明'), findsNothing);
    expect(find.text('集数/场景标签'), findsNothing);
    expect(find.text('参考来源'), findsNothing);
    expect(find.text('备注'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('quick-point-filling-guide')));
    await tester.pumpAndSettle();
    expect(find.text('快速添加填写指南'), findsOneWidget);
    expect(find.textContaining('之后可从点位编辑页继续补充'), findsOneWidget);
    expect(find.textContaining('暂时不知道准确位置时可以留空'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('quick-point-guide-panel')))
          .height,
      lessThanOrEqualTo(500),
    );
    expect(
      find.byKey(const ValueKey('quick-point-guide-confirm')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('quick-point-guide-confirm')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-point-guide-confirm')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('quick-point-name')),
      '待补充坐标的点位',
    );
    _invokeKeyedAction(tester, 'quick-point-submit');
    await tester.pumpAndSettle();

    final updatedPlan = await repository.loadActivePlan();
    expect(updatedPlan.points.length, initialPlan.points.length + 1);
    final addedPoint = updatedPlan.points.last;
    expect(addedPoint.name, '待补充坐标的点位');
    expect(addedPoint.position, PilgrimagePoint.pendingPosition);
    expect(addedPoint.hasCoordinate, isFalse);
    expect(updatedPlan.currentPointId, initialPlan.currentPointId);
  });

  testWidgets('creates a new plan from the plan manager', (tester) async {
    final repository = SamplePilgrimageRepository();
    await tester.pumpWidget(MiriaGoApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('plan-switch-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('current-plan-section')), findsNothing);
    expect(find.byKey(const ValueKey('all-plans-section')), findsOneWidget);
    final createButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '新建计划'),
    );
    expect(createButton.style?.backgroundColor?.resolve({}), AppColors.surface);
    await tester.tap(find.widgetWithText(OutlinedButton, '新建计划'));
    await tester.pumpAndSettle();

    expect(find.text('新巡礼计划 2'), findsNWidgets(2));
    expect(find.textContaining('未设置区域  /  0 个点位  /  0 部作品'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('plan-status-current')), findsNWidgets(2));
    expect(find.text('可切换'), findsOneWidget);
    expect(find.byKey(const ValueKey('current-plan-section')), findsNothing);
    expect(find.byKey(const ValueKey('all-plans-section')), findsOneWidget);
    expect(find.text('全部计划'), findsOneWidget);
    expect(find.byTooltip('更多计划操作'), findsNWidgets(3));
    expect(tester.getSize(find.byTooltip('更多计划操作').first), const Size(38, 34));
    expect(find.text('导入导出'), findsNothing);
    expect(find.byTooltip('编辑计划信息'), findsNWidgets(3));
    expect(find.byTooltip('计划排序'), findsOneWidget);
    expect(find.byTooltip('拖动排序'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'plan-card-drag-handle-',
            ),
      ),
      findsNothing,
    );
    expect(find.byTooltip('删除计划'), findsNothing);
    expect(find.widgetWithText(TextButton, '切换'), findsNothing);
    final editIcon = tester.widget<Icon>(
      find
          .descendant(
            of: find.byTooltip('编辑计划信息').first,
            matching: find.byIcon(Icons.edit_outlined),
          )
          .first,
    );
    expect(editIcon.size, 21);

    final planCards = find.byWidgetPredicate(
      (widget) =>
          widget is Material &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('plan-card-'),
    );
    expect(planCards, findsNWidgets(3));
    expect(tester.getSize(planCards.first).height, lessThan(150));
    expect(tester.getSize(planCards.last).height, lessThan(150));
    expect(tester.getSize(planCards.first).height, greaterThanOrEqualTo(120));
    expect(tester.getSize(planCards.last).height, greaterThanOrEqualTo(120));
    expect(
      tester.getSize(planCards.first).height,
      closeTo(tester.getSize(planCards.last).height, 0.1),
    );
    expect(
      tester.widgetList<Material>(planCards).map((card) => card.color).toSet(),
      {AppColors.surface},
    );
    final selectedAccents = find.byWidgetPredicate(
      (widget) =>
          widget is Positioned &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'plan-card-selected-accent-',
          ),
    );
    expect(selectedAccents, findsNWidgets(2));
    final selectedAccentRect = tester.getRect(selectedAccents.first);
    final selectedCardRect = tester.getRect(planCards.first);
    expect(selectedAccentRect.width, 3);
    expect(selectedAccentRect.height, selectedCardRect.height - 18);
    final editRect = tester.getRect(find.byTooltip('编辑计划信息').first);
    final moreRect = tester.getRect(find.byTooltip('更多计划操作').first);
    final dividerRect = tester.getRect(
      find.descendant(of: planCards.first, matching: find.byType(Divider)),
    );
    expect(editRect.size, moreRect.size);
    expect(editRect.right, lessThan(moreRect.left));
    expect(editRect.center.dy, closeTo(moreRect.center.dy, 0.1));
    expect(editRect.top - dividerRect.bottom, closeTo(4, 0.1));
    expect(moreRect.top - dividerRect.bottom, closeTo(4, 0.1));
    expect(selectedCardRect.bottom - editRect.bottom, closeTo(4, 0.1));
    expect(selectedCardRect.bottom - moreRect.bottom, closeTo(4, 0.1));
    final dragHandles = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'plan-card-drag-handle-',
          ),
    );
    expect(
      find.descendant(of: planCards.first, matching: dragHandles),
      findsNothing,
    );

    await tester.tap(find.byTooltip('计划排序'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('完成排序'), findsOneWidget);
    expect(find.byTooltip('拖动排序'), findsNWidgets(2));
    expect(dragHandles, findsNWidgets(2));
    final planIdsBeforeReorder = (await repository.loadPlans())
        .map((plan) => plan.id)
        .toList();
    final reorderable = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey('reorderable-plan-list')),
    );
    reorderable.onReorderItem!(1, 0);
    await tester.pumpAndSettle();
    expect((await repository.loadPlans()).map((plan) => plan.id), [
      planIdsBeforeReorder[1],
      planIdsBeforeReorder[0],
    ]);
    await tester.tap(find.byTooltip('完成排序'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('拖动排序'), findsNothing);

    final planTitleTexts = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'plan-card-title-',
            ),
      ),
      matching: find.byType(Text),
    );
    final planSummaryTexts = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'plan-card-summary-',
            ),
      ),
      matching: find.byType(Text),
    );
    for (final text in tester.widgetList<Text>(planTitleTexts)) {
      expect(text.style?.fontSize, 17);
      expect(text.style?.color, AppColors.textPrimary);
    }
    for (final text in tester.widgetList<Text>(planSummaryTexts)) {
      expect(text.style?.fontSize, 12.5);
      expect(text.style?.color, AppColors.textSecondary);
    }

    expect(find.byKey(const ValueKey('plan-work-tags')), findsOneWidget);
    expect(find.text('暂无作品'), findsNWidgets(2));
    expect(
      tester.widget<Text>(find.text('暂无作品').first).style?.color,
      AppColors.textSecondary,
    );
    final workRows = find.byWidgetPredicate(
      (widget) =>
          widget is SizedBox &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'plan-card-work-row-',
          ),
    );
    expect(workRows, findsNWidgets(3));
    for (final workRow in workRows.evaluate()) {
      expect(
        tester.getSize(find.byElementPredicate((e) => e == workRow)).height,
        18,
      );
    }
    final titleRect = tester.getRect(find.text('新巡礼计划 2').first);
    final summaryRect = tester.getRect(
      find.textContaining('未设置区域  /  0 个点位  /  0 部作品').first,
    );
    final emptyWorkRowRect = tester.getRect(
      find
          .ancestor(
            of: find.text('暂无作品').first,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SizedBox &&
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'plan-card-work-row-',
                  ),
            ),
          )
          .first,
    );
    expect(summaryRect.top - titleRect.bottom, closeTo(5, 0.1));
    expect(emptyWorkRowRect.top - summaryRect.bottom, closeTo(3, 0.1));
    expect(titleRect.left, closeTo(summaryRect.left, 0.1));
    await tester.tap(find.byTooltip('更多计划操作').first);
    await tester.pumpAndSettle();
    final menuPointer = find.byKey(const ValueKey('plan-actions-menu-pointer'));
    final menuPanel = find.byKey(const ValueKey('plan-actions-menu-panel'));
    expect(menuPointer, findsOneWidget);
    expect(menuPanel, findsOneWidget);
    final menuPointerRect = tester.getRect(menuPointer);
    final menuPanelRect = tester.getRect(menuPanel);
    expect(menuPointerRect.top, greaterThanOrEqualTo(moreRect.bottom));
    expect(menuPointerRect.center.dx, closeTo(moreRect.center.dx, 0.1));
    expect(menuPanelRect.top, closeTo(menuPointerRect.top, 0.1));
    expect(menuPanelRect.width, 150);
    expect(menuPanelRect.bottom, greaterThan(menuPointerRect.bottom));
    expect(find.text('未设置区域'), findsNothing);
    expect(find.text('导入导出'), findsOneWidget);
    expect(find.text('编辑计划'), findsNothing);
    expect(find.text('复制计划'), findsOneWidget);
    expect(find.text('删除计划'), findsOneWidget);
    for (final actionKey in [
      'plan-menu-action-transfer',
      'plan-menu-action-copy',
      'plan-menu-action-delete',
    ]) {
      final action = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey(actionKey)),
      );
      final decoration = action.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(8));
      expect(decoration.boxShadow, isEmpty);
    }
    final deleteMenuButton = tester
        .widgetList<MenuItemButton>(find.byType(MenuItemButton))
        .singleWhere(
          (button) =>
              button.child is Text && (button.child as Text).data == '删除计划',
        );
    expect(
      deleteMenuButton.style?.foregroundColor?.resolve({}),
      AppColors.error,
    );
    await tester.tap(find.text('复制计划'));
    await tester.pumpAndSettle();
    expect(find.textContaining('新巡礼计划 2 副本'), findsWidgets);

    await tester.tap(find.text('可切换').first);
    await tester.pumpAndSettle();
    expect(find.text('切换计划'), findsNothing);
  });

  testWidgets('work manager opens a compact delete menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final work = plan.works.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: WorkManagerScreen(
          plan: plan,
          repository: repository,
          settings: const AppSettings(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final moreButton = find.byKey(ValueKey('work-manage-more-${work.id}'));
    expect(moreButton, findsOneWidget);
    expect(
      find.descendant(of: moreButton, matching: find.byIcon(Icons.more_horiz)),
      findsOneWidget,
    );
    expect(tester.getSize(moreButton), const Size.square(34));
    final moreMenu = tester.widget<PopupMenuButton<String>>(moreButton);
    expect(moreMenu.style?.side?.resolve({}), isNull);
    expect(find.byKey(const ValueKey('work-action-delete')), findsNothing);
    final cardBadgeTexts = tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(ValueKey('work-manage-badges-${work.id}')),
        matching: find.byType(Text),
      ),
    );
    expect(cardBadgeTexts, isNotEmpty);
    for (final badgeText in cardBadgeTexts) {
      expect(badgeText.maxLines, 1);
      expect(badgeText.softWrap, isFalse);
    }

    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('work-action-delete')), findsOneWidget);
    expect(find.text('删除作品'), findsOneWidget);
    expect(find.text('作品操作'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('work-action-delete')));
    await tester.pumpAndSettle();

    expect(find.text('删除作品'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '删除'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('作品管理'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches plan when tapping copyable card title', (tester) async {
    final repository = SamplePilgrimageRepository();
    await repository.createPlan(name: '第二计划', area: '京都');
    await tester.pumpWidget(MiriaGoApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('plan-switch-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('plan-card-title-sample-uji-hibike')),
    );
    await tester.pumpAndSettle();

    expect(find.text('切换计划'), findsNothing);
    expect((await repository.loadActivePlan()).id, 'sample-uji-hibike');
  });

  testWidgets('plan reorder proxy keeps item spacing transparent', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository();
    await repository.createPlan(name: '第二计划', area: '京都');
    await tester.pumpWidget(
      MaterialApp(home: PlanManagerScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final reorderable = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey('reorderable-plan-list')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: reorderable.proxyDecorator!(
          const SizedBox(key: ValueKey('proxy-child')),
          0,
          const AlwaysStoppedAnimation(1),
        ),
      ),
    );

    final reorderProxy = tester.widget<Material>(
      find.byKey(const ValueKey('plan-reorder-proxy')),
    );
    expect(reorderProxy.color, Colors.transparent);
    expect(find.byKey(const ValueKey('proxy-child')), findsOneWidget);
  });

  testWidgets('restores plan order when persistence fails', (tester) async {
    final repository = _FailingPlanOrderRepository();
    await repository.createPlan(name: '第二计划', area: '京都');
    final originalIds = (await repository.loadPlans())
        .map((plan) => plan.id)
        .toList();
    await tester.pumpWidget(
      MaterialApp(home: PlanManagerScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('计划排序'));
    await tester.pumpAndSettle();
    tester
        .widget<ReorderableListView>(
          find.byKey(const ValueKey('reorderable-plan-list')),
        )
        .onReorderItem!(1, 0);
    await tester.pumpAndSettle();

    expect((await repository.loadPlans()).map((plan) => plan.id), originalIds);
    expect(find.text('保存计划顺序失败，已恢复原来的顺序'), findsOneWidget);
    final cardKeys = tester
        .widgetList<Padding>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Padding &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'reorder-plan-',
                ),
          ),
        )
        .map((widget) => (widget.key! as ValueKey<String>).value)
        .toList();
    expect(cardKeys, originalIds.map((id) => 'reorder-plan-$id'));
  });

  testWidgets('Bangumi work enables work-map import without existing points', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: 'Bangumi 空计划', area: '东京');
    await repository.addWorkToPlan(
      planId: plan.id,
      work: const PilgrimageWork(
        id: 'bangumi-work',
        bangumiId: 12345,
        title: '测试动画',
        subtitle: 'Test Anime',
        city: '东京',
        source: WorkSource.bangumi,
      ),
    );
    await tester.pumpWidget(MiriaGoApp(repository: repository));
    await tester.pumpAndSettle();

    _invokeKeyedAction(tester, 'plan-add-points');
    await tester.pumpAndSettle();

    final mapImportInkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('add-points-anitabi-map')),
        matching: find.byType(InkWell),
      ),
    );
    expect(mapImportInkWell.onTap, isNotNull);
    expect(find.text('在作品地图上选择并导入点位'), findsOneWidget);
    expect(find.text('请先通过 Bangumi 搜索添加作品'), findsNothing);
  });

  testWidgets('Bangumi search shows a trailing clear button after input', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '搜索测试', area: '东京');
    await tester.pumpWidget(
      MaterialApp(
        home: BangumiWorkSearchScreen(
          plan: plan,
          repository: repository,
          bangumiApiClient: BangumiApiClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    expect(
      find.byKey(const ValueKey('bangumi-search-clear-button')),
      findsNothing,
    );
    await tester.enterText(searchField, '轻音少女');
    await tester.pump();
    final clearButton = find.byKey(
      const ValueKey('bangumi-search-clear-button'),
    );
    expect(clearButton, findsOneWidget);
    expect(
      tester.getRect(clearButton).right,
      closeTo(tester.getRect(searchField).right, 0.1),
    );
    await tester.tap(clearButton);
    await tester.pump();
    expect(tester.widget<TextField>(searchField).controller?.text, isEmpty);
    expect(clearButton, findsNothing);
  });

  testWidgets('adds a manual work to an empty plan', (tester) async {
    await _pumpAppWithEmptyPlan(tester);

    await _openAddPointsFromEmptyPlan(tester);
    _invokeKeyedAction(tester, 'add-points-work-manager');
    await tester.pumpAndSettle();
    _invokeKeyedAction(tester, 'work-manager-manual-work');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('manual-work-filling-guide')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('manual-work-filling-guide')),
        matching: find.text('填写指南'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('manual-work-filling-guide')));
    await tester.pumpAndSettle();
    expect(find.text('作品填写指南'), findsOneWidget);
    expect(find.text('示例：京都市 / 宇治市'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('manual-work-guide-panel')))
          .height,
      lessThanOrEqualTo(540),
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '原创短片');
    await tester.enterText(fields.at(1), 'Original');
    await tester.enterText(fields.at(2), '京都市');
    await tester.tap(find.text('保存作品'));
    await tester.pumpAndSettle();

    expect(find.text('手动添加作品'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(fields.at(2)).controller!.text,
      isEmpty,
    );
    await tester.tap(find.byIcon(Icons.arrow_back));
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('manual-point-filling-guide')),
        matching: find.text('填写指南'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('manual-point-filling-guide')));
    await tester.pumpAndSettle();
    expect(find.text('点位填写指南'), findsOneWidget);
    expect(
      find.text('示例：EP 1 / 12:32\n示例：小红书@BilyHurington / Bilibili@麦块晓天'),
      findsOneWidget,
    );
    expect(find.text('示例：35.008900, 135.771100'), findsOneWidget);
    expect(find.textContaining('名称优先填写中文常用名；位置说明优先填写当地原语言'), findsOneWidget);
    expect(find.textContaining('参考来源填写该点位原来所在的平台，或原始上传者'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('manual-point-guide-panel')))
          .height,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '例如：东京国际会展中心',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '例如：東京ビッグサイト',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == '例如：EP 1 / 12:32',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText ==
                '例如：小红书@BilyHurington / Bilibili@麦块晓天',
      ),
      findsOneWidget,
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '轻音少女');
    await tester.enterText(fields.at(3), '鸭川三条');
    await tester.enterText(fields.at(4), '鸭川沿岸');
    await tester.enterText(fields.at(5), '自定义场景 1');
    await tester.enterText(fields.at(6), '手动录入');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('point-form-latitude')),
              matching: find.byType(TextField),
            ),
          )
          .decoration
          ?.hintText,
      '例如：35.712576',
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('point-form-longitude')),
              matching: find.byType(TextField),
            ),
          )
          .decoration
          ?.hintText,
      '例如：139.722166',
    );
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
    expect(find.text('详情'), findsNothing);
    expect(find.text('导航'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('anitabi-point-card-point-1')));
    await tester.pumpAndSettle();
    expect(find.text('坐标'), findsOneWidget);
    Navigator.of(tester.element(find.text('坐标'))).pop();
    await tester.pumpAndSettle();

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
      'https://ww.anitabi.cn/map?pid=qdmnf6iqj',
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
    const link = 'https://ww.anitabi.cn/map?bangumiId=282923&pid=djnfcvo';
    _mockClipboardRead(tester, link);

    await tester.tap(find.byTooltip('粘贴'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, link);
    expect(find.byTooltip('清除搜索框'), findsOneWidget);
    expect(find.byTooltip('粘贴'), findsNothing);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('anitabi-link-input-action')))
          .right,
      closeTo(tester.getRect(find.byType(TextFormField)).right, 0.1),
    );
    await tester.tap(find.byTooltip('清除搜索框'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      isEmpty,
    );
    expect(find.byTooltip('粘贴'), findsOneWidget);
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

  testWidgets('Anitabi import map browses overlapping points at maximum zoom', (
    tester,
  ) async {
    const settings = AppSettings(mapMarkerClusterMaxZoom: 18, mapMaxZoom: 24);
    final repository = SamplePilgrimageRepository(
      plans: const [],
      settings: settings,
    );
    final plan = await repository.createPlan(name: '重合点位测试', area: '京都');
    final planWithWork = await repository.addWorkToPlan(
      planId: plan.id,
      work: const PilgrimageWork(
        id: 'overlap-work',
        bangumiId: 3001,
        title: '重合点位作品',
        subtitle: '',
        city: '京都',
        source: WorkSource.bangumi,
      ),
    );
    const position = LatLng(35, 135);
    final points = [
      for (var index = 0; index < 3; index += 1)
        AnitabiPoint(
          bangumiId: 3001,
          id: 'overlap-$index',
          name: '重合点位 ${index + 1}',
          subtitle: '场景 ${index + 1}',
          position: position,
          episodeLabel: 'EP ${index + 1}',
          referenceImageUrl: null,
          origin: 'Anitabi',
          originUrl: 'https://anitabi.cn/',
        ),
    ];
    final anitabiClient = _FakeAnitabiClient(pointsByBangumi: {3001: points});

    await tester.pumpWidget(
      MaterialApp(
        home: AnitabiMapImportScreen(
          plan: planWithWork,
          repository: repository,
          initialSettings: settings,
          anitabiClient: anitabiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.mapController!.move(position, 24);
    await tester.pumpAndSettle();
    final cluster = tester.widget<MapMarkerClusterBadge>(
      find.byType(MapMarkerClusterBadge),
    );
    expect(cluster.opensPointBrowser, isTrue);
    cluster.onTap();
    await tester.pump();

    expect(find.text('重合点位  1 / 3'), findsOneWidget);
    tester
        .widget<IconButton>(find.byKey(const ValueKey('map-overlap-next')))
        .onPressed!();
    await tester.pump();
    expect(find.text('重合点位  2 / 3'), findsOneWidget);
    expect(find.text('重合点位 2'), findsOneWidget);
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

  testWidgets('Anitabi bulk import creates a group and assigns points', (
    tester,
  ) async {
    final repository = SamplePilgrimageRepository(plans: const []);
    final plan = await repository.createPlan(name: '批量整理测试', area: '京都');
    final anitabiClient = _FakeAnitabiClient(
      pointsByBangumi: const {12345: _bulkImportPoints},
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

    await tester.tap(find.byTooltip('添加所有点位'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加全部'));
    await tester.pumpAndSettle();
    expect(find.text('整理刚导入的点位'), findsOneWidget);

    await tester.tap(find.text('分配到片区'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('plan-point-group-create-entry')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('anitabi-import-group-name-field')),
      '新导入片区',
    );
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新导入片区'));
    await tester.pumpAndSettle();

    final updatedPlan = await repository.loadActivePlan();
    final group = updatedPlan.groups.singleWhere(
      (group) => group.name == '新导入片区',
    );
    expect(updatedPlan.points, hasLength(2));
    expect(
      updatedPlan.points.every((point) => point.groupId == group.id),
      true,
    );
  });

  testWidgets(
    'post-import organization failure does not report import failure',
    (tester) async {
      final repository = _FailingSettingsOnDemandRepository(plans: const []);
      final plan = await repository.createPlan(name: '整理失败测试', area: '京都');
      final anitabiClient = _FakeAnitabiClient(
        pointsByBangumi: const {12345: _bulkImportPoints},
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
      repository.failNextSettingsLoad = true;

      await tester.tap(find.byTooltip('添加所有点位'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加全部'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('最近分配'));
      await tester.pumpAndSettle();

      final updatedPlan = await repository.loadActivePlan();
      expect(updatedPlan.points, hasLength(2));
      expect(find.textContaining('点位已导入，但整理流程打开失败'), findsOneWidget);
      expect(find.textContaining('批量导入失败'), findsNothing);
    },
  );
}

const _bulkImportPoints = [
  AnitabiPoint(
    bangumiId: 12345,
    id: 'bulk-1',
    name: '批量点位 1',
    subtitle: '场景 1',
    position: LatLng(35, 135),
    episodeLabel: 'EP 1',
    referenceImageUrl: null,
    origin: 'Anitabi',
    originUrl: 'https://anitabi.cn/',
  ),
  AnitabiPoint(
    bangumiId: 12345,
    id: 'bulk-2',
    name: '批量点位 2',
    subtitle: '场景 2',
    position: LatLng(35.001, 135.001),
    episodeLabel: 'EP 2',
    referenceImageUrl: null,
    origin: 'Anitabi',
    originUrl: 'https://anitabi.cn/',
  ),
];

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

class _FailingPlanOrderRepository extends SamplePilgrimageRepository {
  @override
  Future<void> reorderPlans({required List<String> orderedPlanIds}) {
    throw StateError('simulated persistence failure');
  }
}

class _FailingSettingsOnDemandRepository extends SamplePilgrimageRepository {
  _FailingSettingsOnDemandRepository({super.plans});

  var failNextSettingsLoad = false;

  @override
  Future<AppSettings> loadAppSettings() {
    if (failNextSettingsLoad) {
      failNextSettingsLoad = false;
      throw StateError('simulated settings failure');
    }
    return super.loadAppSettings();
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
