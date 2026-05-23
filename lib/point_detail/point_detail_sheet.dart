import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../map/map_navigation_launcher.dart';
import '../plan/pilgrimage_models.dart';

class PointDetailSheet extends StatelessWidget {
  const PointDetailSheet({
    required this.point,
    required this.status,
    required this.onSetCurrent,
    required this.onOpenCamera,
    required this.onComplete,
    this.navigationLauncher = const MapNavigationLauncher(),
    super.key,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final VoidCallback onSetCurrent;
  final VoidCallback onOpenCamera;
  final VoidCallback onComplete;
  final MapNavigationLauncher navigationLauncher;

  static Future<void> show(
    BuildContext context, {
    required PilgrimagePoint point,
    required VisitStatus status,
    required VoidCallback onSetCurrent,
    required VoidCallback onOpenCamera,
    required VoidCallback onComplete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return PointDetailSheet(
          point: point,
          status: status,
          onSetCurrent: onSetCurrent,
          onOpenCamera: onOpenCamera,
          onComplete: onComplete,
        );
      },
    );
  }

  Future<void> _openNavigation(BuildContext context) async {
    final opened = await navigationLauncher.openGoogleMapsWalking(point);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开 Google Maps。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ReferencePlaceholder(status: status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusBadge(status: status),
                      const SizedBox(height: 8),
                      Text(
                        point.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${point.work.title} / ${point.subtitle}',
                        maxLines: 2,
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
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.movie_filter_outlined,
              label: '作品',
              value: '${point.work.title} / ${point.work.subtitle}',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.local_movies_outlined,
              label: '场景',
              value: point.episodeLabel,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: '坐标',
              value:
                  '${point.position.latitude.toStringAsFixed(5)}, ${point.position.longitude.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.image_outlined,
              label: '参考',
              value: point.referenceLabel,
            ),
            const SizedBox(height: 8),
            const _InfoRow(
              icon: Icons.source_outlined,
              label: '来源',
              value: '示例数据，Anitabi attribution 待接入',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openNavigation(context),
                    icon: const Icon(Icons.near_me_outlined, size: 18),
                    label: const Text('导航'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpenCamera();
                    },
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
                    onPressed: status == VisitStatus.current
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onSetCurrent();
                          },
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('设为当前'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onComplete();
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('标记完成'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferencePlaceholder extends StatelessWidget {
  const _ReferencePlaceholder({required this.status});

  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      VisitStatus.current => AppColors.accent,
      VisitStatus.completed => AppColors.textSecondary,
      VisitStatus.pending => AppColors.accentDark,
    };

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(Icons.image_outlined, color: color, size: 28),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final text = switch (status) {
      VisitStatus.current => '当前目标',
      VisitStatus.completed => '已完成',
      VisitStatus.pending => '待访问',
    };

    final color = switch (status) {
      VisitStatus.current => AppColors.accent,
      VisitStatus.completed => AppColors.textSecondary,
      VisitStatus.pending => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
          width: 42,
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
