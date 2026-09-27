import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/transfer/plan_import_service.dart';
import 'package:miriago/application/transfer/transfer_notice.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/plan_export_v2.dart';
import 'package:miriago/plan_transfer/plan_import_package.dart';
import 'package:miriago/plan_transfer/plan_package.dart';

const _png = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
];

const _plan = <String, Object?>{
  'id': 'p',
  'name': '宇治巡礼',
  'area': '京都',
  'works': [
    {'id': 'w'},
  ],
  'points': [
    {'id': 'q', 'workId': 'w'},
  ],
};

const _record = <String, Object?>{
  'id': 'r',
  'planId': 'p',
  'pointId': 'q',
  'workId': 'w',
  'photoPath': '/foreign/photo.jpg',
};

PlanImportPackage _v2({
  Map<String, List<int>> assets = const {},
  List<Map<String, Object?>> records = const [],
  Map<String, Object?> manifest = const {},
}) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.string(
        'manifest.json',
        jsonEncode({
          'format': miriagoExportPackageFormat,
          'packageId': 'pkg',
          ...manifest,
        }),
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'plan.json',
        jsonEncode({'plan': _plan, 'visitRecords': records}),
      ),
    );
  for (final entry in assets.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return readPlanImportPackageFromBytes(
    Uint8List.fromList(ZipEncoder().encode(archive)),
    sourceName: 'test.sjhplan',
  );
}

PlanImportPackage _v1(PilgrimagePlan plan) => readPlanImportPackageFromBytes(
  utf8.encode(PlanPackage(plan: plan, visitRecords: const []).toJsonString()),
  sourceName: 'old.json',
);

class _FailingRepository extends SamplePilgrimageRepository {
  _FailingRepository({required this.commitFirst});

  final bool commitFirst;
  int attempts = 0;

  @override
  Future<PilgrimagePlan> importPlanPackage({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> visitRecords,
  }) async {
    attempts++;
    if (commitFirst) {
      await super.importPlanPackage(plan: plan, visitRecords: visitRecords);
    }
    throw StateError('injected repository failure');
  }
}

/// Restored assets whose paths look like files the import wrote.
class _RestoreRecorder {
  bool discarded = false;
  bool finalized = false;
  bool failFinalize = false;
  bool canDiscardAfterRead = true;

  Future<Map<String, String>> call(
    PlanImportPackage package, {
    required bool includeRecords,
  }) async {
    return RestoredPlanImportAssets(
      {
        for (final path in package.referencedAssetPaths(
          includeRecords: includeRecords,
        ))
          path: '/documents/imported_plan_assets/x/$path',
      },
      canDiscardAfterRepositoryRead: canDiscardAfterRead,
      onDiscard: () async => discarded = true,
      onFinalize: () async {
        if (failFinalize) throw StateError('token');
        finalized = true;
      },
    );
  }
}

void main() {
  group('selection', () {
    test('v1 packages only import the plan structure', () async {
      final plan = await SamplePilgrimageRepository().loadActivePlan();
      final selection = PlanImportSelection.initial(
        _v1(plan),
        supportsAssetRestore: true,
      );
      expect(selection.includePlan, isTrue);
      expect(selection.recordsSelectable, isFalse);
      expect(selection.includeRecords, isFalse);
      expect(selection.recordsSubtitle, 'v1 文件不包含照片资源，仅导入计划结构。');
      expect(selection.assetsSelectable, isFalse);
      expect(selection.assetsSubtitle, '这个包里没有可恢复的资源文件。');
      expect(selection.withRecords(true).includeRecords, isFalse);
    });

    test('records and assets default on when available', () {
      final package = _v2(
        assets: {'assets/photo.png': _png},
        records: [
          {..._record, 'visitPhotoAsset': 'assets/photo.png'},
        ],
        manifest: {
          'assetCounts': {'visitPhotos': 1},
        },
      );
      final selection = PlanImportSelection.initial(
        package,
        supportsAssetRestore: true,
      );
      expect(selection.includeRecords, isTrue);
      expect(selection.recordsSubtitle, '1 条记录，包含照片路径和调色参数。');
      expect(selection.includeAssets, isTrue);
      expect(selection.assetsSubtitle, '包内有 1 个资源文件，将恢复到本机存储。');
      final toggled = selection.withRecords(false).withAssets(false);
      expect(toggled.includeRecords, isFalse);
      expect(toggled.includeAssets, isFalse);
    });

    test('assets are locked where the platform cannot restore them', () {
      final package = _v2(
        assets: {'assets/photo.png': _png},
        manifest: {
          'assetCounts': {'thumbnails': 1},
        },
      );
      final selection = PlanImportSelection.initial(
        package,
        supportsAssetRestore: false,
      );
      expect(selection.includeAssets, isFalse);
      expect(selection.assetsSelectable, isFalse);
      expect(selection.assetsSubtitle, '包内有 1 个资源文件；当前平台暂不支持恢复包内资源。');
      expect(selection.withAssets(true).includeAssets, isFalse);
      expect(selection.recordsSubtitle, '这个包里没有拍摄记录。');
    });

    test('declared but missing assets', () {
      final selection = PlanImportSelection.initial(
        _v2(
          manifest: {
            'assetCounts': {'thumbnails': 2},
          },
        ),
        supportsAssetRestore: true,
      );
      expect(selection.assetsSubtitle, '包内记录了资源，但没有可恢复的资源文件。');
    });

    test('at most six package notes and header stats', () {
      final package = _v2(
        manifest: {
          'warnings': [for (var i = 0; i < 9; i++) 'w$i'],
          'appVersion': '1.1.6+23',
          'exportedAt': '2026-09-03T10:00:00.000',
        },
      );
      final selection = PlanImportSelection.initial(package);
      expect(selection.visibleWarnings.length, lessThanOrEqualTo(6));
      final stats = {
        for (final stat in planImportStats(package)) stat.label: stat.value,
      };
      expect(stats['作品'], '1');
      expect(stats['点位'], '1');
      expect(stats['记录'], '0');
      expect(stats['版本'], '1.1.6+23');
      expect(stats['导出'], '2026-09-03');
    });
  });

  group('import', () {
    test('successful import finalizes restored assets', () async {
      final repository = SamplePilgrimageRepository();
      final before = (await repository.loadPlans()).length;
      final restore = _RestoreRecorder();
      final outcome = await importSelectedPlanPackage(
        repository: repository,
        selection: PlanImportSelection.initial(
          _v2(
            assets: {'assets/photo.png': _png},
            records: [
              {..._record, 'visitPhotoAsset': 'assets/photo.png'},
            ],
          ),
          supportsAssetRestore: true,
        ),
        restoreAssets: restore.call,
      );
      expect(outcome.success, isTrue);
      expect(outcome.notice, const TransferNotice.success('已导入计划「宇治巡礼」'));
      expect(restore.finalized, isTrue);
      expect(restore.discarded, isFalse);
      expect((await repository.loadPlans()).length, before + 1);
    });

    test('finalization failure still counts as imported', () async {
      final restore = _RestoreRecorder()..failFinalize = true;
      final outcome = await importSelectedPlanPackage(
        repository: SamplePilgrimageRepository(),
        selection: PlanImportSelection.initial(
          _v2(
            assets: {'assets/photo.png': _png},
            records: [
              {..._record, 'visitPhotoAsset': 'assets/photo.png'},
            ],
          ),
          supportsAssetRestore: true,
        ),
        restoreAssets: restore.call,
      );
      expect(outcome.success, isTrue);
      expect(outcome.notice.kind, TransferNoticeKind.warning);
      expect(outcome.notice.title, '已导入计划「宇治巡礼」，资源确认未完成');
    });

    test('unconfirmed failure discards only unreferenced assets', () async {
      final restore = _RestoreRecorder();
      final repository = _FailingRepository(commitFirst: false);
      final outcome = await importSelectedPlanPackage(
        repository: repository,
        selection: PlanImportSelection.initial(
          _v2(
            assets: {'assets/photo.png': _png},
            records: [
              {..._record, 'visitPhotoAsset': 'assets/photo.png'},
            ],
          ),
          supportsAssetRestore: true,
        ),
        restoreAssets: restore.call,
      );
      expect(repository.attempts, 1);
      expect(outcome.success, isFalse);
      expect(outcome.notice, const TransferNotice.error('导入失败'));
      expect(restore.discarded, isTrue);
    });

    test('a committed-then-failed import keeps its assets', () async {
      final restore = _RestoreRecorder();
      final repository = _FailingRepository(commitFirst: true);
      final outcome = await importSelectedPlanPackage(
        repository: repository,
        selection: PlanImportSelection.initial(
          _v2(
            assets: {'assets/photo.png': _png},
            records: [
              {..._record, 'visitPhotoAsset': 'assets/photo.png'},
            ],
          ),
          supportsAssetRestore: true,
        ),
        restoreAssets: restore.call,
      );
      expect(outcome.success, isFalse);
      expect(outcome.notice, const TransferNotice.error('导入未确认完成，已保留资源以避免误删'));
      expect(restore.discarded, isFalse);
    });

    test('repositories that cannot prove a clean read keep assets', () async {
      final restore = _RestoreRecorder()..canDiscardAfterRead = false;
      final outcome = await importSelectedPlanPackage(
        repository: _FailingRepository(commitFirst: false),
        selection: PlanImportSelection.initial(
          _v2(
            assets: {'assets/photo.png': _png},
            records: [
              {..._record, 'visitPhotoAsset': 'assets/photo.png'},
            ],
          ),
          supportsAssetRestore: true,
        ),
        restoreAssets: restore.call,
      );
      expect(outcome.notice.title, '导入未确认完成，已保留资源以避免误删');
      expect(restore.discarded, isFalse);
    });

    test('skipping assets never calls the restorer', () async {
      var called = false;
      final selection = PlanImportSelection.initial(
        _v2(assets: {'assets/photo.png': _png}),
        supportsAssetRestore: true,
      ).withAssets(false);
      final outcome = await importSelectedPlanPackage(
        repository: SamplePilgrimageRepository(),
        selection: selection,
        restoreAssets: (package, {required includeRecords}) async {
          called = true;
          return const {};
        },
      );
      expect(called, isFalse);
      expect(outcome.success, isTrue);
    });
  });
}
