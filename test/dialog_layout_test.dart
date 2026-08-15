import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/widgets/confirm_action_dialog.dart';
import 'package:miriago/widgets/input_dialog.dart';

void main() {
  testWidgets('confirm dialogs fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(1.8),
          ),
          child: const ConfirmActionDialog(
            title: '删除包含很多内容的记录',
            message: '这是一段用于验证小屏幕和较大字体时仍然可以完整滚动查看的说明。',
            confirmLabel: '确认删除',
            cancelLabel: '暂不删除',
            destructive: true,
            additionalContent: SizedBox(height: 220),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂不删除'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final actionButtons = find.descendant(
      of: find.byType(AppDialogActionRow),
      matching: find.byType(FilledButton),
    );
    expect(actionButtons, findsNWidgets(2));
    expect(
      tester.getTopLeft(actionButtons.first).dy,
      closeTo(tester.getTopLeft(actionButtons.last).dy, 0.1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('input dialog accounts for the software keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 560),
            viewInsets: EdgeInsets.only(bottom: 220),
            textScaler: TextScaler.linear(1.5),
          ),
          child: AppInputDialog(
            title: '新建片区',
            content: const SizedBox(height: 300, child: TextField()),
            confirmLabel: '创建',
            onConfirm: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final frame = tester
        .widgetList<ConstrainedBox>(
          find.descendant(
            of: find.byType(AppInputDialog),
            matching: find.byType(ConstrainedBox),
          ),
        )
        .singleWhere((box) => box.constraints.maxWidth == 420);
    expect(frame.constraints.maxHeight, 292);
    final actionButtons = find.descendant(
      of: find.byType(AppDialogActionRow),
      matching: find.byType(FilledButton),
    );
    expect(actionButtons, findsNWidgets(2));
    expect(
      tester.getTopLeft(actionButtons.first).dy,
      closeTo(tester.getTopLeft(actionButtons.last).dy, 0.1),
    );
    expect(tester.takeException(), isNull);
  });
}
