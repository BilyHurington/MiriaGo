import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/app_motion.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import '../data/anitabi_image_source_scope.dart';
import '../data/pilgrimage_repository.dart';
import '../widgets/snackbar_helper.dart';
import '../records/gallery_saver_stub.dart'
    if (dart.library.io) '../records/gallery_saver_io.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../records/visit_record_photo_stub.dart'
    if (dart.library.io) '../records/visit_record_photo_io.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/anitabi_network_image.dart';
import '../widgets/reference_image_placeholder.dart';
import '../widgets/app_back_button.dart';
import '../widgets/reference_image_source_stub.dart'
    if (dart.library.io) '../widgets/reference_image_source_io.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';
import 'auto_comparison_gallery_backup.dart';
import 'photo_location.dart';
import 'photo_location_save_stub.dart'
    if (dart.library.io) 'photo_location_save_io.dart';
import 'photo_location_status_panel.dart';
import 'visit_record_save_assets.dart';
import '../map/current_location_resolver.dart';

enum VisitRecordConfirmationResult { saved, completed }

class VisitRecordConfirmationScreen extends StatefulWidget {
  const VisitRecordConfirmationScreen({
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
    this.pendingPhotoLocation,
    this.prepareLocation = preparePhotoLocation,
    this.prepareReference = prepareReferenceImage,
    this.discardSourcePhoto,
    this.savePhotoToGallery = saveImageToGallery,
    this.backupComparison,
    this.retainPhotoPreview = retainPhotoPreviewUntilRead,
    super.key,
  });

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
  final PhotoLocationData? pendingPhotoLocation;
  final PhotoLocationPreparer prepareLocation;
  final ReferenceImagePreparer prepareReference;
  final Future<void> Function()? discardSourcePhoto;
  final Future<bool> Function(String) savePhotoToGallery;
  final Future<AutoComparisonGalleryResult> Function(PilgrimageVisitRecord)?
  backupComparison;
  final Future<void> Function(String, BuildContext) retainPhotoPreview;

  @override
  State<VisitRecordConfirmationScreen> createState() =>
      _VisitRecordConfirmationScreenState();
}

class _VisitRecordConfirmationScreenState
    extends State<VisitRecordConfirmationScreen> {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.discardSourcePhoto != null) {
      _previewReadComplete ??=
          Future.sync(
            () => widget.retainPhotoPreview(widget.photoPath, context),
          ).then(
            (_) => true,
            onError: (Object error, StackTrace stack) {
              debugPrint('Could not confirm preview read completion: $error');
              return false;
            },
          );
    }
  }

  @override
  void dispose() {
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
        (record == null || record.photoPath != widget.photoPath)) {
      _sourceDiscarded = true;
      // Route pop completes before its reverse animation and before a pending
      // FileImage read. Both the preview owner and its read must finish first.
      if (await _previewReadComplete == false) return;
      await discard(widget.discardSourcePhoto);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.photoLocationStrategy != PhotoLocationStrategy.disabled) {
      _pendingLocation = widget.pendingPhotoLocation;
      if (_pendingLocation != null) {
        _locationStatus = '已获取拍摄位置，保存时写入照片。';
      }
    }
    if (widget.photoLocationStrategy ==
        PhotoLocationStrategy.waitOnConfirmation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolvePhotoLocation();
      });
    }
  }

  Future<void> _resolvePhotoLocation() async {
    if (_locating || !mounted) {
      return;
    }
    final request = ++_locationRequest;
    setState(() {
      _locating = true;
      _locationStatus = '正在获取拍摄位置...';
    });
    try {
      final location =
          await (widget.resolvePhotoLocation ?? resolveFreshPhotoLocation)();
      if (!mounted || request != _locationRequest) {
        return;
      }
      setState(() {
        _locating = false;
        _pendingLocation = location;
        _locationStatus = '已获取拍摄位置，保存时写入照片。';
      });
    } on CurrentLocationException catch (error) {
      if (!mounted || request != _locationRequest) {
        return;
      }
      setState(() {
        _locating = false;
        _locationStatus = currentLocationFailureMessage(error);
      });
    } catch (_) {
      if (!mounted || request != _locationRequest) {
        return;
      }
      setState(() {
        _locating = false;
        _locationStatus = '定位获取失败，本次不添加位置，保留照片原有信息。';
      });
    }
  }

  Future<void> _save({required bool completePoint}) async {
    final controller = widget.controller;
    if (!mounted ||
        _saving ||
        _locating ||
        _recordCommitUncertain ||
        _savedRecord != null) {
      return;
    }
    if (controller?.repository == null) {
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: AppStatusBannerKind.error,
        title: '记录存储不可用，请返回后重试。',
      );
      return;
    }

    setState(() {
      _saving = true;
      _savingStage = '保存记录中...';
    });

    try {
      await controller!.loadVisitRecords();
      if (!mounted) return;
      final existingIds = controller.visitRecords.map((r) => r.id).toSet();
      final referenceBytes = widget.referenceBytes;
      if (referenceBytes != null && _referenceDraft == null) {
        _referenceDraft = await widget.prepareReference(referenceBytes);
      }
      if (!mounted) return;
      final location = _pendingLocation;
      if (location != null && _preparedPhoto == null) {
        if (mounted) {
          setState(() => _savingStage = '正在写入照片定位，请稍候...');
        }
        final writer = widget.writePhotoLocation;
        _preparedPhoto = writer == null
            ? PreparedPhotoLocation(path: widget.photoPath, written: false)
            : await widget.prepareLocation(
                sourcePath: widget.photoPath,
                location: location,
                writer: writer,
              );
      }
      if (!mounted) return;
      if (mounted) setState(() => _savingStage = '保存记录中...');
      final photoPath = _preparedPhoto?.path ?? widget.photoPath;
      final fallbackReferencePath =
          referenceImageLocalPathCanDisplay(widget.referenceImagePath)
          ? widget.referenceImagePath
          : null;
      if (_savedRecord == null) {
        // From this point a failing response may still mean a committed record.
        _recordCommitUncertain = true;
        try {
          _savedRecord = await controller.createVisitRecord(
            point: widget.point,
            photoPath: photoPath,
            referenceImagePath: _referenceDraft?.path ?? fallbackReferencePath,
            referenceImageUrl:
                _referenceDraft == null && fallbackReferencePath == null
                ? widget.referenceImageUrl
                : null,
            referenceMode: widget.referenceMode,
            capturedAt: widget.capturedAtOverride,
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
                    record.pointId == widget.point.id &&
                    record.photoPath == photoPath,
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
      if (widget.saveVisitPhotoToGallery) {
        if (mounted) {
          setState(() => _savingStage = '备份巡礼照片中...');
        }
        attemptedGalleryBackup = true;
        try {
          galleryBackupSucceeded = await widget.savePhotoToGallery(
            record.photoPath,
          );
        } catch (_) {
          galleryBackupSucceeded = false;
        }
      }

      AutoComparisonGalleryResult? comparisonBackupResult;
      if (widget.autoSaveComparisonToGallery) {
        if (mounted) {
          setState(() => _savingStage = '生成对比图中...');
        }
        try {
          comparisonBackupResult = widget.backupComparison != null
              ? await widget.backupComparison!(record)
              : await autoSaveComparisonImageToGallery(
                  record: record,
                  point: widget.point,
                  settings: widget.settings,
                  pointReferenceFullImagePath: widget.referenceImagePath,
                  pointReferenceImageUrl: widget.referenceImageUrl,
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
        if (mounted) {
          setState(() => _savingStage = '更新点位状态中...');
        }
        try {
          await controller.completePointAndWait(widget.point);
          completed = true;
          nextPointName = controller.currentPoint?.name;
        } catch (_) {
          completionFailed = true;
        }
      }

      if (!mounted) {
        return;
      }
      var message = _saveSuccessMessage(
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
      ScaffoldMessenger.of(
        context,
      ).showStatusSnack(kind: AppStatusBannerKind.success, title: message);
      setState(() => _saving = false);
      if (completed) {
        Navigator.of(context).pop(VisitRecordConfirmationResult.completed);
      } else {
        Navigator.of(context).pop(VisitRecordConfirmationResult.saved);
      }
    } catch (error) {
      debugPrint('Visit record save failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showStatusSnack(
          kind: AppStatusBannerKind.error,
          title: _recordCommitUncertain
              ? '保存结果未确认，请返回记录页检查，勿重复保存。'
              : '保存记录失败，请重试。',
        );
      }
    } finally {
      await _cleanupDrafts(includeSource: !mounted);
      if (mounted) {
        setState(() {
          _saving = false;
          _savingStage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _saving) {
          ScaffoldMessenger.of(context).showStatusSnack(
            kind: AppStatusBannerKind.running,
            title: '正在保存记录，请稍候。',
            icon: LucideIcons.save,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: appBackButtonIfCanPop(context),
          title: const Text('确认记录'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              widget.point.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.point.work.title} / ${widget.point.displayEpisodeLabel}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            AbsorbPointer(
              absorbing: _saving,
              child: _ComparisonPanel(
                photoPath: widget.photoPath,
                referenceBytes: widget.referenceBytes,
                referenceImagePath: widget.referenceImagePath,
                referenceImageUrl: widget.referenceImageUrl,
              ),
            ),
            const SizedBox(height: 16),
            _InfoPanel(referenceMode: widget.referenceMode),
            if (_locationStatus != null) ...[
              const SizedBox(height: 12),
              PhotoLocationStatusPanel(
                label: _locationStatus!,
                loading: _locating,
                onSkip:
                    !_saving &&
                        !_recordCommitUncertain &&
                        (_locating || _pendingLocation != null)
                    ? () {
                        if (_saving || _recordCommitUncertain) return;
                        setState(() {
                          _locationRequest += 1;
                          _locating = false;
                          _pendingLocation = null;
                          _locationStatus = '已跳过定位，本次不添加位置，保留照片原有信息。';
                        });
                      }
                    : null,
              ),
            ],
            AppReveal(
              visible: _savingStage != null,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AppContentFade(
                  revision: _savingStage,
                  child: _SavingProgressPanel(label: _savingStage ?? ''),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving || _locating || _recordCommitUncertain
                  ? null
                  : () => _save(completePoint: false),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.save, size: 18),
              label: Text(_saving ? '保存中' : '保存记录'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving || _locating || _recordCommitUncertain
                  ? null
                  : () => _save(completePoint: true),
              icon: const Icon(LucideIcons.circleCheckBig, size: 18),
              label: const Text('保存并标记完成'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving
                  ? null
                  : () {
                      if (!_saving) Navigator.of(context).pop();
                    },
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }
}

bool shouldAutoSaveVisitPhotoToGallery(AppSettings settings) {
  if (!settings.saveVisitPhotoToGallery || kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

String _saveSuccessMessage({
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
  final comparisonText = _comparisonBackupMessage(comparisonBackupResult);
  final nextText = completePoint && nextPointName != null
      ? '，下一个：$nextPointName'
      : '';
  return '$base$backupText$comparisonText$nextText';
}

String _comparisonBackupMessage(AutoComparisonGalleryResult? result) {
  if (result == null) {
    return '';
  }
  return switch (result.status) {
    AutoComparisonGalleryStatus.saved => '，对比图已保存到相册',
    AutoComparisonGalleryStatus.referenceUnavailable => '，参考图不可用，未生成对比图',
    AutoComparisonGalleryStatus.capturedPhotoUnavailable => '，巡礼图不可用，未生成对比图',
    AutoComparisonGalleryStatus.galleryFailed => '，对比图保存到相册失败',
    AutoComparisonGalleryStatus.renderFailed => '，对比图生成失败',
  };
}

Future<void> _showGallerySaveSheet(
  BuildContext context,
  String photoPath,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(LucideIcons.download),
            title: const Text('保存到相册'),
            onTap: () => Navigator.of(context).pop('save'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  if (action != 'save' || !context.mounted) return;

  final success = await saveImageToGallery(photoPath);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showStatusSnack(
    kind: success ? AppStatusBannerKind.success : AppStatusBannerKind.error,
    title: success ? '已保存到相册' : '保存失败，请稍后重试。',
  );
}

class _ComparisonPanel extends StatelessWidget {
  const _ComparisonPanel({
    required this.photoPath,
    required this.referenceBytes,
    required this.referenceImagePath,
    required this.referenceImageUrl,
  });

  final String photoPath;
  final Uint8List? referenceBytes;
  final String? referenceImagePath;
  final String? referenceImageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ImageCompareTile(
          label: '参考图',
          child: _ReferencePreview(
            bytes: referenceBytes,
            imagePath: referenceImagePath,
            imageUrl: referenceImageUrl,
          ),
          onTap: () => ImageViewerScreen.show(
            context,
            bytes: referenceBytes,
            filePath: referenceImagePath,
            imageUrl: referenceImageUrl,
          ),
        ),
        const SizedBox(height: 12),
        _ImageCompareTile(
          label: '巡礼图',
          child: VisitRecordPhoto(path: photoPath, fit: BoxFit.contain),
          onTap: () => ImageViewerScreen.show(context, filePath: photoPath),
          onLongPress: () => _showGallerySaveSheet(context, photoPath),
        ),
      ],
    );
  }
}

class _ImageCompareTile extends StatelessWidget {
  const _ImageCompareTile({
    required this.label,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: child,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ReferencePreview extends StatelessWidget {
  const _ReferencePreview({
    required this.bytes,
    required this.imagePath,
    required this.imageUrl,
  });

  final Uint8List? bytes;
  final String? imagePath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final localBytes = bytes;
    if (localBytes != null) {
      return Image.memory(localBytes, fit: BoxFit.contain);
    }

    final localPath = imagePath;
    if (referenceImageLocalPathCanDisplay(localPath)) {
      return ReferenceThumbnail(
        localPath: localPath,
        imageUrl: null,
        placeholder: const _ReferencePlaceholder(),
        fit: BoxFit.contain,
      );
    }

    final url = imageUrl;
    if (url != null) {
      return AnitabiNetworkImage(
        url: url,
        imageSource: AnitabiImageSourceScope.of(context),
        fit: BoxFit.contain,
        loadingBuilder: (_) {
          return const _ReferencePlaceholder(
            state: ReferenceImagePlaceholderState.loading,
          );
        },
        errorBuilder: (_) {
          return const _ReferencePlaceholder();
        },
      );
    }

    return const _ReferencePlaceholder();
  }
}

class _ReferencePlaceholder extends StatelessWidget {
  const _ReferencePlaceholder({
    this.state = ReferenceImagePlaceholderState.unavailable,
  });

  final ReferenceImagePlaceholderState state;

  @override
  Widget build(BuildContext context) {
    return ReferenceImagePlaceholder(state: state);
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.referenceMode});

  final String referenceMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.layers, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '参考模式',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          Text(
            referenceMode,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingProgressPanel extends StatelessWidget {
  const _SavingProgressPanel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
