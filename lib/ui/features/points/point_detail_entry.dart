import 'package:flutter/material.dart';

import '../../layout/adaptive_modal.dart';
import '../../layout/window_class.dart';
import '../../../plan/pilgrimage_models.dart';
import 'point_detail_view.dart';

export 'point_detail_view.dart' show PointDetailView;

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

/// Which actions point details offer for a scope and point state
/// (old `_PointDetailActions` + the callers' callbacks, DESIGN Δ9).
@immutable
class PointDetailActions {
  const PointDetailActions({
    required this.camera,
    required this.completion,
    required this.setCurrent,
    required this.edit,
  });

  factory PointDetailActions.of(
    PointDetailScope scope, {
    required VisitStatus status,
    required bool hasCoordinate,
  }) {
    final full = scope != PointDetailScope.assign;
    return PointDetailActions(
      camera: full,
      completion: full,
      setCurrent: full && hasCoordinate && status != VisitStatus.current,
      edit: full,
    );
  }

  /// 拍摄参考 (assign scope: hidden; its callback toasts 「请先完成片区分配」).
  final bool camera;

  /// 标记完成 / 取消完成.
  final bool completion;

  /// 设为当前目标 (needs coordinates; hidden for the current target).
  final bool setCurrent;

  /// 编辑点位.
  final bool edit;

  // Navigation, 移动到片区, 替换参考图 and 删除点位 are available everywhere.
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
    if (_pointId == pointId && _scope == scope) return;
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
    this.alwaysInline = false,
    super.key,
  }) : super(notifier: controller);

  /// When true, [showPointDetail] uses the inspector in every window size
  /// (the 巡礼 page pages details inside its bottom sheet on compact).
  /// Otherwise only from the `expanded` class up.
  final bool alwaysInline;

  static PointInspectorController? maybeOf(BuildContext context) =>
      _scopeOf(context)?.notifier;

  static PointInspectorScope? _scopeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PointInspectorScope>();

  @override
  bool updateShouldNotify(
    covariant InheritedNotifier<PointInspectorController> oldWidget,
  ) =>
      super.updateShouldNotify(oldWidget) ||
      (oldWidget is PointInspectorScope &&
          oldWidget.alwaysInline != alwaysInline);
}

/// Renders the details of the controller's point (empty when closed).
class PointInspectorPanel extends StatelessWidget {
  const PointInspectorPanel({required this.controller, super.key});

  final PointInspectorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pointId = controller.pointId;
        if (pointId == null) return const SizedBox.shrink();
        return PointDetailView(
          key: ValueKey('point-inspector-$pointId'),
          pointId: pointId,
          scope: controller.scope,
          onClose: controller.close,
        );
      },
    );
  }
}

/// Opens point details. On wide layouts inside a [PointInspectorScope]
/// the inline inspector is used; otherwise an adaptive sheet/dialog.
Future<void> showPointDetail(
  BuildContext context, {
  required String pointId,
  PointDetailScope scope = PointDetailScope.go,
}) async {
  final inspectorScope = PointInspectorScope._scopeOf(context);
  final inspector = inspectorScope?.notifier;
  if (inspector != null &&
      (inspectorScope!.alwaysInline || context.layout.showsListDetail)) {
    inspector.show(pointId, scope: scope);
    return;
  }
  await showAdaptiveSheet<void>(
    context,
    title: '点位详情',
    scrollable: false,
    padding: EdgeInsets.zero,
    builder: (sheetContext) => PointDetailView(
      pointId: pointId,
      scope: scope,
      modal: true,
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
  );
}
