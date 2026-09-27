import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../app_theme.dart' show AppColors;
import '../../records/comparison_export_config.dart';
import '../../records/comparison_export_result.dart';

/// What to export (resolved by the record detail logic).
@immutable
class ComparisonExportRequest {
  const ComparisonExportRequest({
    required this.referenceImagePath,
    required this.referenceImageUrl,
    required this.capturedPath,
    required this.metadata,
    required this.colorGradingSummary,
  });

  final String? referenceImagePath;
  final String? referenceImageUrl;
  final String capturedPath;
  final Map<ComparisonMetadataField, String> metadata;
  final String? colorGradingSummary;
}

enum ComparisonExportOutcomeKind {
  /// Nothing to do (user canceled a save dialog, or export not started).
  none,

  /// A local file was written: open the viewer on [ComparisonExportOutcome.path].
  localFile,

  /// Plain web: handed to the browser download.
  downloaded,

  /// Failed: show [ComparisonExportOutcome.message].
  failed,
}

@immutable
class ComparisonExportOutcome {
  const ComparisonExportOutcome._(this.kind, {this.path, this.message});

  const ComparisonExportOutcome.none()
    : this._(ComparisonExportOutcomeKind.none);
  const ComparisonExportOutcome.localFile(String path)
    : this._(ComparisonExportOutcomeKind.localFile, path: path);
  const ComparisonExportOutcome.downloaded()
    : this._(
        ComparisonExportOutcomeKind.downloaded,
        message: ComparisonExportService.downloadedMessage,
      );
  const ComparisonExportOutcome.failed(String message)
    : this._(ComparisonExportOutcomeKind.failed, message: message);

  final ComparisonExportOutcomeKind kind;
  final String? path;
  final String? message;
}

/// Comparison export settings + export flow, ported line by line from the
/// old `ComparisonExportSheet` (config load, serial saves, export, result
/// mapping).
///
/// [loadConfig] / [saveConfig] are the persistence hooks; the UI wires them
/// to the settings store so other settings are never overwritten.
class ComparisonExportService extends ChangeNotifier {
  ComparisonExportService({
    required this.loadConfig,
    required this.saveConfig,
    this.exporter,
  }) : _config = ComparisonExportConfig.lastUsed;

  static const loadFailedMessage = '读取导出设置失败，请重试。';
  static const saveFailedMessage = '导出设置保存失败，导出时将重试。';
  static const exportFailedMessage = '导出失败，设置或图片未能保存，请重试。';
  static const downloadedMessage = '对比图已交给浏览器下载';

  /// Border colour choices: 白色 / 黑色 / 主题色. The theme colour is the
  /// legacy accent the old exporter stored, so saved configs keep matching.
  static List<Color> get borderColorOptions => <Color>[
    const Color(0xFFFFFFFF),
    const Color(0xFF000000),
    AppColors.accent,
  ];
  static const borderColorLabels = <String>['白色', '黑色', '主题色'];

  static const fixedOutputWidths = [
    ComparisonOutputWidth.w1080,
    ComparisonOutputWidth.w1920,
    ComparisonOutputWidth.w2560,
    ComparisonOutputWidth.w3840,
  ];

  /// Display order of the 「显示内容」 chips.
  static const metadataFieldOrder = [
    ComparisonMetadataField.capturedAt,
    ComparisonMetadataField.pointName,
    ComparisonMetadataField.workTitle,
    ComparisonMetadataField.episodeLabel,
    ComparisonMetadataField.coordinates,
    ComparisonMetadataField.anitabiId,
  ];

  final Future<ComparisonExportConfig> Function() loadConfig;
  final Future<void> Function(ComparisonExportConfig config) saveConfig;
  final ComparisonImageExporter? exporter;

  ComparisonExportConfig _config;
  bool _loading = true;
  bool _settingsLoaded = false;
  bool _exporting = false;
  bool _exiting = false;
  bool _disposed = false;
  Future<void> _settingsWrite = Future.value();

  ComparisonExportConfig get config => _config;
  bool get loading => _loading;
  bool get settingsLoaded => _settingsLoaded;
  bool get exporting => _exporting;
  bool get exiting => _exiting;

  /// Controls are locked while loading, exporting or closing.
  bool get locked => _exporting || !_settingsLoaded || _exiting;

  /// 「导出」 / 「取消」 disabled.
  bool get busy => _exporting || _loading || _exiting;

  /// Loads the saved config; returns an error message on failure.
  Future<String?> load() async {
    if (!_loading) {
      _loading = true;
      notifyListeners();
    }
    try {
      final config = await loadConfig();
      if (_disposed) return null;
      _config = config;
      _settingsLoaded = true;
      ComparisonExportConfig.lastUsed = config;
      return null;
    } catch (_) {
      return loadFailedMessage;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _persist(ComparisonExportConfig config) {
    final write = _settingsWrite.then((_) => saveConfig(config));
    _settingsWrite = write.catchError((Object _) {});
    return write;
  }

  /// Applies [config] immediately and saves it (serially); returns an error
  /// message when the save failed.
  Future<String?> update(ComparisonExportConfig config) async {
    if (locked) return null;
    _config = config;
    ComparisonExportConfig.lastUsed = config;
    notifyListeners();
    try {
      await _persist(config);
      return null;
    } catch (_) {
      return _disposed || _exiting ? null : saveFailedMessage;
    }
  }

  /// Saves the config and exports. The page closes on success
  /// ([exiting] becomes true).
  Future<ComparisonExportOutcome> export(
    ComparisonExportRequest request,
  ) async {
    final exporter = this.exporter;
    if (_disposed || busy || exporter == null) {
      return const ComparisonExportOutcome.none();
    }
    _exporting = true;
    notifyListeners();
    try {
      if (!_settingsLoaded) {
        final error = await load();
        if (error != null) return ComparisonExportOutcome.failed(error);
      }
      if (_disposed || !_settingsLoaded) {
        return const ComparisonExportOutcome.none();
      }
      final config = _config;
      ComparisonExportConfig.lastUsed = config;
      await _persist(config);
      if (_disposed) return const ComparisonExportOutcome.none();
      final result = await exporter(
        referenceImagePath: request.referenceImagePath,
        referenceImageUrl: request.referenceImageUrl,
        capturedPath: request.capturedPath,
        config: config,
        metadata: request.metadata,
        colorGradingSummary: request.colorGradingSummary,
      );
      if (_disposed) return const ComparisonExportOutcome.none();
      if (result.disposition == ComparisonExportDisposition.canceled) {
        return const ComparisonExportOutcome.none();
      }
      if (!result.isSuccess) {
        return ComparisonExportOutcome.failed(failureMessage(result));
      }
      _exporting = false;
      _exiting = true;
      if (result.disposition == ComparisonExportDisposition.localFile &&
          result.path != null) {
        return ComparisonExportOutcome.localFile(result.path!);
      }
      return const ComparisonExportOutcome.downloaded();
    } catch (_) {
      return const ComparisonExportOutcome.failed(exportFailedMessage);
    } finally {
      if (!_exiting) _exporting = false;
      notifyListeners();
    }
  }

  static String failureMessage(ComparisonExportImageResult result) {
    return result.message ??
        switch (result.failureReason) {
          ComparisonExportFailureReason.referenceUnavailable =>
            '参考图不可用，无法导出对比图片。',
          ComparisonExportFailureReason.capturedPhotoUnavailable =>
            '巡礼图不可用，无法导出对比图片。',
          ComparisonExportFailureReason.budgetExceeded => '图片超过处理预算，原件未更改。',
          ComparisonExportFailureReason.unsupportedFormat => '当前平台不支持处理此图片格式。',
          ComparisonExportFailureReason.invalidData => '图片数据无法解码。',
          ComparisonExportFailureReason.renderFailed || null => '导出失败，请稍后重试。',
        };
  }

  /// Label of the border width capsule: 「无」 at 0, else 「x.x%」.
  static String borderWidthLabel(double percent) =>
      percent == 0 ? '无' : '${percent.toStringAsFixed(1)}%';

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
