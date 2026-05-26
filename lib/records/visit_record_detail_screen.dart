import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../color_grading/color_grading_params.dart';
import '../color_grading/color_grading_screen.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../widgets/copyable_info.dart';
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
    final referenceImagePath = _resolvedReferenceImagePath(resolvedPoint);
    final referenceImageUrl = _resolvedReferenceImageUrl(resolvedPoint);

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
            referenceImagePath: referenceImagePath,
            referenceImageUrl: referenceImageUrl,
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
              CopyableInfoRow(
                icon: Icons.schedule,
                label: '拍摄时间',
                value: _formatDateTime(_record.capturedAt),
                labelWidth: 70,
              ),
              CopyableInfoRow(
                icon: Icons.layers_outlined,
                label: '参考模式',
                value: _record.referenceMode,
                labelWidth: 70,
              ),
              CopyableInfoRow(
                icon: Icons.photo_outlined,
                label: _record.hasColorGrading ? '显示照片' : '照片路径',
                value: _record.displayPhotoPath,
                labelWidth: 70,
              ),
              if (_record.hasColorGrading)
                CopyableInfoRow(
                  icon: Icons.photo_library_outlined,
                  label: '原图',
                  value: _record.sourcePhotoPath,
                  labelWidth: 70,
                ),
              if (referenceImagePath != null || referenceImageUrl != null)
                CopyableInfoRow(
                  icon: Icons.image_outlined,
                  label: '参考图',
                  value: referenceImagePath ?? referenceImageUrl!,
                  labelWidth: 70,
                ),
              if (resolvedPoint != null) ...[
                CopyableInfoRow(
                  icon: Icons.movie_filter_outlined,
                  label: '作品',
                  value:
                      '${resolvedPoint.work.title} / ${resolvedPoint.work.subtitle}',
                  labelWidth: 70,
                ),
                CopyableInfoRow(
                  icon: Icons.local_movies_outlined,
                  label: '场景',
                  value: resolvedPoint.displayEpisodeLabel,
                  labelWidth: 70,
                ),
                CopyableInfoRow(
                  icon: Icons.location_on_outlined,
                  label: '坐标',
                  value:
                      '${resolvedPoint.position.latitude.toStringAsFixed(5)},${resolvedPoint.position.longitude.toStringAsFixed(5)}',
                  labelWidth: 70,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openColorGrading(BuildContext context) async {
    final resolvedPoint = widget.point;
    final updated = await Navigator.of(context).push<PilgrimageVisitRecord>(
      MaterialPageRoute<PilgrimageVisitRecord>(
        builder: (_) => ColorGradingScreen(
          record: _record,
          controller: widget.controller,
          fallbackReferenceImagePath: _resolvedReferenceImagePath(
            resolvedPoint,
          ),
          fallbackReferenceImageUrl: _resolvedReferenceImageUrl(resolvedPoint),
        ),
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
      referenceImagePath: _resolvedReferenceImagePath(resolvedPoint),
      referenceImageUrl: _resolvedReferenceImageUrl(resolvedPoint),
      capturedPath: _record.displayPhotoPath,
      metadata: meta,
      colorGradingSummary: _colorGradingSummary(),
    );
  }

  String? _resolvedReferenceImagePath(PilgrimagePoint? resolvedPoint) {
    for (final path in [
      _record.referenceImagePath,
      resolvedPoint?.referenceFullImagePath,
    ].whereType<String>()) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  String? _resolvedReferenceImageUrl(PilgrimagePoint? resolvedPoint) {
    return _record.referenceImageUrl ?? resolvedPoint?.referenceImageUrl;
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
      final targetParams = ColorGradingParams.fromJson(
        Map<String, Object?>.from(decoded),
      );
      final intensity = (_record.colorGradingIntensity ?? 1).clamp(0.0, 1.0);
      final params = ColorGradingParams.lerp(
        ColorGradingParams.defaults,
        targetParams,
        intensity,
      );
      const threshold = 0.005;
      final defaults = ColorGradingParams.defaults;
      final parts = <String>[];

      String signed(double value) =>
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';
      String plain(double value) => value.toStringAsFixed(2);
      bool changed(double value, double fallback) =>
          (value - fallback).abs() >= threshold;
      void addZeroBased(String label, double value, double fallback) {
        if (changed(value, fallback)) {
          parts.add('$label ${signed(value)}');
        }
      }

      addZeroBased('亮度', params.brightness, defaults.brightness);
      addZeroBased('曝光', params.exposure, defaults.exposure);
      if (changed(params.contrast, defaults.contrast)) {
        parts.add('对比 ${plain(params.contrast)}');
      }
      if (changed(params.saturation, defaults.saturation)) {
        parts.add('饱和 ${plain(params.saturation)}');
      }
      addZeroBased('色温', params.temperature, defaults.temperature);
      addZeroBased('色调', params.tint, defaults.tint);
      addZeroBased('高光', params.highlights, defaults.highlights);
      addZeroBased('阴影', params.shadows, defaults.shadows);
      addZeroBased('R暗', params.redShadowCurve, defaults.redShadowCurve);
      addZeroBased('R中', params.redMidCurve, defaults.redMidCurve);
      addZeroBased('R亮', params.redHighlightCurve, defaults.redHighlightCurve);
      addZeroBased('G暗', params.greenShadowCurve, defaults.greenShadowCurve);
      addZeroBased('G中', params.greenMidCurve, defaults.greenMidCurve);
      addZeroBased(
        'G亮',
        params.greenHighlightCurve,
        defaults.greenHighlightCurve,
      );
      addZeroBased('B暗', params.blueShadowCurve, defaults.blueShadowCurve);
      addZeroBased('B中', params.blueMidCurve, defaults.blueMidCurve);
      addZeroBased(
        'B亮',
        params.blueHighlightCurve,
        defaults.blueHighlightCurve,
      );

      if (parts.isEmpty) {
        return null;
      }
      return parts.join('  ');
    } catch (_) {
      return null;
    }
  }
}

class _RecordComparisonPanel extends StatelessWidget {
  const _RecordComparisonPanel({
    required this.record,
    required this.referenceImagePath,
    required this.referenceImageUrl,
  });

  final PilgrimageVisitRecord record;
  final String? referenceImagePath;
  final String? referenceImageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecordImageTile(
          label: '参考图',
          child: _RecordReferencePhoto(
            path: referenceImagePath,
            url: referenceImageUrl,
          ),
          onTap: () => ImageViewerScreen.show(
            context,
            filePath: referenceImagePath,
            imageUrl: referenceImageUrl,
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
    return ColoredBox(
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

String _formatDateTime(DateTime value) {
  final year = value.year.toString();
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
