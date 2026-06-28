import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/snackbar_helper.dart';
import '../records/gallery_saver_stub.dart'
    if (dart.library.io) '../records/gallery_saver_io.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../records/visit_record_photo_stub.dart'
    if (dart.library.io) '../records/visit_record_photo_io.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/reference_image_placeholder.dart';
import '../widgets/reference_image_source_stub.dart'
    if (dart.library.io) '../widgets/reference_image_source_io.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';
import 'auto_comparison_gallery_backup.dart';
import 'camera_storage_stub.dart'
    if (dart.library.io) 'camera_storage_io.dart'
    as camera_storage;

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

  @override
  State<VisitRecordConfirmationScreen> createState() =>
      _VisitRecordConfirmationScreenState();
}

class _VisitRecordConfirmationScreenState
    extends State<VisitRecordConfirmationScreen> {
  bool _saving = false;
  String? _savingStage;

  Future<void> _save({required bool completePoint}) async {
    final controller = widget.controller;
    if (controller == null || _saving) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _savingStage = '保存记录中...';
    });

    String? referenceImagePath;
    final referenceBytes = widget.referenceBytes;
    if (referenceBytes != null) {
      referenceImagePath = await camera_storage.saveRecordImageBytes(
        bytes: referenceBytes,
        prefix: 'reference',
      );
    }
    final fallbackReferencePath =
        referenceImageLocalPathCanDisplay(widget.referenceImagePath)
        ? widget.referenceImagePath
        : null;

    final record = await controller.createVisitRecord(
      point: widget.point,
      photoPath: widget.photoPath,
      referenceImagePath: referenceImagePath ?? fallbackReferencePath,
      referenceImageUrl:
          referenceImagePath == null && fallbackReferencePath == null
          ? widget.referenceImageUrl
          : null,
      referenceMode: widget.referenceMode,
      capturedAt: widget.capturedAtOverride,
    );

    var attemptedGalleryBackup = false;
    var galleryBackupSucceeded = false;
    if (widget.saveVisitPhotoToGallery) {
      if (mounted) {
        setState(() => _savingStage = '备份巡礼照片中...');
      }
      attemptedGalleryBackup = true;
      galleryBackupSucceeded = await saveImageToGallery(widget.photoPath);
    }

    AutoComparisonGalleryResult? comparisonBackupResult;
    if (record != null && widget.autoSaveComparisonToGallery) {
      if (mounted) {
        setState(() => _savingStage = '生成对比图中...');
      }
      comparisonBackupResult = await autoSaveComparisonImageToGallery(
        record: record,
        point: widget.point,
        settings: widget.settings,
        pointReferenceFullImagePath: widget.referenceImagePath,
        pointReferenceImageUrl: widget.referenceImageUrl,
      );
    }

    String? nextPointName;
    if (completePoint) {
      if (mounted) {
        setState(() => _savingStage = '更新点位状态中...');
      }
      controller.completePoint(widget.point);
      nextPointName = controller.currentPoint?.name;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _savingStage = null;
    });
    final message = _saveSuccessMessage(
      completePoint: completePoint,
      nextPointName: nextPointName,
      attemptedGalleryBackup: attemptedGalleryBackup,
      galleryBackupSucceeded: galleryBackupSucceeded,
      comparisonBackupResult: comparisonBackupResult,
    );
    ScaffoldMessenger.of(
      context,
    ).showReplacingSnackBar(SnackBar(content: Text(message)));
    if (completePoint) {
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _saving) {
          ScaffoldMessenger.of(
            context,
          ).showReplacingSnackBar(const SnackBar(content: Text('正在保存记录，请稍候。')));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('确认记录')),
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
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            _ComparisonPanel(
              photoPath: widget.photoPath,
              referenceBytes: widget.referenceBytes,
              referenceImagePath: widget.referenceImagePath,
              referenceImageUrl: widget.referenceImageUrl,
            ),
            const SizedBox(height: 16),
            _InfoPanel(referenceMode: widget.referenceMode),
            if (_savingStage != null) ...[
              const SizedBox(height: 12),
              _SavingProgressPanel(label: _savingStage!),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(completePoint: false),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? '保存中' : '保存记录'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _save(completePoint: true),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('保存并标记完成'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
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
            leading: const Icon(Icons.save_alt_outlined),
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

  ScaffoldMessenger.of(context).showReplacingSnackBar(
    SnackBar(content: Text(success ? '已保存到相册' : '保存失败，请稍后重试。')),
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
          style: const TextStyle(
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
      return Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return const _ReferencePlaceholder(
            state: ReferenceImagePlaceholderState.loading,
          );
        },
        errorBuilder: (context, error, stackTrace) {
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
          const Icon(Icons.layers_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Text(
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
              style: const TextStyle(
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
