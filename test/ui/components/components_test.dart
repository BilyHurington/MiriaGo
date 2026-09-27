import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/components/components.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'harness.dart';

Widget _img(Color color) => ColoredBox(color: color);

void main() {
  group('ListRow', () {
    for (final dark in [false, true]) {
      testWidgets('no overflow at 320 wide with text scale 2.0 (dark: $dark)', (
        tester,
      ) async {
        await pumpComponent(
          tester,
          ListView(
            children: [
              ListRow(
                title: '一个很长很长的点位名称，京阪宇治駅前バス停付近の交差点',
                titleLocale: MiriaFonts.japanese,
                subtitle: '宇治 · 第 12 站 · 约 1.2 km · 有参考图 · 已缓存',
                leading: const Icon(Symbols.place_rounded),
                trailing: const StatusBadge(status: VisitStatus.current),
                routeLine: const RouteLine(status: VisitStatus.current),
                showChevron: true,
                onTap: () {},
                contextActions: [MenuAction(label: '删除', onSelected: () {})],
              ),
              const KeyValueRow(label: '坐标', value: '34.889412, 135.807736'),
              SwitchRow(
                title: '显示参考图缩略图并在地图上替代圆点',
                subtitle: '副标题也会换行',
                value: true,
                onChanged: (_) {},
              ),
              SliderRow(title: '叠影透明度', value: 0.5, onChanged: (_) {}),
              const SectionHeader(title: '一个很长的分组标题', count: 128),
              SplitNavButton(onNavigate: () {}, onOpenExternal: () {}),
              MiriaButton(
                label: '开始今天的巡礼',
                shortLabel: '开始',
                icon: Symbols.explore_rounded,
                expand: true,
                onPressed: () {},
              ),
              const InfoBanner(message: '有 3 张参考图未缓存，离线时无法显示。'),
              const EmptyState(title: '还没有巡礼记录', message: '在巡礼页拍摄后，记录会出现在这里。'),
            ],
          ),
          size: const Size(320, 568),
          textScale: 2,
          dark: dark,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(ListRow), findsOneWidget);
      });
    }

    testWidgets('secondary click opens the context actions', (tester) async {
      var deleted = false;
      await pumpComponent(
        tester,
        ListRow(
          title: '宇治橋',
          onTap: () {},
          contextActions: [
            MenuAction(label: '删除点位', onSelected: () => deleted = true),
          ],
        ),
      );
      final center = tester.getCenter(find.text('宇治橋'));
      await tester.tapAt(center, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除点位'));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });
  });

  group('SegmentedControl', () {
    Widget control({double? width, bool icons = false}) => Center(
      child: SizedBox(
        width: width,
        child: SegmentedControl<int>(
          collapseToIcons: icons,
          options: [
            SegmentOption(
              value: 0,
              label: '全部点位',
              icon: icons ? Symbols.list_rounded : null,
            ),
            SegmentOption(
              value: 1,
              label: '只看待访问',
              icon: icons ? Symbols.flag_rounded : null,
            ),
            SegmentOption(
              value: 2,
              label: '只看已完成',
              icon: icons ? Symbols.check_rounded : null,
            ),
          ],
          value: 1,
          onChanged: (_) {},
        ),
      ),
    );

    testWidgets('lays segments out in a row when they fit', (tester) async {
      await pumpComponent(tester, control(width: 380));
      final a = tester.getCenter(find.text('全部点位'));
      final b = tester.getCenter(find.text('只看待访问'));
      expect(a.dy, closeTo(b.dy, 0.5));
      expect(b.dx, greaterThan(a.dx));
    });

    testWidgets('stacks vertically when too narrow', (tester) async {
      await pumpComponent(tester, control(width: 220), textScale: 1.5);
      expect(tester.takeException(), isNull);
      final a = tester.getCenter(find.text('全部点位'));
      final b = tester.getCenter(find.text('只看待访问'));
      expect(b.dy, greaterThan(a.dy));
      expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
    });

    testWidgets('collapses to icons before stacking', (tester) async {
      await pumpComponent(tester, control(width: 220, icons: true));
      expect(find.text('全部点位'), findsNothing);
      expect(find.byTooltip('只看待访问'), findsOneWidget);
    });

    testWidgets('tapping a segment reports its value', (tester) async {
      int? picked;
      await pumpComponent(
        tester,
        SegmentedControl<int>(
          options: const [
            SegmentOption(value: 0, label: 'A'),
            SegmentOption(value: 1, label: 'B'),
          ],
          value: 0,
          onChanged: (v) => picked = v,
        ),
      );
      await tester.tap(find.text('B'));
      expect(picked, 1);
    });
  });

  group('PhotoCompare', () {
    Future<void> pumpMode(WidgetTester tester, PhotoCompareMode mode) =>
        pumpComponent(
          tester,
          SingleChildScrollView(
            child: PhotoCompare(
              mode: mode,
              reference: _img(const Color(0xFF336699)),
              photo: _img(const Color(0xFF996633)),
            ),
          ),
        );

    for (final mode in PhotoCompareMode.values) {
      testWidgets('renders ${mode.name}', (tester) async {
        await pumpMode(tester, mode);
        expect(tester.takeException(), isNull);
        expect(find.byType(PhotoCompare), findsOneWidget);
        switch (mode) {
          case PhotoCompareMode.stacked:
          case PhotoCompareMode.sideBySide:
            expect(find.text('参考图'), findsOneWidget);
            expect(find.text('巡礼图'), findsOneWidget);
          case PhotoCompareMode.slider:
            expect(find.bySemanticsLabel('滑动对比'), findsWidgets);
          case PhotoCompareMode.overlay:
            expect(find.byType(Slider), findsOneWidget);
        }
      });
    }

    testWidgets('auto mode: stacked on a phone, side by side when wide', (
      tester,
    ) async {
      Widget compare() => SingleChildScrollView(
        child: PhotoCompare(
          showModeSelector: false,
          reference: _img(const Color(0xFF336699)),
          photo: _img(const Color(0xFF996633)),
        ),
      );
      await pumpComponent(tester, compare(), size: const Size(390, 844));
      var ref = tester.getCenter(find.text('参考图'));
      var photo = tester.getCenter(find.text('巡礼图'));
      expect(photo.dy, greaterThan(ref.dy));

      await pumpComponent(tester, compare(), size: const Size(1200, 900));
      await tester.pumpAndSettle();
      ref = tester.getCenter(find.text('参考图'));
      photo = tester.getCenter(find.text('巡礼图'));
      expect(photo.dx, greaterThan(ref.dx));
      expect(photo.dy, closeTo(ref.dy, 0.5));
    });

    testWidgets('per-image tap callbacks fire', (tester) async {
      var tappedPhoto = false;
      await pumpComponent(
        tester,
        SingleChildScrollView(
          child: PhotoCompare(
            mode: PhotoCompareMode.stacked,
            reference: _img(const Color(0xFF336699)),
            photo: _img(const Color(0xFF996633)),
            onTapPhoto: () => tappedPhoto = true,
          ),
        ),
      );
      await tester.tap(find.text('巡礼图'));
      expect(tappedPhoto, isTrue);
    });
  });

  group('Layout primitives', () {
    testWidgets('adaptive column count respects the minimum', (tester) async {
      expect(adaptiveColumnCount(320, minTileWidth: 168), 2);
      expect(adaptiveColumnCount(1200, minTileWidth: 220), 5);
    });

    testWidgets('ListDetailLayout shows one pane below expanded', (
      tester,
    ) async {
      const layout = ListDetailLayout(
        list: Text('LIST'),
        detailPlaceholder: Text('PLACEHOLDER'),
      );
      await pumpComponent(tester, layout, size: const Size(390, 844));
      expect(find.text('LIST'), findsOneWidget);
      expect(find.text('PLACEHOLDER'), findsNothing);

      await pumpComponent(tester, layout, size: const Size(1440, 900));
      expect(find.text('LIST'), findsOneWidget);
      expect(find.text('PLACEHOLDER'), findsOneWidget);
    });
  });
}
