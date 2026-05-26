import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../color_grading/color_grading_screen.dart';
import '../plan/pilgrimage_models.dart';
import '../widgets/image_viewer_screen.dart';
import 'comparison_export_config.dart';
import 'comparison_export_sheet.dart';
import 'visit_record_photo_stub.dart'
    if (dart.library.io) 'visit_record_photo_io.dart';

class VisitRecordDetailScreen extends StatelessWidget {
  const VisitRecordDetailScreen({
    required this.record,
    required this.point,
    required this.onDelete,
    super.key,
  });

  final PilgrimageVisitRecord record;
  final PilgrimagePoint? point;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final resolvedPoint = point;

    return Scaffold(
      appBar: AppBar(
        title: const Text('记录详情'),
        actions: [
          IconButton(
            tooltip: '自动调色',
            onPressed: () => _openColorGrading(context),
            icon: const Icon(Icons.auto_fix_high_outlined),
          ),
          IconButton(
            tooltip: '导出对比图',
            onPressed: () => _exportComparison(context, resolvedPoint),
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            tooltip: '删除记录',
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _RecordComparisonPanel(
            record: record,
            fallbackReferenceUrl: resolvedPoint?.referenceImageUrl,
          ),
          const SizedBox(height: 16),
          Text(
            resolvedPoint?.name ?? '已删除点位',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            resolvedPoint == null
                ? record.workId
                : '${resolvedPoint.work.title} / ${resolvedPoint.subtitle}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            children: [
              _DetailRow(
                icon: Icons.schedule,
                label: '拍摄时间',
                value: _formatDateTime(record.capturedAt),
              ),
              _DetailRow(
                icon: Icons.layers_outlined,
                label: '参考模式',
                value: record.referenceMode,
              ),
              _DetailRow(
                icon: Icons.photo_outlined,
                label: '照片路径',
                value: record.photoPath,
              ),
              if (record.referenceImagePath != null ||
                  record.referenceImageUrl != null)
                _DetailRow(
                  icon: Icons.image_outlined,
                  label: '参考图',
                  value: record.referenceImagePath ?? record.referenceImageUrl!,
                ),
              if (resolvedPoint != null) ...[
                _DetailRow(
                  icon: Icons.movie_filter_outlined,
                  label: '作品',
                  value:
                      '${resolvedPoint.work.title} / ${resolvedPoint.work.subtitle}',
                ),
                _DetailRow(
                  icon: Icons.local_movies_outlined,
                  label: '场景',
                  value: resolvedPoint.episodeLabel,
                ),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: '坐标',
                  value:
                      '${resolvedPoint.position.latitude.toStringAsFixed(5)}, ${resolvedPoint.position.longitude.toStringAsFixed(5)}',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _openColorGrading(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ColorGradingScreen(
          recordId: record.id,
          capturedPath: record.photoPath,
          referenceImagePath: record.referenceImagePath,
          referenceImageUrl: record.referenceImageUrl,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    var deleteFiles = false;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('删除记录'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('只删除这条巡礼记录，不会改变点位完成状态。'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: deleteFiles,
                        onChanged: (v) =>
                            setState(() => deleteFiles = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const Text('同时删除照片文件'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('删除'),
                ),
              ],
            );
          },
        );
      },
    );
    if (shouldDelete != true || !context.mounted) {
      return;
    }

    if (deleteFiles) {
      try {
        File(record.photoPath).deleteSync();
      } catch (_) {}
      final refPath = record.referenceImagePath;
      if (refPath != null) {
        try {
          File(refPath).deleteSync();
        } catch (_) {}
      }
    }

    await onDelete();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _exportComparison(BuildContext context, PilgrimagePoint? resolvedPoint) {
    final meta = <ComparisonMetadataField, String>{
      ComparisonMetadataField.capturedAt: _formatDateTime(record.capturedAt),
    };

    if (resolvedPoint != null) {
      meta[ComparisonMetadataField.pointName] = resolvedPoint.name;
      meta[ComparisonMetadataField.workTitle] = resolvedPoint.work.title;
      meta[ComparisonMetadataField.episodeLabel] = resolvedPoint.episodeLabel;
      meta[ComparisonMetadataField.coordinates] =
          '${resolvedPoint.position.latitude.toStringAsFixed(5)}, '
          '${resolvedPoint.position.longitude.toStringAsFixed(5)}';
      if (resolvedPoint.sourceId != null) {
        meta[ComparisonMetadataField.anitabiId] = resolvedPoint.sourceId!;
      }
    }

    ComparisonExportSheet.show(
      context,
      referenceImagePath: record.referenceImagePath,
      referenceImageUrl: record.referenceImageUrl,
      capturedPath: record.photoPath,
      metadata: meta,
    );
  }
}

class _RecordComparisonPanel extends StatelessWidget {
  const _RecordComparisonPanel({
    required this.record,
    required this.fallbackReferenceUrl,
  });

  final PilgrimageVisitRecord record;
  final String? fallbackReferenceUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecordImageTile(
          label: '参考图',
          child: _RecordReferencePhoto(
            path: record.referenceImagePath,
            url: record.referenceImageUrl ?? fallbackReferenceUrl,
          ),
          onTap: () => ImageViewerScreen.show(
            context,
            filePath: record.referenceImagePath,
            imageUrl: record.referenceImageUrl ?? fallbackReferenceUrl,
          ),
        ),
        const SizedBox(height: 12),
        _RecordImageTile(
          label: '巡礼图',
          child: VisitRecordPhoto(path: record.photoPath, fit: BoxFit.contain),
          onTap: () =>
              ImageViewerScreen.show(context, filePath: record.photoPath),
        ),
      ],
    );
  }
}

class _RecordImageTile extends StatelessWidget {
  const _RecordImageTile({
    required this.label,
    required this.child,
    this.onTap,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: InkWell(onTap: onTap, child: child),
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

class _RecordReferencePhoto extends StatelessWidget {
  const _RecordReferencePhoto({required this.path, required this.url});

  final String? path;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final localPath = path;
    if (localPath != null) {
      return VisitRecordPhoto(path: localPath, fit: BoxFit.contain);
    }

    final imageUrl = url;
    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const _RecordReferencePlaceholder();
        },
      );
    }

    return const _RecordReferencePlaceholder();
  }
}

class _RecordReferencePlaceholder extends StatelessWidget {
  const _RecordReferencePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(Icons.image_outlined, color: AppColors.accentDark),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index += 1) ...[
            if (index > 0) const Divider(height: 18),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 19),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
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
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  final year = value.year.toString();
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
