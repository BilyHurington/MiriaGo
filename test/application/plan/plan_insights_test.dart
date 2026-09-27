import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:miriago/application/plan/plan_insights.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

const _bangumi = PilgrimageWork(
  id: 'w-bangumi',
  bangumiId: 1,
  title: '吹响吧！上低音号',
  subtitle: '響け！ユーフォニアム',
  city: '宇治市',
  source: WorkSource.bangumi,
);

const _manual = PilgrimageWork(
  id: 'w-manual',
  title: '手动作品',
  subtitle: '暂无作品原名',
  city: '京都',
  source: WorkSource.manual,
);

const _pointOnly = PilgrimageWork(
  id: 'w-point-only',
  title: '只在点位里',
  subtitle: 'Bangumi #3',
  city: '',
  source: WorkSource.bangumi,
);

PilgrimagePoint _point(String id, PilgrimageWork work, {String? groupId}) =>
    PilgrimagePoint(
      id: id,
      work: work,
      name: id,
      subtitle: '',
      position: const LatLng(34.9, 135.8),
      episodeLabel: '',
      referenceLabel: '',
      groupId: groupId,
    );

PilgrimagePlan _plan({
  List<PilgrimageWork> works = const [],
  List<PilgrimagePoint> points = const [],
  Set<String> completed = const {},
  String memo = '',
}) => PilgrimagePlan(
  id: 'p',
  name: '计划',
  area: '宇治市',
  memo: memo,
  works: works,
  points: points,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  completedPointIds: completed,
);

void main() {
  group('works', () {
    test('worksForPlan lists plan works then point-only works', () {
      final plan = _plan(
        works: const [_bangumi, _manual],
        points: [_point('a', _pointOnly), _point('b', _bangumi)],
      );
      expect(worksForPlan(plan).map((w) => w.id), [
        'w-bangumi',
        'w-manual',
        'w-point-only',
      ]);
      expect(pointCountForWork(plan, 'w-bangumi'), 1);
      expect(pointCountForWork(plan, 'w-manual'), 0);
    });

    test('planCardWorks falls back to point works only when plan has none', () {
      final withWorks = _plan(
        works: const [_manual],
        points: [_point('a', _pointOnly)],
      );
      expect(planCardWorks(withWorks).map((w) => w.id), ['w-manual']);
      final withoutWorks = _plan(points: [_point('a', _pointOnly)]);
      expect(planCardWorks(withoutWorks).map((w) => w.id), ['w-point-only']);
    });

    test('firstBangumiWork finds the first work with a Bangumi id', () {
      expect(firstBangumiWork(_plan(works: const [_manual])), isNull);
      expect(
        firstBangumiWork(_plan(works: const [_manual, _bangumi]))?.id,
        'w-bangumi',
      );
    });

    test('workOriginalTitle hides placeholders', () {
      expect(workOriginalTitle(_bangumi), '響け！ユーフォニアム');
      expect(workOriginalTitle(_manual), isNull);
      expect(workOriginalTitle(_pointOnly), isNull);
      expect(workInfoCopyText(_bangumi), '吹响吧！上低音号\n響け！ユーフォニアム');
      expect(workInfoCopyText(_manual), '手动作品');
    });
  });

  group('plan summary', () {
    test('summary and copy text use the old format', () {
      final plan = _plan(
        works: const [_bangumi],
        points: [_point('a', _bangumi), _point('b', _bangumi)],
      );
      expect(planSummaryText(plan), '宇治市  /  2 个点位  /  1 部作品');
      expect(planInfoCopyText(plan), '计划\n宇治市\n2 个点位\n1 部作品');
    });

    test('progress ignores completed ids of removed points', () {
      final plan = _plan(
        points: [_point('a', _bangumi), _point('b', _bangumi)],
        completed: {'a', 'gone'},
      );
      expect(completedPointCount(plan), 1);
      expect(planProgress(plan), 0.5);
      expect(planProgress(_plan()), 0);
    });
  });

  group('readiness', () {
    test('counts ungrouped points and uncached references', () {
      final plan = _plan(
        points: [
          _point('a', _bangumi, groupId: 'g'),
          _point('b', _bangumi),
          _point('c', _bangumi),
        ],
      );
      final readiness = PlanReadiness.of(plan, uncachedReferences: 4);
      expect(readiness.ungroupedPoints, 2);
      expect(readiness.pendingCount, 2);
      expect(readiness.isReady, isFalse);
    });

    test('is ready when nothing is pending (backup is only a suggestion)', () {
      final plan = _plan(points: [_point('a', _bangumi, groupId: 'g')]);
      final readiness = PlanReadiness.of(plan, uncachedReferences: 0);
      expect(readiness.pendingCount, 0);
      expect(readiness.isReady, isTrue);
    });

    test('stats count groups, points, works and records', () {
      final plan = _plan(
        works: const [_bangumi],
        points: [_point('a', _bangumi), _point('b', _pointOnly)],
        completed: {'a'},
      );
      final stats = PlanStats.of(plan, records: 5);
      expect(stats.points, 2);
      expect(stats.works, 2);
      expect(stats.records, 5);
      expect(stats.completed, 1);
      expect(stats.progress, 0.5);
    });
  });

  group('memoPreviewLine', () {
    test('returns null for empty memos', () {
      expect(memoPreviewLine(''), isNull);
      expect(memoPreviewLine('\n  \n---\n'), isNull);
    });

    test('strips markdown markers from the first meaningful line', () {
      expect(memoPreviewLine('## 行程\n- a'), '行程');
      expect(memoPreviewLine('\n- [ ] JR 奈良线 9:12 发'), 'JR 奈良线 9:12 发');
      expect(memoPreviewLine('> **注意** 天气'), '注意 天气');
      expect(memoPreviewLine('1. [官网](https://x.y) 预约'), '官网 预约');
    });

    test('truncates long lines', () {
      expect(memoPreviewLine('a' * 80, maxLength: 10), '${'a' * 10}…');
    });
  });
}
