import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/settings/reference_cache_cleanup_page.dart';
import 'package:miriago/widgets/confirm_action_dialog.dart';

void main() {
  testWidgets('selection estimates exclude retained and duplicate files', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(824, 1816);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 48);
    addTearDown(tester.view.reset);
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('cache-page-'),
    ))!;
    addTearDown(() => root.delete(recursive: true));
    Future<String> cache(String name, int bytes) async {
      final file = File('${root.path}/reference_full/$name.jpg');
      await file.create(recursive: true);
      await file.writeAsBytes(List.filled(bytes, 1));
      return file.path;
    }

    late List<PilgrimagePlan> plans;
    await tester.runAsync(() async {
      final shared = await cache('shared', 4096);
      final first = await cache('first', 2048);
      final second = await cache('second', 8192);
      final base = samplePilgrimagePlan;
      PilgrimagePoint point(String id, String path) =>
          base.points.first.copyWith(id: id, referenceFullImagePath: path);
      plans = [
        base.copyWith(
          id: 'first',
          name: '示例计划',
          area: '宇治市',
          points: [point('shared-1', shared), point('first', first)],
        ),
        base.copyWith(
          id: 'second',
          name: 'BanGDream（ver0903）',
          area: '东京都',
          points: [point('shared-2', shared), point('second', second)],
        ),
      ];
    });
    final repository = SamplePilgrimageRepository(
      plans: plans,
      visitRecords: [],
    );
    final fontPath = Platform.environment['MIRIAGO_PREVIEW_FONT'];
    if (fontPath != null) {
      await tester.runAsync(() async {
        final loader = FontLoader('CachePreview');
        loader.addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
        await loader.load();
        final icons = FontLoader('packages/lucide_icons_flutter/Lucide');
        icons.addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        );
        await icons.load();
      });
    }
    final boundaryKey = GlobalKey();
    final theme = AppTheme.light();
    await tester.runAsync(
      () => tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: fontPath == null
                ? theme
                : theme.copyWith(
                    textTheme: theme.textTheme.apply(
                      fontFamily: 'CachePreview',
                    ),
                    appBarTheme: theme.appBarTheme.copyWith(
                      titleTextStyle: theme.appBarTheme.titleTextStyle!
                          .copyWith(fontFamily: 'CachePreview'),
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: theme.textButtonTheme.style!.copyWith(
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(fontFamily: 'CachePreview', fontSize: 14),
                        ),
                      ),
                    ),
                    filledButtonTheme: FilledButtonThemeData(
                      style: theme.filledButtonTheme.style!.copyWith(
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(fontFamily: 'CachePreview', fontSize: 16),
                        ),
                      ),
                    ),
                  ),
            home: ReferenceCacheCleanupPage(repository: repository),
          ),
        ),
      ),
    );
    Future<void> settleFileReads() async {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
    }

    await settleFileReads();
    expect(find.text('清理参考图缓存'), findsOneWidget);
    // Nothing is selected until the user chooses: cleaning deletes files.
    expect(find.text('已选 0 个，共 2 个'), findsOneWidget);
    expect(find.text('6 KB'), findsOneWidget);
    expect(find.text('12 KB'), findsOneWidget);
    expect(find.text('0 B'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('清理缓存'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.runAsync(() async {
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '全选'))
          .onPressed!();
    });
    await settleFileReads();
    expect(find.text('已选 2 个，共 2 个'), findsOneWidget);
    expect(find.text('6 KB'), findsOneWidget);
    expect(find.text('12 KB'), findsOneWidget);
    expect(find.text('14 KB'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final selectButton = find.widgetWithText(TextButton, '取消全选');
    final header = find.ancestor(
      of: selectButton,
      matching: find.byType(IntrinsicHeight),
    );
    expect(tester.getSize(selectButton).height, tester.getSize(header).height);
    expect(
      (tester.widget<TextButton>(selectButton).style!.shape!.resolve({})!
              as RoundedRectangleBorder)
          .borderRadius,
      BorderRadius.zero,
    );
    final footer = find.ancestor(
      of: find.text('清理缓存'),
      matching: find.byType(FilledButton),
    );
    expect(tester.getBottomRight(footer).dy, greaterThan(800));

    final screenshot = Platform.environment['MIRIAGO_CACHE_PAGE_SCREENSHOT'];
    Future<void> capture(String suffix) async {
      if (screenshot == null) return;
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$screenshot$suffix',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('');

    await tester.runAsync(() async {
      tester.widget<FilledButton>(footer).onPressed!();
    });
    await settleFileReads();
    expect(find.byType(ConfirmActionDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester
          .widget<ConfirmActionDialog>(find.byType(ConfirmActionDialog))
          .destructive,
      isFalse,
    );
    await capture('.dialog.png');
    tester
        .widget<AppDialogActionRow>(find.byType(AppDialogActionRow))
        .onCancel();
    await tester.pumpAndSettle();

    // Call callbacks directly; no pointer or mouse input is used.
    await tester.runAsync(() async {
      tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged!(false);
    });
    await settleFileReads();
    expect(find.text('已选 1 个，共 2 个'), findsOneWidget);
    expect(find.text('8 KB'), findsOneWidget);
    await tester.runAsync(() async {
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '全选'))
          .onPressed!();
    });
    await settleFileReads();
    expect(find.text('14 KB'), findsOneWidget);
    await tester.runAsync(() async {
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消全选'))
          .onPressed!();
    });
    await settleFileReads();
    expect(find.text('已选 0 个计划'), findsOneWidget);
    expect(find.text('0 B'), findsOneWidget);
    expect(tester.widget<FilledButton>(footer).onPressed, isNull);

    tester.view.physicalSize = const Size(640, 800);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('清理缓存'), findsOneWidget);
  });

  testWidgets('cleanup button follows the theme in dark mode', (tester) async {
    for (final palette in AppThemePalette.values) {
      final theme = AppTheme.dark(palette: palette);
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: theme,
          home: ReferenceCacheCleanupPage(
            repository: SamplePilgrimageRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final style = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      final fill = style.backgroundColor!.resolve({})!;
      final label = style.foregroundColor!.resolve({})!;
      expect(fill, AppColors.accent, reason: '$palette');
      final hi = [
        label,
        fill,
      ].map((c) => c.computeLuminance()).reduce((a, b) => a > b ? a : b);
      final lo = [
        label,
        fill,
      ].map((c) => c.computeLuminance()).reduce((a, b) => a < b ? a : b);
      expect(
        (hi + 0.05) / (lo + 0.05),
        greaterThanOrEqualTo(4.5),
        reason: '$palette',
      );
    }
  });

  testWidgets('a failed usage read can be retried', (tester) async {
    final repository = _FlakyRecordsRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ReferenceCacheCleanupPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(TextButton, '全选'));
    await tester.pumpAndSettle();
    expect(find.text('空间计算失败'), findsOneWidget);
    expect(tester.takeException(), isNull);

    repository.fail = false;
    await tester.tap(find.byKey(const ValueKey('cache-cleanup-retry')));
    await tester.pumpAndSettle();
    expect(find.text('空间计算失败'), findsNothing);
    expect(find.text('可释放约 '), findsOneWidget);
  });

  testWidgets('empty plan list keeps cleanup disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ReferenceCacheCleanupPage(
          repository: SamplePilgrimageRepository(plans: [], visitRecords: []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无计划'), findsOneWidget);
    expect(find.text('0 B'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FlakyRecordsRepository extends SamplePilgrimageRepository {
  var fail = true;

  @override
  Future<List<PilgrimageVisitRecord>> loadVisitRecords(String planId) async {
    if (fail) throw StateError('records unavailable');
    return super.loadVisitRecords(planId);
  }
}
