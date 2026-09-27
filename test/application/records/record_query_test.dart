import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/records/record_query.dart';

import 'records_fixture.dart';

List<String> ids(Iterable<dynamic> records) => [
  for (final record in records) record.id as String,
];

void main() {
  group('search matching', () {
    List<String> search(String query) =>
        ids(RecordQueries.filter(testSource(), searchQuery: query));

    test('empty or blank query matches everything', () {
      expect(search(''), hasLength(testRecords.length));
      expect(search('   '), hasLength(testRecords.length));
    });

    test('matches point, work, group and scene fields case-insensitively', () {
      expect(search('宇治橋'), ['r-bridge-old', 'r-bridge-new']);
      expect(search('京阪'), ['r-bridge-old', 'r-bridge-new']);
      expect(search('響け'), ['r-bridge-old', 'r-bridge-new', 'r-peak']);
      expect(search('宇治站附近'), ['r-bridge-old', 'r-bridge-new']);
      expect(search('ep8'), ['r-peak']);
      expect(search('ANITABI-001'), ['r-bridge-old', 'r-bridge-new']);
      expect(search('115908'), ['r-bridge-old', 'r-bridge-new', 'r-peak']);
      expect(search('高山'), ['r-loose']);
    });

    test('coordinates use 6 decimals; pending points match 坐标待补充', () {
      expect(search('34.889412'), ['r-bridge-old', 'r-bridge-new']);
      expect(search('34.8894123'), isEmpty);
      expect(search('坐标待补充'), ['r-loose']);
    });

    test('ungrouped points match 未分组', () {
      expect(search('未分组'), ['r-loose']);
    });

    test('record ids, snapshots and reference mode are searched', () {
      expect(search('r-peak'), ['r-peak']);
      expect(search('消えた'), ['r-orphan']);
      expect(search('旧副标题'), ['r-orphan']);
      expect(search('上下'), ['r-peak']);
    });
  });

  group('filters', () {
    test('status: orphan records count as not completed', () {
      expect(
        ids(
          RecordQueries.filter(
            testSource(),
            status: RecordStatusFilter.completed,
          ),
        ),
        ['r-bridge-old', 'r-bridge-new'],
      );
      expect(
        ids(
          RecordQueries.filter(
            testSource(),
            status: RecordStatusFilter.pending,
          ),
        ),
        ['r-peak', 'r-loose', 'r-orphan'],
      );
    });

    test('work and group filters include 未分组 and 孤立记录', () {
      expect(ids(RecordQueries.filter(testSource(), workIds: {'work-b'})), [
        'r-loose',
      ]);
      expect(
        ids(
          RecordQueries.filter(
            testSource(),
            groupIds: {kUngroupedRecordFilterId, kOrphanRecordFilterId},
          ),
        ),
        ['r-loose', 'r-orphan'],
      );
      expect(
        ids(RecordQueries.filter(testSource(), groupIds: {'g-mountain'})),
        ['r-peak'],
      );
    });
  });

  group('sections', () {
    test('plan group order, then 未分组 and 孤立记录, newest first', () {
      final source = testSource();
      final sections = RecordQueries.group(source, source.records);
      expect(
        [for (final s in sections) s.id],
        [
          'g-mountain',
          'g-uji',
          kUngroupedRecordFilterId,
          kOrphanRecordFilterId,
        ],
      );
      expect(sections[0].subtitle, '未设置关键点');
      expect(sections[1].subtitle, 'JR 宇治站');
      expect(ids(sections[1].entries.map((e) => e.record)), [
        'r-bridge-new',
        'r-bridge-old',
      ]);
      expect(sections[2].title, '未分组');
      expect(sections[2].subtitle, '还没有放入片区的记录');
      expect(sections[3].title, '孤立记录');
      expect(sections[3].subtitle, '对应点位已不在当前计划中');
      expect(sections[3].entries.single.point, isNull);
    });

    test('card text', () {
      final record = testRecords.first;
      expect(RecordQueries.cardTitle(record, pointBridge), '宇治橋');
      expect(
        RecordQueries.cardMeta(record, pointBridge),
        '吹响吧！上低音号 / EP1・12:30',
      );
      expect(RecordQueries.cardMeta(testRecords.last, null), '旧作品');
      expect(RecordQueries.cardTitle(testRecords.last, null), '消えた場所');
      expect(
        RecordQueries.formatCapturedAt(DateTime(2026, 6, 1, 9, 5)),
        '06-01 09:05',
      );
    });
  });

  group('RecordsFilterController', () {
    test('drops ids that no longer exist and resets on plan change', () {
      final filters = RecordsFilterController();
      filters.synchronize(testPlan);
      filters.setWorkIds({'work-a', 'work-gone'});
      filters.setGroupIds({'g-uji', kOrphanRecordFilterId, 'g-gone'});
      filters.synchronize(testPlan);
      expect(filters.workIds, {'work-a'});
      expect(filters.groupIds, {'g-uji', kOrphanRecordFilterId});
      expect(filters.activeScopeFilterCount, 2);

      filters.setWorkIds({'work-gone'});
      filters.synchronize(testPlan);
      expect(filters.workIds, isNull);

      filters.synchronize(testPlan.copyWith(id: 'plan-2'));
      expect(filters.groupIds, isNull);
      expect(filters.hasActiveFilters, isFalse);
    });

    test('search and filter changes expand every section again', () {
      final source = testSource();
      final filters = RecordsFilterController();
      final sections = RecordQueries.group(source, filters.apply(source));
      filters.ensureExpandedInitialized(sections);
      expect(filters.allExpanded(sections), isTrue);
      filters.toggleAll(sections);
      expect(filters.expandedSectionIds, isEmpty);
      filters.toggleSection('g-uji');
      expect(filters.isExpanded('g-uji'), isTrue);

      filters.searchQuery = '宇治';
      final next = RecordQueries.group(source, filters.apply(source));
      filters.ensureExpandedInitialized(next);
      expect(filters.allExpanded(next), isTrue);

      filters.status = RecordStatusFilter.completed;
      expect(filters.hasActiveFilters, isTrue);
      filters.resetFilters();
      expect(filters.hasActiveFilters, isFalse);
    });
  });

  test('browse order neighbours fall back to all records', () {
    final result = RecordBrowseOrder.neighbours(
      'b',
      order: const ['a', 'b', 'c'],
      fallback: const [],
    );
    expect(result.previous, 'a');
    expect(result.next, 'c');
    final fallback = RecordBrowseOrder.neighbours(
      'x',
      order: const ['a'],
      fallback: const ['x', 'y'],
    );
    expect(fallback.previous, isNull);
    expect(fallback.next, 'y');
  });
}
