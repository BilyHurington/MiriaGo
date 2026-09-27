import 'package:flutter/foundation.dart';

import '../../plan/pilgrimage_models.dart';
import '../../plan/pilgrimage_plan_controller.dart';

/// What is needed to undo 「标记完成」 from the result toast (DESIGN Δ15).
@immutable
class GoCompletionUndo {
  const GoCompletionUndo({
    required this.pointId,
    required this.previousCurrentPointId,
  });

  final String pointId;

  /// The current target before completing (may be the point itself).
  final String? previousCurrentPointId;
}

/// Completes [point] through the controller (which moves the current
/// target on as the old app did) and returns the data to undo it.
GoCompletionUndo completePointWithUndo(
  PilgrimagePlanController controller,
  PilgrimagePoint point,
) {
  final undo = GoCompletionUndo(
    pointId: point.id,
    previousCurrentPointId: controller.currentPoint?.id,
  );
  controller.completePoint(point);
  return undo;
}

/// Reopens the completed point and restores the previous current target.
///
/// Returns false when there is nothing to undo (the point is gone or was
/// reopened meanwhile). `reopenPoint` makes a positioned point the current
/// target (old behaviour); when another point was the target before, it is
/// restored as long as it is still pending and positioned.
bool undoPointCompletion(
  PilgrimagePlanController controller,
  GoCompletionUndo undo,
) {
  if (controller.isDisposed) return false;
  final point = controller.pointById(undo.pointId);
  if (point == null || controller.statusFor(point) != VisitStatus.completed) {
    return false;
  }
  controller.reopenPoint(point);
  final previousId = undo.previousCurrentPointId;
  if (previousId == null || previousId == point.id) return true;
  final previous = controller.pointById(previousId);
  if (previous != null &&
      previous.hasCoordinate &&
      controller.statusFor(previous) != VisitStatus.completed &&
      controller.currentPoint?.id != previous.id) {
    controller.setCurrentPoint(previous);
  }
  return true;
}
