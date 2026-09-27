import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/ui/features/organize/group_picker.dart';
import 'package:miriago/ui/features/organize/location_picker.dart';
import 'package:miriago/ui/features/organize/organize_common.dart';

import '../../helpers/pump_app.dart';
import '../components/harness.dart';

const _station = 'sample-group-uji-station';
const _ungrouped = 'anitabi-115908-sample-unassigned-02';

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void _mockClipboard(WidgetTester tester, Object? Function() read) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.getData') {
        final value = read();
        return value == null ? null : {'text': value};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

/// Opens the coordinate dialog and returns a holder for its result.
Future<List<LatLng?>> _openDialog(
  WidgetTester tester, {
  LatLng? initial,
}) async {
  final results = <LatLng?>[];
  await pumpComponent(
    tester,
    Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () async => results.add(
            await showCoordinateInputDialog(context, initial: initial),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
  return results;
}

TextField _field(WidgetTester tester, String key) => tester.widget<TextField>(
  find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  ),
);

void main() {
  group('coordinate dialog', () {
    testWidgets('prefills 6 decimals and validates input', (tester) async {
      final results = await _openDialog(
        tester,
        initial: const LatLng(34.8903, 135.8009),
      );
      expect(find.text('输入经纬度'), findsOne);
      expect(
        _field(tester, 'coordinate-dialog-latitude').controller!.text,
        '34.890300',
      );
      expect(
        _field(tester, 'coordinate-dialog-longitude').controller!.text,
        '135.800900',
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('coordinate-dialog-latitude')),
          matching: find.byType(TextField),
        ),
        '91',
      );
      await tester.tap(find.text('确定'));
      await _settle(tester);
      expect(find.text('请输入有效经纬度'), findsOne);

      // Full-width digits are accepted.
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('coordinate-dialog-latitude')),
          matching: find.byType(TextField),
        ),
        '３５．５',
      );
      await _settle(tester);
      expect(find.text('请输入有效经纬度'), findsNothing, reason: 'cleared on edit');
      await tester.tap(find.text('确定'));
      await _settle(tester);
      expect(results.single, const LatLng(35.5, 135.8009));
    });

    testWidgets('pastes DMS / NSEW coordinates from the clipboard', (
      tester,
    ) async {
      String? clipboard = '34°53\'25.1"N 135°48\'03.2"E';
      _mockClipboard(tester, () => clipboard);
      await _openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('coordinate-dialog-paste')));
      await _settle(tester);
      expect(
        _field(tester, 'coordinate-dialog-latitude').controller!.text,
        startsWith('34.890'),
      );
      expect(
        _field(tester, 'coordinate-dialog-longitude').controller!.text,
        startsWith('135.800'),
      );

      clipboard = 'no coordinate here';
      await tester.tap(find.byKey(const ValueKey('coordinate-dialog-paste')));
      await _settle(tester);
      expect(find.text('剪贴板中没有可识别的坐标。'), findsOne);
    });

    testWidgets('reports unreadable clipboards', (tester) async {
      await pumpComponent(
        tester,
        CoordinateInputDialog(
          readClipboardCoordinate: () async => throw StateError('denied'),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('coordinate-dialog-paste')));
      await _settle(tester);
      expect(find.text('无法读取剪贴板。'), findsOne);
    });
  });

  group('map tools', () {
    setUp(() => OrganizeDebug.disableMapTiles = true);
    tearDown(() => OrganizeDebug.disableMapTiles = false);

    testWidgets('nearest assignment assigns after confirmation', (
      tester,
    ) async {
      final repo = await pumpMiriaApp(
        tester,
        location: '/plan/organize/assign/nearest',
      );
      await _settle(tester);
      expect(find.text('最近分配'), findsWidgets);
      expect(find.text('可分配 1/1'), findsOne);
      expect(find.text('未分组点位会分配到距离最近、且在最大距离范围内的片区关键点。'), findsOne);
      expect(find.text('50 m - 5 km'), findsOne);

      await tester.tap(find.byKey(const ValueKey('nearest-assign-submit')));
      await _settle(tester);
      expect(find.text('确认最近分配'), findsOne);
      await tester.tap(find.text('开始分配'));
      await _settle(tester);
      expect(find.text('已分配 1 个点位'), findsOne);
      final plan = await repo.loadActivePlan();
      expect(
        plan.points.firstWhere((point) => point.id == _ungrouped).groupId,
        isNotNull,
      );
      expect(find.text('可分配 0/0'), findsOne);
      final settings = await repo.loadAppSettings();
      expect(settings.nearestAssignDistanceMeters, 350);
    });

    testWidgets('nearest assignment warns when nothing is in range', (
      tester,
    ) async {
      await pumpMiriaApp(tester, location: '/plan/organize/assign/nearest');
      await _settle(tester);
      final slider = find.byKey(const ValueKey('nearest-assign-slider'));
      // Drag to the minimum (50 m).
      await tester.drag(slider, const Offset(-600, 0));
      await _settle(tester);
      expect(find.text('最大距离 50 m'), findsOne);
      await tester.tap(find.byKey(const ValueKey('nearest-assign-submit')));
      await _settle(tester);
      expect(find.text('当前距离内没有可分配点位'), findsOne);
    });

    testWidgets('box assignment needs a box first', (tester) async {
      await pumpMiriaApp(tester, location: '/plan/organize/assign/box');
      await _settle(tester);
      expect(find.text('已框选 0 / 待分配 1'), findsOne);
      expect(find.text('宇治站附近'), findsOne, reason: 'first group is the target');
      await tester.tap(find.byKey(const ValueKey('box-assign-toggle')));
      await _settle(tester);
      expect(find.text('结束框选'), findsOne);
      await tester.tap(find.byKey(const ValueKey('box-assign-group-picker')));
      await _settle(tester);
      expect(find.text('选择片区'), findsOne);
      expect(find.text('未分入片区'), findsNothing);
      await tester.tap(find.text('大吉山').last);
      await _settle(tester);
      expect(find.text('大吉山'), findsOne);
    });

    testWidgets('anchor picker clears and saves an empty key point (Δ6)', (
      tester,
    ) async {
      final repo = await pumpMiriaApp(
        tester,
        location: '/plan/organize/anchor/$_station',
      );
      await _settle(tester);
      expect(find.text('选择关键点'), findsOne);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('anchor-picker-title')))
            .data,
        'JR 宇治站',
      );

      await tester.tap(find.byKey(const ValueKey('anchor-picker-clear')));
      await _settle(tester);
      expect(find.text('将清除当前选择的关键点，可继续在本页重新选择。'), findsOne);
      await tester.tap(find.text('清除选点').last);
      await _settle(tester);
      expect(find.text('尚未选择关键点'), findsOne);

      await tester.tap(find.byKey(const ValueKey('anchor-picker-save')));
      await _settle(tester);
      final group = (await repo.loadActivePlan()).groups.firstWhere(
        (group) => group.id == _station,
      );
      expect(group.anchorName, isNull);
      expect(group.anchorLatitude, isNull);
      expect(group.anchorPointId, isNull);
    });

    testWidgets('anchor picker saves the crosshair as 手动关键点', (tester) async {
      final repo = await pumpMiriaApp(
        tester,
        location: '/plan/organize/anchor/$_station',
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('anchor-picker-crosshair')));
      await _settle(tester);
      expect(find.text('手动关键点'), findsOne);
      await tester.tap(find.byKey(const ValueKey('anchor-picker-save')));
      await _settle(tester);
      final group = (await repo.loadActivePlan()).groups.firstWhere(
        (group) => group.id == _station,
      );
      expect(group.anchorName, '手动关键点');
      expect(group.anchorPointId, isNull);
      expect(group.anchorLatitude, isNotNull);
    });

    for (final location in [
      '/plan/organize/assign/nearest',
      '/plan/organize/assign/box',
      '/plan/organize/anchor/$_station',
    ]) {
      testWidgets('no overflow: $location at small phone ×2', (tester) async {
        await pumpMiriaApp(
          tester,
          location: location,
          size: TestSizes.phoneSmall,
          textScale: 2,
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('pickers', () {
    setUp(() => OrganizeDebug.disableMapTiles = true);
    tearDown(() => OrganizeDebug.disableMapTiles = false);

    testWidgets('pickLocation returns the crosshair position', (tester) async {
      await pumpMiriaApp(tester, location: '/plan/organize');
      await _settle(tester);
      final context = tester.element(
        find.byKey(const ValueKey('organize-search')),
      );
      final future = pickLocation(
        context,
        initial: const LatLng(34.9, 135.8),
        title: '选择点位坐标',
      );
      await _settle(tester);
      expect(find.text('选择点位坐标'), findsOne);
      final coordinates = tester.widget<Text>(
        find.byKey(const ValueKey('location-picker-coordinates')),
      );
      expect(coordinates.data, matches(RegExp(r'^34\.9\d{5}, 135\.8\d{5}$')));
      await tester.tap(find.byKey(const ValueKey('location-picker-use')));
      await _settle(tester);
      final result = await future;
      expect(result, isNotNull);
      expect(result!.latitude, closeTo(34.9, 0.001));
      expect(result.longitude, closeTo(135.8, 0.001));
    });

    testWidgets('pickGroup can create a group inline', (tester) async {
      final repo = await pumpMiriaApp(tester, location: '/plan/organize');
      await _settle(tester);
      final context = tester.element(
        find.byKey(const ValueKey('organize-search')),
      );
      final future = pickGroup(context, title: '移动到片区');
      await _settle(tester);
      expect(find.text('未分入片区'), findsOne);
      await tester.tap(find.byKey(const ValueKey('group-picker-create')));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, '新的片区');
      await tester.tap(find.text('创建'));
      await _settle(tester);
      final plan = await repo.loadActivePlan();
      final created = plan.groups.firstWhere((group) => group.name == '新的片区');
      await tester.tap(
        find.byKey(ValueKey('group-picker-option-${created.id}')),
      );
      await _settle(tester);
      expect(await future, created.id);
    });

    testWidgets('manual groups reorder points by dragging', (tester) async {
      final repo = await pumpMiriaApp(
        tester,
        location: '/plan/organize?group=sample-group-daikichiyama',
      );
      await _settle(tester);
      final before =
          (await repo.loadActivePlan()).points
              .where((point) => point.groupId == 'sample-group-daikichiyama')
              .toList()
            ..sort(
              (a, b) =>
                  (a.groupOrderIndex ?? 0).compareTo(b.groupOrderIndex ?? 0),
            );
      final first = before.first.id;
      final handle = find.byKey(ValueKey('organize-point-drag-$first'));
      expect(handle, findsOne);
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await _settle(tester);
      final after =
          (await repo.loadActivePlan()).points
              .where((point) => point.groupId == 'sample-group-daikichiyama')
              .toList()
            ..sort(
              (a, b) =>
                  (a.groupOrderIndex ?? 0).compareTo(b.groupOrderIndex ?? 0),
            );
      expect(after.first.id, isNot(first));
    });
  });

  group('group sheets', () {
    testWidgets('switcher lists every bucket with counts', (tester) async {
      late BuildContext context;
      final PilgrimageRepository repo = await pumpMiriaApp(
        tester,
        location: '/plan/organize',
      );
      await _settle(tester);
      context = tester.element(find.byKey(const ValueKey('organize-search')));
      final future = showGroupSwitcherSheet(
        context,
        selectedGroupId: 'ungrouped',
      );
      await _settle(tester);
      expect(find.text('选择区域'), findsOne);
      final plan = await repo.loadActivePlan();
      expect(find.text('共 ${plan.groups.length + 1} 个区域'), findsOne);
      expect(
        find.byKey(const ValueKey('group-switcher-option-ungrouped')),
        findsOne,
      );
      await tester.tap(
        find.byKey(const ValueKey('group-switcher-option-$_station')),
      );
      await _settle(tester);
      expect(await future, _station);
    });
  });
}
