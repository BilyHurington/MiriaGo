import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_theme.dart';
import '../plan/pilgrimage_models.dart';
import '../plan/pilgrimage_plan_controller.dart';
import '../plan/plan_group_utils.dart';
import 'visit_record_detail_screen.dart';
import 'visit_record_photo_stub.dart'
    if (dart.library.io) 'visit_record_photo_io.dart';

enum _RecordStatusFilter { all, completed, pending }

const String _ungroupedRecordFilterId = '__ungrouped__';
const String _orphanRecordFilterId = '__orphan__';
const double _recordsToolbarControlHeight = 44;

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({
    required this.controller,
    required this.settings,
    super.key,
  });

  final PilgrimagePlanController controller;
  final AppSettings settings;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  Set<String>? _selectedWorkIds;
  Set<String>? _selectedGroupFilterIds;
  late String _scopeFilterPlanId = widget.controller.plan.id;
  String _searchQuery = '';
  _RecordStatusFilter _statusFilter = _RecordStatusFilter.all;
  var _expandedSectionsInitialized = false;
  final Set<String> _expandedSectionIds = {};

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    _synchronizeScopeFilters(controller.plan);
    final records = _filteredRecords(controller);
    final sections = _groupedRecords(controller, records);
    final trimmedSearchQuery = _searchQuery.trim();
    final hasActiveFilters =
        _statusFilter != _RecordStatusFilter.all ||
        _selectedWorkIds != null ||
        _selectedGroupFilterIds != null;
    if (!_expandedSectionsInitialized && sections.isNotEmpty) {
      _expandedSectionIds.addAll(sections.map((section) => section.id));
      _expandedSectionsInitialized = true;
    }
    final allSectionsExpanded =
        sections.isNotEmpty &&
        sections.every((section) => _expandedSectionIds.contains(section.id));

    return Scaffold(
      appBar: AppBar(
        key: const ValueKey('records-app-bar'),
        toolbarHeight: AppTheme.appBarHeight,
        title: const Text(
          '记录',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            key: const ValueKey('records-toggle-all-sections'),
            tooltip: allSectionsExpanded ? '收起全部片区' : '展开全部片区',
            onPressed: sections.isEmpty
                ? null
                : () {
                    setState(() {
                      if (allSectionsExpanded) {
                        _expandedSectionIds.clear();
                      } else {
                        _expandedSectionIds.addAll(
                          sections.map((section) => section.id),
                        );
                      }
                    });
                  },
            icon: Icon(
              allSectionsExpanded
                  ? LucideIcons.chevronsUp
                  : LucideIcons.chevronsDown,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: CustomScrollView(
        key: const ValueKey('records-scroll-view'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.list(
              children: [
                _RecordsSummary(controller: controller),
                const SizedBox(height: 16),
                _RecordFilters(
                  statusFilter: _statusFilter,
                  searchQuery: _searchQuery,
                  activeScopeFilterCount:
                      (_selectedWorkIds == null ? 0 : 1) +
                      (_selectedGroupFilterIds == null ? 0 : 1),
                  onSearchChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                      _resetExpandedSections();
                    });
                  },
                  onStatusSelected: (filter) {
                    setState(() {
                      _statusFilter = filter;
                      _resetExpandedSections();
                    });
                  },
                  onOpenScopeFilters: _openScopeFilters,
                ),
                const SizedBox(height: 16),
                _RecordsSectionHeader(
                  visibleCount: records.length,
                  totalCount: controller.visitRecords.length,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          if (records.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _EmptyRecords(
                  hasAnyRecords: controller.visitRecords.isNotEmpty,
                  searchQuery: trimmedSearchQuery,
                  hasActiveFilters: hasActiveFilters,
                  onClearSearch: _clearSearch,
                  onResetFilters: _resetFilters,
                ),
              ),
            )
          else
            for (final section in sections)
              SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    pinned: _expandedSectionIds.contains(section.id),
                    delegate: _RecordGroupHeaderDelegate(
                      section: section,
                      expanded: _expandedSectionIds.contains(section.id),
                      onToggleExpanded: () {
                        setState(() {
                          if (!_expandedSectionIds.add(section.id)) {
                            _expandedSectionIds.remove(section.id);
                          }
                        });
                      },
                    ),
                  ),
                  if (_expandedSectionIds.contains(section.id))
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      sliver: SliverList.builder(
                        itemCount: section.entries.length,
                        itemBuilder: (context, index) {
                          final entry = section.entries[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _VisitRecordCard(
                              record: entry.record,
                              point: entry.point,
                              onTap: () =>
                                  _openRecordDetail(context, entry.record),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
          settings: widget.settings,
          onDelete: () => controller.deleteVisitRecord(record),
        ),
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _resetExpandedSections();
    });
  }

  void _resetFilters() {
    setState(() {
      _statusFilter = _RecordStatusFilter.all;
      _selectedWorkIds = null;
      _selectedGroupFilterIds = null;
      _resetExpandedSections();
    });
  }

  void _resetExpandedSections() {
    _expandedSectionIds.clear();
    _expandedSectionsInitialized = false;
  }

  void _synchronizeScopeFilters(PilgrimagePlan plan) {
    if (_scopeFilterPlanId != plan.id) {
      _scopeFilterPlanId = plan.id;
      _selectedWorkIds = null;
      _selectedGroupFilterIds = null;
      _resetExpandedSections();
      return;
    }

    final validWorkIds = plan.works.map((work) => work.id).toSet();
    _selectedWorkIds = _validFilterSelection(_selectedWorkIds, validWorkIds);
    final validGroupIds = {
      ...plan.groups.map((group) => group.id),
      _ungroupedRecordFilterId,
      _orphanRecordFilterId,
    };
    _selectedGroupFilterIds = _validFilterSelection(
      _selectedGroupFilterIds,
      validGroupIds,
    );
  }

  Set<String>? _validFilterSelection(
    Set<String>? selection,
    Set<String> validIds,
  ) {
    if (selection == null) {
      return null;
    }
    final retained = selection.intersection(validIds);
    return retained.isEmpty ? null : retained;
  }

  List<PilgrimageVisitRecord> _filteredRecords(
    PilgrimagePlanController controller,
  ) {
    return controller.visitRecords
        .where((record) {
          final point = controller.pointById(record.pointId);
          final workIds = _selectedWorkIds;
          if (workIds != null && !workIds.contains(record.workId)) {
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
    final orderedGroups = sortGroupsByPlanOrder(controller.plan.groups);
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
          icon: LucideIcons.folder,
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
          icon: LucideIcons.package,
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
          icon: LucideIcons.link2Off,
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
    final filterIds = _selectedGroupFilterIds;
    if (filterIds == null) {
      return true;
    }
    if (point == null) {
      return filterIds.contains(_orphanRecordFilterId);
    }
    final groupId = point.groupId;
    if (groupId == null) {
      return filterIds.contains(_ungroupedRecordFilterId);
    }
    return filterIds.contains(groupId);
  }

  Future<void> _openScopeFilters() async {
    final result = await showModalBottomSheet<_RecordScopeSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RecordScopeFilterSheet(
        works: widget.controller.plan.works,
        groups: widget.controller.plan.groups,
        selectedWorkIds: _selectedWorkIds,
        selectedGroupFilterIds: _selectedGroupFilterIds,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _selectedWorkIds = result.workIds;
      _selectedGroupFilterIds = result.groupIds;
      _resetExpandedSections();
    });
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
        if (point.hasCoordinate) ...[
          point.position.latitude.toStringAsFixed(6),
          point.position.longitude.toStringAsFixed(6),
        ] else
          '坐标待补充',
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
    required this.statusFilter,
    required this.searchQuery,
    required this.activeScopeFilterCount,
    required this.onSearchChanged,
    required this.onStatusSelected,
    required this.onOpenScopeFilters,
  });

  final _RecordStatusFilter statusFilter;
  final String searchQuery;
  final int activeScopeFilterCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_RecordStatusFilter> onStatusSelected;
  final VoidCallback onOpenScopeFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          key: const ValueKey('records-status-filter'),
          width: 124,
          height: _recordsToolbarControlHeight,
          child: _RecordStatusPicker(
            statusFilter: statusFilter,
            onSelected: onStatusSelected,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: _recordsToolbarControlHeight,
            child: _ExpandedRecordFilters(
              searchQuery: searchQuery,
              onSearchChanged: onSearchChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: _recordsToolbarControlHeight,
          height: _recordsToolbarControlHeight,
          child: Badge(
            isLabelVisible: activeScopeFilterCount > 0,
            label: Text('$activeScopeFilterCount'),
            child: IconButton.outlined(
              key: const ValueKey('records-scope-filter-button'),
              tooltip: '按作品和片区筛选',
              onPressed: onOpenScopeFilters,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.border),
              ),
              icon: const Icon(LucideIcons.slidersHorizontal),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordScopeSelection {
  const _RecordScopeSelection({required this.workIds, required this.groupIds});

  final Set<String>? workIds;
  final Set<String>? groupIds;
}

class _RecordScopeFilterSheet extends StatefulWidget {
  const _RecordScopeFilterSheet({
    required this.works,
    required this.groups,
    required this.selectedWorkIds,
    required this.selectedGroupFilterIds,
  });

  final List<PilgrimageWork> works;
  final List<PilgrimagePlanGroup> groups;
  final Set<String>? selectedWorkIds;
  final Set<String>? selectedGroupFilterIds;

  @override
  State<_RecordScopeFilterSheet> createState() =>
      _RecordScopeFilterSheetState();
}

class _RecordScopeFilterSheetState extends State<_RecordScopeFilterSheet> {
  late Set<String>? _workIds = _copyFilter(widget.selectedWorkIds);
  late Set<String>? _groupIds = _copyFilter(widget.selectedGroupFilterIds);

  static Set<String>? _copyFilter(Set<String>? value) {
    return value == null ? null : {...value};
  }

  Future<void> _openWorkFilters() async {
    final selectedIds = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _RecordScopeOptionSheet(
        kind: 'work',
        title: '作品',
        options: [
          for (final work in widget.works)
            _RecordScopeOption(id: work.id, label: work.title),
        ],
        selectedIds: _workIds ?? const {},
      ),
    );
    if (selectedIds == null || !mounted) {
      return;
    }
    setState(() => _workIds = selectedIds.isEmpty ? null : selectedIds);
  }

  Future<void> _openGroupFilters() async {
    final groups = sortGroupsByPlanOrder(widget.groups);
    final selectedIds = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _RecordScopeOptionSheet(
        kind: 'group',
        title: '片区',
        options: [
          for (final group in groups)
            _RecordScopeOption(id: group.id, label: group.name),
          const _RecordScopeOption(id: _ungroupedRecordFilterId, label: '未分组'),
          const _RecordScopeOption(id: _orphanRecordFilterId, label: '孤立记录'),
        ],
        selectedIds: _groupIds ?? const {},
      ),
    );
    if (selectedIds == null || !mounted) {
      return;
    }
    setState(() => _groupIds = selectedIds.isEmpty ? null : selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '筛选记录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('records-scope-clear'),
                    onPressed: () => setState(() {
                      _workIds = null;
                      _groupIds = null;
                    }),
                    child: const Text('清除'),
                  ),
                ],
              ),
              Text(
                '已选：作品 ${_workIds?.length ?? 0} · 片区 ${_groupIds?.length ?? 0}',
                key: const ValueKey('records-scope-summary'),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              const Text('作品', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _RecordScopeEntry(
                key: const ValueKey('records-scope-work-entry'),
                label: _scopeLabel(_workIds, allLabel: '全部作品', noun: '作品'),
                onTap: _openWorkFilters,
              ),
              const SizedBox(height: 16),
              const Text('片区', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _RecordScopeEntry(
                key: const ValueKey('records-scope-group-entry'),
                label: _scopeLabel(_groupIds, allLabel: '全部片区', noun: '片区'),
                onTap: _openGroupFilters,
              ),
              const SizedBox(height: 28),
              FilledButton(
                key: const ValueKey('records-scope-apply'),
                onPressed: () => Navigator.of(context).pop(
                  _RecordScopeSelection(
                    workIds: _copyFilter(_workIds),
                    groupIds: _copyFilter(_groupIds),
                  ),
                ),
                child: Text(
                  '应用筛选（${_workIds == null && _groupIds == null ? '全部点位' : '已选择'}）',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _scopeLabel(
    Set<String>? ids, {
    required String allLabel,
    required String noun,
  }) {
    return ids == null ? allLabel : '已选 ${ids.length} 个$noun';
  }
}

class _RecordScopeEntry extends StatelessWidget {
  const _RecordScopeEntry({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  LucideIcons.checkCircle,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordScopeOption {
  const _RecordScopeOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _RecordScopeOptionSheet extends StatefulWidget {
  const _RecordScopeOptionSheet({
    required this.kind,
    required this.title,
    required this.options,
    required this.selectedIds,
  });

  final String kind;
  final String title;
  final List<_RecordScopeOption> options;
  final Set<String> selectedIds;

  @override
  State<_RecordScopeOptionSheet> createState() =>
      _RecordScopeOptionSheetState();
}

class _RecordScopeOptionSheetState extends State<_RecordScopeOptionSheet> {
  late final Set<String> _selectedIds = {...widget.selectedIds};
  var _scrolling = false;

  void _toggleOption(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _confirm() {
    Navigator.of(context).pop({..._selectedIds});
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification && !_scrolling) {
      setState(() => _scrolling = true);
    } else if (notification is ScrollEndNotification && _scrolling) {
      setState(() => _scrolling = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    final desiredHeight = 52.0 + 40.0 + widget.options.length * 48.0 + 78.0;
    final sheetHeight = desiredHeight
        .clamp(190.0, maxHeight > 560 ? 560.0 : maxHeight)
        .toDouble();
    final noun = widget.kind == 'work' ? '作品' : '片区';
    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          key: ValueKey('records-scope-back-${widget.kind}'),
                          tooltip: '返回筛选记录',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(LucideIcons.chevronLeft),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '选择${widget.title}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 64),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                '全部${widget.title}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            Expanded(
              child: widget.options.isEmpty
                  ? Center(
                      child: Text(
                        '暂无可筛选项',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: _handleScrollNotification,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: widget.options.length,
                        itemBuilder: (context, index) {
                          final option = widget.options[index];
                          final selected = _selectedIds.contains(option.id);
                          return _RecordScopeOptionTile(
                            key: ValueKey(
                              'records-scope-option-${widget.kind}-${option.id}',
                            ),
                            decorationKey: ValueKey(
                              'records-scope-option-decoration-${widget.kind}-${option.id}',
                            ),
                            option: option,
                            badgeLabel: noun,
                            selected: selected,
                            hoverEnabled: !_scrolling,
                            onChanged: (value) =>
                                _toggleOption(option.id, value),
                          );
                        },
                      ),
                    ),
            ),
            ColoredBox(
              color: AppColors.background,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '已选择 ${_selectedIds.length} 个$noun',
                        key: ValueKey(
                          'records-scope-secondary-count-${widget.kind}',
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 176,
                      child: FilledButton(
                        key: ValueKey(
                          'records-scope-secondary-confirm-${widget.kind}',
                        ),
                        onPressed: _confirm,
                        child: Text(
                          _selectedIds.isEmpty
                              ? '确定'
                              : '确定（${_selectedIds.length}）',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordScopeOptionTile extends StatefulWidget {
  const _RecordScopeOptionTile({
    required this.decorationKey,
    required this.option,
    required this.badgeLabel,
    required this.selected,
    required this.hoverEnabled,
    required this.onChanged,
    super.key,
  });

  final Key decorationKey;
  final _RecordScopeOption option;
  final String badgeLabel;
  final bool selected;
  final bool hoverEnabled;
  final ValueChanged<bool> onChanged;

  @override
  State<_RecordScopeOptionTile> createState() => _RecordScopeOptionTileState();
}

class _RecordScopeOptionTileState extends State<_RecordScopeOptionTile> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final showHover = widget.hoverEnabled && _hovered;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: MouseRegion(
        onEnter: (_) {
          if (!_hovered) {
            setState(() => _hovered = true);
          }
        },
        onExit: (_) {
          if (_hovered) {
            setState(() => _hovered = false);
          }
        },
        child: SizedBox(
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                top: 6,
                right: 0,
                bottom: 6,
                child: AnimatedContainer(
                  key: widget.decorationKey,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(
                      alpha: widget.selected ? 0.10 : (showHover ? 0.05 : 0),
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onChanged(!widget.selected),
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.translationValues(
                      showHover && !widget.selected ? 12 : 0,
                      0,
                      0,
                    ),
                    transformAlignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.42),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.badgeLabel,
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Checkbox(
                          value: widget.selected,
                          onChanged: (value) =>
                              widget.onChanged(value ?? false),
                          shape: const CircleBorder(),
                          side: BorderSide(color: AppColors.border, width: 1.5),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordStatusPicker extends StatefulWidget {
  const _RecordStatusPicker({
    required this.statusFilter,
    required this.onSelected,
  });

  final _RecordStatusFilter statusFilter;
  final ValueChanged<_RecordStatusFilter> onSelected;

  @override
  State<_RecordStatusPicker> createState() => _RecordStatusPickerState();
}

class _RecordStatusPickerState extends State<_RecordStatusPicker> {
  var _isOpen = false;

  static const _options = [
    (_RecordStatusFilter.all, '全部', 'all'),
    (_RecordStatusFilter.completed, '已完成', 'completed'),
    (_RecordStatusFilter.pending, '未完成', 'pending'),
  ];

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final statusLabel = _options
        .firstWhere((option) => option.$1 == widget.statusFilter)
        .$2;
    return MenuAnchor(
      key: const ValueKey('records-status-menu-anchor'),
      onOpen: () => setState(() => _isOpen = true),
      onClose: () => setState(() => _isOpen = false),
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(AppColors.surface),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(
          AppColors.textPrimary.withValues(alpha: 0.14),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      builder: (context, controller, child) {
        return Tooltip(
          message: '按状态筛选',
          child: Material(
            key: const ValueKey('records-status-filter-surface'),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('records-status-filter-button'),
              onTap: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.listFilter,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Icon(
                      _isOpen ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      color: AppColors.accentDark,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      menuChildren: [
        SizedBox(
          key: const ValueKey('records-status-menu'),
          width: 124,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 14, 8, 10),
                  child: Text(
                    '选择状态',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                for (final option in _options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: MenuItemButton(
                      key: ValueKey('records-status-option-${option.$3}'),
                      onPressed: () => widget.onSelected(option.$1),
                      leadingIcon: option.$1 == widget.statusFilter
                          ? Icon(
                              LucideIcons.check,
                              color: accentColor,
                              size: 19,
                            )
                          : const SizedBox(width: 19),
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(
                          Size.fromHeight(42),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 10),
                        ),
                        backgroundColor: WidgetStatePropertyAll(
                          option.$1 == widget.statusFilter
                              ? accentColor.withValues(alpha: 0.09)
                              : Colors.transparent,
                        ),
                        foregroundColor: WidgetStatePropertyAll(
                          option.$1 == widget.statusFilter
                              ? accentColor
                              : AppColors.textPrimary,
                        ),
                        overlayColor: WidgetStateProperty.resolveWith((states) {
                          if (option.$1 == widget.statusFilter) {
                            return Colors.transparent;
                          }
                          return states.contains(WidgetState.hovered)
                              ? accentColor.withValues(alpha: 0.035)
                              : Colors.transparent;
                        }),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      child: Text(
                        option.$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpandedRecordFilters extends StatefulWidget {
  const _ExpandedRecordFilters({
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

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
    return Container(
      key: const ValueKey('records-search-shell'),
      height: _recordsToolbarControlHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        onTapOutside: dismissKeyboardOnTapOutside,
        key: const ValueKey('records-search-field'),
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索点位、作品、场景',
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.42),
            letterSpacing: 0,
          ),
          prefixIcon: const Icon(
            LucideIcons.search,
            key: ValueKey('records-search-prefix-icon'),
            size: 20,
          ),
          prefixIconConstraints: const BoxConstraints.tightFor(
            width: 40,
            height: 42,
          ),
          constraints: const BoxConstraints.tightFor(
            height: _recordsToolbarControlHeight,
          ),
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIconConstraints: const BoxConstraints.tightFor(
            width: 40,
            height: 42,
          ),
          suffixIcon: SizedBox(
            width: 40,
            child: _searchController.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    key: const ValueKey('records-search-clear-button'),
                    tooltip: '清空搜索',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 42,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      widget.onSearchChanged('');
                      setState(() {});
                    },
                    icon: const Icon(LucideIcons.x, size: 18),
                  ),
          ),
        ),
        textAlignVertical: TextAlignVertical.center,
        onChanged: (value) {
          widget.onSearchChanged(value);
          setState(() {});
        },
      ),
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
          style: TextStyle(
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

class _RecordGroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _RecordGroupHeaderDelegate({
    required this.section,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final _RecordGroup section;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _RecordGroupHeader(
      key: ValueKey('records-group-${section.id}'),
      section: section,
      expanded: expanded,
      onToggleExpanded: onToggleExpanded,
    );
  }

  @override
  bool shouldRebuild(covariant _RecordGroupHeaderDelegate oldDelegate) {
    return section != oldDelegate.section ||
        expanded != oldDelegate.expanded ||
        onToggleExpanded != oldDelegate.onToggleExpanded;
  }
}

class _RecordGroupHeader extends StatefulWidget {
  const _RecordGroupHeader({
    required this.section,
    required this.expanded,
    required this.onToggleExpanded,
    super.key,
  });

  final _RecordGroup section;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  State<_RecordGroupHeader> createState() => _RecordGroupHeaderState();
}

class _RecordGroupHeaderState extends State<_RecordGroupHeader> {
  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onToggleExpanded,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              key: ValueKey('records-group-surface-${section.id}'),
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          key: ValueKey('records-group-icon-${section.id}'),
                          _sectionIcon(section, widget.expanded),
                          color: AppColors.accent,
                          size: 27,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                section.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                section.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox.square(
                          key: ValueKey('records-group-count-${section.id}'),
                          dimension: 30,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Text(
                                    '${section.entries.length}',
                                    style: TextStyle(
                                      color: AppColors.accentDark,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          widget.expanded
                              ? LucideIcons.chevronUp
                              : LucideIcons.chevronDown,
                          color: AppColors.textSecondary,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                  if (!widget.expanded)
                    AppHairline(
                      key: ValueKey('records-group-divider-${section.id}'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _sectionIcon(_RecordGroup section, bool expanded) {
    if (section.id == _ungroupedRecordFilterId) {
      return expanded ? LucideIcons.package : LucideIcons.package;
    }
    if (section.id == _orphanRecordFilterId) {
      return LucideIcons.link2Off;
    }
    return expanded ? LucideIcons.mapPin : LucideIcons.mapPin;
  }
}

class _RecordsSummary extends StatelessWidget {
  const _RecordsSummary({required this.controller});

  final PilgrimagePlanController controller;

  @override
  Widget build(BuildContext context) {
    final completionProgress = controller.totalCount == 0
        ? 0.0
        : (controller.completedCount / controller.totalCount).clamp(0.0, 1.0);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _RecordsDashboardMetric(
                    value: TextSpan(
                      text: '${controller.visitRecords.length}',
                      style: TextStyle(color: AppColors.accent),
                    ),
                    label: '条巡礼记录',
                  ),
                ),
                Container(width: 1, height: 42, color: AppColors.border),
                const SizedBox(width: 24),
                Expanded(
                  child: _RecordsDashboardMetric(
                    value: TextSpan(
                      text: '${controller.completedCount}',
                      children: [
                        TextSpan(
                          text: ' / ${controller.totalCount}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    label: '已完成',
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 4,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.accent.withValues(alpha: 0.12),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: completionProgress,
                    heightFactor: 1,
                    child: ColoredBox(
                      key: const ValueKey('records-completion-progress'),
                      color: AppColors.accent,
                    ),
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

class _RecordsDashboardMetric extends StatelessWidget {
  const _RecordsDashboardMetric({required this.value, required this.label});

  final InlineSpan value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
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
    final title = resolvedPoint?.name ?? record.displayPointNameSnapshot;
    final workTitle =
        resolvedPoint?.work.title ?? record.displayWorkTitleSnapshot;
    final episodeParts = resolvedPoint?.displayEpisodeLabel
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final episodeText = episodeParts == null || episodeParts.isEmpty
        ? ''
        : ' / ${episodeParts.join('・')}';
    final photoPath = resolveVisitRecordDisplayPhotoPath(record);
    return Material(
      key: ValueKey('record-card-${record.id}'),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 112,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox(
                    width: 108,
                    height: 96,
                    child: VisitRecordPhoto(path: photoPath),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$workTitle$episodeText',
                        key: ValueKey('record-meta-text-${record.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        key: ValueKey('record-captured-row-${record.id}'),
                        children: [
                          Icon(
                            LucideIcons.calendarClock,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _formatCapturedAt(record.capturedAt),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  color: AppColors.textSecondary,
                  size: 25,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords({
    required this.hasAnyRecords,
    required this.searchQuery,
    required this.hasActiveFilters,
    required this.onClearSearch,
    required this.onResetFilters,
  });

  final bool hasAnyRecords;
  final String searchQuery;
  final bool hasActiveFilters;
  final VoidCallback onClearSearch;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final hasSearchQuery = hasAnyRecords && searchQuery.isNotEmpty;
    final hasFilterResult =
        hasAnyRecords && !hasSearchQuery && hasActiveFilters;
    final icon = hasSearchQuery
        ? LucideIcons.searchX
        : hasFilterResult
        ? LucideIcons.listFilter
        : LucideIcons.images;
    final title = hasSearchQuery
        ? '没有找到相关记录'
        : hasFilterResult
        ? '没有符合筛选条件的记录'
        : '还没有巡礼记录';
    final description = hasSearchQuery
        ? hasActiveFilters
              ? '没有与当前关键词和筛选条件同时匹配的点位、作品或场景。试试更换关键词，或重置筛选条件。'
              : '没有与当前关键词匹配的点位、作品或场景。试试更换关键词，或清除搜索查看全部记录。'
        : hasFilterResult
        ? '调整状态、作品或片区筛选条件后再试。'
        : '完成一次点位拍摄后，记录会自动汇总到这里。';

    return Semantics(
      liveRegion: true,
      child: Padding(
        key: const ValueKey('records-empty-state'),
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.accent, size: 42),
                const SizedBox(height: 14),
                Text(
                  title,
                  key: const ValueKey('records-empty-title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  key: const ValueKey('records-empty-description'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                    letterSpacing: 0,
                  ),
                ),
                if (hasSearchQuery || hasFilterResult) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasSearchQuery)
                        TextButton.icon(
                          key: const ValueKey('records-empty-clear-search'),
                          onPressed: onClearSearch,
                          icon: const Icon(LucideIcons.x, size: 18),
                          label: const Text('清除搜索'),
                        ),
                      if (hasActiveFilters)
                        TextButton.icon(
                          key: const ValueKey('records-empty-reset-filters'),
                          onPressed: onResetFilters,
                          icon: const Icon(LucideIcons.listFilter, size: 18),
                          label: const Text('重置筛选'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
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
