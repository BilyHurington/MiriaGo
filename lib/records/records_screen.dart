import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import 'visit_record_detail_screen.dart';
import 'visit_record_photo_stub.dart'
    if (dart.library.io) 'visit_record_photo_io.dart';

enum _RecordStatusFilter { all, completed, pending }

const String _ungroupedRecordFilterId = '__ungrouped__';
const String _orphanRecordFilterId = '__orphan__';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({required this.controller, super.key});

  final PilgrimagePlanController controller;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String? _selectedWorkId;
  String? _selectedGroupFilterId;
  String _searchQuery = '';
  _RecordStatusFilter _statusFilter = _RecordStatusFilter.all;
  var _filtersExpanded = false;
  final Set<String> _expandedSectionIds = {};

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final records = _filteredRecords(controller);
    final sections = _groupedRecords(controller, records);

    return Scaffold(
      appBar: AppBar(title: const Text('记录')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _RecordsSummary(controller: controller),
          const SizedBox(height: 16),
          _RecordFilters(
            works: controller.plan.works,
            groups: controller.plan.groups,
            selectedWorkId: _selectedWorkId,
            selectedGroupFilterId: _selectedGroupFilterId,
            statusFilter: _statusFilter,
            searchQuery: _searchQuery,
            expanded: _filtersExpanded,
            activeFilterCount: _activeFilterCount,
            onToggleExpanded: () {
              setState(() => _filtersExpanded = !_filtersExpanded);
            },
            onSearchChanged: (query) {
              setState(() {
                _searchQuery = query;
                _resetExpandedSections();
              });
            },
            onWorkSelected: (workId) {
              setState(() {
                _selectedWorkId = workId;
                _resetExpandedSections();
              });
            },
            onGroupSelected: (groupId) {
              setState(() {
                _selectedGroupFilterId = groupId;
                _resetExpandedSections();
              });
            },
            onStatusSelected: (filter) {
              setState(() {
                _statusFilter = filter;
                _resetExpandedSections();
              });
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
            for (final section in sections)
              _RecordGroupSection(
                section: section,
                expanded: _expandedSectionIds.contains(section.id),
                onToggleExpanded: () {
                  setState(() {
                    if (!_expandedSectionIds.add(section.id)) {
                      _expandedSectionIds.remove(section.id);
                    }
                  });
                },
                onOpenRecord: (record) => _openRecordDetail(context, record),
              ),
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

  void _resetExpandedSections() {
    _expandedSectionIds.clear();
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

          if (!_matchesGroupFilter(point)) {
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

  List<_RecordGroup> _groupedRecords(
    PilgrimagePlanController controller,
    List<PilgrimageVisitRecord> records,
  ) {
    final recordsByGroupId = <String?, List<_RecordEntry>>{};
    final orphanRecords = <_RecordEntry>[];

    for (final record in records) {
      final point = controller.pointById(record.pointId);
      final entry = _RecordEntry(record: record, point: point);
      if (point == null) {
        orphanRecords.add(entry);
        continue;
      }
      recordsByGroupId.putIfAbsent(point.groupId, () => []).add(entry);
    }

    final groups = <_RecordGroup>[];
    final orderedGroups = [...controller.plan.groups]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    for (final group in orderedGroups) {
      final entries = recordsByGroupId[group.id];
      if (entries == null || entries.isEmpty) {
        continue;
      }
      groups.add(
        _RecordGroup(
          id: group.id,
          title: group.name,
          subtitle: _groupAnchorLabel(group),
          icon: Icons.folder_outlined,
          entries: _sortEntries(entries),
        ),
      );
    }

    final ungroupedEntries = recordsByGroupId[null];
    if (ungroupedEntries != null && ungroupedEntries.isNotEmpty) {
      groups.add(
        _RecordGroup(
          id: _ungroupedRecordFilterId,
          title: '未分组',
          subtitle: '还没有放入片区的记录',
          icon: Icons.inventory_2_outlined,
          entries: _sortEntries(ungroupedEntries),
        ),
      );
    }

    if (orphanRecords.isNotEmpty) {
      groups.add(
        _RecordGroup(
          id: _orphanRecordFilterId,
          title: '孤立记录',
          subtitle: '对应点位已不在当前计划中',
          icon: Icons.link_off_outlined,
          entries: _sortEntries(orphanRecords),
        ),
      );
    }

    return groups;
  }

  List<_RecordEntry> _sortEntries(List<_RecordEntry> entries) {
    return [...entries]
      ..sort((a, b) => b.record.capturedAt.compareTo(a.record.capturedAt));
  }

  bool _matchesGroupFilter(PilgrimagePoint? point) {
    final filterId = _selectedGroupFilterId;
    if (filterId == null) {
      return true;
    }
    if (filterId == _orphanRecordFilterId) {
      return point == null;
    }
    if (filterId == _ungroupedRecordFilterId) {
      return point != null && point.groupId == null;
    }
    return point != null && point.groupId == filterId;
  }

  int get _activeFilterCount {
    var count = 0;
    if (_selectedWorkId != null) {
      count += 1;
    }
    if (_selectedGroupFilterId != null) {
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
      record.workTitle ?? '',
      record.workSubtitle ?? '',
      record.pointName ?? '',
      record.pointSubtitle ?? '',
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
        _groupNameFor(point),
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

  String _groupNameFor(PilgrimagePoint point) {
    final groupId = point.groupId;
    if (groupId == null) {
      return '未分组';
    }
    return widget.controller.plan.groups
            .where((group) => group.id == groupId)
            .firstOrNull
            ?.name ??
        '未知片区';
  }

  String _groupAnchorLabel(PilgrimagePlanGroup group) {
    final anchorName = group.anchorName;
    if (anchorName == null || anchorName.trim().isEmpty) {
      return '未设置关键点';
    }
    return anchorName;
  }
}

class _RecordFilters extends StatelessWidget {
  const _RecordFilters({
    required this.works,
    required this.groups,
    required this.selectedWorkId,
    required this.selectedGroupFilterId,
    required this.statusFilter,
    required this.searchQuery,
    required this.expanded,
    required this.activeFilterCount,
    required this.onToggleExpanded,
    required this.onSearchChanged,
    required this.onWorkSelected,
    required this.onGroupSelected,
    required this.onStatusSelected,
  });

  final List<PilgrimageWork> works;
  final List<PilgrimagePlanGroup> groups;
  final String? selectedWorkId;
  final String? selectedGroupFilterId;
  final _RecordStatusFilter statusFilter;
  final String searchQuery;
  final bool expanded;
  final int activeFilterCount;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onWorkSelected;
  final ValueChanged<String?> onGroupSelected;
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
                groups: groups,
                selectedWorkId: selectedWorkId,
                selectedGroupFilterId: selectedGroupFilterId,
                statusFilter: statusFilter,
                searchQuery: searchQuery,
                onSearchChanged: onSearchChanged,
                onWorkSelected: onWorkSelected,
                onGroupSelected: onGroupSelected,
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
    required this.groups,
    required this.selectedWorkId,
    required this.selectedGroupFilterId,
    required this.statusFilter,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onWorkSelected,
    required this.onGroupSelected,
    required this.onStatusSelected,
  });

  final List<PilgrimageWork> works;
  final List<PilgrimagePlanGroup> groups;
  final String? selectedWorkId;
  final String? selectedGroupFilterId;
  final _RecordStatusFilter statusFilter;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onWorkSelected;
  final ValueChanged<String?> onGroupSelected;
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
          '片区',
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
                selected: widget.selectedGroupFilterId == null,
                onSelected: () => widget.onGroupSelected(null),
              ),
              for (final group in widget.groups) ...[
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: group.name,
                  selected: widget.selectedGroupFilterId == group.id,
                  onSelected: () => widget.onGroupSelected(group.id),
                ),
              ],
              const SizedBox(width: 8),
              _FilterChipButton(
                label: '未分组',
                selected:
                    widget.selectedGroupFilterId == _ungroupedRecordFilterId,
                onSelected: () =>
                    widget.onGroupSelected(_ungroupedRecordFilterId),
              ),
              const SizedBox(width: 8),
              _FilterChipButton(
                label: '孤立记录',
                selected: widget.selectedGroupFilterId == _orphanRecordFilterId,
                onSelected: () => widget.onGroupSelected(_orphanRecordFilterId),
              ),
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

class _RecordEntry {
  const _RecordEntry({required this.record, required this.point});

  final PilgrimageVisitRecord record;
  final PilgrimagePoint? point;
}

class _RecordGroup {
  const _RecordGroup({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.entries,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_RecordEntry> entries;
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

class _RecordGroupSection extends StatelessWidget {
  const _RecordGroupSection({
    required this.section,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onOpenRecord,
  });

  final _RecordGroup section;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<PilgrimageVisitRecord> onOpenRecord;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    Icon(
                      expanded ? Icons.folder_open_outlined : section.icon,
                      color: AppColors.accentDark,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            section.subtitle,
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
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '${section.entries.length} 条',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            for (final entry in section.entries) ...[
              _VisitRecordCard(
                record: entry.record,
                point: entry.point,
                groupName: section.title,
                onTap: () => onOpenRecord(entry.record),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
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
    required this.groupName,
    required this.onTap,
  });

  final PilgrimageVisitRecord record;
  final PilgrimagePoint? point;
  final String groupName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedPoint = point;
    final title = resolvedPoint?.name ?? record.displayPointNameSnapshot;
    final subtitle = resolvedPoint == null
        ? _recordSnapshotSubtitle(record)
        : '${resolvedPoint.work.title} / ${resolvedPoint.displayEpisodeLabel}';
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
                      title,
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
                      subtitle,
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
                          icon: Icons.grid_view_outlined,
                          label: groupName,
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

String _recordSnapshotSubtitle(PilgrimageVisitRecord record) {
  final workTitle = record.displayWorkTitleSnapshot;
  final pointSubtitle = record.displayPointSubtitleSnapshot;
  if (pointSubtitle.isEmpty) {
    return workTitle;
  }
  return '$workTitle / $pointSubtitle';
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
