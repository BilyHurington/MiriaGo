import 'package:flutter/material.dart';
import '../widgets/app_motion.dart';
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
      enableDrag: false,
      useSafeArea: true,
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
  var _isWork = true;
  final _workScroll = ScrollController(keepScrollOffset: false);
  final _groupScroll = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _workScroll.dispose();
    _groupScroll.dispose();
    super.dispose();
  }

  static Set<String>? _copyFilter(Set<String>? value) =>
      value == null ? null : {...value};

  String _tabLabel(String title, Set<String>? ids) =>
      '$title · ${ids == null ? '不限' : '已选 ${ids.length}'}';

  @override
  Widget build(BuildContext context) {
    final kind = _isWork ? 'work' : 'group';
    final selectedIds = (_isWork ? _workIds : _groupIds) ?? const <String>{};
    final options = _isWork
        ? [
            for (final work in widget.works)
              _RecordScopeOption(id: work.id, label: work.title),
          ]
        : [
            for (final group in sortGroupsByPlanOrder(widget.groups))
              _RecordScopeOption(id: group.id, label: group.name),
            const _RecordScopeOption(
              id: _ungroupedRecordFilterId,
              label: '未分组',
            ),
            const _RecordScopeOption(id: _orphanRecordFilterId, label: '孤立记录'),
          ];
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: SafeArea(
        top: false,
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '筛选记录',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('records-scope-clear'),
                      onPressed: () => setState(() {
                        _workIds = null;
                        _groupIds = null;
                      }),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 44),
                        foregroundColor: AppColors.accentForeground,
                      ),
                      child: const Text(
                        '重置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  onTap: (index) => setState(() => _isWork = index == 0),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 3,
                  labelColor: AppColors.accentForeground,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                  tabs: [
                    Tab(
                      key: const ValueKey('records-scope-work-tab'),
                      text: _tabLabel('作品', _workIds),
                    ),
                    Tab(
                      key: const ValueKey('records-scope-group-tab'),
                      text: _tabLabel('片区', _groupIds),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Text(
                  '可多选',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: options.isEmpty
                    ? const Center(child: Text('暂无可筛选项'))
                    : ListView.separated(
                        key: PageStorageKey('records-scope-list-$kind'),
                        controller: _isWork ? _workScroll : _groupScroll,
                        separatorBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Divider(
                            height: 1,
                            thickness: 0.5,
                            color: AppColors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final selected = selectedIds.contains(option.id);
                          return Material(
                            color: selected
                                ? AppColors.accent.withValues(alpha: 0.10)
                                : Colors.transparent,
                            clipBehavior: Clip.antiAlias,
                            child: CheckboxListTile(
                              key: ValueKey(
                                'records-scope-option-$kind-${option.id}',
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              visualDensity: VisualDensity.standard,
                              minTileHeight: 52,
                              checkboxScaleFactor: 1.2,
                              side: BorderSide(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.8,
                                ),
                                width: 1.5,
                              ),
                              title: Text(
                                option.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.35,
                                  letterSpacing: 0,
                                ),
                              ),
                              value: selected,
                              checkboxShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(3),
                              ),
                              onChanged: (value) => setState(() {
                                final next = {...selectedIds};
                                if (value == true) {
                                  next.add(option.id);
                                } else {
                                  next.remove(option.id);
                                }
                                if (_isWork) {
                                  _workIds = next.isEmpty ? null : next;
                                } else {
                                  _groupIds = next.isEmpty ? null : next;
                                }
                              }),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_workIds == null ? '作品不限' : '作品已选 ${_workIds!.length} 部'} · '
                      '${_groupIds == null ? '片区不限' : '片区已选 ${_groupIds!.length} 个'}',
                      key: const ValueKey('records-scope-summary'),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      key: const ValueKey('records-scope-apply'),
                      onPressed: () => Navigator.of(context).pop(
                        _RecordScopeSelection(
                          workIds: _copyFilter(_workIds),
                          groupIds: _copyFilter(_groupIds),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        '应用筛选',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          Colors.black.withValues(alpha: 0.14),
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
                      color: AppColors.accentForeground,
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
                      color: AppColors.accentStrongForeground,
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
                              color: AppColors.accentForeground,
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
                              ? AppColors.accentForeground
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
                          color: AppColors.accentForeground,
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
                                      color: AppColors.accentStrongForeground,
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
                        AnimatedRotation(
                          turns: widget.expanded ? 0.5 : 0,
                          duration: AppMotion.durationOf(context),
                          child: Icon(
                            LucideIcons.chevronDown,
                            color: AppColors.textSecondary,
                            size: 24,
                          ),
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
                      style: TextStyle(color: AppColors.accentForeground),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox(
                    width: 108,
                    height: 96,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VisitRecordPhoto(path: photoPath),
                        if (record.hasColorGrading)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: _GradedBadge(
                              key: ValueKey('record-graded-badge-${record.id}'),
                            ),
                          ),
                      ],
                    ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            LucideIcons.calendarClock,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _formatCapturedAt(record.capturedAt),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                              ),
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
                Icon(icon, color: AppColors.accentForeground, size: 42),
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

/// Marks a record whose photo has been color graded.
class _GradedBadge extends StatelessWidget {
  const _GradedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '已调色',
      child: Semantics(
        label: '已调色',
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            LucideIcons.wandSparkles,
            size: 15,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
