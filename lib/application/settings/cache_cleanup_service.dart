import 'package:flutter/foundation.dart';

import '../../data/pilgrimage_repository.dart';
import '../../data/reference_cache_cleanup.dart' as cleanup;
import '../../plan/pilgrimage_models.dart';
import 'settings_options.dart';

typedef ReferenceCacheScanner =
    Future<cleanup.ReferenceCacheScan> Function(
      PilgrimageRepository repository,
      List<PilgrimagePlan> plans,
    );

typedef ReferenceCacheCleaner =
    Future<cleanup.ReferenceCacheCleanupResult> Function(
      PilgrimageRepository repository,
      List<PilgrimagePlan> plans,
      void Function(int completed, int total) onProgress,
    );

Future<cleanup.ReferenceCacheScan> _defaultScan(
  PilgrimageRepository repository,
  List<PilgrimagePlan> plans,
) async {
  return cleanup.scanDownloadedReferenceCaches(
    plans,
    retainedPaths: await cleanup.referenceCachePathsInUseElsewhere(
      repository: repository,
      planIds: plans.map((plan) => plan.id),
    ),
  );
}

Future<cleanup.ReferenceCacheCleanupResult> _defaultClean(
  PilgrimageRepository repository,
  List<PilgrimagePlan> plans,
  void Function(int completed, int total) onProgress,
) {
  return cleanup.cleanupDownloadedReferenceCaches(
    repository: repository,
    plans: plans,
    onProgress: onProgress,
  );
}

/// Result of the 「清除下载的参考图缓存」 flow, mapped to toasts by the page.
sealed class CacheCleanupOutcome {
  const CacheCleanupOutcome();
}

/// 「缓存扫描失败」.
class CacheScanFailed extends CacheCleanupOutcome {
  const CacheScanFailed(this.error);
  final Object error;
}

/// 「所选计划没有可清理的下载缓存」.
class CacheNothingToClean extends CacheCleanupOutcome {
  const CacheNothingToClean();
}

/// The user dismissed the confirmation.
class CacheCleanupCancelled extends CacheCleanupOutcome {
  const CacheCleanupCancelled();
}

class CacheCleanupDone extends CacheCleanupOutcome {
  const CacheCleanupDone(this.result);
  final cleanup.ReferenceCacheCleanupResult result;

  bool get hasFailures => result.failedFileCount > 0;

  String get title => '已清理 ${result.deletedFileCount} 个缓存文件';

  String get message => result.failedFileCount == 0
      ? '释放 ${formatByteSize(result.reclaimedBytes)}'
      : '${result.failedFileCount} 个文件清理失败';
}

/// State of the 清除缓存 page: plan list, selection and progress
/// (ported from `_CacheCleanupSettingsPageState`).
class CacheCleanupController extends ChangeNotifier {
  CacheCleanupController({
    required this.repository,
    ReferenceCacheScanner? scanner,
    ReferenceCacheCleaner? cleaner,
  }) : _scan = scanner ?? _defaultScan,
       _clean = cleaner ?? _defaultClean;

  final PilgrimageRepository repository;
  final ReferenceCacheScanner _scan;
  final ReferenceCacheCleaner _clean;

  List<PilgrimagePlan>? _plans;
  Object? _loadError;
  bool _loading = false;
  final Set<String> _selected = <String>{};
  bool _busy = false;
  int _completed = 0;
  int _total = 0;
  bool _disposed = false;

  List<PilgrimagePlan>? get plans => _plans;
  Object? get loadError => _loadError;
  bool get loading => _loading;
  Set<String> get selectedPlanIds => Set.unmodifiable(_selected);
  bool get busy => _busy;
  int get completed => _completed;
  int get total => _total;

  bool isSelected(String planId) => _selected.contains(planId);

  String get selectionSummary =>
      '已选择 ${_selected.length} / ${_plans?.length ?? 0} 个计划';

  String get actionLabel =>
      _busy && _total > 0 ? '正在清理 $_completed / $_total' : '清除下载的参考图缓存';

  bool get canClean => _selected.isNotEmpty && !_busy;

  Future<void> loadPlans() async {
    _loading = true;
    _loadError = null;
    _notify();
    try {
      final plans = await repository.loadPlans();
      _plans = plans;
      _selected.removeWhere((id) => plans.every((plan) => plan.id != id));
    } catch (error) {
      _loadError = error;
      _plans = null;
    } finally {
      _loading = false;
      _notify();
    }
  }

  void toggle(String planId, bool selected) {
    if (selected) {
      _selected.add(planId);
    } else {
      _selected.remove(planId);
    }
    _notify();
  }

  void selectAll() {
    _selected
      ..clear()
      ..addAll((_plans ?? const []).map((plan) => plan.id));
    _notify();
  }

  void clearSelection() {
    _selected.clear();
    _notify();
  }

  /// Scan → (nothing / confirm) → clean with progress. [confirm] receives
  /// the scan and returns whether to proceed.
  Future<CacheCleanupOutcome> run({
    required Future<bool> Function(cleanup.ReferenceCacheScan scan) confirm,
  }) async {
    final plans = (_plans ?? const <PilgrimagePlan>[])
        .where((plan) => _selected.contains(plan.id))
        .toList(growable: false);
    _busy = true;
    _notify();
    final cleanup.ReferenceCacheScan scan;
    try {
      scan = await _scan(repository, plans);
    } on Object catch (error) {
      _busy = false;
      _notify();
      return CacheScanFailed(error);
    }
    _busy = false;
    _notify();
    if (scan.fileCount == 0) {
      return const CacheNothingToClean();
    }
    if (!await confirm(scan) || _disposed) {
      return const CacheCleanupCancelled();
    }
    _busy = true;
    _completed = 0;
    _total = scan.paths.length;
    _notify();
    try {
      final result = await _clean(repository, plans, (completed, total) {
        _completed = completed;
        _total = total;
        _notify();
      });
      await loadPlans();
      return CacheCleanupDone(result);
    } finally {
      _busy = false;
      _completed = 0;
      _total = 0;
      _notify();
    }
  }

  /// Confirmation text of the old dialog.
  static String confirmMessage(cleanup.ReferenceCacheScan scan) =>
      '将删除 ${scan.fileCount} 个下载缓存，约 ${formatByteSize(scan.byteCount)}。'
      '本地上传图片和计划包导入图片不会被删除。';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
