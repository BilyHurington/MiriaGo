import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../color_grading/color_grading_params.dart';
import '../color_grading/color_grading_screen.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../widgets/image_viewer_screen.dart';
import 'comparison_export_config.dart';
import 'comparison_export_sheet.dart';
import 'visit_record_photo_stub.dart'
    if (dart.library.io) 'visit_record_photo_io.dart';

class VisitRecordDetailScreen extends StatefulWidget {
  const VisitRecordDetailScreen({
    required this.record,
    required this.point,
    required this.controller,
    required this.onDelete,
    super.key,
  });

  final PilgrimageVisitRecord record;
  final PilgrimagePoint? point;
  final PilgrimagePlanController controller;
  final Future<void> Function() onDelete;

  @override
  State<VisitRecordDetailScreen> createState() =>
      _VisitRecordDetailScreenState();
}

class _VisitRecordDetailScreenState extends State<VisitRecordDetailScreen> {
  late PilgrimageVisitRecord _record = widget.record;

  @override
  Widget build(BuildContext context) {
    final resolvedPoint = widget.point;

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
            record: _record,
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
                ? _record.workId
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
                value: _formatDateTime(_record.capturedAt),
              ),
              _DetailRow(
                icon: Icons.layers_outlined,
                label: '参考模式',
                value: _record.referenceMode,
              ),
              _DetailRow(
                icon: Icons.photo_outlined,
                label: _record.hasColorGrading ? '显示照片' : '照片路径',
                value: _record.displayPhotoPath,
              ),
              if (_record.hasColorGrading)
                _DetailRow(
                  icon: Icons.photo_library_outlined,
                  label: '原图',
                  value: _record.sourcePhotoPath,
                ),
              if (_record.referenceImagePath != null ||
                  _record.referenceImageUrl != null)
                _DetailRow(
                  icon: Icons.image_outlined,
                  label: '参考图',
                  value:
                      _record.referenceImagePath ?? _record.referenceImageUrl!,
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
                  value: resolvedPoint.displayEpisodeLabel,
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

  Future<void> _openColorGrading(BuildContext context) async {
    final updated = await Navigator.of(context).push<PilgrimageVisitRecord>(
      MaterialPageRoute<PilgrimageVisitRecord>(
        builder: (_) =>
            ColorGradingScreen(record: _record, controller: widget.controller),
      ),
    );
    if (updated == null || !mounted) {
      return;
    }
    setState(() => _record = updated);
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
      for (final path in {
        _record.photoPath,
        _record.originalPhotoPath,
        _record.gradedPhotoPath,
      }.whereType<String>()) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
      final refPath = _record.referenceImagePath;
      if (refPath != null) {
        try {
          File(refPath).deleteSync();
        } catch (_) {}
      }
    }

    await widget.onDelete();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _exportComparison(BuildContext context, PilgrimagePoint? resolvedPoint) {
    final meta = <ComparisonMetadataField, String>{
      ComparisonMetadataField.capturedAt: _formatDateTime(_record.capturedAt),
    };

    if (resolvedPoint != null) {
      meta[ComparisonMetadataField.pointName] = resolvedPoint.name;
      meta[ComparisonMetadataField.workTitle] = resolvedPoint.work.title;
      meta[ComparisonMetadataField.episodeLabel] =
          resolvedPoint.displayEpisodeLabel;
      meta[ComparisonMetadataField.coordinates] =
          '${resolvedPoint.position.latitude.toStringAsFixed(5)}, '
          '${resolvedPoint.position.longitude.toStringAsFixed(5)}';
      if (resolvedPoint.sourceId != null) {
        meta[ComparisonMetadataField.anitabiId] = resolvedPoint.sourceId!;
      }
    }

    ComparisonExportSheet.show(
      context,
      referenceImagePath: _record.referenceImagePath,
      referenceImageUrl: _record.referenceImageUrl,
      capturedPath: _record.displayPhotoPath,
      metadata: meta,
      colorGradingSummary: _colorGradingSummary(),
    );
  }

  String? _colorGradingSummary() {
    final paramsJson = _record.colorGradingParamsJson;
    if (paramsJson == null || paramsJson.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(paramsJson);
      if (decoded is! Map) {
        return null;
      }
      final params = ColorGradingParams.fromJson(
        Map<String, Object?>.from(decoded),
      );
      final mode = ColorMatchMode.values
          .firstWhere(
            (candidate) => candidate.name == _record.colorGradingMode,
            orElse: () => ColorMatchMode.standard,
          )
          .label;
      final intensity =
          ((_record.colorGradingIntensity ?? 1).clamp(0.0, 1.0) * 100).round();
      String f(double value) => value.toStringAsFixed(2);
      return '调色 $mode $intensity%  '
          '曝光 ${f(params.exposure)}  对比 ${f(params.contrast)}  饱和 ${f(params.saturation)}  '
          '高光 ${f(params.highlights)}  阴影 ${f(params.shadows)}  '
          'R ${f(params.redShadowCurve)}/${f(params.redMidCurve)}/${f(params.redHighlightCurve)}  '
          'G ${f(params.greenShadowCurve)}/${f(params.greenMidCurve)}/${f(params.greenHighlightCurve)}  '
          'B ${f(params.blueShadowCurve)}/${f(params.blueMidCurve)}/${f(params.blueHighlightCurve)}';
    } catch (_) {
      return null;
    }
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
          child: VisitRecordPhoto(
            path: record.displayPhotoPath,
            fit: BoxFit.contain,
          ),
          onTap: () => ImageViewerScreen.show(
            context,
            filePath: record.displayPhotoPath,
          ),
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
