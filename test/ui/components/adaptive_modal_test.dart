import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/ui/components/components.dart';

import 'harness.dart';

Widget _launcher(Future<void> Function(BuildContext context) onPressed) {
  return Center(
    child: Builder(
      builder: (context) =>
          MiriaButton(label: 'open', onPressed: () => onPressed(context)),
    ),
  );
}

void main() {
  group('showConfirmDialog', () {
    testWidgets('destructive shows the irreversible line and returns true', (
      tester,
    ) async {
      bool? result;
      await pumpComponent(
        tester,
        _launcher((context) async {
          result = await showConfirmDialog(
            context,
            title: '删除计划',
            message: '确定删除「京都之旅」吗？',
            confirmLabel: '删除',
            destructive: true,
            emphasizedValues: const ['京都之旅'],
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('删除计划'), findsOneWidget);
      expect(find.text('此操作无法撤销'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.text('删除计划'), findsNothing);
    });

    testWidgets('non-destructive has no irreversible line; cancel → false', (
      tester,
    ) async {
      bool? result;
      await pumpComponent(
        tester,
        _launcher((context) async {
          result = await showConfirmDialog(
            context,
            title: '设为当前目标',
            message: '继续吗？',
            confirmLabel: '确定',
            notice: '当前目标会显示在巡礼页顶部。',
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('此操作无法撤销'), findsNothing);
      expect(find.text('当前目标会显示在巡礼页顶部。'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('dismissing with the barrier returns false', (tester) async {
      bool? result;
      await pumpComponent(
        tester,
        _launcher((context) async {
          result = await showConfirmDialog(
            context,
            title: 'T',
            message: 'M',
            confirmLabel: '好',
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('checkbox variant returns the checkbox value', (tester) async {
      ConfirmResult? result;
      await pumpComponent(
        tester,
        _launcher((context) async {
          result = await showConfirmDialogWithCheckbox(
            context,
            title: '删除记录',
            message: '确定删除这条巡礼记录吗？',
            confirmLabel: '删除',
            destructive: true,
            checkboxLabel: '同时删除照片文件',
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同时删除照片文件'));
      await tester.pump();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(result, (confirmed: true, checked: true));
    });
  });

  group('showInputDialog', () {
    testWidgets('validates, then returns the trimmed value', (tester) async {
      String? result;
      await pumpComponent(
        tester,
        _launcher((context) async {
          result = await showInputDialog(
            context,
            title: '重命名片区',
            label: '片区名称',
            confirmLabel: '保存',
            validator: (v) => v.isEmpty ? '请输入片区名称' : null,
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(find.text('请输入片区名称'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  宇治  ');
      await tester.pump();
      expect(find.text('请输入片区名称'), findsNothing);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(result, '宇治');
    });
  });

  group('showAdaptiveSheet', () {
    Widget sheetLauncher() => _launcher(
      (context) => showAdaptiveSheet<void>(
        context,
        title: '选择片区',
        builder: (context) => const Text('sheet body'),
      ),
    );

    testWidgets('is a bottom sheet on a phone', (tester) async {
      await pumpComponent(tester, sheetLauncher(), size: const Size(390, 844));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(SheetHandle), findsOneWidget);
    });

    testWidgets('is a centred dialog on desktop', (tester) async {
      await pumpComponent(tester, sheetLauncher(), size: const Size(1440, 900));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final width = tester
          .getSize(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .width;
      expect(width, inInclusiveRange(480, 560));
    });

    testWidgets('is a dialog on a short (landscape) phone', (tester) async {
      await pumpComponent(tester, sheetLauncher(), size: const Size(844, 390));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
    });
  });

  group('showAdaptiveMenu', () {
    testWidgets('touch on a phone uses a bottom action list', (tester) async {
      String? picked;
      await pumpComponent(
        tester,
        _launcher((context) async {
          picked = await showAdaptiveMenu<String>(
            context,
            anchor: context,
            items: const [
              AdaptiveMenuItem(label: '重命名', value: 'rename'),
              AdaptiveMenuItem(label: '删除', value: 'delete', destructive: true),
            ],
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(picked, 'delete');
    });

    testWidgets('anchored on a wide window uses a popup menu', (tester) async {
      await pumpComponent(
        tester,
        _launcher(
          (context) => showAdaptiveMenu<String>(
            context,
            anchor: context,
            items: const [AdaptiveMenuItem(label: '重命名', value: 'rename')],
          ),
        ),
        size: const Size(1440, 900),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byWidgetPredicate((w) => w is PopupMenuItem), findsOneWidget);
    });
  });
}
