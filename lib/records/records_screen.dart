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
  String _searchQuery = '';
  _RecordStatusFilter _statusFilter = _RecordStatusFilter.all;
  var _filtersExpanded = false;

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
            searchQuery: _searchQuery,
            expanded: _filtersExpanded,
            activeFilterCount: _activeFilterCount,
            onToggleExpanded: () {
              setState(() => _filtersExpanded = !_filtersExpanded);
            },
            onSearchChanged: (query) {
              setState(() => _searchQuery = query);
            },
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
          controller: controller,
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

          if (!_matchesSearch(record, point)) {
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

  int get _activeFilterCount {
    var count = 0;
    if (_selectedWorkId != null) {
      count += 1;
    }
    if (_statusFilter != _RecordStatusFilter.all) {
      count += 1;
    }
    if (_searchQuery.trim().isNotEmpty) {
      count += 1;
    }
    return count;
  }

  bool _matchesSearch(PilgrimageVisitRecord record, PilgrimagePoint? point) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    final values = <String>[
      record.id,
      record.pointId,
      record.workId,
      record.referenceMode,
      record.referenceImagePath ?? '',
      record.referenceImageUrl ?? '',
      if (point != null) ...[
        point.id,
        point.name,
        point.subtitle,
        point.displayEpisodeLabel,
        point.referenceLabel,
        point.sourceId ?? '',
        point.sourceUrl ?? '',
        point.referenceImageUrl ?? '',
        point.position.latitude.toStringAsFixed(6),
        point.position.longitude.toStringAsFixed(6),
        point.work.id,
        point.work.title,
        point.work.subtitle,
        point.work.city,
        point.work.bangumiId?.toString() ?? '',
      ],
    ];

    return values.any((value) => value.toLowerCase().contains(query));
  }
}

class _RecordFilters extends StatelessWidget {
  const _RecordFilters({
    required this.works,
    required this.selectedWorkId,
    required this.statusFilter,
    required this.searchQuery,
    required this.expanded,
    required this.activeFilterCount,
    required this.onToggleExpanded,
    required this.onSearchChanged,
    required this.onWorkSelected,
    required this.onStatusSelected,
  });

  final List<PilgrimageWork> works;
  final String? selectedWorkId;
  final _RecordStatusFilter statusFilter;
  final String searchQuery;
  final bool expanded;
  final int activeFilterCount;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onWorkSelected;
  final ValueChanged<_RecordStatusFilter> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final summary = activeFilterCount == 0
        ? '全部记录'
        : '$activeFilterCount 个筛选条件';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: AppColors.accentDark),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '筛选',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Text(
                    summary,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: _ExpandedRecordFilters(
                works: works,
                selectedWorkId: selectedWorkId,
                statusFilter: statusFilter,
                searchQuery: searchQuery,
                onSearchChanged: onSearchChanged,
                onWorkSelected: onWorkSelected,
                onStatusSelected: onStatusSelected,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpandedRecordFilters extends StatefulWidget {
  const _ExpandedRecordFilters({
    required this.works,
    required this.selectedWorkId,
    required this.statusFilter,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onWorkSelected,
    required this.onStatusSelected,
  });

  final List<PilgrimageWork> works;
  final String? selectedWorkId;
  final _RecordStatusFilter statusFilter;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onWorkSelected;
  final ValueChanged<_RecordStatusFilter> onStatusSelected;

  @override
  State<_ExpandedRecordFilters> createState() => _ExpandedRecordFiltersState();
}

class _ExpandedRecordFiltersState extends State<_ExpandedRecordFilters> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _ExpandedRecordFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
      _searchController.selection = TextSelection.collapsed(
        offset: widget.searchQuery.length,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: '搜索点位',
            prefixIcon: const Icon(Icons.search),
            hintText: '点位、作品、场景、集数、坐标',
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空搜索',
                    onPressed: () {
                      _searchController.clear();
                      widget.onSearchChanged('');
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: (value) {
            widget.onSearchChanged(value);
            setState(() {});
          },
        ),
        const SizedBox(height: 14),
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
                selected: widget.selectedWorkId == null,
                onSelected: () => widget.onWorkSelected(null),
              ),
              for (final work in widget.works) ...[
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: work.title,
                  selected: widget.selectedWorkId == work.id,
                  onSelected: () => widget.onWorkSelected(work.id),
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
              selected: widget.statusFilter == _RecordStatusFilter.all,
              onSelected: () =>
                  widget.onStatusSelected(_RecordStatusFilter.all),
            ),
            _FilterChipButton(
              label: '已完成点位',
              selected: widget.statusFilter == _RecordStatusFilter.completed,
              onSelected: () =>
                  widget.onStatusSelected(_RecordStatusFilter.completed),
            ),
            _FilterChipButton(
              label: '未完成点位',
              selected: widget.statusFilter == _RecordStatusFilter.pending,
              onSelected: () =>
                  widget.onStatusSelected(_RecordStatusFilter.pending),
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
          Icon(
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
              child: VisitRecordPhoto(path: record.displayPhotoPath),
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
                          : '${resolvedPoint.work.title} / ${resolvedPoint.displayEpisodeLabel}',
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
      child: Row(
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
