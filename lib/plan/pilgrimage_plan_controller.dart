import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/pilgrimage_repository.dart';
import 'pilgrimage_models.dart';
import 'plan_group_utils.dart';

class PilgrimagePlanController extends ChangeNotifier {
  PilgrimagePlanController({
    required PilgrimagePlan plan,
    PilgrimageRepository? visitRepository,
  }) : _repository = visitRepository,
       _plan = plan,
       _completedPointIds = {...plan.completedPointIds},
       _currentPointId = plan.currentPointId,
       _selectedPointId = plan.points.firstOrNull?.id {
    unawaited(loadVisitRecords());
  }

  PilgrimagePlan _plan;
  final PilgrimageRepository? _repository;
  Set<String> _completedPointIds;
  List<PilgrimageVisitRecord> _visitRecords = const [];

  String? _currentPointId;
  String? _selectedPointId;

  PilgrimagePlan get plan => _plan;

  List<PilgrimagePoint> get points => _plan.points;

  PilgrimageRepository? get repository => _repository;

  PilgrimagePoint? get currentPoint => _pointById(_currentPointId);

  PilgrimagePoint? get selectedPoint => _pointById(_selectedPointId);

  PilgrimagePoint? pointById(String id) => _pointById(id);

  void replacePlan(PilgrimagePlan plan) {
    _plan = plan;
    _completedPointIds = {...plan.completedPointIds};
    _currentPointId = plan.currentPointId;
    if (_selectedPointId != null && _pointById(_selectedPointId!) == null) {
      _selectedPointId = plan.points.firstOrNull?.id;
    }
    notifyListeners();
  }

  List<PilgrimagePoint> get completedPoints => points
      .where((point) => _completedPointIds.contains(point.id))
      .toList(growable: false);

  List<PilgrimageVisitRecord> get visitRecords => _visitRecords;

  Set<String> get completedPointIds => Set.unmodifiable(_completedPointIds);

  List<PilgrimageVisitRecord> recordsForPoint(String pointId) => _visitRecords
      .where((record) => record.pointId == pointId)
      .toList(growable: false);

  int get completedCount => _completedPointIds.length;

  int get totalCount => points.length;

  bool get isPlanComplete => completedCount == totalCount;

  bool get hasPoints => points.isNotEmpty;

  VisitStatus statusFor(PilgrimagePoint point) {
    if (_completedPointIds.contains(point.id)) {
      return VisitStatus.completed;
    }

    if (point.id == _currentPointId) {
      return VisitStatus.current;
    }

    return VisitStatus.pending;
  }

  void selectPoint(PilgrimagePoint point) {
    _selectedPointId = point.id;
    notifyListeners();
  }

  void setCurrentPoint(PilgrimagePoint point) {
    if (_completedPointIds.contains(point.id)) {
      _completedPointIds.remove(point.id);
    }

    _currentPointId = point.id;
    _selectedPointId = point.id;
    _persistSetCurrent(point);
    notifyListeners();
  }

  void completePoint(PilgrimagePoint point) {
    _completedPointIds.add(point.id);

    if (point.id == _currentPointId) {
      final nextPoint = nextPendingPointAfterCompletion(
        points: points,
        completedPoint: point,
        completedPointIds: _completedPointIds,
      );
      _currentPointId = nextPoint?.id;
      _selectedPointId = nextPoint?.id ?? point.id;
    }

    _persistComplete(point);
    notifyListeners();
  }

  void reopenPoint(PilgrimagePoint point) {
    _completedPointIds.remove(point.id);
    _currentPointId = point.id;
    _selectedPointId = point.id;
    _persistReopen(point);
    notifyListeners();
  }

  Future<void> loadVisitRecords() async {
    final repository = _repository;
    if (repository == null) {
      return;
    }

    _visitRecords = await repository.loadVisitRecords(_plan.id);
    notifyListeners();
  }

  Future<PilgrimageVisitRecord?> createVisitRecord({
    required PilgrimagePoint point,
    required String photoPath,
    String? referenceImagePath,
    String? referenceImageUrl,
    required String referenceMode,
    DateTime? capturedAt,
  }) async {
    final repository = _repository;
    if (repository == null) {
      return null;
    }

    final record = await repository.createVisitRecord(
      planId: _plan.id,
      pointId: point.id,
      workId: point.work.id,
      workTitle: point.work.title,
      workSubtitle: point.work.subtitle,
      pointName: point.name,
      pointSubtitle: point.subtitle,
      photoPath: photoPath,
      referenceImagePath: referenceImagePath,
      referenceImageUrl: referenceImageUrl,
      referenceMode: referenceMode,
      capturedAt: capturedAt,
    );
    _visitRecords = [record, ..._visitRecords];
    notifyListeners();
    return record;
  }

  Future<void> updatePointImageCache(
    PilgrimagePoint point, {
    String? referenceThumbnailPath,
    String? referenceFullImagePath,
  }) async {
    final repository = _repository;
    if (repository == null) {
      return;
    }

    final updatedPlan = await repository.updatePointImageCache(
      planId: _plan.id,
      pointId: point.id,
      referenceThumbnailPath: referenceThumbnailPath,
      referenceFullImagePath: referenceFullImagePath,
    );
    _replacePlanState(updatedPlan);
  }

  Future<void> updatePointImageCaches(
    Map<String, PointImageCacheUpdate> updatesByPointId,
  ) async {
    final repository = _repository;
    if (repository == null || updatesByPointId.isEmpty) {
      return;
    }

    final updatedPlan = await repository.updatePointImageCaches(
      planId: _plan.id,
      updatesByPointId: updatesByPointId,
    );
    _replacePlanState(updatedPlan);
  }

  Future<void> updatePoint(PilgrimagePoint point) async {
    final repository = _repository;
    if (repository == null) {
      return;
    }

    final updatedPlan = await repository.updatePointInPlan(
      planId: _plan.id,
      point: point,
    );
    _replacePlanState(updatedPlan);
  }

  Future<void> updatePlanMemo(String memo) async {
    final repository = _repository;
    if (repository == null) {
      return;
    }

    final updatedPlan = await repository.updatePlanMemo(
      planId: _plan.id,
      memo: memo,
    );
    _replacePlanState(updatedPlan);
  }

  Future<void> movePointToGroup(PilgrimagePoint point, String? groupId) async {
    final repository = _repository;
    if (repository == null || point.groupId == groupId) {
      return;
    }

    final updatedPlan = await repository.movePointsToGroup(
      planId: _plan.id,
      pointIds: {point.id},
      groupId: groupId,
    );
    _replacePlanState(updatedPlan);
  }

  Future<void> deleteVisitRecord(PilgrimageVisitRecord record) async {
    final repository = _repository;
    if (repository == null) {
      return;
    }

    await repository.deleteVisitRecord(planId: _plan.id, recordId: record.id);
    _visitRecords = _visitRecords
        .where((candidate) => candidate.id != record.id)
        .toList(growable: false);
    notifyListeners();
  }

  Future<PilgrimageVisitRecord?> updateVisitRecordColorGrading({
    required PilgrimageVisitRecord record,
    required String originalPhotoPath,
    required String gradedPhotoPath,
    required String colorGradingMode,
    required String colorGradingParamsJson,
    required double colorGradingIntensity,
  }) async {
    final repository = _repository;
    if (repository == null) {
      return null;
    }

    final updated = await repository.updateVisitRecordColorGrading(
      planId: _plan.id,
      recordId: record.id,
      originalPhotoPath: originalPhotoPath,
      gradedPhotoPath: gradedPhotoPath,
      colorGradingMode: colorGradingMode,
      colorGradingParamsJson: colorGradingParamsJson,
      colorGradingIntensity: colorGradingIntensity,
    );
    _visitRecords = [
      for (final candidate in _visitRecords)
        candidate.id == updated.id ? updated : candidate,
    ];
    notifyListeners();
    return updated;
  }

  Future<PilgrimageVisitRecord?> clearVisitRecordColorGrading({
    required PilgrimageVisitRecord record,
  }) async {
    final repository = _repository;
    if (repository == null) {
      return null;
    }

    final updated = await repository.clearVisitRecordColorGrading(
      planId: _plan.id,
      recordId: record.id,
    );
    _visitRecords = [
      for (final candidate in _visitRecords)
        candidate.id == updated.id ? updated : candidate,
    ];
    notifyListeners();
    return updated;
  }

  void _persistSetCurrent(PilgrimagePoint point) {
    final repository = _repository;
    if (repository == null) {
      return;
    }

    unawaited(repository.setCurrentPoint(planId: _plan.id, pointId: point.id));
  }

  void _persistComplete(PilgrimagePoint point) {
    final repository = _repository;
    if (repository == null) {
      return;
    }

    unawaited(
      repository.completePoint(
        planId: _plan.id,
        pointId: point.id,
        nextCurrentPointId: _currentPointId,
      ),
    );
  }

  void _persistReopen(PilgrimagePoint point) {
    final repository = _repository;
    if (repository == null) {
      return;
    }

    unawaited(repository.reopenPoint(planId: _plan.id, pointId: point.id));
  }

  PilgrimagePoint? _pointById(String? id) {
    if (id == null || points.isEmpty) {
      return null;
    }

    return points.firstWhere(
      (point) => point.id == id,
      orElse: () => points.first,
    );
  }

  void _replacePlanState(PilgrimagePlan updatedPlan) {
    _plan = updatedPlan;
    _completedPointIds = {...updatedPlan.completedPointIds};
    _currentPointId = updatedPlan.currentPointId;
    _selectedPointId =
        updatedPlan.points.any((point) => point.id == _selectedPointId)
        ? _selectedPointId
        : updatedPlan.currentPointId;
    notifyListeners();
  }
}
