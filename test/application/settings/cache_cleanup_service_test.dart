import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/settings/cache_cleanup_service.dart';
import 'package:miriago/application/settings/settings_reset.dart';
import 'package:miriago/application/settings_store.dart';
import 'package:miriago/data/reference_cache_cleanup.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/records/comparison_export_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CacheCleanupController', () {
    late SamplePilgrimageRepository repository;
    setUp(() => repository = SamplePilgrimageRepository());

    CacheCleanupController controller({
      ReferenceCacheScan scan = const ReferenceCacheScan(
        fileCount: 0,
        byteCount: 0,
        paths: {},
      ),
      Object? scanError,
      int failed = 0,
    }) {
      return CacheCleanupController(
        repository: repository,
        scanner: (repo, plans) async {
          if (scanError != null) throw scanError;
          return scan;
        },
        cleaner: (repo, plans, onProgress) async {
          for (var i = 1; i <= scan.fileCount; i++) {
            onProgress(i, scan.fileCount);
          }
          return ReferenceCacheCleanupResult(
            deletedFileCount: scan.fileCount - failed,
            reclaimedBytes: scan.byteCount,
            failedFileCount: failed,
          );
        },
      );
    }

    test('selection helpers and labels', () async {
      final c = controller();
      await c.loadPlans();
      final plans = c.plans!;
      expect(plans, isNotEmpty);
      expect(c.canClean, isFalse);
      expect(c.selectionSummary, '已选择 0 / ${plans.length} 个计划');
      c.selectAll();
      expect(c.selectedPlanIds, hasLength(plans.length));
      c.toggle(plans.first.id, false);
      expect(c.isSelected(plans.first.id), isFalse);
      c.clearSelection();
      expect(c.selectedPlanIds, isEmpty);
      expect(c.actionLabel, '清除下载的参考图缓存');
    });

    test('nothing to clean skips the confirmation', () async {
      final c = controller();
      await c.loadPlans();
      c.selectAll();
      var asked = false;
      final outcome = await c.run(
        confirm: (_) async {
          asked = true;
          return true;
        },
      );
      expect(outcome, isA<CacheNothingToClean>());
      expect(asked, isFalse);
      expect(c.busy, isFalse);
    });

    test('scan failures are reported', () async {
      final c = controller(scanError: StateError('disk'));
      await c.loadPlans();
      c.selectAll();
      final outcome = await c.run(confirm: (_) async => true);
      expect(outcome, isA<CacheScanFailed>());
      expect(c.busy, isFalse);
    });

    test('declining keeps the files', () async {
      final c = controller(
        scan: const ReferenceCacheScan(
          fileCount: 3,
          byteCount: 2048,
          paths: {'a', 'b', 'c'},
        ),
      );
      await c.loadPlans();
      c.selectAll();
      String? message;
      final outcome = await c.run(
        confirm: (scan) async {
          message = CacheCleanupController.confirmMessage(scan);
          return false;
        },
      );
      expect(outcome, isA<CacheCleanupCancelled>());
      expect(message, '将删除 3 个下载缓存，约 2.0 KB。本地上传图片和计划包导入图片不会被删除。');
    });

    test('cleaning reports progress and the result', () async {
      final c = controller(
        scan: const ReferenceCacheScan(
          fileCount: 2,
          byteCount: 3 * 1024 * 1024,
          paths: {'a', 'b'},
        ),
      );
      await c.loadPlans();
      c.selectAll();
      final labels = <String>[];
      c.addListener(() => labels.add(c.actionLabel));
      final outcome = await c.run(confirm: (_) async => true);
      expect(labels, contains('正在清理 1 / 2'));
      expect(labels, contains('正在清理 2 / 2'));
      expect(outcome, isA<CacheCleanupDone>());
      final done = outcome as CacheCleanupDone;
      expect(done.title, '已清理 2 个缓存文件');
      expect(done.message, '释放 3.0 MB');
      expect(done.hasFailures, isFalse);
      expect(c.busy, isFalse);
      expect(c.actionLabel, '清除下载的参考图缓存');
    });

    test('partial failures are summarised', () async {
      final c = controller(
        scan: const ReferenceCacheScan(
          fileCount: 3,
          byteCount: 10,
          paths: {'a', 'b', 'c'},
        ),
        failed: 1,
      );
      await c.loadPlans();
      c.selectAll();
      final done = await c.run(confirm: (_) async => true) as CacheCleanupDone;
      expect(done.title, '已清理 2 个缓存文件');
      expect(done.message, '1 个文件清理失败');
      expect(done.hasFailures, isTrue);
    });
  });

  test(
    'restoring defaults saves AppSettings() and resets the export config',
    () async {
      final repository = SamplePilgrimageRepository();
      await repository.saveAppSettings(
        const AppSettings(mapMaxZoom: 17, valhallaBaseUrl: 'https://x.org'),
      );
      final store = SettingsStore(repository: repository);
      await store.load();
      ComparisonExportConfig.lastUsed = const ComparisonExportConfig(
        showLabels: true,
      );
      var cleared = false;
      await resetAppSettingsToDefaults(
        store,
        clearExportConfig: () async => cleared = true,
      );
      expect(cleared, isTrue);
      expect(store.settings.mapMaxZoom, 22);
      final saved = await repository.loadAppSettings();
      expect(saved.valhallaBaseUrl, const AppSettings().valhallaBaseUrl);
      expect(ComparisonExportConfig.lastUsed.showLabels, isFalse);
    },
  );
}
