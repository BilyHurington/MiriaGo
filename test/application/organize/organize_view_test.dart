import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/organize/organize_view.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/reference_image_status.dart';

void main() {
  final plan = samplePilgrimagePlan;

  test('inbox comes first while it has points, then groups in order', () {
    final sections = organizeSections(plan, plan.completedPointIds);
    expect(sections.first.isInbox, isTrue);
    expect(sections.first.id, kInboxSectionId);
    expect(sections.first.totalCount, 1);
    expect(sections.skip(1).map((s) => s.id).first, 'sample-group-uji-station');
    expect(sections.length, plan.groups.length + 1);
  });

  test('no inbox when every point has a group', () {
    final grouped = plan.copyWith(
      points: [
        for (final point in plan.points)
          point.copyWith(groupId: point.groupId ?? 'sample-group-uji-station'),
      ],
    );
    final sections = organizeSections(grouped, const {});
    expect(sections.any((section) => section.isInbox), isFalse);
  });

  test('filter shows one section; search hides sections without matches', () {
    final filtered = organizeSections(
      plan,
      const {},
      filterId: 'sample-group-daikichiyama',
    );
    expect(filtered.map((s) => s.id), ['sample-group-daikichiyama']);

    final searched = organizeSections(plan, const {}, query: '展望台');
    expect(searched.map((s) => s.id), ['sample-group-daikichiyama']);
    expect(
      searched.single.points.every((point) => point.name.contains('展望台')),
      isTrue,
    );
    expect(
      searched.single.totalCount,
      greaterThan(searched.single.points.length),
    );
  });

  test('search matches work titles case-insensitively', () {
    final point = plan.points.first;
    expect(pointMatchesQuery(point, point.work.title.toUpperCase()), isTrue);
    expect(pointMatchesQuery(point, '   '), isTrue);
    expect(pointMatchesQuery(point, 'zzz-no-match'), isFalse);
  });

  test('section texts', () {
    final station = organizeSections(
      plan,
      const {},
    ).firstWhere((s) => s.id == 'sample-group-uji-station');
    expect(station.anchorText, '关键点：JR 宇治站');
    expect(station.orderModeText, '无序');
    expect(station.progressText, '0/${station.totalCount}');

    final manual = organizeSections(
      plan,
      const {},
    ).firstWhere((s) => s.id == 'sample-group-daikichiyama');
    expect(manual.orderModeText, '手动排序');

    final unset = organizeSections(
      plan.copyWith(
        groups: [
          for (final group in plan.groups)
            group.copyWith(anchorName: null, anchorPointId: null),
        ],
      ),
      const {},
    ).firstWhere((s) => s.id == 'sample-group-uji-station');
    expect(unset.anchorText, '关键点：未设置');
  });

  test('reference status labels and cache', () {
    expect(referenceStatusLabel(ReferenceImageStatus.none), '无参考图');
    expect(referenceStatusLabel(ReferenceImageStatus.localUpload), '本地上传');
    expect(referenceStatusLabel(ReferenceImageStatus.fullCached), '已缓存');
    expect(referenceStatusLabel(ReferenceImageStatus.remote), '未缓存');

    final cache = ReferenceStatusCache();
    final remote = plan.points.first;
    expect(cache.statusFor(remote), ReferenceImageStatus.remote);
    final none = remote.copyWith(
      referenceImageUrl: null,
      referenceThumbnailPath: null,
      referenceFullImagePath: null,
    );
    expect(cache.statusFor(none), ReferenceImageStatus.none);
  });

  test('row subtitle and group name', () {
    final point = plan.points.first;
    expect(pointRowSubtitle(point), '${point.work.title} / ${point.subtitle}');
    final ungrouped = plan.points.firstWhere((p) => p.groupId == null);
    expect(groupNameForPoint(plan, ungrouped), '未分配点位');
    expect(groupNameForPoint(plan, point), '宇治站附近');
    expect(groupNameForPoint(plan, point.copyWith(groupId: 'gone')), '未知片区');
    expect(PilgrimagePoint.pendingPosition.latitude, -90);
  });
}
