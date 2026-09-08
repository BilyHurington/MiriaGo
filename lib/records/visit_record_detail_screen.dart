import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/foundation.dart';

import '../app_theme.dart';
import '../data/anitabi_image_source_scope.dart';
import '../desktop/desktop_asset_image.dart';
import '../color_grading/color_grading_params.dart';
import '../color_grading/color_grading_screen.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../plan/plan_group_utils.dart';
import '../plan/reference_image_status.dart';
import '../point_detail/point_detail_sheet.dart';
import '../widgets/copyable_text.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/app_back_button.dart';
import '../widgets/anitabi_network_image.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/reference_image_placeholder.dart';
import '../widgets/reference_image_source_stub.dart'
    if (dart.library.io) '../widgets/reference_image_source_io.dart';
import 'comparison_export_config.dart';
import 'comparison_export_sheet.dart';
import 'point_visit_records_screen.dart';
import 'visit_record_file_ops_stub.dart'
    if (dart.library.io) 'visit_record_file_ops_io.dart';
import 'visit_record_photo_stub.dart'
    if (dart.library.io) 'visit_record_photo_io.dart';

class VisitRecordDetailScreen extends StatefulWidget {
  const VisitRecordDetailScreen({
    required this.record,
    required this.point,
    required this.controller,
    required this.settings,
    required this.onDelete,
    super.key,
  });

  final PilgrimageVisitRecord record;
  final PilgrimagePoint? point;
  final PilgrimagePlanController controller;
  final AppSettings settings;
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
    final group = _groupFor(resolvedPoint);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppTheme.appBarHeight,
        leading: AppBackButton(
          key: const ValueKey('record-detail-back-button'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('记录详情'),
        actions: [
          IconButton(
            tooltip: '删除记录',
            onPressed: () => _confirmDelete(context),
            icon: const Icon(LucideIcons.trash2),
          ),
        ],
      ),
      body: ListView(
        key: const ValueKey('record-detail-scroll-view'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _RecordComparisonPanel(
            record: _record,
            referenceImagePath: referenceImagePath,
            referenceImageUrl: referenceImageUrl,
          ),
          const SizedBox(height: 16),
          if (resolvedPoint == null) ...[
            const _OrphanRecordNotice(),
            const SizedBox(height: 12),
          ],
          _RecordInfoDashboard(
            title: resolvedPoint?.name ?? _record.displayPointNameSnapshot,
            subtitle: resolvedPoint == null
                ? _recordSnapshotSubtitle(_record)
                : '${resolvedPoint.work.title} / ${resolvedPoint.subtitle}',
            onHeaderTap: resolvedPoint == null
                ? null
                : () => _showPointDetail(resolvedPoint),
            children: [
              _DetailRow(
                icon: LucideIcons.calendarClock,
                label: '拍摄时间',
                value: _formatDateTime(_record.capturedAt),
              ),
              if (resolvedPoint != null) ...[
                _DetailRow(
                  icon: LucideIcons.grid2X2,
                  label: '片区',
                  value: _groupName(resolvedPoint, group),
                ),
                _DetailRow(
                  icon: LucideIcons.film,
                  label: '场景',
                  value: resolvedPoint.displayEpisodeLabel,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _RecordActionPanel(
            onColorGrading: () => _openColorGrading(context),
            onExportComparison: () => _exportComparison(context, resolvedPoint),
          ),
        ],
      ),
    );
  }

  void _showPointDetail(PilgrimagePoint point) {
    PointDetailSheet.show(
      context,
      point: point,
      status: widget.controller.statusFor(point),
      onSetCurrent: () => widget.controller.setCurrentPoint(point),
      onOpenCamera: null,
      onComplete: () =>
          widget.controller.statusFor(point) == VisitStatus.completed
          ? widget.controller.reopenPoint(point)
          : widget.controller.completePoint(point),
      onReplaceReference: (point, image) => widget.controller.updatePoint(
        point.copyWith(
          referenceImageUrl: null,
          referenceThumbnailPath: image.thumbnailPath,
          referenceFullImagePath: image.fullImagePath,
        ),
      ),
      actionScope: PointDetailActionScope.manage,
      groups: widget.controller.plan.groups,
      groupBuckets: planGroupBuckets(
        widget.controller.plan,
        widget.controller.completedPointIds,
      ),
      onMoveToGroup: widget.controller.movePointToGroup,
      records: widget.controller.recordsForPoint(point.id),
      onOpenRecords: () => _openPointRecords(point),
      onOpenRecord: _openRelatedRecord,
      onDelete: widget.controller.deletePoint,
      navigationApp: widget.settings.navigationApp,
      settings: widget.settings,
    );
  }

  void _openPointRecords(PilgrimagePoint point) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PointVisitRecordsScreen(
          point: point,
          controller: widget.controller,
          settings: widget.settings,
        ),
      ),
    );
  }

  void _openRelatedRecord(PilgrimageVisitRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitRecordDetailScreen(
          record: record,
          point: widget.controller.pointById(record.pointId),
          controller: widget.controller,
          settings: widget.settings,
          onDelete: () => widget.controller.deleteVisitRecord(record),
        ),
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
            return ConfirmActionDialog(
              title: '删除记录',
              message: '将删除这条巡礼记录，不会改变点位完成状态。',
              confirmLabel: '删除',
              destructive: true,
              emphasizedValues: const ['这条巡礼记录'],
              additionalContent: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => deleteFiles = !deleteFiles),
                child: Row(
                  children: [
                    Checkbox(
                      value: deleteFiles,
                      checkColor: Colors.white,
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        return states.contains(WidgetState.selected)
                            ? ConfirmActionDialog.dangerColor
                            : Colors.transparent;
                      }),
                      side: BorderSide(color: AppColors.border, width: 1.5),
                      onChanged: (value) =>
                          setState(() => deleteFiles = value ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '同时删除照片文件',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
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
        deleteVisitRecordLocalFile(path);
      }
      final refPath = _record.referenceImagePath;
      if (refPath != null) {
        deleteVisitRecordLocalFile(refPath);
      }
    }

    await widget.onDelete();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _exportComparison(BuildContext context, PilgrimagePoint? resolvedPoint) {
    final capturedPath = resolveVisitRecordDisplayPhotoPath(_record);
    if (capturedPath == null) {
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: AppStatusBannerKind.warning,
        title: '巡礼图不可用，无法导出对比图片。',
      );
      return;
    }

    final meta = <ComparisonMetadataField, String>{
      ComparisonMetadataField.capturedAt: _formatDateTime(_record.capturedAt),
    };

    if (resolvedPoint != null) {
      meta[ComparisonMetadataField.pointName] = resolvedPoint.name;
      meta[ComparisonMetadataField.workTitle] = resolvedPoint.work.title;
      meta[ComparisonMetadataField.episodeLabel] =
          resolvedPoint.displayEpisodeLabel;
      if (resolvedPoint.hasCoordinate) {
        meta[ComparisonMetadataField.coordinates] =
            '${resolvedPoint.position.latitude.toStringAsFixed(5)}, '
            '${resolvedPoint.position.longitude.toStringAsFixed(5)}';
      }
      if (resolvedPoint.sourceId != null) {
        meta[ComparisonMetadataField.anitabiId] = resolvedPoint.sourceId!;
      }
    } else {
      meta[ComparisonMetadataField.pointName] =
          _record.displayPointNameSnapshot;
      meta[ComparisonMetadataField.workTitle] =
          _record.displayWorkTitleSnapshot;
    }

    final repository = widget.controller.repository;
    if (repository == null) {
      ScaffoldMessenger.of(context).showStatusSnack(
        kind: AppStatusBannerKind.warning,
        title: '当前平台暂不支持保存导出偏好。',
      );
      return;
    }

    ComparisonExportSheet.show(
      context,
      referenceImagePath: _resolvedReferenceImagePath(resolvedPoint),
      referenceImageUrl: _resolvedReferenceImageUrl(resolvedPoint),
      capturedPath: capturedPath,
      metadata: meta,
      colorGradingSummary: _colorGradingSummary(),
      repository: repository,
    );
  }

  String? _resolvedReferenceImagePath(PilgrimagePoint? resolvedPoint) {
    for (final path in [
      _record.referenceImagePath,
      resolvedPoint?.referenceFullImagePath,
    ].whereType<String>()) {
      if (visitRecordLocalFileExists(path) ||
          (kIsWeb && isDesktopAssetPath(path))) {
        return path;
      }
    }
    return null;
  }

  String? _resolvedReferenceImageUrl(PilgrimagePoint? resolvedPoint) {
    if (_record.referenceImageUrl != null) {
      return _record.referenceImageUrl;
    }
    if (resolvedPoint == null || !hasRemoteReferenceImage(resolvedPoint)) {
      return null;
    }
    return resolvedPoint.referenceImageUrl;
  }

  PilgrimagePlanGroup? _groupFor(PilgrimagePoint? point) {
    final groupId = point?.groupId;
    if (groupId == null) {
      return null;
    }
    return widget.controller.plan.groups
        .where((group) => group.id == groupId)
        .firstOrNull;
  }

  String _groupName(PilgrimagePoint point, PilgrimagePlanGroup? group) {
    if (point.groupId == null) {
      return '未分组';
    }
    return group?.name ?? '未知片区';
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
    final photoPath = resolveVisitRecordDisplayPhotoPath(record);
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
          child: VisitRecordPhoto(path: photoPath, fit: BoxFit.contain),
          onTap: () => ImageViewerScreen.show(context, filePath: photoPath),
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
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
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

class _RecordReferencePhoto extends StatelessWidget {
  const _RecordReferencePhoto({required this.path, required this.url});

  final String? path;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final localPath = path;
    if (referenceImageLocalPathCanDisplay(localPath)) {
      return VisitRecordPhoto(path: localPath!, fit: BoxFit.contain);
    }

    final imageUrl = url;
    if (imageUrl != null) {
      return AnitabiNetworkImage(
        url: imageUrl,
        imageSource: AnitabiImageSourceScope.of(context),
        fit: BoxFit.contain,
        loadingBuilder: (_) {
          return const _RecordReferencePlaceholder(
            state: ReferenceImagePlaceholderState.loading,
          );
        },
        errorBuilder: (_) {
          return const _RecordReferencePlaceholder();
        },
      );
    }

    return const _RecordReferencePlaceholder();
  }
}

class _RecordReferencePlaceholder extends StatelessWidget {
  const _RecordReferencePlaceholder({
    this.state = ReferenceImagePlaceholderState.unavailable,
  });

  final ReferenceImagePlaceholderState state;

  @override
  Widget build(BuildContext context) {
    return ReferenceImagePlaceholder(state: state);
  }
}

class _OrphanRecordNotice extends StatelessWidget {
  const _OrphanRecordNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.link2Off, color: AppColors.warning, size: 19),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '这条记录对应的点位已不在当前计划中，照片和导出功能仍然可以使用。',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordInfoDashboard extends StatelessWidget {
  const _RecordInfoDashboard({
    required this.title,
    required this.subtitle,
    required this.children,
    this.onHeaderTap,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onHeaderTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onHeaderTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onHeaderTap != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      LucideIcons.chevronRight,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const _DashboardBorder(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index += 1) ...[
                  if (index > 0) const _DashboardBorder(verticalMargin: 9),
                  children[index],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBorder extends StatelessWidget {
  const _DashboardBorder({this.verticalMargin = 0});

  final double verticalMargin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(vertical: verticalMargin),
      color: AppColors.border.withValues(alpha: 0.65),
    );
  }
}

class _RecordActionPanel extends StatelessWidget {
  const _RecordActionPanel({
    required this.onColorGrading,
    required this.onExportComparison,
  });

  final VoidCallback onColorGrading;
  final VoidCallback onExportComparison;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _RecordAction(
                icon: LucideIcons.wandSparkles,
                title: '自动调色',
                subtitle: '优化巡礼照片',
                onTap: onColorGrading,
              ),
            ),
            VerticalDivider(
              width: 9,
              indent: 8,
              endIndent: 8,
              color: AppColors.border,
            ),
            Expanded(
              child: _RecordAction(
                icon: LucideIcons.share2,
                title: '导出对比图',
                subtitle: '生成分享图片',
                onTap: onExportComparison,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordAction extends StatelessWidget {
  const _RecordAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CopyableText(
            text: value,
            copyLabel: label,
            style: TextStyle(
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

String _recordSnapshotSubtitle(PilgrimageVisitRecord record) {
  final workTitle = record.displayWorkTitleSnapshot;
  final pointSubtitle = record.displayPointSubtitleSnapshot;
  if (pointSubtitle.isEmpty) {
    return workTitle;
  }
  return '$workTitle / $pointSubtitle';
}
