import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/application/go/go_completion.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/plan/pilgrimage_models.dart';
import 'package:miriago/plan/pilgrimage_plan_controller.dart';

Future<PilgrimagePlanController> _controller() async {
  final repository = SamplePilgrimageRepository();
  final plan = await repository.loadActivePlan();
  return PilgrimagePlanController(plan: plan, visitRepository: repository);
}

void main() {
  test('completing the current target moves on; undo restores it', () async {
    final controller = await _controller();
    final current = controller.currentPoint!;

    final undo = completePointWithUndo(controller, current);
    expect(controller.statusFor(current), VisitStatus.completed);
    expect(controller.currentPoint?.id, isNot(current.id));

    expect(undoPointCompletion(controller, undo), isTrue);
    expect(controller.statusFor(current), VisitStatus.current);
    expect(controller.currentPoint?.id, current.id);
  });

  test('undo of another point keeps the previous current target', () async {
    final controller = await _controller();
    final current = controller.currentPoint!;
    final other = controller.points.firstWhere(
      (p) => p.id != current.id && p.hasCoordinate,
    );

    final undo = completePointWithUndo(controller, other);
    expect(controller.currentPoint?.id, current.id);

    expect(undoPointCompletion(controller, undo), isTrue);
    expect(controller.statusFor(other), VisitStatus.pending);
    expect(controller.currentPoint?.id, current.id);
  });

  test('nothing to undo once the point was reopened or deleted', () async {
    final controller = await _controller();
    final current = controller.currentPoint!;
    final undo = completePointWithUndo(controller, current);
    controller.reopenPoint(current);
    expect(undoPointCompletion(controller, undo), isFalse);

    final again = completePointWithUndo(controller, current);
    await controller.deletePoint(current);
    expect(undoPointCompletion(controller, again), isFalse);
  });
}
