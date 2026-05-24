import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
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
            tooltip: '删除记录',
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: VisitRecordPhoto(path: record.photoPath),
            ),
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

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除记录'),
          content: const Text('只删除这条巡礼记录，不会改变点位完成状态。'),
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
    if (shouldDelete != true || !context.mounted) {
      return;
    }

    await onDelete();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
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
