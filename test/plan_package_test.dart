import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan_transfer/plan_package.dart';

void main() {
  test('encodes and decodes plan package data', () async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final point = plan.points.first;
    final record = await repository.createVisitRecord(
      planId: plan.id,
      pointId: point.id,
      workId: point.work.id,
      workTitle: point.work.title,
      workSubtitle: point.work.subtitle,
      pointName: point.name,
      pointSubtitle: point.subtitle,
      photoPath: '/tmp/photo.jpg',
      referenceImagePath: '/tmp/reference.jpg',
      referenceImageUrl: 'https://example.com/reference.jpg',
      referenceMode: '叠影',
    );

    final originalWork = plan.works.first;
    final workWithCover = PilgrimageWork(
      id: originalWork.id,
      bangumiId: originalWork.bangumiId,
      bangumiSubjectType: BangumiSubjectType.anime,
      coverImageUrl: 'https://lain.bgm.tv/r/200/pic/cover/test.jpg',
      title: originalWork.title,
      subtitle: originalWork.subtitle,
      city: originalWork.city,
      source: originalWork.source,
    );
    final encoded = PlanPackage(
      plan: plan.copyWith(
        memo: '第一天先去宇治站，晚上整理补拍点。',
        works: [workWithCover, ...plan.works.skip(1)],
      ),
      visitRecords: [record],
    ).toJsonString();
    final decoded = PlanPackage.fromJsonString(encoded);

    expect(decoded.plan.name, plan.name);
    expect(decoded.plan.memo, '第一天先去宇治站，晚上整理补拍点。');
    expect(decoded.plan.works.first.coverImageUrl, workWithCover.coverImageUrl);
    expect(
      decoded.plan.works.first.bangumiSubjectType,
      BangumiSubjectType.anime,
    );
    expect(encoded, contains('"memo": "第一天先去宇治站，晚上整理补拍点。"'));
    expect(
      decoded.plan.points.map((point) => point.id),
      plan.points.map((p) => p.id),
    );
    expect(
      decoded.plan.works.map((work) => work.id),
      plan.works.map((w) => w.id),
    );
    expect(decoded.visitRecords, hasLength(1));
    expect(decoded.visitRecords.single.referenceMode, '叠影');
    expect(decoded.visitRecords.single.workTitle, point.work.title);
    expect(decoded.visitRecords.single.pointName, point.name);
  });

  test('decodes legacy plan packages without memo', () {
    final decoded = PlanPackage.fromJsonString('''
{
  "format": "miriago-plan",
  "version": 1,
  "exportedAt": "2026-07-01T00:00:00.000",
  "plan": {
    "id": "legacy-plan",
    "name": "Legacy Plan",
    "area": "Uji",
    "createdAt": "2026-07-01T00:00:00.000",
    "updatedAt": "2026-07-01T00:00:00.000",
    "currentPointId": null,
    "completedPointIds": [],
    "works": [
      {
        "id": "legacy-work",
        "bangumiId": 123,
        "title": "Legacy Work",
        "subtitle": "",
        "city": "Uji",
        "source": "bangumi"
      }
    ],
    "points": []
  },
  "visitRecords": []
}
''');

    expect(decoded.plan.memo, '');
    expect(decoded.plan.works.single.bangumiSubjectType, isNull);
    expect(decoded.plan.works.single.coverImageUrl, isNull);
  });

  test('keeps exported Anitabi URLs in canonical image host', () async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final sourcePoint = plan.points.first;
    final point = sourcePoint.copyWith(
      referenceImageUrl: 'https://img-tc.anitabi.cn/points/115908/demo.jpg',
    );

    final encoded = PlanPackage(
      plan: plan.copyWith(points: [point]),
      visitRecords: const [],
    ).toJsonString();
    final decoded = PlanPackage.fromJsonString(encoded);

    expect(
      decoded.plan.points.single.referenceImageUrl,
      'https://image.anitabi.cn/points/115908/demo.jpg',
    );
    expect(
      encoded,
      contains('https://image.anitabi.cn/points/115908/demo.jpg'),
    );
    expect(encoded, isNot(contains('img-tc.anitabi.cn')));
  });
}
