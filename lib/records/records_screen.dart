import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import 'visit_record_detail_screen.dart';
import 'visit_record_photo_stub.dart'
    if (dart.library.io) 'visit_record_photo_io.dart';

enum _RecordStatusFilter { all, completed, pending }

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({required this.controller, super.key});

  final PilgrimagePlanController controller;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String? _selectedWorkId;
  _RecordStatusFilter _statusFilter = _RecordStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final records = _filteredRecords(controller);

    return Scaffold(
      appBar: AppBar(title: const Text('记录')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _RecordsSummary(controller: controller),
          const SizedBox(height: 16),
          _RecordFilters(
            works: controller.plan.works,
            selectedWorkId: _selectedWorkId,
            statusFilter: _statusFilter,
            onWorkSelected: (workId) {
              setState(() => _selectedWorkId = workId);
            },
            onStatusSelected: (filter) {
              setState(() => _statusFilter = filter);
            },
          ),
          const SizedBox(height: 16),
          _RecordsSectionHeader(
            visibleCount: records.length,
            totalCount: controller.visitRecords.length,
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const _EmptyRecords()
          else
            for (final record in records) ...[
              _VisitRecordCard(
                record: record,
                point: controller.pointById(record.pointId),
                onTap: () => _openRecordDetail(context, record),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  void _openRecordDetail(BuildContext context, PilgrimageVisitRecord record) {
    final controller = widget.controller;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitRecordDetailScreen(
          record: record,
          point: controller.pointById(record.pointId),
          onDelete: () => controller.deleteVisitRecord(record),
        ),
      ),
    );
  }

  List<PilgrimageVisitRecord> _filteredRecords(
    PilgrimagePlanController controller,
  ) {
    return controller.visitRecords
        .where((record) {
          final point = controller.pointById(record.pointId);
          if (_selectedWorkId != null && record.workId != _selectedWorkId) {
            return false;
          }

          return switch (_statusFilter) {
            _RecordStatusFilter.all => true,
            _RecordStatusFilter.completed =>
              point != null &&
                  controller.statusFor(point) == VisitStatus.completed,
            _RecordStatusFilter.pending =>
              point == null ||
                  controller.statusFor(point) != VisitStatus.completed,
          };
        })
        .toList(growable: false);
  }
}

class _RecordFilters extends StatelessWidget {
  const _RecordFilters({
    required this.works,
    required this.selectedWorkId,
    required this.statusFilter,
    required this.onWorkSelected,
    required this.onStatusSelected,
  });

  final List<PilgrimageWork> works;
  final String? selectedWorkId;
  final _RecordStatusFilter statusFilter;
  final ValueChanged<String?> onWorkSelected;
  final ValueChanged<_RecordStatusFilter> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '作品',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChipButton(
                label: '全部',
                selected: selectedWorkId == null,
                onSelected: () => onWorkSelected(null),
              ),
              for (final work in works) ...[
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: work.title,
                  selected: selectedWorkId == work.id,
                  onSelected: () => onWorkSelected(work.id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '状态',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChipButton(
              label: '全部',
              selected: statusFilter == _RecordStatusFilter.all,
              onSelected: () => onStatusSelected(_RecordStatusFilter.all),
            ),
            _FilterChipButton(
              label: '已完成点位',
              selected: statusFilter == _RecordStatusFilter.completed,
              onSelected: () => onStatusSelected(_RecordStatusFilter.completed),
            ),
            _FilterChipButton(
              label: '未完成点位',
              selected: statusFilter == _RecordStatusFilter.pending,
              onSelected: () => onStatusSelected(_RecordStatusFilter.pending),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _RecordsSectionHeader extends StatelessWidget {
  const _RecordsSectionHeader({
    required this.visibleCount,
    required this.totalCount,
  });

  final int visibleCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final suffix = visibleCount == totalCount
        ? '$totalCount'
        : '$visibleCount/$totalCount';
    return Row(
      children: [
        const Expanded(
          child: Text(
            '巡礼照片',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        Text(
          suffix,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _RecordsSummary extends StatelessWidget {
  const _RecordsSummary({required this.controller});

  final PilgrimagePlanController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.collections_bookmark_outlined,
            color: AppColors.accent,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${controller.visitRecords.length} 条巡礼记录',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '完成 ${controller.completedCount}/${controller.totalCount}',
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

class _VisitRecordCard extends StatelessWidget {
  const _VisitRecordCard({
    required this.record,
    required this.point,
    required this.onTap,
  });

  final PilgrimageVisitRecord record;
  final PilgrimagePoint? point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedPoint = point;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: VisitRecordPhoto(path: record.photoPath),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedPoint?.name ?? '已删除点位',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      resolvedPoint == null
                          ? record.workId
                          : '${resolvedPoint.work.title} / ${resolvedPoint.episodeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _RecordChip(
                          icon: Icons.layers_outlined,
                          label: record.referenceMode,
                        ),
                        _RecordChip(
                          icon: Icons.schedule,
                          label: _formatCapturedAt(record.capturedAt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordChip extends StatelessWidget {
  const _RecordChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '还没有巡礼记录。拍摄成功后会自动出现在这里。',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCapturedAt(DateTime capturedAt) {
  final month = capturedAt.month.toString().padLeft(2, '0');
  final day = capturedAt.day.toString().padLeft(2, '0');
  final hour = capturedAt.hour.toString().padLeft(2, '0');
  final minute = capturedAt.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
