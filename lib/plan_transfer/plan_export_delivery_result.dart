enum PlanExportDeliveryAction { saved, shared, canceled }

class PlanExportCanceledException implements Exception {
  const PlanExportCanceledException();
}

abstract class PreparedPlanExportDestination {
  Future<PlanExportDeliveryResult> save(List<int> bytes);
}

class PlanExportDeliveryResult {
  const PlanExportDeliveryResult(this.action, {this.path});

  final PlanExportDeliveryAction action;
  final String? path;
}
