import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/app_theme.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/main.dart';
import 'package:miriago/map/map_colors.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/plan_link_import_screen.dart';
import 'package:miriago/widgets/confirm_action_dialog.dart';

void main() {
  tearDown(AppTheme.light);

  testWidgets('dark dialogs and bottom sheets use the requested base color', (
    tester,
  ) async {
    final theme = AppTheme.dark();
    const base = Color(0xFF121417);
    expect(theme.dialogTheme.backgroundColor, base);
    expect(theme.bottomSheetTheme.backgroundColor, base);
    expect(
      (theme.dialogTheme.shape! as RoundedRectangleBorder).side.color,
      AppColors.border,
    );
    expect(
      (theme.bottomSheetTheme.shape! as RoundedRectangleBorder).side.color,
      AppColors.border,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: ConfirmActionDialog(
            title: '确认操作',
            message: '测试弹窗底色',
            confirmLabel: '确定',
          ),
        ),
      ),
    );
    expect(tester.widget<Dialog>(find.byType(Dialog)).backgroundColor, base);
    expect(
      (tester.widget<Dialog>(find.byType(Dialog)).shape!
              as RoundedRectangleBorder)
          .side
          .color,
      AppColors.border,
    );
    expect(tester.takeException(), isNull);
  });

  test('dark primary buttons keep the standard theme white labels', () {
    final theme = AppTheme.dark();
    final foreground = theme.filledButtonTheme.style!.foregroundColor!.resolve(
      {},
    )!;
    expect(foreground, Colors.white);
    expect(_contrast(foreground, theme.colorScheme.primary), greaterThan(3));
  });

  testWidgets('dark link action has a readable white label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: PlanLinkImportScreen(
          repository: SamplePilgrimageRepository(),
          initialLink: 'https://example.com/plan.sjhplan',
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('读取链接')).style!.color, Colors.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark cancel button uses the requested gray without a border', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: AppDialogActionRow(
            cancelLabel: '取消',
            confirmLabel: '确定',
            onCancel: () {},
            onConfirm: () {},
          ),
        ),
      ),
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '取消'),
    );
    final border = button.style!.side?.resolve({});
    final fill = button.style!.backgroundColor!.resolve({})!;
    expect(border == null || border.style == BorderStyle.none, isTrue);
    expect(fill, const Color(0xFF1C1C1E));
    expect(_contrast(AppColors.textPrimary, fill), greaterThanOrEqualTo(4.5));
  });

  testWidgets('dark map controls have visible borders', (tester) async {
    final repository = SamplePilgrimageRepository();
    await repository.saveAppSettings(
      const AppSettings(themeMode: AppThemeMode.dark),
    );
    await tester.pumpWidget(MiriaGoApp(repository: repository));
    await tester.pumpAndSettle();
    tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .onDestinationSelected!(1);
    await tester.pumpAndSettle();

    final group = tester.widget<Material>(
      find.byKey(const ValueKey('map-group-filter-bar')),
    );
    expect(
      (group.shape! as RoundedRectangleBorder).side.color,
      MapColors.border,
    );
    final layers = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const ValueKey('map-layers-button')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      (layers.shape! as RoundedRectangleBorder).side.color,
      MapColors.border,
    );
    final camera = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .firstWhere((button) => button.tooltip == '拍摄参考');
    expect(camera.style!.side!.resolve({})!.color, MapColors.border);
    expect(
      _contrast(MapColors.border, MapColors.surface),
      greaterThanOrEqualTo(3),
    );
    expect(tester.takeException(), isNull);
  });
}

double _contrast(Color a, Color b) {
  final luminances = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (luminances.last + 0.05) / (luminances.first + 0.05);
}
