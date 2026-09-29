@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:miriago/color_grading/color_grading_params.dart';
import 'package:miriago/color_grading/color_grading_screen.dart';
import 'package:miriago/data/public_http.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';

void main() {
  testWidgets('save panel stays hidden before automatic matching', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late Directory root;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('grading-before-match-');
      await File(
        '${root.path}/photo.png',
      ).writeAsBytes(img.encodePng(img.Image(width: 40, height: 30)));
    });
    addTearDown(() => root.delete(recursive: true));
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final point = plan.points.first;
    final record = await repository.createVisitRecord(
      planId: plan.id,
      pointId: point.id,
      workId: point.work.id,
      photoPath: '${root.path}/photo.png',
      referenceMode: 'overlay',
    );
    final controller = PilgrimagePlanController(
      plan: plan,
      visitRepository: repository,
    );
    addTearDown(controller.dispose);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorGradingScreen(record: record, controller: controller),
        ),
      );
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
    });
    await tester.pump();
    expect(find.text('自动匹配后可保存调色结果'), findsOneWidget);
    expect(find.text('保存结果'), findsNothing);
    expect(find.text('保存调色结果'), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  for (final source in [
    'absent',
    '404',
    'corrupt',
    'over-budget',
    'local-network',
  ]) {
    testWidgets(
      'unavailable reference ($source) preserves saved grading controls',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final previous = HttpOverrides.current;
        HttpOverrides.global = null;
        // The test server is on this device; only 'local-network' checks
        // that such references are refused.
        allowLocalNetworkHostsForTesting = source != 'local-network';
        addTearDown(() => allowLocalNetworkHostsForTesting = false);
        late Directory root;
        late HttpServer server;
        var requests = 0;
        final imageBytes = img.encodePng(img.Image(width: 40, height: 30));
        final oversized = Uint8List.fromList(imageBytes);
        ByteData.sublistView(oversized)
          ..setUint32(16, 8000)
          ..setUint32(20, 6000);
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp(
            'grading-reference-failure-',
          );
          await File('${root.path}/photo.png').writeAsBytes(imageBytes);
          server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          server.listen((request) async {
            requests++;
            if (source == '404') {
              request.response.statusCode = 404;
            } else {
              request.response.add(source == 'corrupt' ? [0, 1, 2] : oversized);
            }
            await request.response.close();
          });
        });
        addTearDown(() async {
          HttpOverrides.global = previous;
          await server.close(force: true);
          await root.delete(recursive: true);
        });
        final repository = SamplePilgrimageRepository();
        final plan = await repository.loadActivePlan();
        final point = plan.points.first;
        final record = await repository.createVisitRecord(
          planId: plan.id,
          pointId: point.id,
          workId: point.work.id,
          photoPath: '${root.path}/photo.png',
          referenceImageUrl: source == 'absent'
              ? null
              : 'http://127.0.0.1:${server.port}/reference.png',
          referenceMode: 'overlay',
        );
        final graded = await repository.updateVisitRecordColorGrading(
          planId: plan.id,
          recordId: record.id,
          originalPhotoPath: record.photoPath,
          gradedPhotoPath: record.photoPath,
          colorGradingMode: 'standard',
          colorGradingParamsJson: jsonEncode(
            const ColorGradingParams().toJson(),
          ),
          colorGradingIntensity: 0.8,
        );
        final controller = PilgrimagePlanController(
          plan: plan,
          visitRepository: repository,
        );
        addTearDown(controller.dispose);
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: ColorGradingScreen(record: graded, controller: controller),
            ),
          );
          for (var i = 0; i < 100; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
            if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
              break;
            }
          }
        });
        await tester.pump();
        expect(
          requests,
          source == 'absent' || source == 'local-network' ? 0 : 1,
        );
        expect(find.byType(Slider), findsOneWidget);
        tester.widget<Slider>(find.byType(Slider)).onChanged!(0.4);
        await tester.pump();
        expect(tester.widget<Slider>(find.byType(Slider)).value, 0.4);
        expect(find.text('保存结果'), findsOneWidget);
        await tester.tap(find.byTooltip('重置'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '重置'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '保存调色结果'));
        await tester.pumpAndSettle();
        final saved = (await repository.loadVisitRecords(
          plan.id,
        )).firstWhere((item) => item.id == record.id);
        expect(saved.hasColorGrading, false);
        expect(File(record.photoPath).readAsBytesSync(), imageBytes);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
