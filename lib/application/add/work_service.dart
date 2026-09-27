import 'package:flutter/foundation.dart';

import '../../data/bangumi_api_client.dart';
import '../../plan/pilgrimage_models.dart';
import '../plan_session.dart';
import 'add_dependencies.dart';

/// Bangumi subject types in the order of the old type filter / dropdown.
const List<BangumiSubjectType> kBangumiSubjectTypes = [
  BangumiSubjectType.anime,
  BangumiSubjectType.game,
  BangumiSubjectType.book,
  BangumiSubjectType.music,
  BangumiSubjectType.real,
];

/// Default Bangumi search filter (old: 动画 + 游戏).
const Set<BangumiSubjectType> kDefaultBangumiSearchTypes = {
  BangumiSubjectType.anime,
  BangumiSubjectType.game,
};

/// Fallback original title of a work (old: 「暂无作品原名」).
const String kNoWorkSubtitle = '暂无作品原名';

/// Toggles [type] in [selected], keeping at least one type selected
/// (old `_BangumiTypeFilter._toggleType`). Returns [selected] unchanged when
/// the last selected type would be removed.
Set<BangumiSubjectType> toggleBangumiSearchType(
  Set<BangumiSubjectType> selected,
  BangumiSubjectType type,
) {
  final next = {...selected};
  if (selected.contains(type)) {
    if (next.length == 1) return selected;
    next.remove(type);
  } else {
    next.add(type);
  }
  return next;
}

/// Whether a Bangumi result's original title is worth showing (old
/// `_WorkResultCard`): not empty, not the title, not a 「Bangumi #」 stub.
bool showsWorkSubtitle(PilgrimageWork work) {
  final subtitle = work.subtitle.trim();
  return subtitle.isNotEmpty &&
      subtitle != work.title.trim() &&
      !subtitle.startsWith('Bangumi #');
}

/// Builds a manual work exactly like the old `ManualWorkFormScreen` /
/// `_fallbackWork`: id `manual-work-<µs>`, empty original title →
/// 「暂无作品原名」, empty area → the plan area.
PilgrimageWork buildManualWork({
  required String title,
  required String subtitle,
  required String city,
  required String planArea,
  BangumiSubjectType? subjectType,
  DateTime? now,
}) {
  final time = now ?? DateTime.now();
  final trimmedSubtitle = subtitle.trim();
  final trimmedCity = city.trim();
  return PilgrimageWork(
    id: 'manual-work-${time.microsecondsSinceEpoch}',
    title: title.trim(),
    subtitle: trimmedSubtitle.isEmpty ? kNoWorkSubtitle : trimmedSubtitle,
    city: trimmedCity.isEmpty ? planArea : trimmedCity,
    source: WorkSource.manual,
    bangumiSubjectType: subjectType,
  );
}

/// Work writes for the active plan.
class WorkService {
  WorkService(this.session);

  final PlanSession session;

  /// Adds [work] to the active plan. Returns the old toast.
  Future<AddNotice> addWork(PilgrimageWork work) async {
    try {
      await session.mutate(
        (repository, planId) =>
            repository.addWorkToPlan(planId: planId, work: work),
      );
      return AddNotice(AddNoticeKind.success, '已添加「${work.title}」。');
    } catch (_) {
      return const AddNotice(AddNoticeKind.error, '作品添加失败，请稍后重试。');
    }
  }

  /// Saves a manual work (old `ManualWorkFormScreen._saveWork`). Returns the
  /// saved work, or null with the failure toast.
  Future<({PilgrimageWork? work, AddNotice notice})> saveManualWork({
    required String title,
    required String subtitle,
    required String city,
    required BangumiSubjectType subjectType,
    DateTime? now,
  }) async {
    try {
      final work = buildManualWork(
        title: title,
        subtitle: subtitle,
        city: city,
        planArea: session.plan.area,
        subjectType: subjectType,
        now: now,
      );
      await session.mutate(
        (repository, planId) =>
            repository.addWorkToPlan(planId: planId, work: work),
      );
      return (
        work: work,
        notice: AddNotice(AddNoticeKind.success, '已添加「${work.title}」。'),
      );
    } catch (_) {
      return (
        work: null,
        notice: const AddNotice(AddNoticeKind.error, '作品保存失败，请稍后重试。'),
      );
    }
  }
}

/// State of the Bangumi search page (old `BangumiWorkSearchScreenState`).
class BangumiSearchController extends ChangeNotifier {
  BangumiSearchController({required this.session, BangumiApiClient? client})
    : client = client ?? AddDependencies.bangumiClient();

  final PlanSession session;
  final BangumiApiClient client;

  List<PilgrimageWork> _results = const [];
  Set<BangumiSubjectType> _selectedTypes = kDefaultBangumiSearchTypes;
  Object? _error;
  bool _isSearching = false;
  bool _isAdding = false;
  bool _didAdd = false;
  bool _typeFilterExpanded = true;
  bool _hasSearched = false;
  final Set<String> _addedWorkIds = {};
  bool _disposed = false;

  List<PilgrimageWork> get results => _results;
  Set<BangumiSubjectType> get selectedTypes => _selectedTypes;
  Object? get error => _error;
  bool get isSearching => _isSearching;
  bool get isAdding => _isAdding;
  bool get didAdd => _didAdd;
  bool get typeFilterExpanded => _typeFilterExpanded;

  /// True once a search finished (used for the 「没有结果」 hint).
  bool get hasSearched => _hasSearched;

  void toggleType(BangumiSubjectType type) {
    final next = toggleBangumiSearchType(_selectedTypes, type);
    if (identical(next, _selectedTypes)) return;
    _selectedTypes = next;
    _notify();
  }

  /// Replaces the selection; an empty set is ignored (at least one type).
  void setTypes(Set<BangumiSubjectType> types) {
    if (types.isEmpty || setEquals(types, _selectedTypes)) return;
    _selectedTypes = {...types};
    _notify();
  }

  void toggleTypeFilter() {
    _typeFilterExpanded = !_typeFilterExpanded;
    _notify();
  }

  Future<void> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty || _isSearching) return;

    _isSearching = true;
    _error = null;
    _typeFilterExpanded = false;
    _notify();

    try {
      final results = await client.searchSubjects(query, types: _selectedTypes);
      if (_disposed) return;
      _results = results;
    } catch (error) {
      if (_disposed) return;
      _error = error;
      _results = const [];
    } finally {
      if (!_disposed) {
        _isSearching = false;
        _hasSearched = true;
        _notify();
      }
    }
  }

  /// Whether [work] is already in the plan (or was added here).
  bool hasWork(PilgrimageWork work) =>
      _addedWorkIds.contains(work.id) ||
      (session.isReady &&
          session.plan.works.any((candidate) => candidate.id == work.id));

  /// Adds [work]; returns null when another add is still running.
  Future<AddNotice?> addWork(PilgrimageWork work) async {
    if (_isAdding) return null;
    _isAdding = true;
    _notify();
    try {
      final notice = await WorkService(session).addWork(work);
      if (!_disposed && notice.kind == AddNoticeKind.success) {
        _didAdd = true;
        _addedWorkIds.add(work.id);
      }
      return notice;
    } finally {
      if (!_disposed) {
        _isAdding = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
