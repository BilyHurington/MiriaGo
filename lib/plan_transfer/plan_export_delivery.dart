import 'plan_export_delivery_save.dart'
    if (dart.library.html) 'plan_export_delivery_web.dart'
    if (dart.library.io) 'plan_export_delivery_io.dart';
import 'plan_export_delivery_result.dart';

Future<PlanExportDeliveryResult> deliverPlanExport({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
  required String shareSubject,
  required String shareText,
  required String extension,
  PreparedPlanExportDestination? destination,
}) {
  if (destination != null) {
    return destination.save(bytes);
  }
  return deliverPlanExportImpl(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
    shareSubject: shareSubject,
    shareText: shareText,
    extension: extension,
  );
}

Future<PreparedPlanExportDestination?> preparePlanExportDestination({
  required String fileName,
  required String mimeType,
  required String extension,
}) {
  return preparePlanExportDestinationImpl(
    fileName: fileName,
    mimeType: mimeType,
    extension: extension,
  );
}
