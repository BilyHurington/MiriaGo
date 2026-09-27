import 'package:flutter/material.dart';

import '../../app/placeholder.dart';
import '../../layout/window_class.dart';

/// Where point details are opened from. Controls which actions show
/// (see DESIGN §8.3 and FEATURE_CHECKLIST §C).
enum PointDetailScope {
  /// 巡礼 page: all actions.
  go,

  /// 片区与点位 page: all actions.
  organize,

  /// From a record detail: all actions.
  records,

  /// Assignment tools: navigation, move group, delete, replace reference.
  assign,
}

/// Controls an inline "inspector" panel that shows point details next to a
/// list/map on wide layouts. Pages that support it wrap their body in
/// [PointInspectorScope] and render a [PointInspectorPanel].
class PointInspectorController extends ChangeNotifier {
  String? _pointId;
  PointDetailScope _scope = PointDetailScope.go;

  String? get pointId => _pointId;
  PointDetailScope get scope => _scope;
  bool get isOpen => _pointId != null;

  void show(String pointId, {PointDetailScope scope = PointDetailScope.go}) {
    _pointId = pointId;
    _scope = scope;
    notifyListeners();
  }

  void close() {
    if (_pointId == null) return;
    _pointId = null;
    notifyListeners();
  }
}

class PointInspectorScope extends InheritedNotifier<PointInspectorController> {
  const PointInspectorScope({
    required PointInspectorController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static PointInspectorController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PointInspectorScope>()
      ?.notifier;
}

/// Renders the details of the controller's point (empty when closed).
/// OWNER: feature agent A (go/points).
class PointInspectorPanel extends StatelessWidget {
  const PointInspectorPanel({required this.controller, super.key});

  final PointInspectorController controller;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Opens point details. On wide layouts inside a [PointInspectorScope]
/// the inline inspector is used; otherwise an adaptive sheet/dialog.
/// OWNER: feature agent A (go/points).
Future<void> showPointDetail(
  BuildContext context, {
  required String pointId,
  PointDetailScope scope = PointDetailScope.go,
}) async {
  final inspector = PointInspectorScope.maybeOf(context);
  if (inspector != null && context.layout.showsListDetail) {
    inspector.show(pointId, scope: scope);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const FeaturePlaceholder(title: '点位详情'),
    ),
  );
}
