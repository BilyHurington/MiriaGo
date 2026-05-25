import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/snackbar_helper.dart';
import '../map/map_navigation_launcher.dart';
import '../plan/pilgrimage_models.dart';
import '../records/visit_record_photo_stub.dart'
    if (dart.library.io) '../records/visit_record_photo_io.dart';
import '../widgets/image_viewer_screen.dart';
import '../widgets/reference_thumbnail_stub.dart'
    if (dart.library.io) '../widgets/reference_thumbnail_io.dart';

class PointDetailSheet extends StatelessWidget {
  const PointDetailSheet({
    required this.point,
    required this.status,
    required this.onSetCurrent,
    required this.onOpenCamera,
    required this.onComplete,
    this.records = const [],
    this.navigationLauncher = const MapNavigationLauncher(),
    super.key,
  });

  final PilgrimagePoint point;
  final VisitStatus status;
  final VoidCallback onSetCurrent;
  final VoidCallback onOpenCamera;
  final VoidCallback onComplete;
  final List<PilgrimageVisitRecord> records;
  final MapNavigationLauncher navigationLauncher;

  static Future<void> show(
    BuildContext context, {
    required PilgrimagePoint point,
    required VisitStatus status,
    required VoidCallback onSetCurrent,
    required VoidCallback onOpenCamera,
    required VoidCallback onComplete,
    List<PilgrimageVisitRecord> records = const [],
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
          records: records,
        );
      },
    );
  }

  Future<void> _openNavigation(BuildContext context) async {
    final opened = await navigationLauncher.openGoogleMapsWalking(point);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showReplacingSnackBar(const SnackBar(content: Text('无法打开 Google Maps。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.84;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetHeight,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  _ReferencePreview(point: point, status: status),
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
              _InfoRow(
                icon: Icons.source_outlined,
                label: '来源',
                value: _sourceText,
              ),
              if (point.sourceId != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.tag_outlined,
                  label: 'ID',
                  value: point.sourceId!,
                ),
              ],
              if (point.sourceUrl != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.link_outlined,
                  label: '链接',
                  value: point.sourceUrl!,
                ),
              ],
              if (records.isNotEmpty) ...[
                const SizedBox(height: 18),
                _PointRecordsPreview(records: records),
              ],
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
      ),
      ),
    );
  }

  String get _sourceText {
    return switch (point.source) {
      PointSource.anitabi => 'Anitabi / ${point.referenceLabel}',
      PointSource.manual => '手动录入 / ${point.referenceLabel}',
    };
  }
}

class _ReferencePreview extends StatelessWidget {
  const _ReferencePreview({required this.point, required this.status});

  final PilgrimagePoint point;
  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      VisitStatus.current => AppColors.accent,
      VisitStatus.completed => AppColors.textSecondary,
      VisitStatus.pending => AppColors.accentDark,
    };

    return GestureDetector(
      onTap: () => ImageViewerScreen.show(
        context,
        filePath: point.referenceFullImagePath,
        imageUrl: point.referenceImageUrl,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            border: Border.all(color: AppColors.border),
          ),
          child: ReferenceThumbnail(
            localPath: point.referenceThumbnailPath,
            imageUrl: point.referenceImageUrl,
            fit: BoxFit.cover,
            placeholder: Icon(Icons.image_outlined, color: color, size: 28),
          ),
        ),
      ),
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

class _PointRecordsPreview extends StatelessWidget {
  const _PointRecordsPreview({required this.records});

  final List<PilgrimageVisitRecord> records;

  @override
  Widget build(BuildContext context) {
    final recentRecords = records.take(6).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.collections_bookmark_outlined,
              color: AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '本点记录 ${records.length}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final record = recentRecords[index];
              return SizedBox(
                width: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: VisitRecordPhoto(path: record.photoPath),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.referenceMode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemCount: recentRecords.length,
          ),
        ),
      ],
    );
  }
}
