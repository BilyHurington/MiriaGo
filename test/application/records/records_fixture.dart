import 'package:latlong2/latlong.dart';
import 'package:miriago/application/records/record_query.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

const workA = PilgrimageWork(
  id: 'work-a',
  title: '吹响吧！上低音号',
  subtitle: '響け！ユーフォニアム',
  city: '宇治',
  source: WorkSource.bangumi,
  bangumiId: 115908,
);

const workB = PilgrimageWork(
  id: 'work-b',
  title: '冰菓',
  subtitle: '氷菓',
  city: '高山',
  source: WorkSource.manual,
);

final groupUji = PilgrimagePlanGroup(
  id: 'g-uji',
  name: '宇治站附近',
  orderIndex: 1,
  anchorName: 'JR 宇治站',
  createdAt: DateTime(2026),
);

final groupMountain = PilgrimagePlanGroup(
  id: 'g-mountain',
  name: '大吉山',
  orderIndex: 0,
  createdAt: DateTime(2026),
);

const pointBridge = PilgrimagePoint(
  id: 'p-bridge',
  work: workA,
  name: '宇治橋',
  subtitle: '京阪宇治駅前',
  position: LatLng(34.8894123, 135.8077456),
  episodeLabel: 'EP1 / 12:30',
  referenceLabel: 'OP',
  sourceId: 'anitabi-001',
  sourceUrl: 'https://anitabi.cn/map?p=1',
  referenceImageUrl: 'https://image.anitabi.cn/points/1.jpg',
  groupId: 'g-uji',
);

const pointPeak = PilgrimagePoint(
  id: 'p-peak',
  work: workA,
  name: '大吉山展望台',
  subtitle: '山頂',
  position: LatLng(34.8912, 135.8111),
  episodeLabel: 'EP8',
  referenceLabel: '',
  groupId: 'g-mountain',
);

const pointLoose = PilgrimagePoint(
  id: 'p-loose',
  work: workB,
  name: '高山陣屋',
  subtitle: '',
  position: PilgrimagePoint.pendingPosition,
  episodeLabel: '',
  referenceLabel: '',
);

final testPlan = PilgrimagePlan(
  id: 'plan-1',
  name: '京都',
  area: '宇治',
  works: const [workA, workB],
  groups: [groupUji, groupMountain],
  points: const [pointBridge, pointPeak, pointLoose],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  completedPointIds: const {'p-bridge'},
);

PilgrimageVisitRecord makeRecord(
  String id, {
  required String pointId,
  String workId = 'work-a',
  DateTime? capturedAt,
  String? pointName,
  String? workTitle,
  String? pointSubtitle,
  String referenceMode = '叠影',
  String? referenceImagePath,
  String? referenceImageUrl,
  String? gradedPhotoPath,
  String? colorGradingParamsJson,
  double? colorGradingIntensity,
  String? colorGradingMode,
}) {
  return PilgrimageVisitRecord(
    id: id,
    planId: 'plan-1',
    pointId: pointId,
    workId: workId,
    workTitle: workTitle,
    pointName: pointName,
    pointSubtitle: pointSubtitle,
    photoPath: 'photos/$id.jpg',
    gradedPhotoPath: gradedPhotoPath,
    colorGradingParamsJson: colorGradingParamsJson,
    colorGradingIntensity: colorGradingIntensity,
    colorGradingMode: colorGradingMode,
    referenceImagePath: referenceImagePath,
    referenceImageUrl: referenceImageUrl,
    referenceMode: referenceMode,
    capturedAt: capturedAt ?? DateTime(2026, 6, 1, 9),
  );
}

final testRecords = [
  makeRecord(
    'r-bridge-old',
    pointId: 'p-bridge',
    capturedAt: DateTime(2026, 6, 1, 9, 12),
  ),
  makeRecord(
    'r-bridge-new',
    pointId: 'p-bridge',
    capturedAt: DateTime(2026, 6, 1, 10, 5),
  ),
  makeRecord(
    'r-peak',
    pointId: 'p-peak',
    capturedAt: DateTime(2026, 6, 1, 8),
    referenceMode: '上下',
  ),
  makeRecord(
    'r-loose',
    pointId: 'p-loose',
    workId: 'work-b',
    capturedAt: DateTime(2026, 6, 2, 8),
  ),
  makeRecord(
    'r-orphan',
    pointId: 'p-gone',
    workId: 'work-gone',
    pointName: '消えた場所',
    workTitle: '旧作品',
    pointSubtitle: '旧副标题',
    capturedAt: DateTime(2026, 6, 3, 8),
  ),
];

RecordsSource testSource({
  PilgrimagePlan? plan,
  List<PilgrimageVisitRecord>? records,
}) {
  final resolvedPlan = plan ?? testPlan;
  return RecordsSource(
    plan: resolvedPlan,
    records: records ?? testRecords,
    pointById: (id) =>
        resolvedPlan.points.where((point) => point.id == id).firstOrNull,
    statusFor: (point) => resolvedPlan.completedPointIds.contains(point.id)
        ? VisitStatus.completed
        : VisitStatus.pending,
  );
}
