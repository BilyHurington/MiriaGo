import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../camera_reference/camerawesome_reference_screen.dart';
import '../data/reference_image_cache_stub.dart'
    if (dart.library.io) '../data/reference_image_cache_io.dart'
    as reference_image_cache;
import '../point_detail/point_detail_sheet.dart';
import 'pilgrimage_models.dart';
import 'pilgrimage_plan_controller.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({
    required this.controller,
    required this.settings,
    required this.onOpenMap,
    required this.onOpenPlanManager,
    required this.onOpenAddPoints,
    required this.onOpenPointManager,
    super.key,
  });

  final PilgrimagePlanController controller;
  final AppSettings settings;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenPlanManager;
  final VoidCallback onOpenAddPoints;
  final VoidCallback onOpenPointManager;

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan;
    final currentPoint = controller.currentPoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划'),
        actions: [
          IconButton(
            tooltip: '切换计划',
            onPressed: onOpenPlanManager,
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: '添加点位',
            onPressed: onOpenAddPoints,
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
          IconButton(
            tooltip: '管理点位',
            onPressed: onOpenPointManager,
            icon: const Icon(Icons.tune_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _WorkHeader(plan: plan),
          const SizedBox(height: 16),
          if (currentPoint == null)
            _EmptyPlanCard(onAddPoints: onOpenAddPoints)
          else
            _CurrentTargetCard(
              point: currentPoint,
              completedCount: controller.completedCount,
              totalCount: controller.totalCount,
              onOpenMap: onOpenMap,
              onOpenDetail: () => _showPointDetail(context, currentPoint),
              onOpenCamera: () => _openCamera(context, currentPoint),
              onComplete: () => controller.completePoint(currentPoint),
            ),
          const SizedBox(height: 18),
          const Text(
            '今日点位',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onOpenPointManager,
                  icon: const Icon(Icons.tune_outlined, size: 18),
                  label: const Text('管理点位'),
                ),
                TextButton.icon(
                  onPressed: () => _cacheFullReferenceImages(context),
                  icon: const Icon(
                    Icons.download_for_offline_outlined,
                    size: 18,
                  ),
                  label: const Text('缓存完整参考图'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (controller.points.isEmpty)
            _EmptyPointList(onAddPoints: onOpenAddPoints)
          else
            for (final point in controller.points) ...[
              _PlanPointTile(
                point: point,
                status: controller.statusFor(point),
                recordCount: controller.recordsForPoint(point.id).length,
                onTap: () => _showPointDetail(context, point),
                onOpenCamera: () => _openCamera(context, point),
                onComplete: () => controller.completePoint(point),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  void _openCamera(BuildContext context, PilgrimagePoint point) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CamerawesomeReferenceScreen(
          point: point,
          controller: controller,
          settings: settings,
        ),
      ),
    );
  }

  void _showPointDetail(BuildContext context, PilgrimagePoint point) {
    PointDetailSheet.show(
      context,
      point: point,
      status: controller.statusFor(point),
      onSetCurrent: () => controller.setCurrentPoint(point),
      onOpenCamera: () => _openCamera(context, point),
      onComplete: () => controller.completePoint(point),
      records: controller.recordsForPoint(point.id),
    );
  }

  Future<void> _cacheFullReferenceImages(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final points = controller.points
        .where((point) => point.referenceImageUrl != null)
        .toList(growable: false);
    if (points.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('当前计划没有参考图')));
      return;
    }

    messenger.showSnackBar(const SnackBar(content: Text('正在缓存完整参考图...')));
    var cached = 0;
    for (final point in points) {
      final path = await reference_image_cache.cacheReferenceFullImage(point);
      if (path == null) {
        continue;
      }
      await controller.updatePointImageCache(
        point,
        referenceThumbnailPath: point.referenceThumbnailPath,
        referenceFullImagePath: path,
      );
      cached += 1;
    }

    messenger.showSnackBar(SnackBar(content: Text('已缓存 $cached 张完整参考图')));
  }
}

class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard({required this.onAddPoints});

  final VoidCallback onAddPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.route_outlined, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                '还没有点位',
                style: TextStyle(
                  color: AppColors.accentDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '先从 Anitabi 或手动录入添加巡礼点，之后这里会显示当前目标和完成进度。',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAddPoints,
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('添加点位'),
          ),
        ],
      ),
    );
  }
}

class _EmptyPointList extends StatelessWidget {
  const _EmptyPointList({required this.onAddPoints});

  final VoidCallback onAddPoints;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onAddPoints,
      icon: const Icon(Icons.add_location_alt_outlined, size: 18),
      label: const Text('添加第一个点位'),
    );
  }
}

class _WorkHeader extends StatelessWidget {
  const _WorkHeader({required this.plan});

  final PilgrimagePlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.movie_filter_outlined,
              color: AppColors.accentDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${plan.area} / ${plan.points.length} 个点位 / ${_workCountText(plan)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _workCountText(PilgrimagePlan plan) {
    final count = plan.works.isNotEmpty
        ? plan.works.length
        : plan.points.map((point) => point.work.id).toSet().length;
    return '$count 部作品';
  }
}

class _CurrentTargetCard extends StatelessWidget {
  const _CurrentTargetCard({
    required this.point,
    required this.completedCount,
    required this.totalCount,
    required this.onOpenMap,
    required this.onOpenDetail,
    required this.onOpenCamera,
    required this.onComplete,
  });

  final PilgrimagePoint point;
  final int completedCount;
  final int totalCount;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenCamera;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                '当前目标 $completedCount/$totalCount',
                style: const TextStyle(
                  color: AppColors.accentDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            point.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${point.work.title} / ${point.subtitle} / ${point.episodeLabel}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('查看地图'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenCamera,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('拍摄参考'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('点位详情'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('标记完成'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanPointTile extends StatelessWidget {
  const _PlanPointTile({
    required this.point,
    required this.status,
    required this.recordCount,
    required this.onTap,
    required this.onOpenCamera,
    required this.onComplete,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final int recordCount;
  final VoidCallback onTap;
  final VoidCallback onOpenCamera;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(status);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(colors.icon, color: colors.foreground, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${point.work.title} / ${point.subtitle} / ${point.episodeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                    ),
                    if (recordCount > 0) ...[
                      const SizedBox(height: 6),
                      _PointRecordBadge(count: recordCount),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: '拍摄参考',
                onPressed: onOpenCamera,
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              IconButton(
                tooltip: '完成',
                onPressed: onComplete,
                icon: const Icon(Icons.check_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _PointStatusColors _statusColors(VisitStatus status) {
    return switch (status) {
      VisitStatus.current => const _PointStatusColors(
        background: AppColors.accent,
        foreground: Colors.white,
        border: AppColors.accent,
        icon: Icons.flag,
      ),
      VisitStatus.completed => const _PointStatusColors(
        background: AppColors.surfaceMuted,
        foreground: AppColors.textSecondary,
        border: AppColors.border,
        icon: Icons.check_circle_outline,
      ),
      VisitStatus.pending => const _PointStatusColors(
        background: AppColors.surfaceMuted,
        foreground: AppColors.accentDark,
        border: AppColors.border,
        icon: Icons.place_outlined,
      ),
    };
  }
}

class _PointRecordBadge extends StatelessWidget {
  const _PointRecordBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 13,
            color: AppColors.accentDark,
          ),
          const SizedBox(width: 4),
          Text(
            '已拍 $count',
            style: const TextStyle(
              color: AppColors.accentDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointStatusColors {
  const _PointStatusColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final IconData icon;
}
