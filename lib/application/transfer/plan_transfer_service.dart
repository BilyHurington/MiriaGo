import 'dart:async';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';

import '../../data/pilgrimage_repository.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan_transfer/my_maps_csv_export.dart';
import '../../plan_transfer/plan_export_delivery.dart';
import '../../plan_transfer/plan_export_delivery_result.dart';
import '../../plan_transfer/plan_export_size_estimator.dart';
import '../../plan_transfer/plan_export_v2.dart';
import '../../plan_transfer/plan_import_file_stub.dart'
    if (dart.library.io) '../../plan_transfer/plan_import_file_io.dart'
    as import_file;
import '../../plan_transfer/plan_import_package.dart';
import '../../plan_transfer/plan_import_stream.dart';
import '../../plan_transfer/plan_package.dart'
    show seichiPlanFileExtension, seichiPlanMimeType;
import '../../plan_transfer/plan_transfer_background.dart';
import 'transfer_notice.dart';

/// Accepted types of the import file picker (old `_importFromFile`).
const planImportTypeGroup = file_selector.XTypeGroup(
  label: 'MiriaGo plan package',
  extensions: [seichiPlanFileExtension],
  mimeTypes: [
    miriagoExportPackageMimeType,
    'application/zip',
    'application/x-zip-compressed',
    seichiPlanMimeType,
    'application/octet-stream',
    'application/json',
    'text/json',
    'text/plain',
  ],
);

/// Copy of the iOS 「从其他 App 打开」 help dialog.
abstract final class IosImportHelpCopy {
  static const title = '从其他 App 打开 .sjhplan';
  static const message =
      '请在文件、聊天、浏览器下载页、网盘或其他保存位置找到 .sjhplan 文件，然后点开文件，或使用分享/更多菜单选择 MiriaGo。\n\n'
      'MiriaGo 收到文件后会自动进入导入预览页面。若列表里没有 MiriaGo，可以先把文件保存到“文件”App，再长按文件选择分享或打开方式。';
  static const confirmLabel = '知道了';
}

/// Backend entry points used by [PlanTransferController]; replaceable in
/// tests.
class PlanTransferBackend {
  const PlanTransferBackend({
    this.pickImportFile = _pickImportFile,
    this.estimate = estimatePlanExportV2Size,
    this.buildPackage = _buildPackage,
    this.prepareDestination = preparePlanExportDestination,
    this.deliver = deliverPlanExport,
    this.buildCsv = _buildCsv,
    this.canReadFromPath = import_file.canReadPlanImportFromPath,
    this.readFromPath = import_file.readPlanImportPackageFromPath,
    this.readFromBytes = readPlanImportPackageInBackground,
  });

  final Future<file_selector.XFile?> Function() pickImportFile;
  final Future<PlanExportSizeEstimate> Function({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> visitRecords,
    required PlanExportV2Options options,
  })
  estimate;
  final Future<PlanExportV2Result> Function({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> visitRecords,
    required PlanExportV2Options options,
    required DateTime exportedAt,
    required PlanTransferCancellation cancellation,
  })
  buildPackage;
  final Future<PreparedPlanExportDestination?> Function({
    required String fileName,
    required String mimeType,
    required String extension,
  })
  prepareDestination;
  final Future<PlanExportDeliveryResult> Function({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    required String shareSubject,
    required String shareText,
    required String extension,
    PreparedPlanExportDestination? destination,
  })
  deliver;
  final MyMapsCsvExportResult Function(PilgrimagePlan plan) buildCsv;
  final bool Function(String path) canReadFromPath;
  final Future<PlanImportPackage> Function(
    String path, {
    String? sourceName,
    PlanTransferCancellation? cancellation,
  })
  readFromPath;
  final Future<PlanImportPackage> Function(
    Uint8List bytes, {
    required String sourceName,
    PlanTransferCancellation? cancellation,
  })
  readFromBytes;
}

Future<file_selector.XFile?> _pickImportFile() {
  return file_selector.openFile(
    acceptedTypeGroups: const [planImportTypeGroup],
  );
}

Future<PlanExportV2Result> _buildPackage({
  required PilgrimagePlan plan,
  required List<PilgrimageVisitRecord> visitRecords,
  required PlanExportV2Options options,
  required DateTime exportedAt,
  required PlanTransferCancellation cancellation,
}) {
  return buildPlanExportV2Package(
    plan: plan,
    visitRecords: visitRecords,
    options: options,
    exportedAt: exportedAt,
    cancellation: cancellation,
  );
}

MyMapsCsvExportResult _buildCsv(PilgrimagePlan plan) =>
    buildMyMapsCsvExport(plan: plan);

class _ExportAbortedException implements Exception {
  const _ExportAbortedException();
}

class _ExportRunResult {
  const _ExportRunResult(
    this.delivery, [
    this.warnings = const <String>[],
    this.warningCounts = const <String, int>{},
  ]);

  final PlanExportDeliveryResult delivery;
  final List<String> warnings;
  final Map<String, int> warningCounts;
}

const _cancelledNotice = TransferNotice.running('已取消导出');

/// Import / export state of the 导入导出 page, ported line by line from the
/// old `_ImportExportScreenState`. Every status message goes to [onNotice].
class PlanTransferController extends ChangeNotifier {
  PlanTransferController({
    required this.repository,
    this.backend = const PlanTransferBackend(),
    this.onNotice,
  });

  final PilgrimageRepository repository;
  final PlanTransferBackend backend;

  /// Receives status messages (the page shows them as toasts).
  void Function(TransferNotice notice)? onNotice;

  PlanExportV2Mode _mode = PlanExportV2Mode.planOnly;
  bool _includeFullReferenceCache = false;
  bool _exporting = false;
  bool _importing = false;
  int _exportGeneration = 0;
  int _estimateGeneration = 0;
  PlanExportSizeEstimate? _sizeEstimate;
  bool _estimatingSize = false;
  PlanTransferCancellation? _importCancellation;
  PlanTransferCancellation? _exportCancellation;
  bool _disposed = false;

  PlanExportV2Mode get mode => _mode;
  bool get includeFullReferenceCache => _includeFullReferenceCache;
  bool get exporting => _exporting;
  bool get importing => _importing;
  bool get busy => _exporting || _importing;
  PlanExportSizeEstimate? get sizeEstimate => _sizeEstimate;
  bool get estimatingSize => _estimatingSize;

  PlanExportV2Options get options => PlanExportV2Options(
    mode: _mode,
    includeFullReferenceCache: _includeFullReferenceCache,
  );

  /// 3 states: estimating / estimate / unavailable.
  String get sizeEstimateLabel => _estimatingSize
      ? '正在估算数据包大小...'
      : _sizeEstimate?.label ?? '预计数据包大小：暂时无法估算';

  void setMode(PlanExportV2Mode mode, PilgrimagePlan plan) {
    if (busy || mode == _mode) return;
    _mode = mode;
    _notify();
    unawaited(refreshSizeEstimate(plan));
  }

  void setIncludeFullReferenceCache(bool value, PilgrimagePlan plan) {
    if (busy || value == _includeFullReferenceCache) return;
    _includeFullReferenceCache = value;
    _notify();
    unawaited(refreshSizeEstimate(plan));
  }

  Future<void> refreshSizeEstimate(PilgrimagePlan plan) async {
    final generation = ++_estimateGeneration;
    _estimatingSize = true;
    _notify();
    try {
      final records = _mode == PlanExportV2Mode.planWithRecords
          ? await repository.loadVisitRecords(plan.id)
          : const <PilgrimageVisitRecord>[];
      final estimate = await backend.estimate(
        plan: plan,
        visitRecords: records,
        options: options,
      );
      if (_disposed || generation != _estimateGeneration) return;
      _sizeEstimate = estimate;
      _estimatingSize = false;
      _notify();
    } catch (_) {
      if (_disposed || generation != _estimateGeneration) return;
      _sizeEstimate = null;
      _estimatingSize = false;
      _notify();
    }
  }

  // -------------------------------------------------------------------------
  // Import
  // -------------------------------------------------------------------------

  /// Picks and reads a plan package. Returns null when the user cancelled or
  /// reading failed (the failure is reported through [onNotice]).
  Future<PlanImportPackage?> pickImportPackage() async {
    if (busy) return null;
    final cancellation = PlanTransferCancellation();
    _importCancellation = cancellation;
    _importing = true;
    _notify();
    try {
      final file = await backend.pickImportFile();
      if (file == null) {
        return null;
      }
      if (backend.canReadFromPath(file.path)) {
        // Native pickers hand over a local file: the worker isolate reads it
        // (with the same size limit) instead of receiving a copy of up to
        // 128 MiB from the UI isolate.
        return await backend.readFromPath(
          file.path,
          sourceName: file.name,
          cancellation: cancellation,
        );
      }
      const limits = PlanImportLimits();
      final size = await file.length();
      if (size > limits.maxCompressedBytes) {
        throw PlanImportLimitException(
          '压缩包字节数',
          size,
          limits.maxCompressedBytes,
        );
      }
      final bytes = await readBoundedPlanImportStream(file.openRead());
      if (_disposed || cancellation.isCancelled) {
        return null;
      }
      return await backend.readFromBytes(
        bytes,
        sourceName: file.name,
        cancellation: cancellation,
      );
    } on PlanTransferCancelledException {
      return null;
    } catch (error) {
      if (_disposed) return null;
      _emit(
        TransferNotice.error(
          error is PlanImportLimitException ? error.message : '导入文件读取失败',
        ),
      );
      return null;
    } finally {
      if (identical(_importCancellation, cancellation)) {
        _importCancellation = null;
      }
      _importing = false;
      _notify();
    }
  }

  // -------------------------------------------------------------------------
  // Export
  // -------------------------------------------------------------------------

  /// Exports the MiriaGo data package. [confirmMissingAssets] shows the
  /// 「部分本地资源缺失」 confirmation with the given lines.
  Future<void> exportPackage(
    PilgrimagePlan plan, {
    required Future<bool> Function(List<String> messages) confirmMissingAssets,
  }) {
    return _runExport((generation) async {
      final exportedAt = DateTime.now();
      final exportOptions = options;
      final records = await repository.loadVisitRecords(plan.id);
      if (!_isCurrentExport(generation)) {
        throw const _ExportAbortedException();
      }
      final shouldContinue = await _confirmExportResourceRisks(
        plan: plan,
        records: records,
        options: exportOptions,
        confirm: confirmMissingAssets,
      );
      if (!_isCurrentExport(generation)) {
        throw const _ExportAbortedException();
      }
      if (!shouldContinue) {
        throw const PlanExportCanceledException();
      }
      final fileName = suggestPlanExportV2FileName(
        plan: plan,
        exportedAt: exportedAt,
      );
      final destination = await backend.prepareDestination(
        fileName: fileName,
        mimeType: miriagoExportPackageMimeType,
        extension: seichiPlanFileExtension,
      );
      if (!_isCurrentExport(generation)) {
        throw const _ExportAbortedException();
      }
      final cancellation = PlanTransferCancellation();
      _exportCancellation?.cancel();
      _exportCancellation = cancellation;
      final PlanExportV2Result package;
      try {
        package = await backend.buildPackage(
          plan: plan,
          visitRecords: records,
          options: exportOptions,
          exportedAt: exportedAt,
          cancellation: cancellation,
        );
      } on PlanTransferCancelledException {
        throw const _ExportAbortedException();
      } finally {
        if (identical(_exportCancellation, cancellation)) {
          _exportCancellation = null;
        }
      }
      if (!_isCurrentExport(generation)) {
        throw const _ExportAbortedException();
      }
      final result = await backend.deliver(
        bytes: package.bytes,
        fileName: package.fileName,
        mimeType: miriagoExportPackageMimeType,
        shareSubject: plan.name,
        shareText: 'MiriaGo数据包：${plan.name}',
        extension: seichiPlanFileExtension,
        destination: destination,
      );
      return _ExportRunResult(result, package.warnings, package.warningCounts);
    }, successMessage: '数据包已导出');
  }

  Future<bool> _confirmExportResourceRisks({
    required PilgrimagePlan plan,
    required List<PilgrimageVisitRecord> records,
    required PlanExportV2Options options,
    required Future<bool> Function(List<String> messages) confirm,
  }) async {
    final estimate = await backend.estimate(
      plan: plan,
      visitRecords: records,
      options: options,
    );
    if (!_disposed) {
      _sizeEstimate = estimate;
      _notify();
    }
    if (!estimate.hasMissingCriticalAssets || _disposed) {
      return true;
    }
    return confirm(missingAssetMessages(estimate));
  }

  /// Lines listed in the 「部分本地资源缺失」 confirmation.
  static List<String> missingAssetMessages(PlanExportSizeEstimate estimate) {
    return estimate.detailMessages
        .where(
          (message) =>
              message.contains('本地上传参考图') ||
              message.contains('巡礼照片') ||
              message.contains('调色照片'),
        )
        .toList(growable: false);
  }

  Future<void> exportMyMapsCsv(PilgrimagePlan plan) {
    return _runExport((generation) async {
      final export = backend.buildCsv(plan);
      if (!_isCurrentExport(generation)) {
        throw const _ExportAbortedException();
      }
      final destination = await backend.prepareDestination(
        fileName: export.fileName,
        mimeType: export.mimeType,
        extension: myMapsCsvExtension,
      );
      if (!_isCurrentExport(generation)) {
        throw const _ExportAbortedException();
      }
      final result = await backend.deliver(
        bytes: export.bytes,
        fileName: export.fileName,
        mimeType: export.mimeType,
        shareSubject: plan.name,
        shareText: 'MiriaGo My Maps CSV：${plan.name}',
        extension: myMapsCsvExtension,
        destination: destination,
      );
      return _ExportRunResult(
        result,
        export.skippedPointCount == 0 ? const [] : const ['存在坐标待补充的点位'],
        export.skippedPointCount == 0
            ? const {}
            : {'pendingCoordinate': export.skippedPointCount},
      );
    }, successMessage: 'My Maps CSV 已导出');
  }

  /// Cancels a running export (back navigation). Returns whether an export
  /// was running; 「已取消导出」 is reported through [onNotice].
  bool cancelExport() {
    if (!_exporting) return false;
    _exportGeneration++;
    _exportCancellation?.cancel();
    _exporting = false;
    _notify();
    _emit(_cancelledNotice);
    return true;
  }

  Future<void> _runExport(
    Future<_ExportRunResult> Function(int generation) action, {
    required String successMessage,
  }) async {
    if (busy) return;
    final generation = ++_exportGeneration;
    _exporting = true;
    _notify();
    _emit(const TransferNotice.running('正在导出...'));
    try {
      final result = await action(generation);
      if (!_isCurrentExport(generation)) {
        return;
      }
      if (result.delivery.action == PlanExportDeliveryAction.canceled) {
        _emit(_cancelledNotice);
        return;
      }
      _emit(
        exportResultNotice(
          successMessage,
          delivery: result.delivery,
          warnings: result.warnings,
          warningCounts: result.warningCounts,
        ),
      );
    } on PlanExportCanceledException {
      if (!_isCurrentExport(generation)) {
        return;
      }
      _emit(_cancelledNotice);
    } on _ExportAbortedException {
      return;
    } catch (error, stackTrace) {
      debugPrint('Plan export failed: $error');
      debugPrint(stackTrace.toString());
      if (!_isCurrentExport(generation)) {
        return;
      }
      _emit(const TransferNotice.error('导出失败', message: '请稍后重试'));
    } finally {
      if (_isCurrentExport(generation)) {
        _exporting = false;
        _notify();
      }
    }
  }

  bool _isCurrentExport(int generation) {
    return !_disposed && generation == _exportGeneration;
  }

  void _emit(TransferNotice notice) {
    if (!_disposed) onNotice?.call(notice);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _exportGeneration++;
    _estimateGeneration++;
    _importCancellation?.cancel();
    _exportCancellation?.cancel();
    super.dispose();
  }
}

/// Result toast of an export (old `_PlanExportRunResult.statusSnackBar`).
TransferNotice exportResultNotice(
  String title, {
  required PlanExportDeliveryResult delivery,
  List<String> warnings = const [],
  Map<String, int> warningCounts = const {},
}) {
  if (warnings.isEmpty) {
    return TransferNotice.success(
      title,
      message: switch (delivery.action) {
        PlanExportDeliveryAction.saved => '已保存到本地',
        PlanExportDeliveryAction.shared => '已通过系统分享送出',
        PlanExportDeliveryAction.canceled => null,
      },
    );
  }
  final summary = exportWarningSummary(warningCounts);
  return TransferNotice.warning(
    title,
    message: summary.isEmpty ? '部分资源未能加入' : summary,
  );
}

/// Missing-resource summary by category (old `_warningSummary`).
String exportWarningSummary(Map<String, int> counts) {
  final parts = <String>[];

  void add(PlanExportWarningType type, String label) {
    final count = counts[type.key] ?? 0;
    if (count > 0) {
      parts.add('$count $label');
    }
  }

  add(PlanExportWarningType.userReferenceMissing, '张本地上传参考图缺失');
  add(PlanExportWarningType.thumbnailMissing, '张缩略图未加入');
  add(PlanExportWarningType.fullReferenceDownloadFailed, '张完整参考图下载失败');
  add(PlanExportWarningType.fullReferenceMissing, '张完整参考图缺失');
  add(PlanExportWarningType.visitPhotoMissing, '张巡礼照片缺失');
  add(PlanExportWarningType.gradedPhotoMissing, '张调色照片缺失');
  final pendingCoordinateCount = counts['pendingCoordinate'] ?? 0;
  if (pendingCoordinateCount > 0) {
    parts.add('$pendingCoordinateCount 个坐标待补充点位未导出');
  }

  return parts.isEmpty ? '' : parts.join('，');
}
