import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../color_grading/color_adjustment.dart';
import '../../color_grading/color_grading_params.dart';
import '../../color_grading/graded_photo_reclamation.dart';
import '../../color_grading/graded_photo_storage_stub.dart'
    if (dart.library.io) '../../color_grading/graded_photo_storage_io.dart'
    as storage;
import '../../data/bounded_image_decoder.dart';
import '../../data/pilgrimage_repository.dart';
import '../../plan/pilgrimage_models.dart';
import '../../widgets/bounded_image.dart' show readBoundedImageSource;
import 'record_details.dart';

enum GradingNoticeKind { success, warning, error }

/// A toast the page should show (old status snack).
@immutable
class GradingNotice {
  const GradingNotice(this.kind, this.title);

  final GradingNoticeKind kind;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is GradingNotice && other.kind == kind && other.title == title;

  @override
  int get hashCode => Object.hash(kind, title);

  @override
  String toString() => 'GradingNotice($kind, $title)';
}

/// Result of [ColorGradingService.save].
@immutable
class GradingSaveResult {
  const GradingSaveResult({this.notice, this.popWith, this.pop = false});

  final GradingNotice? notice;

  /// Whether the page should close (returning [popWith]).
  final bool pop;
  final PilgrimageVisitRecord? popWith;
}

/// Plan-controller writes the service needs (injectable for tests).
class GradingRecordWriter {
  const GradingRecordWriter({
    required this.repository,
    required this.update,
    required this.clear,
  });

  final PilgrimageRepository? repository;

  final Future<PilgrimageVisitRecord?> Function({
    required PilgrimageVisitRecord record,
    required String originalPhotoPath,
    required String gradedPhotoPath,
    required String colorGradingMode,
    required String colorGradingParamsJson,
    required double colorGradingIntensity,
  })
  update;

  final Future<PilgrimageVisitRecord?> Function({
    required PilgrimageVisitRecord record,
  })
  clear;
}

typedef GradingImageReader = Future<Uint8List> Function(String path);
typedef GradingAutoMatch =
    Future<ColorMatchResult?> Function({
      required Uint8List capturedBytes,
      required Uint8List referenceBytes,
      required ColorMatchMode mode,
    });
typedef GradingRender =
    Future<Uint8List> Function({
      required Uint8List imageBytes,
      required ColorGradingParams params,
    });
typedef GradedPhotoSaver =
    Future<String?> Function({
      required Uint8List bytes,
      required String recordId,
    });

/// State and flows of the 自动调色 page, ported line by line from the old
/// `ColorGradingScreen`.
class ColorGradingService extends ChangeNotifier {
  ColorGradingService({
    required this.record,
    required this.writer,
    this.fallbackReferenceImagePath,
    this.fallbackReferenceImageUrl,
    GradingImageReader? readImage,
    Future<void> Function(Uint8List bytes)? probe,
    this.sourcePhotoPath = RecordDetails.sourcePhotoPath,
    this.autoMatch = autoMatchColorTone,
    this.renderJpeg = renderGradedJpeg,
    this.saveGradedPhoto = storage.saveGradedPhoto,
  }) : _readImage = readImage ?? ((path) => readBoundedImageSource(path)),
       _probe = probe ?? ((bytes) async => probeBoundedImage(bytes)) {
    _restoreSavedGrading();
  }

  final GradingRecordWriter writer;
  final String? fallbackReferenceImagePath;
  final String? fallbackReferenceImageUrl;
  final GradingImageReader _readImage;
  final Future<void> Function(Uint8List bytes) _probe;
  final String? Function(PilgrimageVisitRecord record) sourcePhotoPath;
  final GradingAutoMatch autoMatch;
  final GradingRender renderJpeg;
  final GradedPhotoSaver saveGradedPhoto;

  /// The record being graded (as it was when the page opened).
  final PilgrimageVisitRecord record;
  bool _loading = true;
  bool _matching = false;
  bool _saving = false;
  bool _showOriginal = false;
  double _intensity = 1.0;
  ColorMatchMode _selectedMode = ColorMatchMode.standard;
  Uint8List? _capturedBytes;
  Uint8List? _referenceBytes;
  ColorGradingParams? _targetParams;
  int? _beforeScore;
  int? _afterScore;
  Object? _loadError;
  Object? _referenceError;
  bool _resetPending = false;
  bool _disposed = false;

  bool get loading => _loading;
  bool get matching => _matching;
  bool get saving => _saving;
  bool get showOriginal => _showOriginal;
  double get intensity => _intensity;
  ColorMatchMode get selectedMode => _selectedMode;
  Uint8List? get capturedBytes => _capturedBytes;
  Uint8List? get referenceBytes => _referenceBytes;
  ColorGradingParams? get targetParams => _targetParams;
  bool get hasParams => _targetParams != null;
  int? get beforeScore => _beforeScore;
  int? get afterScore => _afterScore;
  Object? get loadError => _loadError;
  Object? get referenceError => _referenceError;
  bool get resetPending => _resetPending;

  /// Whether the preview shows the untouched photo.
  bool get previewShowsOriginal => _showOriginal || _targetParams == null;

  ColorGradingParams get activeParams {
    return ColorGradingParams.lerp(
      ColorGradingParams.defaults,
      _targetParams ?? ColorGradingParams.defaults,
      _intensity,
    );
  }

  int? get currentToneScore {
    final before = _beforeScore;
    final after = _afterScore;
    if (before == null || after == null) {
      return null;
    }
    return (before + (after - before) * _intensity).round().clamp(0, 100);
  }

  void _restoreSavedGrading() {
    final savedMode = record.colorGradingMode;
    if (savedMode != null) {
      _selectedMode = ColorMatchMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => ColorMatchMode.standard,
      );
    }

    _intensity = (record.colorGradingIntensity ?? 1).clamp(0.0, 1.0);
    final paramsJson = record.colorGradingParamsJson;
    if (paramsJson == null || paramsJson.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(paramsJson);
      if (decoded is Map<String, Object?>) {
        _targetParams = ColorGradingParams.fromJson(decoded);
      }
    } catch (_) {}
  }

  Future<void> load() async {
    try {
      final sourcePath = sourcePhotoPath(record);
      if (sourcePath == null) {
        throw StateError('Visit record photo is unavailable');
      }
      final capturedBytes = await _readImage(sourcePath);
      await _probe(capturedBytes);
      Uint8List? referenceBytes;
      Object? referenceError;
      try {
        referenceBytes = await _loadReferenceBytes();
        if (referenceBytes != null) await _probe(referenceBytes);
      } catch (error) {
        // A missing reference disables matching, not edits to saved grading.
        referenceBytes = null;
        referenceError = error;
      }
      if (_disposed) return;
      _capturedBytes = capturedBytes;
      _referenceBytes = referenceBytes;
      _referenceError = referenceError;
      _loading = false;
      notifyListeners();
    } catch (error) {
      if (_disposed) return;
      _loadError = error;
      _loading = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> _loadReferenceBytes() async {
    for (final path in [
      record.referenceImagePath,
      fallbackReferenceImagePath,
    ].whereType<String>()) {
      try {
        return await _readImage(path);
      } on ImageBudgetException {
        rethrow;
      } catch (_) {
        // Missing local references may still have their original remote source.
      }
    }

    final url = record.referenceImageUrl ?? fallbackReferenceImageUrl;
    if (url == null || url.isEmpty) {
      return null;
    }
    return _readImage(url);
  }

  void setShowOriginal(bool value) {
    if (value && _targetParams == null) return;
    if (_showOriginal == value) return;
    _showOriginal = value;
    notifyListeners();
  }

  void setIntensity(double value) {
    _intensity = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Changing the mode clears the parameters (old behaviour).
  void selectMode(ColorMatchMode mode) {
    _selectedMode = mode;
    _targetParams = null;
    _beforeScore = null;
    _afterScore = null;
    _intensity = 1.0;
    _resetPending = false;
    notifyListeners();
  }

  /// 「重置」 after confirmation.
  void reset() {
    _targetParams = null;
    _beforeScore = null;
    _afterScore = null;
    _intensity = 1.0;
    _showOriginal = false;
    _resetPending = record.hasColorGrading;
    notifyListeners();
  }

  /// Runs automatic matching; returns the toast to show (null = none).
  Future<GradingNotice?> runAutoMatch() async {
    if (_disposed || _matching || _saving) return null;
    try {
      return await _runAutoMatchUnchecked();
    } catch (error) {
      return GradingNotice(
        GradingNoticeKind.error,
        error is ImageBudgetException ? error.message : '自动调色失败',
      );
    } finally {
      if (!_disposed && _matching) {
        _matching = false;
        notifyListeners();
      }
    }
  }

  Future<GradingNotice?> _runAutoMatchUnchecked() async {
    final captured = _capturedBytes;
    final reference = _referenceBytes;
    if (captured == null) {
      return const GradingNotice(GradingNoticeKind.error, '巡礼图读取失败');
    }
    if (reference == null) {
      final error = _referenceError;
      return GradingNotice(
        GradingNoticeKind.warning,
        error is ImageBudgetException
            ? error.message
            : error == null
            ? '没有可用于自动调色的参考图'
            : '参考图暂不可用，无法自动匹配色调',
      );
    }

    _matching = true;
    notifyListeners();
    final result = await autoMatch(
      capturedBytes: captured,
      referenceBytes: reference,
      mode: _selectedMode,
    );
    if (_disposed) return null;

    _matching = false;
    if (result != null) {
      _targetParams = result.targetParams;
      _selectedMode = result.mode;
      _beforeScore = result.beforeScore;
      _afterScore = result.afterScore;
      _intensity = 1.0;
      _resetPending = false;
    }
    notifyListeners();

    return result == null
        ? const GradingNotice(GradingNoticeKind.error, '自动调色失败')
        : const GradingNotice(GradingNoticeKind.success, '已生成自动调色参数');
  }

  /// Saves (or restores the original after a reset).
  Future<GradingSaveResult> save() async {
    if (_disposed || _saving || _matching) return const GradingSaveResult();
    try {
      return await _saveUnchecked();
    } catch (error) {
      return GradingSaveResult(
        notice: GradingNotice(
          GradingNoticeKind.error,
          error is ImageBudgetException ? error.message : '保存失败，原件未更改',
        ),
      );
    } finally {
      if (!_disposed && _saving) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  Future<GradingSaveResult> _saveUnchecked() async {
    final captured = _capturedBytes;
    final targetParams = _targetParams;
    if (captured == null || _saving) {
      return const GradingSaveResult();
    }
    if (_resetPending) {
      _saving = true;
      notifyListeners();
      final updated = await clearGradedPhoto(
        repository: writer.repository,
        previousGradedPath: record.gradedPhotoPath,
        clear: () => writer.clear(record: record),
      );
      if (_disposed) return const GradingSaveResult();
      _saving = false;
      notifyListeners();
      return GradingSaveResult(
        notice: const GradingNotice(GradingNoticeKind.success, '已还原为原图'),
        pop: true,
        popWith: updated,
      );
    }
    if (targetParams == null) {
      return const GradingSaveResult(
        notice: GradingNotice(GradingNoticeKind.warning, '请先自动匹配色调'),
      );
    }

    _saving = true;
    notifyListeners();
    final bytes = await renderJpeg(imageBytes: captured, params: activeParams);
    final path = await saveGradedPhoto(bytes: bytes, recordId: record.id);
    if (path == null) {
      if (_disposed) return const GradingSaveResult();
      _saving = false;
      notifyListeners();
      return const GradingSaveResult(
        notice: GradingNotice(GradingNoticeKind.error, '保存失败'),
      );
    }

    final updated = await commitGradedPhoto(
      repository: writer.repository,
      newGradedPath: path,
      previousGradedPath: record.gradedPhotoPath,
      update: () => writer.update(
        record: record,
        originalPhotoPath: sourcePhotoPath(record) ?? record.sourcePhotoPath,
        gradedPhotoPath: path,
        colorGradingMode: _selectedMode.name,
        colorGradingParamsJson: jsonEncode(targetParams.toJson()),
        colorGradingIntensity: _intensity,
      ),
    );
    if (_disposed) return const GradingSaveResult();
    _saving = false;
    notifyListeners();
    return GradingSaveResult(
      notice: const GradingNotice(GradingNoticeKind.success, '已保存调色结果'),
      pop: true,
      popWith: updated,
    );
  }

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

/// The 17 parameters of the 「调色参数」 sheet with their ranges.
@immutable
class GradingParameterItem {
  const GradingParameterItem(this.label, this.value, this.min, this.max);

  final String label;
  final double value;
  final double min;
  final double max;

  double get fraction =>
      ((value - min) / (max - min)).clamp(0.0, 1.0).toDouble();
}

List<GradingParameterItem> gradingParameterItems(ColorGradingParams p) => [
  GradingParameterItem('亮度', p.brightness, -0.25, 0.25),
  GradingParameterItem('曝光', p.exposure, -1.0, 1.0),
  GradingParameterItem('对比度', p.contrast, 0.7, 1.4),
  GradingParameterItem('饱和度', p.saturation, 0.5, 1.6),
  GradingParameterItem('色温', p.temperature, -1.0, 1.0),
  GradingParameterItem('色调', p.tint, -1.0, 1.0),
  GradingParameterItem('高光', p.highlights, -1.0, 1.0),
  GradingParameterItem('阴影', p.shadows, -1.0, 1.0),
  GradingParameterItem('红暗部曲线', p.redShadowCurve, -1.0, 1.0),
  GradingParameterItem('红中间调曲线', p.redMidCurve, -1.0, 1.0),
  GradingParameterItem('红高光曲线', p.redHighlightCurve, -1.0, 1.0),
  GradingParameterItem('绿暗部曲线', p.greenShadowCurve, -1.0, 1.0),
  GradingParameterItem('绿中间调曲线', p.greenMidCurve, -1.0, 1.0),
  GradingParameterItem('绿高光曲线', p.greenHighlightCurve, -1.0, 1.0),
  GradingParameterItem('蓝暗部曲线', p.blueShadowCurve, -1.0, 1.0),
  GradingParameterItem('蓝中间调曲线', p.blueMidCurve, -1.0, 1.0),
  GradingParameterItem('蓝高光曲线', p.blueHighlightCurve, -1.0, 1.0),
];
