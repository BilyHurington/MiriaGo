import 'package:flutter/foundation.dart';

import 'pilgrimage_models.dart';

class PilgrimagePlanController extends ChangeNotifier {
  PilgrimagePlanController({required PilgrimagePlan plan})
    : assert(plan.points.isNotEmpty, 'A pilgrimage plan requires points.'),
      _plan = plan,
      _currentPointId = plan.points.first.id,
      _selectedPointId = plan.points.first.id;

  final PilgrimagePlan _plan;
  final Set<String> _completedPointIds = {};

  String _currentPointId;
  String _selectedPointId;

  PilgrimagePlan get plan => _plan;

  List<PilgrimagePoint> get points => _plan.points;

  PilgrimagePoint get currentPoint => _pointById(_currentPointId);

  PilgrimagePoint get selectedPoint => _pointById(_selectedPointId);

  List<PilgrimagePoint> get completedPoints => points
      .where((point) => _completedPointIds.contains(point.id))
      .toList(growable: false);

  int get completedCount => _completedPointIds.length;

  int get totalCount => points.length;

  bool get isPlanComplete => completedCount == totalCount;

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
    notifyListeners();
  }

  void completePoint(PilgrimagePoint point) {
    _completedPointIds.add(point.id);

    if (point.id == _currentPointId) {
      final nextPoint = points
          .where((candidate) => !_completedPointIds.contains(candidate.id))
          .firstOrNull;
      if (nextPoint != null) {
        _currentPointId = nextPoint.id;
        _selectedPointId = nextPoint.id;
      }
    }

    notifyListeners();
  }

  void reopenPoint(PilgrimagePoint point) {
    _completedPointIds.remove(point.id);
    _currentPointId = point.id;
    _selectedPointId = point.id;
    notifyListeners();
  }

  PilgrimagePoint _pointById(String id) {
    return points.firstWhere(
      (point) => point.id == id,
      orElse: () => points.first,
    );
  }
}
