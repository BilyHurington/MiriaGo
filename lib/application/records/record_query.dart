import 'package:flutter/foundation.dart';

import '../../plan/pilgrimage_models.dart';
import '../../plan/pilgrimage_plan_controller.dart';
import '../../plan/plan_group_utils.dart';

/// Status filter of the records page (old `_RecordStatusFilter`).
enum RecordStatusFilter {
  all('全部'),
  completed('已完成'),
  pending('未完成');

  const RecordStatusFilter(this.label);
  final String label;
}

/// Pseudo group ids used by the 片区 filter and the section ids.
const String kUngroupedRecordFilterId = '__ungrouped__';
const String kOrphanRecordFilterId = '__orphan__';

enum RecordSectionKind { group, ungrouped, orphan }

@immutable
class RecordEntry {
  const RecordEntry({required this.record, required this.point});

  final PilgrimageVisitRecord record;

  /// Null for an orphan record (its point is no longer in the plan).
  final PilgrimagePoint? point;
}

@immutable
class RecordSection {
  const RecordSection({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.entries,
  });

  final String id;
  final RecordSectionKind kind;
  final String title;
  final String subtitle;
  final List<RecordEntry> entries;
}

/// Read-only view of the data the queries need.
@immutable
class RecordsSource {
  const RecordsSource({
    required this.plan,
    required this.records,
    required this.pointById,
    required this.statusFor,
  });

  factory RecordsSource.fromController(PilgrimagePlanController controller) {
    return RecordsSource(
      plan: controller.plan,
      records: controller.visitRecords,
      pointById: controller.pointById,
      statusFor: controller.statusFor,
    );
  }

  final PilgrimagePlan plan;
  final List<PilgrimageVisitRecord> records;
  final PilgrimagePoint? Function(String id) pointById;
  final VisitStatus Function(PilgrimagePoint point) statusFor;
}

/// Pure record queries ported line by line from the old `RecordsScreen`.
abstract final class RecordQueries {
  /// Search matching of the old records screen (exact field list).
  static bool matchesSearch(
    PilgrimagePlan plan,
    PilgrimageVisitRecord record,
    PilgrimagePoint? point,
    String searchQuery,
  ) {
    final query = searchQuery.trim().toLowerCase();
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
        groupNameFor(plan, point),
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

  /// 「未分组」, the group name, or 「未知片区」.
  static String groupNameFor(PilgrimagePlan plan, PilgrimagePoint point) {
    final groupId = point.groupId;
    if (groupId == null) {
      return '未分组';
    }
    return plan.groups
            .where((group) => group.id == groupId)
            .firstOrNull
            ?.name ??
        '未知片区';
  }

  static String groupAnchorLabel(PilgrimagePlanGroup group) {
    final anchorName = group.anchorName;
    if (anchorName == null || anchorName.trim().isEmpty) {
      return '未设置关键点';
    }
    return anchorName;
  }

  static bool matchesGroupFilter(
    Set<String>? filterIds,
    PilgrimagePoint? point,
  ) {
    if (filterIds == null) {
      return true;
    }
    if (point == null) {
      return filterIds.contains(kOrphanRecordFilterId);
    }
    final groupId = point.groupId;
    if (groupId == null) {
      return filterIds.contains(kUngroupedRecordFilterId);
    }
    return filterIds.contains(groupId);
  }

  static bool matchesStatus(
    RecordStatusFilter filter,
    PilgrimagePoint? point,
    VisitStatus Function(PilgrimagePoint point) statusFor,
  ) {
    return switch (filter) {
      RecordStatusFilter.all => true,
      RecordStatusFilter.completed =>
        point != null && statusFor(point) == VisitStatus.completed,
      RecordStatusFilter.pending =>
        point == null || statusFor(point) != VisitStatus.completed,
    };
  }

  static List<PilgrimageVisitRecord> filter(
    RecordsSource source, {
    RecordStatusFilter status = RecordStatusFilter.all,
    Set<String>? workIds,
    Set<String>? groupIds,
    String searchQuery = '',
  }) {
    return source.records
        .where((record) {
          final point = source.pointById(record.pointId);
          if (workIds != null && !workIds.contains(record.workId)) {
            return false;
          }
          if (!matchesGroupFilter(groupIds, point)) {
            return false;
          }
          if (!matchesSearch(source.plan, record, point, searchQuery)) {
            return false;
          }
          return matchesStatus(status, point, source.statusFor);
        })
        .toList(growable: false);
  }

  /// Sections in plan group order, then 「未分组」 and 「孤立记录」;
  /// entries newest first.
  static List<RecordSection> group(
    RecordsSource source,
    List<PilgrimageVisitRecord> records,
  ) {
    final recordsByGroupId = <String?, List<RecordEntry>>{};
    final orphanRecords = <RecordEntry>[];

    for (final record in records) {
      final point = source.pointById(record.pointId);
      final entry = RecordEntry(record: record, point: point);
      if (point == null) {
        orphanRecords.add(entry);
        continue;
      }
      recordsByGroupId.putIfAbsent(point.groupId, () => []).add(entry);
    }

    final sections = <RecordSection>[];
    for (final group in sortGroupsByPlanOrder(source.plan.groups)) {
      final entries = recordsByGroupId[group.id];
      if (entries == null || entries.isEmpty) {
        continue;
      }
      sections.add(
        RecordSection(
          id: group.id,
          kind: RecordSectionKind.group,
          title: group.name,
          subtitle: groupAnchorLabel(group),
          entries: sortEntries(entries),
        ),
      );
    }

    final ungroupedEntries = recordsByGroupId[null];
    if (ungroupedEntries != null && ungroupedEntries.isNotEmpty) {
      sections.add(
        RecordSection(
          id: kUngroupedRecordFilterId,
          kind: RecordSectionKind.ungrouped,
          title: '未分组',
          subtitle: '还没有放入片区的记录',
          entries: sortEntries(ungroupedEntries),
        ),
      );
    }

    if (orphanRecords.isNotEmpty) {
      sections.add(
        RecordSection(
          id: kOrphanRecordFilterId,
          kind: RecordSectionKind.orphan,
          title: '孤立记录',
          subtitle: '对应点位已不在当前计划中',
          entries: sortEntries(orphanRecords),
        ),
      );
    }
    return sections;
  }

  static List<RecordEntry> sortEntries(List<RecordEntry> entries) {
    return [...entries]
      ..sort((a, b) => b.record.capturedAt.compareTo(a.record.capturedAt));
  }

  /// Keeps only ids that still exist; an empty result means "no filter".
  static Set<String>? validFilterSelection(
    Set<String>? selection,
    Set<String> validIds,
  ) {
    if (selection == null) {
      return null;
    }
    final retained = selection.intersection(validIds);
    return retained.isEmpty ? null : retained;
  }

  /// 「MM-dd HH:mm」 (record cards).
  static String formatCapturedAt(DateTime capturedAt) {
    final month = capturedAt.month.toString().padLeft(2, '0');
    final day = capturedAt.day.toString().padLeft(2, '0');
    final hour = capturedAt.hour.toString().padLeft(2, '0');
    final minute = capturedAt.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  /// 「作品 / 集数」 of a record card (old `_VisitRecordCard`).
  static String cardMeta(PilgrimageVisitRecord record, PilgrimagePoint? point) {
    final workTitle = point?.work.title ?? record.displayWorkTitleSnapshot;
    final episodeParts = point?.displayEpisodeLabel
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final episodeText = episodeParts == null || episodeParts.isEmpty
        ? ''
        : ' / ${episodeParts.join('・')}';
    return '$workTitle$episodeText';
  }

  static String cardTitle(
    PilgrimageVisitRecord record,
    PilgrimagePoint? point,
  ) => point?.name ?? record.displayPointNameSnapshot;
}

/// Filter + section-expansion state of the records page (old
/// `_RecordsScreenState` fields).
class RecordsFilterController extends ChangeNotifier {
  RecordsFilterController({String? planId}) : _scopeFilterPlanId = planId;

  Set<String>? _workIds;
  Set<String>? _groupIds;
  String? _scopeFilterPlanId;
  String _searchQuery = '';
  RecordStatusFilter _status = RecordStatusFilter.all;
  bool _expandedInitialized = false;
  final Set<String> _expandedSectionIds = {};

  Set<String>? get workIds => _workIds;
  Set<String>? get groupIds => _groupIds;
  String get searchQuery => _searchQuery;
  RecordStatusFilter get status => _status;
  Set<String> get expandedSectionIds => Set.unmodifiable(_expandedSectionIds);

  bool get hasActiveFilters =>
      _status != RecordStatusFilter.all ||
      _workIds != null ||
      _groupIds != null;

  int get activeScopeFilterCount =>
      (_workIds == null ? 0 : 1) + (_groupIds == null ? 0 : 1);

  /// Resets scope filters when the plan changes and drops ids that no
  /// longer exist. Safe to call during build (does not notify).
  void synchronize(PilgrimagePlan plan) {
    if (_scopeFilterPlanId != plan.id) {
      final first = _scopeFilterPlanId == null;
      _scopeFilterPlanId = plan.id;
      if (!first) {
        _workIds = null;
        _groupIds = null;
        _resetExpanded();
      }
      return;
    }
    final validWorkIds = plan.works.map((work) => work.id).toSet();
    _workIds = RecordQueries.validFilterSelection(_workIds, validWorkIds);
    final validGroupIds = {
      ...plan.groups.map((group) => group.id),
      kUngroupedRecordFilterId,
      kOrphanRecordFilterId,
    };
    _groupIds = RecordQueries.validFilterSelection(_groupIds, validGroupIds);
  }

  List<PilgrimageVisitRecord> apply(RecordsSource source) {
    synchronize(source.plan);
    return RecordQueries.filter(
      source,
      status: _status,
      workIds: _workIds,
      groupIds: _groupIds,
      searchQuery: _searchQuery,
    );
  }

  set searchQuery(String value) {
    if (value == _searchQuery) return;
    _searchQuery = value;
    _resetExpanded();
    notifyListeners();
  }

  set status(RecordStatusFilter value) {
    _status = value;
    _resetExpanded();
    notifyListeners();
  }

  void setWorkIds(Set<String>? ids) {
    _workIds = ids == null || ids.isEmpty ? null : {...ids};
    _resetExpanded();
    notifyListeners();
  }

  void setGroupIds(Set<String>? ids) {
    _groupIds = ids == null || ids.isEmpty ? null : {...ids};
    _resetExpanded();
    notifyListeners();
  }

  void clearSearch() => searchQuery = '';

  void resetFilters() {
    _status = RecordStatusFilter.all;
    _workIds = null;
    _groupIds = null;
    _resetExpanded();
    notifyListeners();
  }

  /// First build after a reset expands every section (old behaviour).
  void ensureExpandedInitialized(List<RecordSection> sections) {
    if (!_expandedInitialized && sections.isNotEmpty) {
      _expandedSectionIds.addAll(sections.map((section) => section.id));
      _expandedInitialized = true;
    }
  }

  bool isExpanded(String sectionId) => _expandedSectionIds.contains(sectionId);

  bool allExpanded(List<RecordSection> sections) =>
      sections.isNotEmpty &&
      sections.every((section) => _expandedSectionIds.contains(section.id));

  void toggleSection(String sectionId) {
    if (!_expandedSectionIds.add(sectionId)) {
      _expandedSectionIds.remove(sectionId);
    }
    notifyListeners();
  }

  void toggleAll(List<RecordSection> sections) {
    if (allExpanded(sections)) {
      _expandedSectionIds.clear();
    } else {
      _expandedSectionIds.addAll(sections.map((section) => section.id));
    }
    notifyListeners();
  }

  void _resetExpanded() {
    _expandedSectionIds.clear();
    _expandedInitialized = false;
  }
}

/// Order of records the user is browsing (the records page's current
/// filtered result), used by the detail page for 上一条 / 下一条.
class RecordBrowseOrder extends ValueNotifier<List<String>> {
  RecordBrowseOrder._() : super(const []);

  static final RecordBrowseOrder instance = RecordBrowseOrder._();

  void publish(List<String> ids) {
    if (listEquals(ids, value)) return;
    value = List.unmodifiable(ids);
  }

  /// Neighbour of [recordId] in [order] (falls back to [fallback] when the
  /// record is not part of the published order).
  static ({String? previous, String? next}) neighbours(
    String recordId, {
    required List<String> order,
    required List<String> fallback,
  }) {
    var ids = order;
    var index = ids.indexOf(recordId);
    if (index < 0) {
      ids = fallback;
      index = ids.indexOf(recordId);
    }
    if (index < 0) return (previous: null, next: null);
    return (
      previous: index > 0 ? ids[index - 1] : null,
      next: index < ids.length - 1 ? ids[index + 1] : null,
    );
  }
}
