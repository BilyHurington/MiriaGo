import 'package:flutter/foundation.dart';

import '../../data/pilgrimage_repository.dart';
import '../../data/reference_asset_paths.dart';
import '../../plan_transfer/plan_import_asset_restore.dart' as restore;
import '../../plan_transfer/plan_import_package.dart';
import 'transfer_notice.dart';

typedef PlanImportAssetRestorer =
    Future<Map<String, String>> Function(
      PlanImportPackage importPackage, {
      required bool includeRecords,
    });

/// What to import from a package and the explanatory copy of each option
/// (ported from `_PlanImportPreviewScreenState`).
@immutable
class PlanImportSelection {
  const PlanImportSelection._({
    required this.package,
    required this.supportsAssetRestore,
    required this.includeRecords,
    required this.includeAssets,
  });

  /// Default selection: records and assets on whenever they are available.
  factory PlanImportSelection.initial(
    PlanImportPackage package, {
    bool? supportsAssetRestore,
  }) {
    final supports =
        supportsAssetRestore ?? restore.supportsPlanImportAssetRestore;
    return PlanImportSelection._(
      package: package,
      supportsAssetRestore: supports,
      includeRecords: package.hasVisitRecords,
      includeAssets: package.hasRestorableAssets && supports,
    );
  }

  final PlanImportPackage package;
  final bool supportsAssetRestore;
  final bool includeRecords;
  final bool includeAssets;

  /// 计划结构 is always imported.
  bool get includePlan => true;

  bool get recordsSelectable => package.hasVisitRecords;

  bool get assetsSelectable =>
      package.hasRestorableAssets && supportsAssetRestore;

  PlanImportSelection withRecords(bool value) => recordsSelectable
      ? PlanImportSelection._(
          package: package,
          supportsAssetRestore: supportsAssetRestore,
          includeRecords: value,
          includeAssets: includeAssets,
        )
      : this;

  PlanImportSelection withAssets(bool value) => assetsSelectable
      ? PlanImportSelection._(
          package: package,
          supportsAssetRestore: supportsAssetRestore,
          includeRecords: includeRecords,
          includeAssets: value,
        )
      : this;

  static const planSubtitle = '作品、片区、点位、完成状态和当前目标。';

  String get recordsSubtitle => package.isLegacyJson
      ? 'v1 文件不包含照片资源，仅导入计划结构。'
      : package.hasVisitRecords
      ? '${package.visitRecordCount} 条记录，包含照片路径和调色参数。'
      : '这个包里没有拍摄记录。';

  String get assetsSubtitle {
    if (!package.hasAssets) {
      return '这个包里没有可恢复的资源文件。';
    }
    if (!package.hasRestorableAssets) {
      return '包内记录了资源，但没有可恢复的资源文件。';
    }
    if (!supportsAssetRestore) {
      return '包内有 ${package.totalAssetCount} 个资源文件；当前平台暂不支持恢复包内资源。';
    }
    return '包内有 ${package.totalAssetCount} 个资源文件，将恢复到本机存储。';
  }

  /// At most 6 「包内提示」.
  List<String> get visibleWarnings =>
      package.warnings.take(6).toList(growable: false);
}

/// Statistic chips of the preview header.
List<({String label, String value})> planImportStats(PlanImportPackage p) {
  final exportedAt = p.exportedAt;
  return [
    (label: '作品', value: '${p.workCount}'),
    (label: '片区', value: '${p.groupCount}'),
    (label: '点位', value: '${p.pointCount}'),
    (label: '记录', value: '${p.visitRecordCount}'),
    (label: '资源', value: '${p.totalAssetCount}'),
    if (p.appVersion != null) (label: '版本', value: p.appVersion!),
    if (exportedAt != null)
      (
        label: '导出',
        value:
            '${exportedAt.year}-${exportedAt.month.toString().padLeft(2, '0')}-${exportedAt.day.toString().padLeft(2, '0')}',
      ),
  ];
}

/// Result of [importSelectedPlanPackage].
@immutable
class PlanImportOutcome {
  const PlanImportOutcome({required this.success, required this.notice});

  final bool success;
  final TransferNotice notice;
}

/// Restores assets → rewrites paths → `importPlanPackage` → finalizes the
/// restored files. On failure, restored files are only removed when that is
/// proven safe (old `_importSelected`).
Future<PlanImportOutcome> importSelectedPlanPackage({
  required PilgrimageRepository repository,
  required PlanImportSelection selection,
  PlanImportAssetRestorer restoreAssets = restore.restorePlanImportAssets,
}) async {
  final package = selection.package;
  final includeRecords = selection.includeRecords;
  Map<String, String> restoredPaths = const {};
  var repositoryAttempted = false;
  var committed = false;
  try {
    restoredPaths = selection.includeAssets
        ? await restoreAssets(package, includeRecords: includeRecords)
        : const <String, String>{};
    final restored = applyRestoredAssetPaths(
      importPackage: package,
      restoredPaths: restoredPaths,
      includeRecords: includeRecords,
    );
    repositoryAttempted = true;
    final importedPlan = await repository.importPlanPackage(
      plan: restored.plan,
      visitRecords: restored.visitRecords,
    );
    committed = true;
    var finalizationFailed = false;
    if (restoredPaths is RestoredPlanImportAssets) {
      try {
        await restoredPaths.finalize();
      } catch (_) {
        finalizationFailed = true;
      }
    }
    final ok = restored.warnings.isEmpty && !finalizationFailed;
    final title = finalizationFailed
        ? '已导入计划「${importedPlan.name}」，资源确认未完成'
        : restored.warnings.isEmpty
        ? '已导入计划「${importedPlan.name}」'
        : '已导入计划「${importedPlan.name}」，部分资源未恢复';
    return PlanImportOutcome(
      success: true,
      notice: ok
          ? TransferNotice.success(title)
          : TransferNotice.warning(title),
    );
  } catch (_) {
    var cleanupIncomplete = false;
    if (!committed && restoredPaths.isNotEmpty) {
      try {
        if (restoredPaths is RestoredPlanImportAssets &&
            (!repositoryAttempted ||
                (restoredPaths.canDiscardAfterRepositoryRead &&
                    await restoredAssetsAreUnreferenced(
                      repository,
                      restoredPaths,
                    )))) {
          await restoredPaths.discard();
        } else {
          cleanupIncomplete = true;
        }
      } catch (_) {
        cleanupIncomplete = true;
      }
    }
    return PlanImportOutcome(
      success: false,
      notice: TransferNotice.error(
        cleanupIncomplete ? '导入未确认完成，已保留资源以避免误删' : '导入失败',
      ),
    );
  }
}

/// An import may commit and then fail while reading its result. Only remove
/// assets if a successful repository read proves they are not referenced.
Future<bool> restoredAssetsAreUnreferenced(
  PilgrimageRepository repository,
  Map<String, String> restoredPaths,
) async {
  final paths = restoredPaths.values.map(normalizeAssetPathSeparators).toSet();
  bool referenced(String? path) =>
      path != null && paths.contains(normalizeAssetPathSeparators(path));
  for (final plan in await repository.loadPlans()) {
    for (final point in plan.points) {
      if (referenced(point.referenceThumbnailPath) ||
          referenced(point.referenceFullImagePath)) {
        return false;
      }
    }
    for (final record in await repository.loadVisitRecords(plan.id)) {
      if (referenced(record.photoPath) ||
          referenced(record.originalPhotoPath) ||
          referenced(record.gradedPhotoPath) ||
          referenced(record.referenceImagePath)) {
        return false;
      }
    }
  }
  return true;
}
