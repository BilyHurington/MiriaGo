import 'dart:async';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:miriago/application/add/point_edit_service.dart';
import 'package:miriago/data/anitabi_client.dart';
import 'package:miriago/data/bangumi_api_client.dart';
import 'package:miriago/data/pilgrimage_repository.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';

/// Bangumi id of the sample plan's work.
const sampleBangumiId = 115908;

AnitabiPoint anitabiPoint(
  String id, {
  int bangumiId = sampleBangumiId,
  double lat = 34.89,
  double lng = 135.80,
  String? image = 'https://image.anitabi.cn/points/115908/$_img.jpg',
}) => AnitabiPoint(
  bangumiId: bangumiId,
  id: id,
  name: '点位 $id',
  subtitle: '宇治橋',
  position: LatLng(lat, lng),
  episodeLabel: 'EP1',
  referenceImageUrl: image,
  origin: 'Anitabi',
  originUrl: null,
);

const _img = 'x';

AnitabiBangumiLite anitabiLite({
  int bangumiId = sampleBangumiId,
  int pointsLength = 0,
  LatLng center = const LatLng(34.89, 135.80),
}) => AnitabiBangumiLite(
  bangumiId: bangumiId,
  title: '吹响吧！上低音号',
  subtitle: '響け！ユーフォニアム',
  city: '宇治市',
  center: center,
  zoom: 14,
  pointsLength: pointsLength,
);

/// In-memory Anitabi client (a subclass, so the static lite path is skipped
/// exactly like the old screen did for test doubles).
class FakeAnitabiClient extends AnitabiClient {
  FakeAnitabiClient({
    Map<int, List<AnitabiPoint>>? points,
    this.fetchError,
    this.pointsGate,
  }) : points =
           points ??
           {
             sampleBangumiId: [
               anitabiPoint('a1'),
               anitabiPoint('a2', lat: 34.891),
               anitabiPoint('a3', lat: 34.892),
             ],
           };

  final Map<int, List<AnitabiPoint>> points;
  Object? fetchError;
  Completer<void>? pointsGate;
  int clearCount = 0;
  int fetchCount = 0;
  bool globalLookupFinds = true;

  @override
  void clearStaticCache() => clearCount++;

  @override
  Future<AnitabiBangumiLite> fetchBangumiLite(int bangumiId) async =>
      anitabiLite(bangumiId: bangumiId);

  @override
  Future<List<AnitabiPoint>> fetchPoints(
    int bangumiId, {
    AnitabiBangumiLite? lite,
  }) async {
    fetchCount++;
    await pointsGate?.future;
    final error = fetchError;
    if (error != null) throw error;
    final list = points[bangumiId];
    if (list == null) throw AnitabiWorkNotFoundException(bangumiId);
    return list;
  }

  @override
  Future<AnitabiPointLookupResult?> findPointGlobally({
    required String pointId,
  }) async {
    if (!globalLookupFinds) return null;
    return _lookup(pointId);
  }

  @override
  Future<AnitabiPointLookupResult?> findPointInBangumi({
    required int bangumiId,
    required String pointId,
  }) async => _lookup(pointId, onlyBangumiId: bangumiId);

  AnitabiPointLookupResult? _lookup(String pointId, {int? onlyBangumiId}) {
    for (final entry in points.entries) {
      if (onlyBangumiId != null && entry.key != onlyBangumiId) continue;
      for (final point in entry.value) {
        if (point.id == pointId) {
          return AnitabiPointLookupResult(
            work: anitabiLite(bangumiId: entry.key),
            point: point,
            points: entry.value,
          );
        }
      }
    }
    return null;
  }
}

/// Bangumi client answering from memory.
class FakeBangumiClient extends BangumiApiClient {
  FakeBangumiClient({this.results = const [], this.error});

  List<PilgrimageWork> results;
  Object? error;
  final List<Set<BangumiSubjectType>> requestedTypes = [];
  final List<String> queries = [];

  @override
  Future<List<PilgrimageWork>> searchSubjects(
    String keyword, {
    required Set<BangumiSubjectType> types,
  }) async {
    queries.add(keyword);
    requestedTypes.add({...types});
    final error = this.error;
    if (error != null) throw error;
    return results;
  }
}

const bangumiResult = PilgrimageWork(
  id: 'bangumi-1424',
  bangumiId: 1424,
  title: '轻音少女',
  subtitle: 'けいおん！',
  city: '动画',
  source: WorkSource.bangumi,
  bangumiSubjectType: BangumiSubjectType.anime,
);

/// Sample repository whose writes can be made to fail.
class ScriptedRepository extends SamplePilgrimageRepository {
  ScriptedRepository({super.plans, super.activePlanId});

  bool failAdd = false;

  /// Writes the point, then throws (a commit whose confirmation was lost).
  bool failAfterAdd = false;
  bool failUpdate = false;
  bool failAddWork = false;
  bool failMove = false;
  int addPointCalls = 0;
  Completer<void>? addGate;

  @override
  Future<PilgrimagePlan> addPointToPlan({
    required String planId,
    required PilgrimagePoint point,
  }) async {
    addPointCalls++;
    await addGate?.future;
    if (failAdd) throw StateError('add failed');
    final plan = await super.addPointToPlan(planId: planId, point: point);
    if (failAfterAdd) throw StateError('confirmation lost');
    return plan;
  }

  @override
  Future<PilgrimagePlan> addPointsToPlan({
    required String planId,
    required List<PilgrimagePoint> points,
  }) async {
    await addGate?.future;
    if (failAdd) throw StateError('add failed');
    return super.addPointsToPlan(planId: planId, points: points);
  }

  @override
  Future<PilgrimagePlan> updatePointInPlan({
    required String planId,
    required PilgrimagePoint point,
  }) async {
    if (failUpdate) throw StateError('update failed');
    return super.updatePointInPlan(planId: planId, point: point);
  }

  @override
  Future<PilgrimagePlan> addWorkToPlan({
    required String planId,
    required PilgrimageWork work,
  }) async {
    if (failAddWork) throw StateError('add work failed');
    return super.addWorkToPlan(planId: planId, work: work);
  }

  @override
  Future<PilgrimagePlan> movePointsToGroup({
    required String planId,
    required Set<String> pointIds,
    required String? groupId,
  }) async {
    if (failMove) throw StateError('move failed');
    return super.movePointsToGroup(
      planId: planId,
      pointIds: pointIds,
      groupId: groupId,
    );
  }
}

/// Reference-image store that records every file operation.
class FakeImageStore {
  final List<StoredUserReferenceImage> stored = [];
  final List<StoredUserReferenceImage> deleted = [];
  String? nextPath = '/picked/image.jpg';
  bool failStore = false;
  bool failRead = false;
  Completer<void>? storeGate;
  var _counter = 0;

  ReferenceImageStore get store => ReferenceImageStore(
    pickPath: () async => nextPath,
    store: (path, pointId) async {
      await storeGate?.future;
      if (failStore) return null;
      _counter++;
      final image = StoredUserReferenceImage(
        thumbnailPath: '/store/$pointId-$_counter/thumb.jpg',
        fullImagePath: '/store/$pointId-$_counter/full.jpg',
      );
      stored.add(image);
      return image;
    },
    delete: (image) async => deleted.add(image),
    readThumbnail: (image) async {
      if (failRead) throw StateError('read failed');
      return Uint8List.fromList(const [1, 2, 3]);
    },
  );
}

/// The group used by the organize tests.
Future<PilgrimagePlanGroup> firstGroup(PilgrimageRepository repository) async =>
    (await repository.loadActivePlan()).groups.first;
