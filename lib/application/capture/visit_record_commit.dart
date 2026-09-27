import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../camera_reference/auto_comparison_gallery_backup.dart';
import '../../camera_reference/photo_location.dart';
import '../../camera_reference/photo_location_save_stub.dart'
    if (dart.library.io) '../../camera_reference/photo_location_save_io.dart'
    as photo_location_save;
import '../../camera_reference/visit_record_save_assets.dart';
import '../../data/pilgrimage_repository.dart';
import '../../map/current_location_resolver.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan/pilgrimage_plan_controller.dart';
import '../../records/gallery_saver_stub.dart'
    if (dart.library.io) '../../records/gallery_saver_io.dart';
import '../../widgets/reference_image_source_stub.dart'
    if (dart.library.io) '../../widgets/reference_image_source_io.dart';

/// What the confirmation page returns to the camera.
enum VisitRecordConfirmationResult { saved, completed }

/// Staged save progress texts (old confirmation screen, verbatim).
abstract final class VisitRecordSaveStage {
  static const saving = '保存记录中...';
  static const writingLocation = '正在写入照片定位，请稍候...';
  static const backingUpPhoto = '备份巡礼照片中...';
  static const renderingComparison = '生成对比图中...';
  static const completingPoint = '更新点位状态中...';
}

/// Location status texts (old confirmation screen, verbatim).
abstract final class PhotoLocationStatusText {
  static const locating = '正在获取拍摄位置...';
  static const ready = '已获取拍摄位置，保存时写入照片。';
  static const failed = '定位获取失败，本次不添加位置，保留照片原有信息。';
  static const skipped = '已跳过定位，本次不添加位置，保留照片原有信息。';
}

/// Result of [VisitRecordCommit.save] that the page turns into a toast and,
/// when [result] is set, a pop.
@immutable
class VisitRecordSaveOutcome {
  const VisitRecordSaveOutcome.success(this.message, this.result)
    : isError = false;
  const VisitRecordSaveOutcome.error(this.message)
    : isError = true,
      result = null;

  final String message;
  final bool isError;
  final VisitRecordConfirmationResult? result;
}

/// Old `shouldAutoSaveVisitPhotoToGallery`: only on Android / iOS.
bool shouldAutoSaveVisitPhotoToGallery(AppSettings settings) {
  if (!settings.saveVisitPhotoToGallery || kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// The confirmation save protocol, ported line by line from the old
/// `VisitRecordConfirmationScreen` state (`_save`, `_cleanupDrafts`,
/// location staging). The page owns one instance and calls [dispose] from
/// its own dispose; "mounted" in the old code maps to `!isDisposed`.
class VisitRecordCommit extends ChangeNotifier {
  VisitRecordCommit({
    required this.point,
    required this.controller,
    required this.photoPath,
    required this.referenceMode,
    this.referenceBytes,
    this.referenceImagePath,
    this.referenceImageUrl,
    this.capturedAtOverride,
    this.settings = const AppSettings(),
    this.saveVisitPhotoToGallery = false,
    this.autoSaveComparisonToGallery = false,
    this.photoLocationStrategy = PhotoLocationStrategy.disabled,
    this.writePhotoLocation,
    this.resolvePhotoLocation,
    PhotoLocationData? pendingPhotoLocation,
    this.prepareLocation = photo_location_save.preparePhotoLocation,
    this.prepareReference = photo_location_save.prepareReferenceImage,
    this.discardSourcePhoto,
    this.savePhotoToGallery = saveImageToGallery,
    this.backupComparison,
    bool Function(String? path)? referencePathCanDisplay,
  }) : _referencePathCanDisplay =
           referencePathCanDisplay ?? referenceImageLocalPathCanDisplay {
    if (photoLocationStrategy != PhotoLocationStrategy.disabled) {
      _pendingLocation = pendingPhotoLocation;
      if (_pendingLocation != null) {
        _locationStatus = PhotoLocationStatusText.ready;
      }
    }
  }

  final PilgrimagePoint point;
  final PilgrimagePlanController? controller;
  final String photoPath;
  final String referenceMode;
  final Uint8List? referenceBytes;
  final String? referenceImagePath;
  final String? referenceImageUrl;
  final DateTime? capturedAtOverride;
  final AppSettings settings;
  final bool saveVisitPhotoToGallery;
  final bool autoSaveComparisonToGallery;
  final PhotoLocationStrategy photoLocationStrategy;
  final PhotoLocationWriter? writePhotoLocation;
  final Future<PhotoLocationData> Function()? resolvePhotoLocation;
  final PhotoLocationPreparer prepareLocation;
  final ReferenceImagePreparer prepareReference;
  final Future<void> Function()? discardSourcePhoto;
  final Future<bool> Function(String) savePhotoToGallery;
  final Future<AutoComparisonGalleryResult> Function(PilgrimageVisitRecord)?
  backupComparison;
  final bool Function(String? path) _referencePathCanDisplay;

  bool _disposed = false;
  bool _saving = false;
  String? _savingStage;
  bool _locating = false;
  String? _locationStatus;
  int _locationRequest = 0;
  PhotoLocationData? _pendingLocation;
  PreparedPhotoLocation? _preparedPhoto;
  PreparedRecordImage? _referenceDraft;
  PilgrimageVisitRecord? _savedRecord;
  bool _recordCommitUncertain = false;
  bool _sourceDiscarded = false;
  Future<bool>? _previewReadComplete;

  bool get isDisposed => _disposed;
  bool get saving => _saving;
  String? get savingStage => _savingStage;
  bool get locating => _locating;
  String? get locationStatus => _locationStatus;
  PhotoLocationData? get pendingLocation => _pendingLocation;
  bool get recordCommitUncertain => _recordCommitUncertain;
  PilgrimageVisitRecord? get savedRecord => _savedRecord;

  /// Save buttons are enabled.
  bool get canSave => !_saving && !_locating && !_recordCommitUncertain;

  /// 取消 is enabled.
  bool get canCancel => !_saving;

  /// 跳过 is shown for a pending or staged location.
  bool get canSkipLocation =>
      !_saving &&
      !_recordCommitUncertain &&
      (_locating || _pendingLocation != null);

  /// Whether leaving must be blocked (PopScope).
  bool get blocksPop => _saving;

  /// Registers the completion of the preview's bounded read. The source
  /// photo is only discarded after it (old `retainPhotoPreview`).
  void attachPreviewRead(Future<void> Function() retain) {
    if (discardSourcePhoto == null) return;
    _previewReadComplete ??= Future.sync(retain).then(
      (_) => true,
      onError: (Object error, StackTrace stack) {
        debugPrint('Could not confirm preview read completion: $error');
        return false;
      },
    );
  }

  /// Old `initState` post-frame work: resolve the location right away for
  /// "wait on confirmation", and for "use recent location" when no fix was
  /// staged before the capture.
  void start() {
    final resolveOnOpen = switch (photoLocationStrategy) {
      PhotoLocationStrategy.waitOnConfirmation => true,
      PhotoLocationStrategy.useRecentLocation => _pendingLocation == null,
      _ => false,
    };
    if (resolveOnOpen) unawaited(_resolvePhotoLocation());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _locationRequest++;
    if (!_saving) unawaited(_cleanupDrafts(includeSource: true));
    super.dispose();
  }

  Future<void> _cleanupDrafts({required bool includeSource}) async {
    if (_recordCommitUncertain) return;
    Future<void> discard(Future<void> Function()? action) async {
      try {
        await action?.call();
      } catch (error) {
        debugPrint('Could not clean confirmation draft: $error');
      }
    }

    final record = _savedRecord;
    if (record == null) {
      final photo = _preparedPhoto;
      final reference = _referenceDraft;
      _preparedPhoto = null;
      _referenceDraft = null;
      await discard(photo?.discard);
      await discard(reference?.discard);
    }
    if (includeSource &&
        !_sourceDiscarded &&
        (record == null || record.photoPath != photoPath)) {
      _sourceDiscarded = true;
      // Route pop completes before its reverse animation and before a pending
      // bounded provider read. Both the preview owner and its read must finish first.
      if (await _previewReadComplete == false) return;
      await discard(discardSourcePhoto);
    }
  }

  Future<PhotoLocationData> _locatePhoto() {
    final resolver = resolvePhotoLocation;
    if (resolver != null) {
      return resolver();
    }
    return photoLocationStrategy == PhotoLocationStrategy.useRecentLocation
        ? resolveRecentPhotoLocation()
        : resolveFreshPhotoLocation();
  }

  Future<void> _resolvePhotoLocation() async {
    if (_locating || _disposed) {
      return;
    }
    final request = ++_locationRequest;
    _locating = true;
    _locationStatus = PhotoLocationStatusText.locating;
    _notify();
    try {
      final location = await _locatePhoto();
      if (_disposed || request != _locationRequest) {
        return;
      }
      _locating = false;
      _pendingLocation = location;
      _locationStatus = PhotoLocationStatusText.ready;
      _notify();
    } on CurrentLocationException catch (error) {
      if (_disposed || request != _locationRequest) {
        return;
      }
      _locating = false;
      _locationStatus = currentLocationFailureMessage(error);
      _notify();
    } catch (_) {
      if (_disposed || request != _locationRequest) {
        return;
      }
      _locating = false;
      _locationStatus = PhotoLocationStatusText.failed;
      _notify();
    }
  }

  /// 跳过: stop waiting and never write a location for this photo.
  void skipLocation() {
    if (_saving || _recordCommitUncertain) return;
    if (!(_locating || _pendingLocation != null)) return;
    _locationRequest += 1;
    _locating = false;
    _pendingLocation = null;
    _locationStatus = PhotoLocationStatusText.skipped;
    _notify();
  }

  /// Runs the full save. Returns null when nothing happened (already
  /// saving, disposed, locked); otherwise the toast to show and, on
  /// success, the result to pop with.
  Future<VisitRecordSaveOutcome?> save({required bool completePoint}) async {
    final controller = this.controller;
    if (_disposed ||
        _saving ||
        _locating ||
        _recordCommitUncertain ||
        _savedRecord != null) {
      return null;
    }
    if (controller?.repository == null) {
      return const VisitRecordSaveOutcome.error('记录存储不可用，请返回后重试。');
    }

    _saving = true;
    _savingStage = VisitRecordSaveStage.saving;
    _notify();

    try {
      await controller!.loadVisitRecords();
      if (_disposed) return null;
      final existingIds = controller.visitRecords.map((r) => r.id).toSet();
      final referenceBytes = this.referenceBytes;
      if (referenceBytes != null && _referenceDraft == null) {
        _referenceDraft = await prepareReference(referenceBytes);
      }
      if (_disposed) return null;
      final location = _pendingLocation;
      if (location != null && _preparedPhoto == null) {
        _savingStage = VisitRecordSaveStage.writingLocation;
        _notify();
        final writer = writePhotoLocation;
        _preparedPhoto = writer == null
            ? PreparedPhotoLocation(path: photoPath, written: false)
            : await prepareLocation(
                sourcePath: photoPath,
                location: location,
                writer: writer,
              );
      }
      if (_disposed) return null;
      _savingStage = VisitRecordSaveStage.saving;
      _notify();
      final savedPhotoPath = _preparedPhoto?.path ?? photoPath;
      final fallbackReferencePath = _referencePathCanDisplay(referenceImagePath)
          ? referenceImagePath
          : null;
      if (_savedRecord == null) {
        // From this point a failing response may still mean a committed record.
        _recordCommitUncertain = true;
        try {
          _savedRecord = await controller.createVisitRecord(
            point: point,
            photoPath: savedPhotoPath,
            referenceImagePath: _referenceDraft?.path ?? fallbackReferencePath,
            referenceImageUrl:
                _referenceDraft == null && fallbackReferencePath == null
                ? referenceImageUrl
                : null,
            referenceMode: referenceMode,
            capturedAt: capturedAtOverride,
          );
        } on VisitRecordNotCommittedException {
          _recordCommitUncertain = false;
          rethrow;
        } catch (_) {
          // A positive read can recover a lost response. A negative/cached read
          // cannot prove that a remote commit did not happen.
          await controller.loadVisitRecords();
          final matches = controller.visitRecords
              .where(
                (record) =>
                    !existingIds.contains(record.id) &&
                    record.pointId == point.id &&
                    record.photoPath == savedPhotoPath,
              )
              .toList();
          _savedRecord = matches.length == 1 ? matches.single : null;
          if (_savedRecord == null) rethrow;
        }
        if (_savedRecord == null) throw StateError('Record not confirmed');
        _recordCommitUncertain = false;
      }
      final record = _savedRecord!;
      var attemptedGalleryBackup = false;
      var galleryBackupSucceeded = false;
      if (saveVisitPhotoToGallery) {
        _savingStage = VisitRecordSaveStage.backingUpPhoto;
        _notify();
        attemptedGalleryBackup = true;
        try {
          galleryBackupSucceeded = await savePhotoToGallery(record.photoPath);
        } catch (_) {
          galleryBackupSucceeded = false;
        }
      }

      AutoComparisonGalleryResult? comparisonBackupResult;
      if (autoSaveComparisonToGallery) {
        _savingStage = VisitRecordSaveStage.renderingComparison;
        _notify();
        try {
          final backup = backupComparison;
          comparisonBackupResult = backup != null
              ? await backup(record)
              : await autoSaveComparisonImageToGallery(
                  record: record,
                  point: point,
                  settings: settings,
                  loadCurrentSettings: controller.repository!.loadAppSettings,
                  pointReferenceFullImagePath: referenceImagePath,
                  pointReferenceImageUrl: referenceImageUrl,
                );
        } catch (_) {
          comparisonBackupResult = const AutoComparisonGalleryResult(
            AutoComparisonGalleryStatus.renderFailed,
          );
        }
      }

      String? nextPointName;
      var completed = false;
      var completionFailed = false;
      if (completePoint) {
        _savingStage = VisitRecordSaveStage.completingPoint;
        _notify();
        try {
          await controller.completePointAndWait(point);
          completed = true;
          nextPointName = controller.currentPoint?.name;
        } catch (_) {
          completionFailed = true;
        }
      }

      if (_disposed) {
        return null;
      }
      var message = visitRecordSaveSuccessMessage(
        completePoint: completed,
        nextPointName: nextPointName,
        attemptedGalleryBackup: attemptedGalleryBackup,
        galleryBackupSucceeded: galleryBackupSucceeded,
        comparisonBackupResult: comparisonBackupResult,
      );
      if (_preparedPhoto?.written == false) {
        message += '；定位写入失败，保留照片原有信息';
      }
      if (completionFailed) message += '；标记完成失败，请在计划中重试';
      _saving = false;
      return VisitRecordSaveOutcome.success(
        message,
        completed
            ? VisitRecordConfirmationResult.completed
            : VisitRecordConfirmationResult.saved,
      );
    } catch (error) {
      debugPrint('Visit record save failed: $error');
      if (_disposed) return null;
      return VisitRecordSaveOutcome.error(
        _recordCommitUncertain ? '保存结果未确认，请返回记录页检查，勿重复保存。' : '保存记录失败，请重试。',
      );
    } finally {
      await _cleanupDrafts(includeSource: _disposed);
      if (!_disposed) {
        _saving = false;
        _savingStage = null;
        _notify();
      }
    }
  }
}

/// Old `_saveSuccessMessage`: base sentence + gallery backup + comparison
/// backup + next point.
String visitRecordSaveSuccessMessage({
  required bool completePoint,
  required String? nextPointName,
  required bool attemptedGalleryBackup,
  required bool galleryBackupSucceeded,
  required AutoComparisonGalleryResult? comparisonBackupResult,
}) {
  final base = completePoint ? '已保存并标记完成' : '记录已保存';
  final backupText = attemptedGalleryBackup
      ? (galleryBackupSucceeded ? '，并备份到相册' : '；相册备份失败')
      : '';
  final comparisonText = comparisonBackupMessage(comparisonBackupResult);
  final nextText = completePoint && nextPointName != null
      ? '，下一个：$nextPointName'
      : '';
  return '$base$backupText$comparisonText$nextText';
}

String comparisonBackupMessage(AutoComparisonGalleryResult? result) {
  if (result == null) {
    return '';
  }
  if (result.message != null) return '，${result.message}';
  return switch (result.status) {
    AutoComparisonGalleryStatus.saved => '，对比图已保存到相册',
    AutoComparisonGalleryStatus.referenceUnavailable => '，参考图不可用，未生成对比图',
    AutoComparisonGalleryStatus.capturedPhotoUnavailable => '，巡礼图不可用，未生成对比图',
    AutoComparisonGalleryStatus.galleryFailed => '，对比图保存到相册失败',
    AutoComparisonGalleryStatus.renderFailed => '，对比图生成失败',
  };
}
