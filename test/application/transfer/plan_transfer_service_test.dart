import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/transfer/plan_transfer_service.dart';
import 'package:miriago/application/transfer/transfer_notice.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/my_maps_csv_export.dart';
import 'package:miriago/plan_transfer/plan_export_delivery_result.dart';
import 'package:miriago/plan_transfer/plan_export_size_estimator.dart';
import 'package:miriago/plan_transfer/plan_export_v2.dart';
import 'package:miriago/plan_transfer/plan_import_package.dart';
import 'package:miriago/plan_transfer/plan_package.dart';
import 'package:miriago/plan_transfer/plan_transfer_background.dart';

PlanExportSizeEstimate _estimate({
  int bytes = 2048,
  int missingUserReferences = 0,
  int missingVisitPhotos = 0,
  int missingThumbnails = 0,
}) => PlanExportSizeEstimate(
  knownBytes: bytes,
  missingFullReferenceCount: 0,
  missingThumbnailCount: missingThumbnails,
  missingUserReferenceCount: missingUserReferences,
  missingVisitPhotoCount: missingVisitPhotos,
  missingGradedPhotoCount: 0,
  hasUnknownLocalAssets: false,
);

class _FakeBackend {
  PlanExportSizeEstimate estimate = _estimate();
  Completer<void>? buildGate;
  Object? buildError;
  PlanExportDeliveryAction deliveryAction = PlanExportDeliveryAction.saved;
  List<String> warnings = const [];
  Map<String, int> warningCounts = const {};
  int builds = 0;
  int deliveries = 0;
  PlanTransferCancellation? lastCancellation;
  file_selector.XFile? pickedFile;
  PlanImportPackage? pathPackage;

  PlanTransferBackend get backend => PlanTransferBackend(
    pickImportFile: () async => pickedFile,
    estimate:
        ({required plan, required visitRecords, required options}) async =>
            estimate,
    buildPackage:
        ({
          required plan,
          required visitRecords,
          required options,
          required exportedAt,
          required cancellation,
        }) async {
          builds++;
          lastCancellation = cancellation;
          final gate = buildGate;
          if (gate != null) {
            await Future.any([gate.future, cancellation.whenCancelled]);
            cancellation.throwIfCancelled();
          }
          if (buildError != null) throw buildError!;
          return PlanExportV2Result(
            bytes: const [1, 2, 3],
            fileName: 'plan.sjhplan',
            warnings: warnings,
            warningCounts: warningCounts,
          );
        },
    prepareDestination:
        ({required fileName, required mimeType, required extension}) async =>
            null,
    deliver:
        ({
          required bytes,
          required fileName,
          required mimeType,
          required shareSubject,
          required shareText,
          required extension,
          destination,
        }) async {
          deliveries++;
          return PlanExportDeliveryResult(deliveryAction);
        },
    buildCsv: (plan) => const MyMapsCsvExportResult(
      bytes: [0x41],
      fileName: 'plan.csv',
      mimeType: myMapsCsvMimeType,
      skippedPointCount: 2,
    ),
    canReadFromPath: (path) => pathPackage != null,
    readFromPath: (path, {sourceName, cancellation}) async => pathPackage!,
    readFromBytes: (bytes, {required sourceName, cancellation}) async =>
        readPlanImportPackageFromBytes(bytes, sourceName: sourceName),
  );
}

void main() {
  late SamplePilgrimageRepository repository;
  late PilgrimagePlan plan;
  late _FakeBackend fake;
  late List<TransferNotice> notices;
  late PlanTransferController controller;

  setUp(() async {
    repository = SamplePilgrimageRepository();
    plan = await repository.loadActivePlan();
    fake = _FakeBackend();
    notices = [];
    controller = PlanTransferController(
      repository: repository,
      backend: fake.backend,
      onNotice: notices.add,
    );
  });

  tearDown(() => controller.dispose());

  test('size estimate has three states', () async {
    expect(controller.sizeEstimateLabel, '预计数据包大小：暂时无法估算');
    final refresh = controller.refreshSizeEstimate(plan);
    expect(controller.estimatingSize, isTrue);
    expect(controller.sizeEstimateLabel, '正在估算数据包大小...');
    await refresh;
    expect(controller.sizeEstimateLabel, '预计数据包大小：约 2.0 KB');
  });

  test('changing options re-estimates', () async {
    controller.setMode(PlanExportV2Mode.planWithRecords, plan);
    expect(controller.mode, PlanExportV2Mode.planWithRecords);
    expect(controller.estimatingSize, isTrue);
    controller.setIncludeFullReferenceCache(true, plan);
    expect(controller.options.includeFullReferenceCache, isTrue);
    await pumpEventQueue();
    expect(controller.estimatingSize, isFalse);
  });

  test('successful export reports progress then the delivery', () async {
    await controller.exportPackage(
      plan,
      confirmMissingAssets: (_) async => fail('no missing assets'),
    );
    expect(notices, const [
      TransferNotice.running('正在导出...'),
      TransferNotice.success('数据包已导出', message: '已保存到本地'),
    ]);
    expect(controller.exporting, isFalse);
    expect(fake.deliveries, 1);
  });

  test('shared delivery message', () async {
    fake.deliveryAction = PlanExportDeliveryAction.shared;
    await controller.exportPackage(
      plan,
      confirmMissingAssets: (_) async => true,
    );
    expect(
      notices.last,
      const TransferNotice.success('数据包已导出', message: '已通过系统分享送出'),
    );
  });

  test('missing critical assets ask first; declining cancels', () async {
    fake.estimate = _estimate(
      missingUserReferences: 2,
      missingVisitPhotos: 1,
      missingThumbnails: 4,
    );
    List<String>? asked;
    await controller.exportPackage(
      plan,
      confirmMissingAssets: (messages) async {
        asked = messages;
        return false;
      },
    );
    expect(asked, ['2 张本地上传参考图文件缺失，导出后无法恢复', '1 张巡礼照片文件缺失']);
    expect(notices.last, const TransferNotice.running('已取消导出'));
    expect(fake.builds, 0);
  });

  test('warnings are summarised by category', () async {
    fake.warnings = const ['x'];
    fake.warningCounts = {
      PlanExportWarningType.thumbnailMissing.key: 3,
      PlanExportWarningType.visitPhotoMissing.key: 1,
    };
    await controller.exportPackage(
      plan,
      confirmMissingAssets: (_) async => true,
    );
    expect(
      notices.last,
      const TransferNotice.warning('数据包已导出', message: '3 张缩略图未加入，1 张巡礼照片缺失'),
    );
  });

  test('user-cancelled delivery reports 已取消导出', () async {
    fake.deliveryAction = PlanExportDeliveryAction.canceled;
    await controller.exportPackage(
      plan,
      confirmMissingAssets: (_) async => true,
    );
    expect(notices.last, const TransferNotice.running('已取消导出'));
  });

  test('back during the build cancels the worker', () async {
    fake.buildGate = Completer<void>();
    final export = controller.exportPackage(
      plan,
      confirmMissingAssets: (_) async => true,
    );
    await pumpEventQueue();
    expect(controller.exporting, isTrue);
    expect(controller.cancelExport(), isTrue);
    expect(fake.lastCancellation!.isCancelled, isTrue);
    await export;
    expect(notices, const [
      TransferNotice.running('正在导出...'),
      TransferNotice.running('已取消导出'),
    ]);
    expect(fake.deliveries, 0);
    expect(controller.exporting, isFalse);
    expect(controller.cancelExport(), isFalse);
  });

  test('failures show 导出失败', () async {
    fake.buildError = StateError('zip');
    await controller.exportPackage(
      plan,
      confirmMissingAssets: (_) async => true,
    );
    expect(notices.last, const TransferNotice.error('导出失败', message: '请稍后重试'));
    expect(controller.exporting, isFalse);
  });

  test('My Maps CSV warns about points without coordinates', () async {
    await controller.exportMyMapsCsv(plan);
    expect(
      notices.last,
      const TransferNotice.warning('My Maps CSV 已导出', message: '2 个坐标待补充点位未导出'),
    );
  });

  test('export warning summary', () {
    expect(exportWarningSummary(const {}), '');
    expect(
      exportWarningSummary({
        PlanExportWarningType.userReferenceMissing.key: 1,
        PlanExportWarningType.fullReferenceDownloadFailed.key: 2,
        PlanExportWarningType.fullReferenceMissing.key: 3,
        PlanExportWarningType.gradedPhotoMissing.key: 4,
      }),
      '1 张本地上传参考图缺失，2 张完整参考图下载失败，3 张完整参考图缺失，4 张调色照片缺失',
    );
    expect(
      exportResultNotice(
        'x',
        delivery: const PlanExportDeliveryResult(
          PlanExportDeliveryAction.saved,
        ),
        warnings: const ['w'],
      ),
      const TransferNotice.warning('x', message: '部分资源未能加入'),
    );
  });

  group('import file', () {
    test('cancelled picker returns null quietly', () async {
      expect(await controller.pickImportPackage(), isNull);
      expect(notices, isEmpty);
      expect(controller.importing, isFalse);
    });

    test('reads a v1 JSON package through the bounded stream', () async {
      final json = PlanPackage(
        plan: plan,
        visitRecords: const [],
      ).toJsonString();
      fake.pickedFile = file_selector.XFile.fromData(
        Uint8List.fromList(utf8.encode(json)),
        name: 'old.sjhplan',
        path: '/virtual/old.sjhplan',
      );
      final package = await controller.pickImportPackage();
      expect(package, isNotNull);
      expect(package!.isLegacyJson, isTrue);
      expect(package.sourceName, 'old.sjhplan');
      expect(package.pointCount, plan.points.length);
    });

    test('invalid files report 导入文件读取失败', () async {
      fake.pickedFile = file_selector.XFile.fromData(
        Uint8List.fromList(utf8.encode('not a plan')),
        name: 'x.sjhplan',
        path: '',
      );
      expect(await controller.pickImportPackage(), isNull);
      expect(notices, const [TransferNotice.error('导入文件读取失败')]);
    });
  });
}
