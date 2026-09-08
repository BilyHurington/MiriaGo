import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/widgets/app_status_banner.dart';

void main() {
  tearDown(() {
    AppTheme.light();
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
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
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
    expect(statusBannerRunningIcon('正在导出...'), LucideIcons.share2);
    expect(statusBannerRunningIcon('已取消导出'), LucideIcons.circleX);
    expect(statusBannerRunningIcon('正在缓存参考图...'), LucideIcons.refreshCw);
    expect(statusBannerRunningIcon('正在保存记录，请稍候。'), LucideIcons.save);
    expect(statusBannerRunningIcon('正在替换参考图...'), LucideIcons.arrowLeftRight);
    expect(statusBannerRunningIcon('正在读取参考图比例，请稍后拍摄。'), LucideIcons.ratio);
    expect(
      statusBannerRunningIcon('正在清除缓存并重新加载 Anitabi 点位...'),
      LucideIcons.brushCleaning,
    );
    expect(statusBannerRunningIcon('正在导入 12 个点位...'), LucideIcons.mapPinPlus);
    expect(statusBannerRunningIcon('正在缓存缩略图 8/12，成功 7'), LucideIcons.images);
    expect(statusBannerRunningIcon('已取消保存'), LucideIcons.circleX);
    expect(statusBannerRunningIcon('正在处理...'), LucideIcons.hourglass);
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

    expect(find.byIcon(LucideIcons.hourglass), findsOneWidget);
    expect(find.byIcon(LucideIcons.download), findsNothing);
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
            icon: LucideIcons.share2,
          ),
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.share2), findsOneWidget);
    expect(find.byIcon(LucideIcons.download), findsNothing);
  });
}
