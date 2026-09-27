import '../../plan/pilgrimage_models.dart';

/// Read-only facts about a plan used by the 计划 workspace (overview,
/// switcher, plan library, works). Pure functions, no widgets.

/// Works of [plan] plus works only referenced by its points, in the old
/// `WorkManagerScreen._worksForPlan` order (plan works first; a point's
/// copy of a work replaces the plan entry but keeps its position).
List<PilgrimageWork> worksForPlan(PilgrimagePlan plan) {
  final worksById = <String, PilgrimageWork>{};
  for (final work in plan.works) {
    worksById[work.id] = work;
  }
  for (final point in plan.points) {
    worksById[point.work.id] = point.work;
  }
  return worksById.values.toList(growable: false);
}

/// Works shown on plan cards (old `PlanManagerScreen._works`): the plan's
/// own works, or the works referenced by points when it has none.
List<PilgrimageWork> planCardWorks(PilgrimagePlan plan) {
  if (plan.works.isNotEmpty) return plan.works;
  final worksById = <String, PilgrimageWork>{};
  for (final point in plan.points) {
    worksById[point.work.id] = point.work;
  }
  return worksById.values.toList(growable: false);
}

/// Number of points that belong to [workId].
int pointCountForWork(PilgrimagePlan plan, String workId) =>
    plan.points.where((point) => point.work.id == workId).length;

/// Points not assigned to any group (the 「未分组 / 待整理」 bucket).
int ungroupedPointCount(PilgrimagePlan plan) =>
    plan.points.where((point) => point.groupId == null).length;

/// Completed points that still exist in the plan.
int completedPointCount(PilgrimagePlan plan) => plan.points
    .where((point) => plan.completedPointIds.contains(point.id))
    .length;

/// Completion ratio 0–1 (0 for an empty plan).
double planProgress(PilgrimagePlan plan) {
  final total = plan.points.length;
  if (total == 0) return 0;
  return completedPointCount(plan) / total;
}

/// First Bangumi work of the plan (plan works first, then point works).
PilgrimageWork? firstBangumiWork(PilgrimagePlan plan) {
  for (final work in worksForPlan(plan)) {
    if (work.bangumiId != null) return work;
  }
  return null;
}

/// 「宇治市  /  27 个点位  /  1 部作品」 (old plan card summary).
String planSummaryText(PilgrimagePlan plan) =>
    '${plan.area}  /  ${plan.points.length} 个点位  /  '
    '${planCardWorks(plan).length} 部作品';

/// Multi-line 「计划信息」 copied from a plan card.
String planInfoCopyText(PilgrimagePlan plan) =>
    '${plan.name}\n${plan.area}\n${plan.points.length} 个点位\n'
    '${planCardWorks(plan).length} 部作品';

/// Original title of [work], or null when it only repeats the title or is
/// one of the old placeholders (old `_WorkManageCard.showSubtitle`).
String? workOriginalTitle(PilgrimageWork work) {
  final subtitle = work.subtitle.trim();
  final show =
      subtitle.isNotEmpty &&
      subtitle != work.title.trim() &&
      !subtitle.startsWith('Bangumi #') &&
      subtitle != 'Manual Work' &&
      subtitle != '暂无作品原名';
  return show ? subtitle : null;
}

/// 「作品信息」 copied from a work card: title and original title.
String workInfoCopyText(PilgrimageWork work) => [
  work.title,
  ?workOriginalTitle(work),
].where((value) => value.trim().isNotEmpty).join('\n');

/// First meaningful line of a Markdown memo with list/heading/quote/task
/// markers removed, for one-line previews. Null when the memo is empty.
String? memoPreviewLine(String memo, {int maxLength = 60}) {
  final prefix = RegExp(r'^\s*(?:>\s*)*(?:#{1,6}\s+|[-*+]\s+|\d+[.)]\s+)?');
  final task = RegExp(r'^\[[ xX]\]\s+');
  for (final raw in memo.split('\n')) {
    var line = raw.trim();
    if (line.isEmpty || RegExp(r'^([-*_]\s*){3,}$').hasMatch(line)) continue;
    if (line.startsWith('```')) continue;
    line = line.replaceFirst(prefix, '');
    line = line.replaceFirst(task, '');
    line = line
        .replaceAll(RegExp(r'\*\*|__|`'), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]*)\]\([^)]*\)'),
          (match) => match[1] ?? '',
        )
        .trim();
    if (line.isEmpty) continue;
    if (line.length > maxLength) {
      return '${line.substring(0, maxLength)}…';
    }
    return line;
  }
  return null;
}

/// Counts shown on the overview stats card.
class PlanStats {
  const PlanStats({
    required this.groups,
    required this.points,
    required this.works,
    required this.records,
    required this.completed,
  });

  factory PlanStats.of(PilgrimagePlan plan, {required int records}) =>
      PlanStats(
        groups: plan.groups.length,
        points: plan.points.length,
        works: worksForPlan(plan).length,
        records: records,
        completed: completedPointCount(plan),
      );

  final int groups;
  final int points;
  final int works;
  final int records;
  final int completed;

  double get progress => points == 0 ? 0 : completed / points;
}

/// 「出发前准备」 checklist state. The backup item is only a suggestion and
/// never counts as pending (there is no "last exported" field).
class PlanReadiness {
  const PlanReadiness({
    required this.ungroupedPoints,
    required this.uncachedReferences,
  });

  factory PlanReadiness.of(
    PilgrimagePlan plan, {
    required int uncachedReferences,
  }) => PlanReadiness(
    ungroupedPoints: ungroupedPointCount(plan),
    uncachedReferences: uncachedReferences,
  );

  final int ungroupedPoints;
  final int uncachedReferences;

  bool get hasUngrouped => ungroupedPoints > 0;
  bool get hasUncached => uncachedReferences > 0;

  /// Number of items that still need attention.
  int get pendingCount => (hasUngrouped ? 1 : 0) + (hasUncached ? 1 : 0);

  bool get isReady => pendingCount == 0;
}
