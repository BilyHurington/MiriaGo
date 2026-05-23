import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../camera_reference/camera_reference_screen.dart';
import 'pilgrimage_models.dart';
import 'pilgrimage_plan_controller.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({
    required this.controller,
    required this.onOpenMap,
    super.key,
  });

  final PilgrimagePlanController controller;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan;
    final currentPoint = controller.currentPoint;

    return Scaffold(
      appBar: AppBar(title: const Text('计划')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _WorkHeader(plan: plan),
          const SizedBox(height: 16),
          _CurrentTargetCard(
            point: currentPoint,
            completedCount: controller.completedCount,
            totalCount: controller.totalCount,
            onOpenMap: onOpenMap,
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
          const SizedBox(height: 8),
          for (final point in controller.points) ...[
            _PlanPointTile(
              point: point,
              status: controller.statusFor(point),
              onTap: () => controller.setCurrentPoint(point),
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
        builder: (_) => CameraReferenceScreen(point: point),
      ),
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
                  plan.work.title,
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
                  '${plan.name} / ${plan.work.city}',
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
}

class _CurrentTargetCard extends StatelessWidget {
  const _CurrentTargetCard({
    required this.point,
    required this.completedCount,
    required this.totalCount,
    required this.onOpenMap,
    required this.onOpenCamera,
    required this.onComplete,
  });

  final PilgrimagePoint point;
  final int completedCount;
  final int totalCount;
  final VoidCallback onOpenMap;
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
            '${point.subtitle} / ${point.episodeLabel}',
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('标记完成'),
            ),
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
    required this.onTap,
    required this.onOpenCamera,
    required this.onComplete,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
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
                      '${point.subtitle} / ${point.episodeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                    ),
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
