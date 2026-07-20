import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import 'visit_record_detail_screen.dart';
import 'visit_record_photo_stub.dart'
    if (dart.library.io) 'visit_record_photo_io.dart';

class PointVisitRecordsScreen extends StatelessWidget {
  const PointVisitRecordsScreen({
    required this.point,
    required this.controller,
    required this.settings,
    super.key,
  });

  final PilgrimagePoint point;
  final PilgrimagePlanController controller;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: appTextScaler(settings.fontScale)),
      child: AppUiScaleView(
        scale: settings.uiScale,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final resolvedPoint = controller.pointById(point.id) ?? point;
            final records = controller.recordsForPoint(point.id);

            return Scaffold(
              appBar: AppBar(title: const Text('点位拍摄记录')),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _PointRecordsHeader(
                    point: resolvedPoint,
                    count: records.length,
                  ),
                  const SizedBox(height: 16),
                  if (records.isEmpty)
                    const _EmptyPointRecords()
                  else ...[
                    const _PointRecordsListLabel(),
                    const SizedBox(height: 8),
                    for (final record in records) ...[
                      _PointVisitRecordCard(
                        record: record,
                        onTap: () =>
                            _openRecordDetail(context, record, resolvedPoint),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openRecordDetail(
    BuildContext context,
    PilgrimageVisitRecord record,
    PilgrimagePoint point,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitRecordDetailScreen(
          record: record,
          point: point,
          controller: controller,
          settings: settings,
          onDelete: () => controller.deleteVisitRecord(record),
        ),
      ),
    );
  }
}

class _PointRecordsHeader extends StatelessWidget {
  const _PointRecordsHeader({required this.point, required this.count});

  final PilgrimagePoint point;
  final int count;

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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.collections_bookmark_outlined,
              color: AppColors.accent,
            ),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${point.work.title} / ${point.displayEpisodeLabel}',
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
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: AppColors.accentDark,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '条',
                style: TextStyle(
                  color: AppColors.accentDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyPointRecords extends StatelessWidget {
  const _EmptyPointRecords();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            color: AppColors.textSecondary,
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            '这个点位还没有拍摄记录',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointRecordsListLabel extends StatelessWidget {
  const _PointRecordsListLabel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Icon(Icons.schedule, color: AppColors.accent, size: 15),
          const SizedBox(width: 6),
          const Text(
            '拍摄记录',
            style: TextStyle(
              color: AppColors.textPrimary,
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

class _RecordCapturedAt {
  const _RecordCapturedAt({required this.date, required this.time});

  final String date;
  final String time;
}

class _RecordCapturedAtText extends StatelessWidget {
  const _RecordCapturedAtText({required this.capturedAt});

  final DateTime capturedAt;

  @override
  Widget build(BuildContext context) {
    final value = _formatCapturedAt(capturedAt);
    return SizedBox(
      width: 82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.date,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointVisitRecordCard extends StatelessWidget {
  const _PointVisitRecordCard({required this.record, required this.onTap});

  final PilgrimageVisitRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photoPath = resolveVisitRecordDisplayPhotoPath(record);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 104, child: VisitRecordPhoto(path: photoPath)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RecordCapturedAtText(capturedAt: record.capturedAt),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _RecordMetaChip(
                            icon: Icons.layers_outlined,
                            label: record.referenceMode,
                          ),
                          if (record.hasColorGrading)
                            const _RecordMetaChip(
                              icon: Icons.auto_fix_high_outlined,
                              label: '已调色',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordMetaChip extends StatelessWidget {
  const _RecordMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

_RecordCapturedAt _formatCapturedAt(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return _RecordCapturedAt(
    date: '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}',
    time: '${twoDigits(value.hour)}:${twoDigits(value.minute)}',
  );
}
