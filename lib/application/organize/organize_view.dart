import '../../data/reference_cache_file_stub.dart'
    if (dart.library.io) '../../data/reference_cache_file_io.dart';
import '../../plan/pilgrimage_models.dart';
import '../../plan/plan_group_utils.dart';
import '../../plan/reference_image_status.dart';

/// Id of the 「待整理」 (ungrouped) section; same as `planGroupBuckets`.
const String kInboxSectionId = 'ungrouped';

/// One section of the 片区与点位 list: a plan group or the 「待整理」 inbox.
class OrganizeSection {
  const OrganizeSection({
    required this.bucket,
    required this.points,
    required this.colorIndex,
  });

  /// The full bucket (all points, completion count).
  final PlanGroupBucket bucket;

  /// Points shown in this section (after search), in plan order.
  final List<PilgrimagePoint> points;

  /// Index of the bucket in `planGroupBuckets` (for group colours).
  final int colorIndex;

  String get id => bucket.id;
  bool get isInbox => bucket.isUngrouped;
  PilgrimagePlanGroup? get group => bucket.group;
  int get totalCount => bucket.points.length;
  int get completedCount => bucket.completedCount;
  bool get isEmpty => bucket.points.isEmpty;
  bool get isManualOrder => bucket.isManualOrder;

  /// 「关键点：X」 or 「关键点：未设置」.
  String get anchorText {
    final name = group?.anchorName?.trim();
    return name == null || name.isEmpty ? '关键点：未设置' : '关键点：$name';
  }

  /// 「无序」 / 「手动排序」.
  String get orderModeText => isManualOrder ? '手动排序' : '无序';

  /// 「2/6」.
  String get progressText => '$completedCount/$totalCount';
}

/// Whether [point] matches the search [query] (name, work, scene / place
/// description, episode). Case-insensitive; blank queries match everything.
bool pointMatchesQuery(PilgrimagePoint point, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  bool has(String? value) =>
      value != null && value.toLowerCase().contains(needle);
  return has(point.name) ||
      has(point.work.title) ||
      has(point.work.subtitle) ||
      has(point.subtitle) ||
      has(point.episodeLabel) ||
      has(point.referenceLabel);
}

/// Builds the sections of the 片区与点位 list.
///
/// - Groups in plan order; the 「待整理」 inbox first, and only while it has
///   points.
/// - [filterId] limits the list to one section ([kInboxSectionId] = inbox).
/// - With a [query], only matching points are shown and sections without
///   matches are hidden.
List<OrganizeSection> organizeSections(
  PilgrimagePlan plan,
  Set<String> completedPointIds, {
  String query = '',
  String? filterId,
}) {
  final buckets = planGroupBuckets(plan, completedPointIds);
  final searching = query.trim().isNotEmpty;
  final sections = <OrganizeSection>[];
  OrganizeSection? inbox;
  for (var index = 0; index < buckets.length; index++) {
    final bucket = buckets[index];
    if (filterId != null && bucket.id != filterId) continue;
    final points = searching
        ? bucket.points
              .where((point) => pointMatchesQuery(point, query))
              .toList(growable: false)
        : bucket.points;
    if (searching && points.isEmpty) continue;
    final section = OrganizeSection(
      bucket: bucket,
      points: points,
      colorIndex: index,
    );
    if (bucket.isUngrouped) {
      if (bucket.points.isNotEmpty) inbox = section;
    } else {
      sections.add(section);
    }
  }
  return [?inbox, ...sections];
}

/// Label of a reference image status (old cache pill).
String referenceStatusLabel(ReferenceImageStatus status) => switch (status) {
  ReferenceImageStatus.none => '无参考图',
  ReferenceImageStatus.localUpload => '本地上传',
  ReferenceImageStatus.fullCached => '已缓存',
  ReferenceImageStatus.remote => '未缓存',
};

/// Memoised reference image status per point. The "full image cached"
/// check touches the file system, so results are kept until [clear] (call
/// it when the plan changes).
class ReferenceStatusCache {
  final Map<String, (String?, String?, String?, ReferenceImageStatus)>
  _entries = {};

  ReferenceImageStatus statusFor(PilgrimagePoint point) {
    final cached = _entries[point.id];
    if (cached != null &&
        cached.$1 == point.referenceFullImagePath &&
        cached.$2 == point.referenceImageUrl &&
        cached.$3 == point.referenceThumbnailPath) {
      return cached.$4;
    }
    final status = referenceImageStatusForPoint(
      point,
      fullCacheIsCurrent: referenceFullCacheFileIsCurrent(
        path: point.referenceFullImagePath,
        imageUrl: point.referenceImageUrl,
      ),
    );
    _entries[point.id] = (
      point.referenceFullImagePath,
      point.referenceImageUrl,
      point.referenceThumbnailPath,
      status,
    );
    return status;
  }

  void clear() => _entries.clear();
}

/// 「作品 / 位置说明」 line of a point row.
String pointRowSubtitle(PilgrimagePoint point) {
  final work = point.work.title.trim();
  final place = point.subtitle.trim();
  if (work.isEmpty) return place;
  if (place.isEmpty) return work;
  return '$work / $place';
}

/// Name of the group [point] belongs to (old `_groupNameForPoint`).
String groupNameForPoint(PilgrimagePlan plan, PilgrimagePoint point) {
  final groupId = point.groupId;
  if (groupId == null) return '未分配点位';
  for (final group in plan.groups) {
    if (group.id == groupId) return group.name;
  }
  return '未知片区';
}
