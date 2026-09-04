import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/widgets/app_status_banner.dart';
import 'package:miriago/widgets/status_snack_samples.dart';

void main() {
  tearDown(() {
    AppTheme.light();
  });

  test('status snack catalog covers every banner kind', () {
    expect(statusSnackDebugSamples, isNotEmpty);
    expect(
      statusSnackDebugSamples.map((sample) => sample.kind).toSet(),
      AppStatusBannerKind.values.toSet(),
    );
    expect(
      statusSnackDebugSamples.any(
        (sample) => sample.title == '正在缓存参考图...' && sample.hasProgress,
      ),
      isTrue,
    );
  });

  test('running catalog samples use distinct fitting icons', () {
    final running = statusSnackDebugSamples
        .where((sample) => sample.kind == AppStatusBannerKind.running)
        .toList();
    expect(running, isNotEmpty);
    expect(running.every((sample) => sample.icon != null), isTrue);
    expect(running.map((sample) => sample.icon).toSet().length, 9);
    expect(
      running.any((sample) => sample.icon == Icons.download_rounded),
      isFalse,
    );

    IconData? iconFor(String title) =>
        running.firstWhere((sample) => sample.title == title).icon;
    expect(iconFor('正在导出...'), Icons.ios_share_outlined);
    expect(iconFor('已取消导出'), Icons.cancel_outlined);
    expect(iconFor('正在缓存参考图...'), Icons.cached_outlined);
    expect(iconFor('正在保存记录，请稍候。'), Icons.save_outlined);
    expect(iconFor('正在替换参考图...'), Icons.swap_horiz_outlined);
    expect(iconFor('正在读取参考图比例，请稍后拍摄。'), Icons.aspect_ratio_outlined);
    expect(
      iconFor('正在清除缓存并重新加载 Anitabi 点位...'),
      Icons.cleaning_services_outlined,
    );
    expect(iconFor('正在导入 12 个点位...'), Icons.add_location_alt_outlined);
    expect(iconFor('正在缓存缩略图 8/12，成功 7'), Icons.photo_library_outlined);
    expect(iconFor('已取消保存'), Icons.cancel_outlined);
  });

  test('dark mode status banners use opaque fills', () {
    AppTheme.dark();
    for (final kind in AppStatusBannerKind.values) {
      final palette = AppStatusBannerPalette.of(kind);
      expect(
        palette.background.a,
        1.0,
        reason: '$kind background should be opaque',
      );
    }
  });

  testWidgets('export snack uses the status banner layout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    appStatusSnackBar(
                      kind: AppStatusBannerKind.success,
                      title: '数据包已导出',
                      subtitle: '已保存到本地',
                    ),
                  );
                },
                child: const Text('export'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('export'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('数据包已导出'), findsOneWidget);
    expect(find.text('已保存到本地'), findsOneWidget);
    expect(find.byType(AppStatusBanner), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  test('single-sentence status titles drop the trailing period', () {
    expect(statusBannerSentence('已添加「声之形」。'), '已添加「声之形」');
    expect(statusBannerSentence('已填入坐标。'), '已填入坐标');
    expect(statusBannerSentence('保存计划顺序失败，已恢复原来的顺序。'), '保存计划顺序失败，已恢复原来的顺序');
    expect(statusBannerSentence('数据包已导出'), '数据包已导出');
    expect(statusBannerSentence('失败。请稍后重试。'), '失败。请稍后重试。');
  });

  testWidgets('single-sentence snack hides the trailing period', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppStatusBanner(
            kind: AppStatusBannerKind.success,
            title: '已添加「声之形」。',
          ),
        ),
      ),
    );

    expect(find.text('已添加「声之形」'), findsOneWidget);
    expect(find.text('已添加「声之形」。'), findsNothing);
  });

  test('running titles infer distinct action icons', () {
    expect(statusBannerRunningIcon('正在导出...'), Icons.ios_share_outlined);
    expect(statusBannerRunningIcon('已取消导出'), Icons.cancel_outlined);
    expect(statusBannerRunningIcon('正在缓存参考图...'), Icons.cached_outlined);
    expect(statusBannerRunningIcon('正在保存记录，请稍候。'), Icons.save_outlined);
    expect(statusBannerRunningIcon('正在替换参考图...'), Icons.swap_horiz_outlined);
    expect(
      statusBannerRunningIcon('正在读取参考图比例，请稍后拍摄。'),
      Icons.aspect_ratio_outlined,
    );
    expect(
      statusBannerRunningIcon('正在清除缓存并重新加载 Anitabi 点位...'),
      Icons.cleaning_services_outlined,
    );
    expect(
      statusBannerRunningIcon('正在导入 12 个点位...'),
      Icons.add_location_alt_outlined,
    );
    expect(
      statusBannerRunningIcon('正在缓存缩略图 8/12，成功 7'),
      Icons.photo_library_outlined,
    );
    expect(statusBannerRunningIcon('已取消保存'), Icons.cancel_outlined);
    expect(statusBannerRunningIcon('正在处理...'), Icons.hourglass_top_outlined);
  });

  testWidgets('unknown running banner uses an hourglass instead of download', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppStatusBanner(
            kind: AppStatusBannerKind.running,
            title: '正在处理...',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.hourglass_top_outlined), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });

  testWidgets('running banner renders a custom icon when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppStatusBanner(
            kind: AppStatusBannerKind.running,
            title: '正在导出...',
            icon: Icons.ios_share_outlined,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });

  testWidgets('export debug preview shows all package export states', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () => showPlanExportBannerDebugPreview(context),
                  child: const Text('export-package'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('export-package'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('plan-export-debug-running')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-export-debug-canceled')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-export-debug-success')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-export-debug-warning')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-export-debug-failed')),
      findsOneWidget,
    );
    expect(find.text('正在导出...'), findsOneWidget);
    expect(find.text('已取消导出'), findsOneWidget);
    expect(find.text('数据包已导出'), findsNWidgets(2));
    expect(find.text('导出失败'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-export-debug-running')),
        matching: find.byIcon(Icons.ios_share_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-export-debug-canceled')),
        matching: find.byIcon(Icons.cancel_outlined),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.download_rounded), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('plan-export-debug-running')),
      findsNothing,
    );
  });
}
