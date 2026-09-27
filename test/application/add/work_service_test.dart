import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/add/add_dependencies.dart';
import 'package:miriago/application/add/work_service.dart';
import 'package:miriago/application/plan_session.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

import 'fakes.dart';

void main() {
  group('Bangumi type filter', () {
    test('defaults to 动画 + 游戏', () {
      expect(kDefaultBangumiSearchTypes, {
        BangumiSubjectType.anime,
        BangumiSubjectType.game,
      });
      expect(kBangumiSubjectTypes.map((t) => t.label), [
        '动画',
        '游戏',
        '书籍',
        '音乐',
        '三次元',
      ]);
    });

    test('toggling adds and removes but keeps at least one type', () {
      var types = kDefaultBangumiSearchTypes;
      types = toggleBangumiSearchType(types, BangumiSubjectType.book);
      expect(types, contains(BangumiSubjectType.book));
      types = toggleBangumiSearchType(types, BangumiSubjectType.anime);
      types = toggleBangumiSearchType(types, BangumiSubjectType.game);
      expect(types, {BangumiSubjectType.book});
      final last = toggleBangumiSearchType(types, BangumiSubjectType.book);
      expect(last, {BangumiSubjectType.book});
      expect(identical(last, types), isTrue);
    });
  });

  test('result subtitles hide empty, duplicate and 「Bangumi #」 stubs', () {
    PilgrimageWork work(String subtitle) => PilgrimageWork(
      id: 'w',
      title: '轻音少女',
      subtitle: subtitle,
      city: '',
      source: WorkSource.bangumi,
    );
    expect(showsWorkSubtitle(work('けいおん！')), isTrue);
    expect(showsWorkSubtitle(work('')), isFalse);
    expect(showsWorkSubtitle(work('轻音少女')), isFalse);
    expect(showsWorkSubtitle(work('Bangumi #1424')), isFalse);
  });

  test('manual work defaults match the old form', () {
    final now = DateTime.fromMicrosecondsSinceEpoch(42);
    final work = buildManualWork(
      title: ' 轻音少女 ',
      subtitle: ' ',
      city: '',
      planArea: '宇治市',
      subjectType: BangumiSubjectType.game,
      now: now,
    );
    expect(work.id, 'manual-work-42');
    expect(work.title, '轻音少女');
    expect(work.subtitle, '暂无作品原名');
    expect(work.city, '宇治市');
    expect(work.source, WorkSource.manual);
    expect(work.bangumiSubjectType, BangumiSubjectType.game);
    expect(work.bangumiId, isNull);
  });

  group('WorkService', () {
    late ScriptedRepository repository;
    late PlanSession session;

    setUp(() async {
      repository = ScriptedRepository();
      session = PlanSession(repository: repository);
      await session.load();
    });

    tearDown(() => session.dispose());

    test('saveManualWork writes through the session', () async {
      final result = await WorkService(session).saveManualWork(
        title: '轻音少女',
        subtitle: 'けいおん！',
        city: '京都市',
        subjectType: BangumiSubjectType.anime,
      );
      expect(
        result.notice,
        const AddNotice(AddNoticeKind.success, '已添加「轻音少女」。'),
      );
      expect(session.plan.works.map((w) => w.title), contains('轻音少女'));
      final saved = session.plan.works.firstWhere((w) => w.title == '轻音少女');
      expect(saved.id, startsWith('manual-work-'));
      expect(saved.city, '京都市');
    });

    test('saveManualWork failure uses the old toast', () async {
      repository.failAddWork = true;
      final result = await WorkService(session).saveManualWork(
        title: 'X',
        subtitle: '',
        city: '',
        subjectType: BangumiSubjectType.anime,
      );
      expect(result.work, isNull);
      expect(
        result.notice,
        const AddNotice(AddNoticeKind.error, '作品保存失败，请稍后重试。'),
      );
    });
  });

  group('BangumiSearchController', () {
    late ScriptedRepository repository;
    late PlanSession session;

    setUp(() async {
      repository = ScriptedRepository();
      session = PlanSession(repository: repository);
      await session.load();
    });

    tearDown(() => session.dispose());

    test('search collapses the filter and passes the selected types', () async {
      final client = FakeBangumiClient(results: [bangumiResult]);
      final controller = BangumiSearchController(
        session: session,
        client: client,
      );
      addTearDown(controller.dispose);
      expect(controller.typeFilterExpanded, isTrue);
      controller.toggleType(BangumiSubjectType.book);
      await controller.search('  ');
      expect(client.queries, isEmpty);
      await controller.search(' 轻音 ');
      expect(client.queries, ['轻音']);
      expect(client.requestedTypes.single, {
        BangumiSubjectType.anime,
        BangumiSubjectType.game,
        BangumiSubjectType.book,
      });
      expect(controller.typeFilterExpanded, isFalse);
      expect(controller.results, [bangumiResult]);
      expect(controller.isSearching, isFalse);
    });

    test('setTypes ignores an empty selection', () {
      final controller = BangumiSearchController(
        session: session,
        client: FakeBangumiClient(),
      );
      addTearDown(controller.dispose);
      controller.setTypes({});
      expect(controller.selectedTypes, kDefaultBangumiSearchTypes);
      controller.setTypes({BangumiSubjectType.music});
      expect(controller.selectedTypes, {BangumiSubjectType.music});
    });

    test('search failure clears results and keeps the error', () async {
      final client = FakeBangumiClient(results: [bangumiResult]);
      final controller = BangumiSearchController(
        session: session,
        client: client,
      );
      addTearDown(controller.dispose);
      await controller.search('a');
      client.error = Exception('offline');
      await controller.search('b');
      expect(controller.error, isNotNull);
      expect(controller.results, isEmpty);
    });

    test('adding a work marks it added; failures use the old toast', () async {
      final controller = BangumiSearchController(
        session: session,
        client: FakeBangumiClient(results: [bangumiResult]),
      );
      addTearDown(controller.dispose);
      expect(controller.hasWork(bangumiResult), isFalse);
      final notice = await controller.addWork(bangumiResult);
      expect(notice, const AddNotice(AddNoticeKind.success, '已添加「轻音少女」。'));
      expect(controller.hasWork(bangumiResult), isTrue);
      expect(controller.didAdd, isTrue);
      expect(session.plan.works.any((w) => w.id == bangumiResult.id), isTrue);

      repository.failAddWork = true;
      const other = PilgrimageWork(
        id: 'bangumi-2',
        bangumiId: 2,
        title: 'B',
        subtitle: '',
        city: '',
        source: WorkSource.bangumi,
      );
      final failed = await controller.addWork(other);
      expect(failed, const AddNotice(AddNoticeKind.error, '作品添加失败，请稍后重试。'));
      expect(controller.hasWork(other), isFalse);
    });
  });
}
