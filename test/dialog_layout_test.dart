import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/plan/coordinate_input_dialog.dart';
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
      tester.getBottomLeft(actionButtons.first).dy,
      lessThan(tester.getTopLeft(actionButtons.last).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('info dialog uses a single confirm action', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(1.4),
          ),
          child: const InfoActionDialog(
            title: '从其他 App 打开 .sjhplan',
            message: '请在文件、聊天、浏览器下载页找到 .sjhplan 文件，然后用 MiriaGo 打开。',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('知道了'), findsOneWidget);
    expect(find.byType(AppDialogActionRow), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(
      find.descendant(
        of: find.byType(InfoActionDialog),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
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
      tester.getBottomLeft(actionButtons.first).dy,
      lessThan(tester.getTopLeft(actionButtons.last).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'coordinate dialog paste sits on the title row and fills fields',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': '35.712576, 139.722166'};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    showCoordinateInputDialog(
                      context: context,
                      current: const LatLng(34, 135),
                    );
                  },
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final paste = find.byKey(const ValueKey('dialog-paste-button'));
      final title = find.text('输入经纬度');
      final firstField = find.byType(TextField).first;
      expect(paste, findsOneWidget);
      expect(
        tester.getCenter(paste).dy,
        closeTo(tester.getCenter(title).dy, 1.0),
      );
      expect(
        tester.getRect(paste).right,
        closeTo(tester.getRect(firstField).right, 0.5),
      );

      await tester.tap(paste);
      await tester.pumpAndSettle();

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].controller?.text, '35.712576');
      expect(fields[1].controller?.text, '139.722166');
    },
  );
}
