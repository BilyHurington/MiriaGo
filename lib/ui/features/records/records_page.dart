import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../application/plan_session.dart';
import '../../../application/records/record_details.dart';
import '../../../application/records/record_query.dart';
import '../../../plan/pilgrimage_models.dart';
import '../../../plan/pilgrimage_plan_controller.dart';
import '../../../plan/plan_group_utils.dart';
import '../../app/router.dart';
import '../../components/components.dart';
import 'record_detail_page.dart';
import 'record_images.dart';

/// Location of the records tab with [recordId] selected (large layouts).
String recordsLocation([String? recordId]) => recordId == null
    ? Routes.records
    : Uri(
        path: Routes.records,
        queryParameters: {'record': recordId},
      ).toString();

/// Whether the records tab shows list and detail side by side.
bool recordsUsesListDetail(BuildContext context) =>
    context.layout.windowClass >= WindowClass.large;

/// Opens a record from anywhere inside the records tab.
void openRecord(BuildContext context, String recordId) {
  if (recordsUsesListDetail(context)) {
    context.go(recordsLocation(recordId));
  } else {
    context.push(Routes.record(recordId));
  }
}

/// 记录 tab (DESIGN §8.15).
class RecordsPage extends StatefulWidget {
  const RecordsPage({this.selectedRecordId, super.key});
  final String? selectedRecordId;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  // Kept across page rebuilds within a session (old app had no grid).
  static bool _gridView = true;

  final _filters = RecordsFilterController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filters.addListener(_changed);
  }

  @override
  void dispose() {
    _filters.removeListener(_changed);
    _filters.dispose();
    _search.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _clearSearch() {
    _search.clear();
    _filters.clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PlanSession>();
    if (!session.isReady) {
      return const MiriaPageScaffold(
        title: '记录',
        body: Center(child: ProgressRing(semanticLabel: '加载中')),
      );
    }
    final controller = session.controller;
    final source = RecordsSource.fromController(controller);
    final records = _filters.apply(source);
    final sections = RecordQueries.group(source, records);
    _filters.ensureExpandedInitialized(sections);
    RecordBrowseOrder.instance.publish([
      for (final section in sections)
        for (final entry in section.entries) entry.record.id,
    ]);

    final listDetail = recordsUsesListDetail(context);
    final selectedId = listDetail ? widget.selectedRecordId : null;
    final list = _RecordsList(
      controller: controller,
      filters: _filters,
      search: _search,
      records: records,
      sections: sections,
      gridView: _gridView,
      selectedRecordId: selectedId,
      onToggleView: () => setState(() => _gridView = !_gridView),
      onClearSearch: _clearSearch,
      onOpen: (record) => openRecord(context, record.id),
    );
    if (!listDetail) return list;

    final selectedExists =
        selectedId != null &&
        controller.visitRecords.any((record) => record.id == selectedId);
    return ListDetailLayout(
      forceSinglePane: false,
      list: list,
      detail: selectedExists
          ? RecordDetailView(
              key: ValueKey('record-detail-pane-$selectedId'),
              recordId: selectedId,
              embedded: true,
            )
          : null,
      detailPlaceholder: const EmptyState(
        icon: Symbols.photo_library_rounded,
        title: '选择一条记录',
        message: '在左侧选择记录后，这里会显示对比和详情。',
      ),
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({
    required this.controller,
    required this.filters,
    required this.search,
    required this.records,
    required this.sections,
    required this.gridView,
    required this.selectedRecordId,
    required this.onToggleView,
    required this.onClearSearch,
    required this.onOpen,
  });

  final PilgrimagePlanController controller;
  final RecordsFilterController filters;
  final TextEditingController search;
  final List<PilgrimageVisitRecord> records;
  final List<RecordSection> sections;
  final bool gridView;
  final String? selectedRecordId;
  final VoidCallback onToggleView;
  final VoidCallback onClearSearch;
  final ValueChanged<PilgrimageVisitRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    final gutter = context.layout.gutter;
    final allExpanded = filters.allExpanded(sections);
    final trimmedQuery = filters.searchQuery.trim();

    return MiriaPageScaffold(
      key: const ValueKey('records-page'),
      title: '记录',
      actions: [
        MiriaIconButton(
          key: const ValueKey('records-view-toggle'),
          icon: gridView
              ? Symbols.view_list_rounded
              : Symbols.grid_view_rounded,
          tooltip: gridView ? '列表视图' : '网格视图',
          onPressed: onToggleView,
        ),
        MiriaIconButton(
          key: const ValueKey('records-toggle-all-sections'),
          icon: allExpanded
              ? Symbols.unfold_less_rounded
              : Symbols.unfold_more_rounded,
          tooltip: allExpanded ? '收起全部片区' : '展开全部片区',
          onPressed: sections.isEmpty
              ? null
              : () => filters.toggleAll(sections),
        ),
      ],
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, Space.x2, gutter, 0),
          sliver: SliverList.list(
            children: [
              _RecordsSummary(controller: controller),
              const SizedBox(height: Space.x4),
              SearchField(
                key: const ValueKey('records-search'),
                controller: search,
                hint: '搜索点位、作品、场景',
                onChanged: (value) => filters.searchQuery = value,
                onCleared: onClearSearch,
              ),
              const SizedBox(height: Space.x3),
              _FilterBar(controller: controller, filters: filters),
              const SizedBox(height: Space.x4),
              _PhotosHeader(
                visibleCount: records.length,
                totalCount: controller.visitRecords.length,
              ),
              const SizedBox(height: Space.x1),
            ],
          ),
        ),
        if (records.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyRecords(
              hasAnyRecords: controller.visitRecords.isNotEmpty,
              searchQuery: trimmedQuery,
              hasActiveFilters: filters.hasActiveFilters,
              onClearSearch: onClearSearch,
              onResetFilters: filters.resetFilters,
            ),
          )
        else
          for (final section in sections)
            SliverMainAxisGroup(
              key: ValueKey('records-section-${section.id}'),
              slivers: [
                SliverPersistentHeader(
                  pinned: filters.isExpanded(section.id),
                  delegate: _SectionHeaderDelegate(
                    section: section,
                    expanded: filters.isExpanded(section.id),
                    gutter: gutter,
                    textScaler: MediaQuery.textScalerOf(context),
                    onToggle: () => filters.toggleSection(section.id),
                  ),
                ),
                if (filters.isExpanded(section.id))
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      Space.x1,
                      gutter,
                      Space.x4,
                    ),
                    sliver: gridView
                        ? SliverAdaptiveGrid(
                            itemCount: section.entries.length,
                            itemBuilder: (context, index) {
                              final entry = section.entries[index];
                              return RecordGridCard(
                                entry: entry,
                                selected: entry.record.id == selectedRecordId,
                                onTap: () => onOpen(entry.record),
                              );
                            },
                          )
                        : SliverList.separated(
                            itemCount: section.entries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: Space.x2),
                            itemBuilder: (context, index) {
                              final entry = section.entries[index];
                              return RecordListTile(
                                entry: entry,
                                selected: entry.record.id == selectedRecordId,
                                onTap: () => onOpen(entry.record),
                              );
                            },
                          ),
                  ),
              ],
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
    final c = context.colors;
    final text = context.text;
    final progress = controller.totalCount == 0
        ? 0.0
        : (controller.completedCount / controller.totalCount).clamp(0.0, 1.0);
    final numberStyle = text.numeric(
      text.headlineSmall!.copyWith(color: c.textPrimary),
    );

    Widget metric(InlineSpan value, String label) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(value, style: numberStyle),
        const SizedBox(height: Space.x1),
        Text(label, style: text.bodySmall),
      ],
    );

    return MiriaCard(
      key: const ValueKey('records-summary'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.x4),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: metric(
                      TextSpan(
                        text: '${controller.visitRecords.length}',
                        style: TextStyle(color: c.primaryText),
                      ),
                      '条巡礼记录',
                    ),
                  ),
                  VerticalDivider(width: Space.x6, color: c.hairline),
                  Expanded(
                    child: metric(
                      TextSpan(
                        text: '${controller.completedCount}',
                        children: [
                          TextSpan(
                            text: ' / ${controller.totalCount}',
                            style: text.bodyMedium?.copyWith(
                              color: c.textSecondary,
                              fontFeatures: MiriaFonts.tabular,
                            ),
                          ),
                        ],
                      ),
                      '已完成',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Semantics(
            label: '完成进度',
            value: '${(progress * 100).round()}%',
            child: LinearProgressIndicator(
              key: const ValueKey('records-completion-progress'),
              value: progress,
              minHeight: 4,
              color: c.primary,
              backgroundColor: c.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller, required this.filters});

  final PilgrimagePlanController controller;
  final RecordsFilterController filters;

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan;
    final workIds = filters.workIds;
    final groupIds = filters.groupIds;
    return Wrap(
      spacing: Space.x2,
      runSpacing: Space.x2,
      children: [
        Builder(
          builder: (anchor) => _FilterPill(
            key: const ValueKey('records-status-filter'),
            icon: Symbols.check_circle_rounded,
            label: filters.status == RecordStatusFilter.all
                ? '全部状态'
                : filters.status.label,
            active: filters.status != RecordStatusFilter.all,
            tooltip: '按状态筛选',
            onTap: () async {
              final picked = await showAdaptiveMenu<RecordStatusFilter>(
                context,
                title: '选择状态',
                anchor: anchor,
                items: [
                  for (final status in RecordStatusFilter.values)
                    AdaptiveMenuItem(
                      label: status.label,
                      value: status,
                      checked: status == filters.status,
                    ),
                ],
              );
              if (picked != null) filters.status = picked;
            },
          ),
        ),
        _FilterPill(
          key: const ValueKey('records-work-filter'),
          icon: Symbols.movie_rounded,
          label: workIds == null ? '作品' : '作品 · ${workIds.length}',
          active: workIds != null,
          tooltip: '按作品筛选',
          onTap: () async {
            final picked = await _showScopeSheet(
              context,
              noun: '作品',
              options: [
                for (final work in plan.works)
                  _ScopeOption(id: work.id, label: work.title),
              ],
              selected: workIds ?? const {},
            );
            if (picked != null) filters.setWorkIds(picked);
          },
        ),
        _FilterPill(
          key: const ValueKey('records-group-filter'),
          icon: Symbols.folder_rounded,
          label: groupIds == null ? '片区' : '片区 · ${groupIds.length}',
          active: groupIds != null,
          tooltip: '按片区筛选',
          onTap: () async {
            final picked = await _showScopeSheet(
              context,
              noun: '片区',
              options: [
                for (final group in sortGroupsByPlanOrder(plan.groups))
                  _ScopeOption(id: group.id, label: group.name),
                const _ScopeOption(id: kUngroupedRecordFilterId, label: '未分组'),
                const _ScopeOption(id: kOrphanRecordFilterId, label: '孤立记录'),
              ],
              selected: groupIds ?? const {},
            );
            if (picked != null) filters.setGroupIds(picked);
          },
        ),
        if (filters.hasActiveFilters)
          _FilterPill(
            key: const ValueKey('records-reset-filters'),
            icon: Symbols.filter_alt_off_rounded,
            label: '重置筛选',
            active: false,
            tooltip: '重置筛选',
            onTap: filters.resetFilters,
          ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = active ? c.onPrimaryContainer : c.textPrimary;
    return Tooltip(
      message: tooltip,
      child: MiriaPressable(
        onTap: onTap,
        borderRadius: Radii.pillAll,
        semanticLabel: '$tooltip：$label',
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: Space.x3),
          decoration: BoxDecoration(
            color: active ? c.primaryContainer : c.surface,
            borderRadius: Radii.pillAll,
            border: Border.all(color: active ? c.primary : c.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground, fill: active ? 1 : 0),
              const SizedBox(width: Space.x1 + 2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(color: foreground),
                ),
              ),
              const SizedBox(width: Space.x1),
              Icon(Symbols.expand_more_rounded, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeOption {
  const _ScopeOption({required this.id, required this.label});
  final String id;
  final String label;
}

Future<Set<String>?> _showScopeSheet(
  BuildContext context, {
  required String noun,
  required List<_ScopeOption> options,
  required Set<String> selected,
}) {
  return showAdaptiveSheet<Set<String>>(
    context,
    title: '选择$noun',
    builder: (context) =>
        _ScopeSheet(noun: noun, options: options, initial: selected),
  );
}

class _ScopeSheet extends StatefulWidget {
  const _ScopeSheet({
    required this.noun,
    required this.options,
    required this.initial,
  });

  final String noun;
  final List<_ScopeOption> options;
  final Set<String> initial;

  @override
  State<_ScopeSheet> createState() => _ScopeSheetState();
}

class _ScopeSheetState extends State<_ScopeSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ListRow(
          key: ValueKey('records-scope-all-${widget.noun}'),
          title: '全部${widget.noun}',
          leading: Icon(
            _selected.isEmpty
                ? Symbols.radio_button_checked_rounded
                : Symbols.radio_button_unchecked_rounded,
            color: _selected.isEmpty ? c.primary : c.textTertiary,
          ),
          selected: _selected.isEmpty,
          borderRadius: Radii.smAll,
          onTap: () => setState(_selected.clear),
        ),
        if (widget.options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x6),
            child: Text(
              '暂无可筛选项',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          )
        else
          for (final option in widget.options)
            ListRow(
              key: ValueKey('records-scope-option-${option.id}'),
              title: option.label,
              titleLocale: MiriaFonts.japanese,
              selected: _selected.contains(option.id),
              borderRadius: Radii.smAll,
              leading: Icon(
                _selected.contains(option.id)
                    ? Symbols.check_box_rounded
                    : Symbols.check_box_outline_blank_rounded,
                fill: _selected.contains(option.id) ? 1 : 0,
                color: _selected.contains(option.id)
                    ? c.primary
                    : c.textTertiary,
              ),
              onTap: () => setState(() {
                if (!_selected.add(option.id)) _selected.remove(option.id);
              }),
            ),
        const SizedBox(height: Space.x3),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.x3,
          runSpacing: Space.x2,
          children: [
            Text(
              '已选择 ${_selected.length} 个${widget.noun}',
              style: text.bodyMedium?.copyWith(color: c.textSecondary),
            ),
            MiriaButton(
              key: ValueKey('records-scope-confirm-${widget.noun}'),
              label: _selected.isEmpty ? '确定' : '确定（${_selected.length}）',
              onPressed: () => Navigator.of(context).pop({..._selected}),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotosHeader extends StatelessWidget {
  const _PhotosHeader({required this.visibleCount, required this.totalCount});

  final int visibleCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final suffix = visibleCount == totalCount
        ? '$totalCount'
        : '$visibleCount/$totalCount';
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text('巡礼照片', style: text.titleMedium),
          ),
        ),
        Text(suffix, style: text.caption),
      ],
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SectionHeaderDelegate({
    required this.section,
    required this.expanded,
    required this.gutter,
    required this.textScaler,
    required this.onToggle,
  });

  final RecordSection section;
  final bool expanded;
  final double gutter;
  final TextScaler textScaler;
  final VoidCallback onToggle;

  double get _extent =>
      (textScaler.scale(22) + textScaler.scale(16) + 26).clamp(64.0, 160.0);

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _SectionHeader(
      section: section,
      expanded: expanded,
      gutter: gutter,
      elevated: overlapsContent || shrinkOffset > 0,
      onToggle: onToggle,
    );
  }

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) {
    return section != oldDelegate.section ||
        expanded != oldDelegate.expanded ||
        gutter != oldDelegate.gutter ||
        textScaler != oldDelegate.textScaler;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.section,
    required this.expanded,
    required this.gutter,
    required this.elevated,
    required this.onToggle,
  });

  final RecordSection section;
  final bool expanded;
  final double gutter;
  final bool elevated;
  final VoidCallback onToggle;

  IconData get _icon => switch (section.kind) {
    RecordSectionKind.group => Symbols.folder_rounded,
    RecordSectionKind.ungrouped => Symbols.inventory_2_rounded,
    RecordSectionKind.orphan => Symbols.link_off_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return DecoratedBox(
      key: ValueKey('records-group-${section.id}'),
      decoration: BoxDecoration(
        color: c.canvas,
        border: Border(
          bottom: BorderSide(
            color: elevated || !expanded ? c.hairline : c.canvas,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter - Space.x2),
        child: MiriaPressable(
          onTap: onToggle,
          borderRadius: Radii.smAll,
          semanticLabel:
              '${section.title}，${section.entries.length} 条记录，${expanded ? '已展开' : '已收起'}',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x2),
            child: Row(
              children: [
                Icon(
                  _icon,
                  size: 24,
                  color: section.kind == RecordSectionKind.orphan
                      ? c.warning
                      : c.primaryText,
                  fill: expanded ? 1 : 0,
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        section.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        locale: MiriaFonts.japanese,
                        style: text.titleMedium,
                      ),
                      Text(
                        section.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        locale: section.kind == RecordSectionKind.group
                            ? MiriaFonts.japanese
                            : null,
                        style: text.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x2),
                CountBubble(
                  key: ValueKey('records-group-count-${section.id}'),
                  count: section.entries.length,
                  tone: MiriaTone.primary,
                ),
                const SizedBox(width: Space.x2),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: Motion.of(context, Motion.standard),
                  child: Icon(
                    Symbols.expand_more_rounded,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid card: photo (graded preferred) with a small reference inset,
/// point name, 「作品 / 集数」 and 「MM-dd HH:mm」.
class RecordGridCard extends StatelessWidget {
  const RecordGridCard({
    required this.entry,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final RecordEntry entry;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    final record = entry.record;
    final point = entry.point;
    final title = RecordQueries.cardTitle(record, point);
    final meta = RecordQueries.cardMeta(record, point);
    final time = RecordQueries.formatCapturedAt(record.capturedAt);
    return MiriaCard(
      key: ValueKey('record-card-${record.id}'),
      padding: EdgeInsets.zero,
      selected: selected,
      onTap: onTap,
      semanticLabel: '$title，$meta，$time',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RecordImage(path: RecordDetails.displayPhotoPath(record)),
                Padding(
                  padding: const EdgeInsets.all(Space.x2),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.36,
                      child: _ReferenceInset(record: record, point: point),
                    ),
                  ),
                ),
                if (record.hasColorGrading)
                  Positioned(
                    left: Space.x2,
                    top: Space.x2,
                    child: _GradedBadge(),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x3,
              Space.x2 + 2,
              Space.x3,
              Space.x3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  locale: MiriaFonts.japanese,
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  key: ValueKey('record-meta-text-${record.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  locale: MiriaFonts.japanese,
                  style: text.bodySmall,
                ),
                const SizedBox(height: Space.x1),
                Row(
                  children: [
                    Icon(
                      Symbols.schedule_rounded,
                      size: 14,
                      color: c.textTertiary,
                    ),
                    const SizedBox(width: Space.x1),
                    Flexible(
                      child: Text(
                        time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.caption,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceInset extends StatelessWidget {
  const _ReferenceInset({required this.record, required this.point});

  final PilgrimageVisitRecord record;
  final PilgrimagePoint? point;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: Radii.xsAll,
          border: Border.all(color: c.surface, width: 1.5),
          boxShadow: Elevations.level1(c),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xs - 1),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: RecordReferenceThumbnail(
              localPath:
                  point?.referenceThumbnailPath ?? record.referenceImagePath,
              url: record.referenceImageUrl ?? point?.referenceImageUrl,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: '已调色',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceOverlay,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.x1),
          child: Icon(
            Symbols.auto_fix_high_rounded,
            size: 16,
            color: c.primaryText,
          ),
        ),
      ),
    );
  }
}

/// Compact list row variant of [RecordGridCard].
class RecordListTile extends StatelessWidget {
  const RecordListTile({
    required this.entry,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  final RecordEntry entry;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final record = entry.record;
    final point = entry.point;
    final meta = RecordQueries.cardMeta(record, point);
    final time = RecordQueries.formatCapturedAt(record.capturedAt);
    return MiriaCard(
      key: ValueKey('record-card-${record.id}'),
      padding: const EdgeInsets.all(Space.x2),
      selected: selected,
      onTap: onTap,
      semanticLabel: '${RecordQueries.cardTitle(record, point)}，$meta，$time',
      child: Row(
        children: [
          ClipRRect(
            borderRadius: Radii.smAll,
            child: SizedBox(
              width: 96,
              height: 72,
              child: RecordImage(path: RecordDetails.displayPhotoPath(record)),
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  RecordQueries.cardTitle(record, point),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  locale: MiriaFonts.japanese,
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  locale: MiriaFonts.japanese,
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(time, style: context.text.caption),
              ],
            ),
          ),
          if (record.hasColorGrading) ...[
            const SizedBox(width: Space.x2),
            Tooltip(
              message: '已调色',
              child: Icon(
                Symbols.auto_fix_high_rounded,
                size: 18,
                color: context.colors.primaryText,
              ),
            ),
          ],
          Icon(
            Symbols.chevron_right_rounded,
            color: context.colors.textTertiary,
          ),
        ],
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
        ? Symbols.search_off_rounded
        : hasFilterResult
        ? Symbols.filter_list_off_rounded
        : Symbols.photo_library_rounded;
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

    final showClear = hasSearchQuery;
    final showReset = (hasSearchQuery || hasFilterResult) && hasActiveFilters;
    return Semantics(
      liveRegion: true,
      child: EmptyState(
        key: const ValueKey('records-empty-state'),
        icon: icon,
        title: title,
        message: description,
        actionLabel: showClear ? '清除搜索' : (showReset ? '重置筛选' : null),
        actionIcon: showClear
            ? Symbols.close_rounded
            : (showReset ? Symbols.filter_alt_off_rounded : null),
        onAction: showClear
            ? onClearSearch
            : (showReset ? onResetFilters : null),
        secondaryActionLabel: showClear && showReset ? '重置筛选' : null,
        onSecondaryAction: showClear && showReset ? onResetFilters : null,
      ),
    );
  }
}
